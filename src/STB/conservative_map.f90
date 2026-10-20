!>
!> 3D conservative remap of a volumetric source given on another mesh.
!>
!> A qvol-file without direction is a Tecplot structured field (cell-centred) on its own mesh,
!> the donor. Every receiver cell takes from each donor cell it overlaps a share of the donor
!> power proportional to the overlap volume over, under the rule covered (qvol-remap, the
!> default), the donor volume that the receiver blocks of the same file cover: the power of a
!> donor cell that the receivers cover only in part goes entirely into the covered part, so
!> the power of every donor cell touched by a receiver is conserved (the rule of the IC-power
!> feature of the first ATLAS, right when the field holds no power outside the blocks); or,
!> under the rule fraction, the whole donor volume: the blocks take the volume fraction of the
!> power (right when they are a part of the field, e.g. a symmetry sector, and the power
!> outside them belongs elsewhere). The receiver value is the received power over the cell
!> volume (W/m3). The donor variable is read by name: power (W per donor cell) or qvol (W/m3,
!> multiplied by the donor cell volume).
!>
!> The overlap volumes come from hexOverlapVolume (both cells split into tetrahedra and clipped
!> exactly, as the chimera search does on warped cells); a bucket grid over the donor cells keeps
!> the search linear. The records are gathered per thread and stored cell by cell in the order
!> of the cells, so the result does not depend on the number of threads.
!>
module st_conservative_mod
  use, intrinsic :: iso_fortran_env, only: R8 => real64
  use global_mod,   only: llen, verbose
  use grid_mod,     only: block_type, mesh_config_type, mesh_cfg, import_nodes
  use st_block_mod, only: st_block
  implicit none
  private
  public :: build_3d_conservative
  public :: is_tecplot_file

  !> records (receiver cell, donor cell, overlap volume) gathered by one thread
  type :: buf_t
    integer               :: n = 0
    integer,  allocatable :: cell(:), donor(:)
    real(R8), allocatable :: vol(:)
  end type buf_t

  !> the records of one receiver block, cell by cell (CSR)
  type :: csr_t
    integer,  allocatable :: ptr(:)       ! (0:ncell)
    integer,  allocatable :: donor(:)
    real(R8), allocatable :: vol(:)
  end type csr_t

  !> the donor field: cells numbered linearly over its blocks, and a bucket grid over them
  type :: donor_t
    integer               :: nblk = 0, ncell = 0
    integer,  allocatable :: off(:), ni(:), nj(:), nk(:)   ! per block: cell offset and dims
    real(R8), allocatable :: vol(:), power(:)              ! per cell: volume, power (W)
    integer               :: nb(3) = 1                     ! buckets per direction
    real(R8)              :: glo(3) = 0.d0, ext(3) = 1.d0  ! grid origin and extent
    integer,  allocatable :: bptr(:), bcell(:)             ! bucket -> donor cells (CSR)
  end type donor_t

contains

  !> .true. when the file opens and carries a Tecplot header (VARIABLES or ZONE in its first lines)
  logical function is_tecplot_file(file)
    implicit none
    character(len=*), intent(in) :: file
    integer :: u, ios, n
    character(len=1024) :: line
    is_tecplot_file = .false.
    open(newunit=u, file=trim(file), status='old', action='read', iostat=ios)
    if (ios /= 0) return
    n = 0
    do
      read(u,'(A)',iostat=ios) line
      if (ios /= 0) exit
      if (len_trim(line) == 0) cycle
      n = n + 1
      if (index(upper(line),'VARIABLES') > 0 .or. index(upper(line),'ZONE') > 0) then
        is_tecplot_file = .true.
        exit
      endif
      if (n >= 10) exit
    enddo
    close(u)
  end function is_tecplot_file


  !> Remap the field of `file` onto the receiver blocks `receivers` (ids in `blocks`) under `rule`
  !> (covered or fraction): the qvol of every receiver cell in var_blocks(receiver)%var.
  subroutine build_3d_conservative(file, rule, blocks, var_blocks, receivers)
    use Lib_ORION_data,   only: orion_data
    use Lib_Tecplot,      only: tec_read_structured_multiblock
    use intersection_mod, only: hexOverlapVolume, fs
    !$ use omp_lib,       only: omp_get_max_threads, omp_get_thread_num
    implicit none
    character(len=*), intent(in)    :: file, rule
    type(block_type), intent(in)    :: blocks(:)
    type(st_block),   intent(inout) :: var_blocks(:)
    integer,          intent(in)    :: receivers(:)
    ! Local
    type(orion_data)              :: io
    type(block_type), allocatable :: dblk(:)
    type(mesh_config_type)        :: dcfg
    type(donor_t)                 :: don
    type(buf_t),      allocatable :: tb(:)
    type(csr_t),      allocatable :: rec(:)
    integer,          allocatable :: cand(:), fill(:)
    real(R8),         allocatable :: vcov(:)
    character(len=32)             :: varname
    character(len=llen)           :: ext
    integer  :: err, iv, ndir, nvar, b, i, j, k, d, c, m, r, br, ni, nj, nk, ncell, nth, tid, ncand, ntot, n_lost, n_part
    real(R8) :: rhex(3,8), dhex(3,8), rlo(3), rhi(3), dlo(3), dhi(3), vr, vr_tet, vclip, vint
    real(R8) :: ptot, mapped, mapped_other, lost, pw, pw_other, vrec, vrec_cov, vcell_cov
    logical  :: per_cell, covered

    covered = (trim(rule) == 'covered')
    if (.not. covered .and. trim(rule) /= 'fraction') then
      write(*,'(A)') '[ERROR] qvol-remap '//trim(rule)//' not allowed (allowed: covered, fraction)'
      stop 1
    endif
    write(*,'(A)') '   3D conservative source from '//trim(file)//' (rule '//trim(rule)//')'

    ! The remap needs cell volumes: a mesh without a third coordinate has none
    if (mesh_cfg%meshType < 1) then
      write(*,'(A)') '[ERROR] qvol-file '//trim(file)//': a 3D field is remapped by cell volumes, which a 2D (x, y)'// &
                     ' mesh has not (give the mesh with three coordinates, or a 1D profile with direction)'
      stop 1
    endif

    ! ---- donor field --------------------------------------------------------------------------
    ext = ''
    i = index(file, '.', back=.true.)
    if (i > 0) ext = lower(file(i+1:))
    io%tec%format = 'ascii'
    if (trim(ext) == 'szplt') io%tec%format = 'binary'
    err = tec_read_structured_multiblock(orion=io, filename=trim(file))
    if (err /= 0 .or. .not.allocated(io%block)) then
      write(*,'(A)') '[ERROR] qvol-file '//trim(file)//': cannot be read as a Tecplot structured field (one or more'// &
                     ' ordered zones with three coordinates and a cell-centred variable)'
      stop 1
    endif
    ndir = size(io%block(1)%mesh, 1)
    if (ndir /= 3) then
      write(*,'(A,I0,A)') '[ERROR] qvol-file '//trim(file)//': the field has ', ndir, &
                          ' coordinates: a 3D field needs x, y and z'
      stop 1
    endif
    if (.not.allocated(io%varnames)) then
      write(*,'(A)') '[ERROR] qvol-file '//trim(file)//': no VARIABLES header'
      stop 1
    endif
    nvar = size(io%varnames) - ndir
    if (nvar < 1) then
      write(*,'(A)') '[ERROR] qvol-file '//trim(file)//': no variable after the coordinates (expected power, the'// &
                     ' power of every cell in W, or qvol, the power density in W/m3)'
      stop 1
    endif
    iv = 0
    per_cell = .true.
    do i = 1, nvar
      varname = unquote(io%varnames(ndir+i))
      if (lower(trim(varname)) == 'power' .or. lower(trim(varname)) == 'qvol') then
        if (iv /= 0) then
          write(*,'(A)') '[ERROR] qvol-file '//trim(file)//': both power and qvol are in the file (keep one)'
          stop 1
        endif
        iv = i
        per_cell = (lower(trim(varname)) == 'power')
      endif
    enddo
    if (iv == 0) then
      write(*,'(A)') '[ERROR] qvol-file '//trim(file)//': no variable named power (W per cell) or qvol (W/m3);'// &
                     ' the file has: '//trim(join_names(io%varnames(ndir+1:)))
      stop 1
    endif
    varname = unquote(io%varnames(ndir+iv))
    if (io%tec%node) then
      write(*,'(A)') '[ERROR] qvol-file '//trim(file)//': variable '//trim(varname)//' is nodal: the field must be'// &
                     ' cell-centred (VARLOCATION=([1-3]=NODAL,[4]=CELLCENTERED))'
      stop 1
    endif

    ! donor geometry: classified on its own (dcfg), the global mesh_cfg keeps describing the STB mesh
    allocate(dblk(size(io%block)))
    call import_nodes(input=io, output=dblk, cfg=dcfg)
    if (dcfg%meshType < 1) then
      write(*,'(A)') '[ERROR] qvol-file '//trim(file)//': the field lies on a single node plane: a 3D field needs'// &
                     ' cells with a volume'
      stop 1
    endif
    don%nblk = size(dblk)
    allocate(don%off(don%nblk), don%ni(don%nblk), don%nj(don%nblk), don%nk(don%nblk))
    don%ncell = 0
    do b = 1, don%nblk
      call dblk(b)%compute_volume(gc=[0, 0, 0])
      call dblk(b)%compute_bounding(gc=[0, 0, 0])
      don%off(b) = don%ncell
      don%ni(b) = dblk(b)%dim(1); don%nj(b) = dblk(b)%dim(2); don%nk(b) = dblk(b)%dim(3)
      don%ncell = don%ncell + don%ni(b)*don%nj(b)*don%nk(b)
    enddo
    allocate(don%vol(don%ncell), don%power(don%ncell))
    do b = 1, don%nblk
      d = don%off(b)
      do k = 1, don%nk(b); do j = 1, don%nj(b); do i = 1, don%ni(b)
        d = d + 1
        don%vol(d) = dblk(b)%vol(i,j,k)
        if (per_cell) then
          don%power(d) = io%block(b)%vars(iv,i,j,k)
        else
          don%power(d) = io%block(b)%vars(iv,i,j,k) * don%vol(d)
        endif
      enddo; enddo; enddo
    enddo
    ptot = sum(don%power)
    if (per_cell) then
      write(*,'(A,I0,A,I0,A)') '     donor: ', don%nblk, ' block(s), ', don%ncell, ' cells, variable '// &
                               trim(varname)//' (W per cell)'
    else
      write(*,'(A,I0,A,I0,A)') '     donor: ', don%nblk, ' block(s), ', don%ncell, ' cells, variable '// &
                               trim(varname)//' (W/m3, times the donor cell volume)'
    endif
    write(*,'(A,ES12.5,A)') '     donor power: ', ptot, ' W'
    call build_buckets(don, dblk)

    ! ---- overlaps: receiver cell by receiver cell, gathered per thread ---------------------------
    nth = 1
    !$ nth = omp_get_max_threads()
    allocate(rec(size(receivers)))
    do r = 1, size(receivers)
      br = receivers(r)
      ni = blocks(br)%dim(1); nj = blocks(br)%dim(2); nk = blocks(br)%dim(3)
      ncell = ni*nj*nk
      if (allocated(tb)) deallocate(tb)
      allocate(tb(0:nth-1))

      !$omp parallel default(none) shared(blocks, br, don, dblk, tb, ni, nj, nk) &
      !$omp& private(i, j, k, c, m, d, tid, ncand, cand, rhex, dhex, rlo, rhi, dlo, dhi, vr, vr_tet, vclip, vint)
      tid = 0
      !$ tid = omp_get_thread_num()
      !$omp do collapse(3) schedule(static)
      do k = 1, nk; do j = 1, nj; do i = 1, ni
        rlo = blocks(br)%bbmin(i,j,k)%c(1:3)
        rhi = blocks(br)%bbmax(i,j,k)%c(1:3)
        call candidates(don, rlo, rhi, cand, ncand)
        if (ncand == 0) cycle
        call corners(blocks(br), i, j, k, rhex)
        vr = blocks(br)%vol(i,j,k)
        c = i + ni*((j-1) + nj*(k-1))
        do m = 1, ncand
          d = cand(m)
          call donor_box(don, dblk, d, dlo, dhi)
          if (any(dlo > rhi) .or. any(dhi < rlo)) cycle
          call donor_corners(don, dblk, d, dhex)
          call hexOverlapVolume(rhex, dhex, vclip, vr_tet)
          if (vr > 0.d0 .and. vr_tet > 0.d0) then
            vint = vclip / vr_tet * vr          ! the fraction of the receiver, on its own volume
          else
            vint = vclip / fs**3
          endif
          if (vint <= 1.d-12 * max(vr, don%vol(d))) cycle
          call push(tb(tid), c, d, vint)
        enddo
      enddo; enddo; enddo
      !$omp end do
      !$omp end parallel

      ! the records cell by cell (each cell's records come from one thread, in their order)
      allocate(rec(r)%ptr(0:ncell))
      rec(r)%ptr = 0
      do tid = 0, nth-1
        do m = 1, tb(tid)%n
          c = tb(tid)%cell(m)
          rec(r)%ptr(c) = rec(r)%ptr(c) + 1
        enddo
      enddo
      do c = 1, ncell
        rec(r)%ptr(c) = rec(r)%ptr(c) + rec(r)%ptr(c-1)
      enddo
      ntot = rec(r)%ptr(ncell)
      allocate(rec(r)%donor(ntot), rec(r)%vol(ntot))
      if (allocated(fill)) deallocate(fill)
      allocate(fill(ncell))
      fill(1:ncell) = rec(r)%ptr(0:ncell-1)
      do tid = 0, nth-1
        do m = 1, tb(tid)%n
          c = tb(tid)%cell(m)
          fill(c) = fill(c) + 1
          rec(r)%donor(fill(c)) = tb(tid)%donor(m)
          rec(r)%vol(fill(c))   = tb(tid)%vol(m)
        enddo
      enddo
      if (verbose) write(*,'(A,I3,A,I0,A,I0,A)') '     block ', br, ': ', ncell, ' cells, ', ntot, ' overlaps'
    enddo
    if (allocated(tb)) deallocate(tb)
    if (allocated(fill)) deallocate(fill)
    if (allocated(cand)) deallocate(cand)

    ! ---- the donor volume covered by the receivers, then the receiver values --------------------
    allocate(vcov(don%ncell))
    vcov = 0.d0
    do r = 1, size(receivers)
      do m = 1, size(rec(r)%donor)
        vcov(rec(r)%donor(m)) = vcov(rec(r)%donor(m)) + rec(r)%vol(m)
      enddo
    enddo

    mapped = 0.d0; mapped_other = 0.d0; vrec = 0.d0; vrec_cov = 0.d0
    do r = 1, size(receivers)
      br = receivers(r)
      ni = blocks(br)%dim(1); nj = blocks(br)%dim(2); nk = blocks(br)%dim(3)
      call var_blocks(br)%allocate(ni, nj, nk)
      c = 0
      do k = 1, nk; do j = 1, nj; do i = 1, ni
        c = c + 1
        pw = 0.d0          ! the power under the rule
        pw_other = 0.d0    ! and under the other one, for the balance
        vcell_cov = 0.d0
        do m = rec(r)%ptr(c-1)+1, rec(r)%ptr(c)
          d = rec(r)%donor(m)
          if (covered) then
            pw = pw + don%power(d) * rec(r)%vol(m) / vcov(d)
            if (don%vol(d) > 0.d0) pw_other = pw_other + don%power(d) * rec(r)%vol(m) / don%vol(d)
          else
            if (don%vol(d) > 0.d0) pw = pw + don%power(d) * rec(r)%vol(m) / don%vol(d)
            pw_other = pw_other + don%power(d) * rec(r)%vol(m) / vcov(d)
          endif
          vcell_cov = vcell_cov + rec(r)%vol(m)
        enddo
        vr = blocks(br)%vol(i,j,k)
        if (vr > 0.d0) then
          var_blocks(br)%var(i,j,k) = pw / vr
        else
          var_blocks(br)%var(i,j,k) = 0.d0
        endif
        mapped = mapped + pw
        mapped_other = mapped_other + pw_other
        vrec = vrec + vr
        vrec_cov = vrec_cov + min(vcell_cov, vr)
      enddo; enddo; enddo
      write(*,'(A,I3,A,ES12.5,A)') '   Block ', br, ' - 3D conservative qvol from '//trim(file)//' (', &
                                   sum(var_blocks(br)%var * blocks(br)%vol(1:ni,1:nj,1:nk)), ' W)'
    enddo

    ! ---- balance ---------------------------------------------------------------------------------
    lost = 0.d0; n_lost = 0; n_part = 0
    do d = 1, don%ncell
      if (vcov(d) <= 0.d0) then
        lost = lost + don%power(d)
        n_lost = n_lost + 1
      elseif (vcov(d) < (1.d0 - 1.d-6) * don%vol(d)) then
        n_part = n_part + 1
      endif
    enddo
    write(*,'(A,ES12.5,A,ES12.5,A)') '     mapped power: ', mapped, ' W of ', ptot, ' W'
    if (covered) then
      write(*,'(A,ES12.5,A)') '     (the rule fraction would map ', mapped_other, ' W)'
      if (n_part > 0) write(*,'(A,I0,A)') '     ', n_part, ' donor cells are covered in part: their whole power'// &
                                          ' goes into the covered part (rule covered)'
      if (n_lost > 0 .and. abs(lost) > 1.d-9 * max(abs(ptot), tiny(1.d0))) then
        write(*,'(A,ES12.5,A,I0,A)') '[WARNING] qvol-file '//trim(file)//': ', lost, ' W lie in ', n_lost, &
                                     ' donor cells that no receiver block overlaps (not mapped)'
      endif
    else
      write(*,'(A,ES12.5,A)') '     (the rule covered would map ', mapped_other, ' W)'
      if (n_part > 0) write(*,'(A,I0,A)') '     ', n_part, ' donor cells are covered in part: the blocks take'// &
                                          ' their volume fraction of the power (rule fraction)'
      if (abs(ptot - mapped) > 1.d-9 * max(abs(ptot), tiny(1.d0))) then
        write(*,'(A,ES12.5,A)') '     ', ptot - mapped, ' W of the field lie outside the receiver blocks (not mapped)'
      endif
    endif
    if (vrec > 0.d0 .and. vrec - vrec_cov > 1.d-6 * vrec) then
      write(*,'(A,F7.2,A)') '[WARNING] qvol-file '//trim(file)//': ', 100.d0*(vrec - vrec_cov)/vrec, &
                            ' % of the receiver volume lies outside the field (no source there)'
    endif

    deallocate(vcov, rec, dblk)

  end subroutine build_3d_conservative


  ! ---- helpers -----------------------------------------------------------------------------------

  !> the bucket grid: every donor cell in the buckets its bounding box spans
  subroutine build_buckets(don, dblk)
    implicit none
    type(donor_t),    intent(inout) :: don
    type(block_type), intent(in)    :: dblk(:)
    integer  :: b, d, ax, nbin, lo(3), hi(3), ib, jb, kb, bin, pass
    real(R8) :: glo(3), ghi(3), dlo(3), dhi(3)
    integer, allocatable :: cnt(:)

    glo = dblk(1)%block_bounding_min
    ghi = dblk(1)%block_bounding_max
    do b = 2, size(dblk)
      glo = min(glo, dblk(b)%block_bounding_min)
      ghi = max(ghi, dblk(b)%block_bounding_max)
    enddo
    don%glo = glo
    do ax = 1, 3
      don%ext(ax) = max(ghi(ax) - glo(ax), 1.d-30) * (1.d0 + 1.d-9)
      don%nb(ax) = max(1, min(128, nint(dble(don%ncell)**(1.d0/3.d0))))
      if (ghi(ax) - glo(ax) <= 0.d0) don%nb(ax) = 1
    enddo
    nbin = don%nb(1)*don%nb(2)*don%nb(3)
    allocate(cnt(nbin), don%bptr(0:nbin))

    do pass = 1, 2
      cnt = 0
      do d = 1, don%ncell
        call donor_box(don, dblk, d, dlo, dhi)
        call bucket_range(don, dlo, dhi, lo, hi)
        do kb = lo(3), hi(3); do jb = lo(2), hi(2); do ib = lo(1), hi(1)
          bin = ib + don%nb(1)*((jb-1) + don%nb(2)*(kb-1))
          cnt(bin) = cnt(bin) + 1
          if (pass == 2) don%bcell(don%bptr(bin-1) + cnt(bin)) = d
        enddo; enddo; enddo
      enddo
      if (pass == 1) then
        don%bptr(0) = 0
        do bin = 1, nbin
          don%bptr(bin) = don%bptr(bin-1) + cnt(bin)
        enddo
        allocate(don%bcell(don%bptr(nbin)))
      endif
    enddo
    deallocate(cnt)
  end subroutine build_buckets


  !> bucket index range spanned by a box (clamped to the grid)
  pure subroutine bucket_range(don, blo, bhi, lo, hi)
    implicit none
    type(donor_t), intent(in)  :: don
    real(R8),      intent(in)  :: blo(3), bhi(3)
    integer,       intent(out) :: lo(3), hi(3)
    integer :: ax
    do ax = 1, 3
      lo(ax) = min(don%nb(ax), max(1, int((blo(ax) - don%glo(ax)) / don%ext(ax) * don%nb(ax)) + 1))
      hi(ax) = min(don%nb(ax), max(1, int((bhi(ax) - don%glo(ax)) / don%ext(ax) * don%nb(ax)) + 1))
    enddo
  end subroutine bucket_range


  !> the donor cells of the buckets a receiver box spans (each once, in increasing order)
  subroutine candidates(don, rlo, rhi, cand, ncand)
    implicit none
    type(donor_t), intent(in)    :: don
    real(R8),      intent(in)    :: rlo(3), rhi(3)
    integer, allocatable, intent(inout) :: cand(:)
    integer,       intent(out)   :: ncand
    integer :: lo(3), hi(3), ib, jb, kb, bin, m, n, key, p
    integer, allocatable :: tmp(:)

    ncand = 0
    if (any(rhi < don%glo) .or. any(rlo > don%glo + don%ext)) return
    if (.not.allocated(cand)) allocate(cand(64))
    call bucket_range(don, rlo, rhi, lo, hi)
    do kb = lo(3), hi(3); do jb = lo(2), hi(2); do ib = lo(1), hi(1)
      bin = ib + don%nb(1)*((jb-1) + don%nb(2)*(kb-1))
      do m = don%bptr(bin-1)+1, don%bptr(bin)
        if (ncand == size(cand)) then
          allocate(tmp(2*size(cand)))
          tmp(1:ncand) = cand(1:ncand)
          call move_alloc(tmp, cand)
        endif
        ncand = ncand + 1
        cand(ncand) = don%bcell(m)
      enddo
    enddo; enddo; enddo

    ! sort (insertion: the lists are short) and drop the repeats of cells spanning several buckets
    do n = 2, ncand
      key = cand(n)
      p = n - 1
      do while (p >= 1)
        if (cand(p) <= key) exit
        cand(p+1) = cand(p)
        p = p - 1
      enddo
      cand(p+1) = key
    enddo
    n = 0
    do m = 1, ncand
      if (n == 0) then
        n = 1
      elseif (cand(m) /= cand(n)) then
        n = n + 1
        cand(n) = cand(m)
      endif
    enddo
    ncand = n
  end subroutine candidates


  !> block and (i, j, k) of the donor cell d
  pure subroutine donor_ijk(don, d, b, i, j, k)
    implicit none
    type(donor_t), intent(in)  :: don
    integer,       intent(in)  :: d
    integer,       intent(out) :: b, i, j, k
    integer :: l
    b = don%nblk
    do while (b > 1)
      if (don%off(b) < d) exit
      b = b - 1
    enddo
    l = d - don%off(b) - 1
    i = mod(l, don%ni(b)) + 1
    j = mod(l / don%ni(b), don%nj(b)) + 1
    k = l / (don%ni(b)*don%nj(b)) + 1
  end subroutine donor_ijk


  !> bounding box of the donor cell d
  pure subroutine donor_box(don, dblk, d, dlo, dhi)
    implicit none
    type(donor_t),    intent(in)  :: don
    type(block_type), intent(in)  :: dblk(:)
    integer,          intent(in)  :: d
    real(R8),         intent(out) :: dlo(3), dhi(3)
    integer :: b, i, j, k
    call donor_ijk(don, d, b, i, j, k)
    dlo = dblk(b)%bbmin(i,j,k)%c(1:3)
    dhi = dblk(b)%bbmax(i,j,k)%c(1:3)
  end subroutine donor_box


  !> corner nodes of the donor cell d, scaled as the chimera search
  pure subroutine donor_corners(don, dblk, d, hex)
    implicit none
    type(donor_t),    intent(in)  :: don
    type(block_type), intent(in)  :: dblk(:)
    integer,          intent(in)  :: d
    real(R8),         intent(out) :: hex(3,8)
    integer :: b, i, j, k
    call donor_ijk(don, d, b, i, j, k)
    call corners(dblk(b), i, j, k, hex)
  end subroutine donor_corners


  !> corner nodes of cell (i, j, k), scaled by fs, in the order of hexOverlapVolume
  !> (1 + 4*di + dj + 2*dk for the corner (i-1+di, j-1+dj, k-1+dk))
  pure subroutine corners(blk, i, j, k, hex)
    use intersection_mod, only: fs
    implicit none
    type(block_type), intent(in)  :: blk
    integer,          intent(in)  :: i, j, k
    real(R8),         intent(out) :: hex(3,8)
    integer :: di, dj, dk
    do dk = 0, 1; do dj = 0, 1; do di = 0, 1
      hex(:, 1 + 4*di + dj + 2*dk) = blk%node(i-1+di, j-1+dj, k-1+dk)%c(1:3) * fs
    enddo; enddo; enddo
  end subroutine corners


  !> append one record to a thread buffer
  subroutine push(buf, c, d, v)
    implicit none
    type(buf_t), intent(inout) :: buf
    integer,     intent(in)    :: c, d
    real(R8),    intent(in)    :: v
    integer,  allocatable :: ti(:)
    real(R8), allocatable :: tr(:)
    integer :: cap
    if (.not.allocated(buf%cell)) then
      allocate(buf%cell(1024), buf%donor(1024), buf%vol(1024))
      buf%n = 0
    endif
    if (buf%n == size(buf%cell)) then
      cap = 2*size(buf%cell)
      allocate(ti(cap)); ti(1:buf%n) = buf%cell(1:buf%n);  call move_alloc(ti, buf%cell)
      allocate(ti(cap)); ti(1:buf%n) = buf%donor(1:buf%n); call move_alloc(ti, buf%donor)
      allocate(tr(cap)); tr(1:buf%n) = buf%vol(1:buf%n);   call move_alloc(tr, buf%vol)
    endif
    buf%n = buf%n + 1
    buf%cell(buf%n)  = c
    buf%donor(buf%n) = d
    buf%vol(buf%n)   = v
  end subroutine push


  pure function upper(s) result(u)
    implicit none
    character(len=*), intent(in) :: s
    character(len=len(s)) :: u
    integer :: i, c
    u = s
    do i = 1, len(s)
      c = iachar(s(i:i))
      if (c >= iachar('a') .and. c <= iachar('z')) u(i:i) = achar(c - 32)
    enddo
  end function upper


  pure function lower(s) result(l)
    implicit none
    character(len=*), intent(in) :: s
    character(len=len(s)) :: l
    integer :: i, c
    l = s
    do i = 1, len(s)
      c = iachar(s(i:i))
      if (c >= iachar('A') .and. c <= iachar('Z')) l(i:i) = achar(c + 32)
    enddo
  end function lower


  !> a variable name without quotes or blanks
  pure function unquote(s) result(u)
    implicit none
    character(len=*), intent(in) :: s
    character(len=len(s)) :: u
    integer :: i, n
    u = ''
    n = 0
    do i = 1, len_trim(s)
      if (s(i:i) == '"' .or. s(i:i) == "'" .or. s(i:i) == ' ') cycle
      n = n + 1
      u(n:n) = s(i:i)
    enddo
  end function unquote


  !> the names, separated by commas
  function join_names(names) result(s)
    implicit none
    character(len=*), intent(in) :: names(:)
    character(len=:), allocatable :: s
    integer :: i
    s = ''
    do i = 1, size(names)
      if (i > 1) s = s//', '
      s = s//trim(unquote(names(i)))
    enddo
  end function join_names

end module st_conservative_mod
