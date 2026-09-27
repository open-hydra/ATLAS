!> General-purpose field interpolation utilities.
!>
!> Two independent capabilities:
!>   1. interpolate_from_file  – reads a source file and nearest-neighbor
!>      interpolates its first variable onto a target block.
!>   2. interp_map_t / compute_interp_map / apply_interp_map – compute an
!>      interpolation index-map once, then apply it to any number of
!>      individual scalar fields.
module ic_interpolation_general_mod
  use, intrinsic :: iso_fortran_env, only : R8 => real64
  use ic_block_mod, only: IC_block, var_block
  implicit none
  private
  public :: interpolate_from_file
  public :: interp_map_t, compute_interp_map, apply_interp_map
  public :: rotate_2d_to_3d

  ! ---------------------------------------------------------------
  !  Interpolation index-map type
  ! ---------------------------------------------------------------
  !> Stores, for every target cell (i,j,k), the source block index,
  !> source cell indices, and stencil weights that define the
  !> interpolation.  Built once and reused for each scalar field.
  type :: interp_map_t
    integer :: dim(3) = 0            !< target block dimensions
    integer :: n_stencil = 0         !< stencil size (1 or 8)
    integer,  allocatable :: src_blk(:,:,:)       !< (Ni,Nj,Nk)
    integer,  allocatable :: src_idx(:,:,:,:,:)    !< (3,n_st,Ni,Nj,Nk)
    real(R8), allocatable :: weight(:,:,:,:)       !< (n_st,Ni,Nj,Nk)
  contains
    procedure :: destroy => interp_map_destroy
  end type interp_map_t

  ! ---------------------------------------------------------------
  !  File-interpolation cache (unchanged from previous version)
  ! ---------------------------------------------------------------
  type(var_block), allocatable, save :: source_blocks(:)
  character(len=256),           save :: source_file  = ''
  logical,                      save :: source_ready = .false.


contains


  ! =================================================================
  !  1. interpolate_from_file  (file → nearest-neighbor onto a field)
  ! =================================================================

  subroutine interpolate_from_file(field, blk, filename)
    implicit none
    type(IC_block), intent(in)  :: blk
    real(R8), intent(inout)     :: field(1:blk%dim(1), 1:blk%dim(2), 1:blk%dim(3))
    character(len=*), intent(in) :: filename

    if (.not.source_ready .or. &
        trim(filename) /= trim(source_file)) then
      call load_source(filename)
    endif
    call nearest_neighbor_file(field, blk)
  end subroutine interpolate_from_file


  ! =================================================================
  !  2. Index-map based interpolation (public API)
  ! =================================================================

  !> Build an interpolation map for the given law.
  !> oldblocks : source IC_block array (already loaded & with centers)
  !> tgt       : target IC_block
  !> oldid     : source block id to use (0 = search all)
  !> law       : 'index','multiple','minimum_distance',
  !>             'spherical_minimum_distance'
  subroutine compute_interp_map(map, oldblocks, tgt, oldid, law)
    use global_mod, only: verbose
    implicit none
    type(interp_map_t),  intent(out)   :: map
    type(IC_block),      intent(in)    :: oldblocks(:)
    type(IC_block),      intent(inout) :: tgt
    integer,             intent(in)    :: oldid
    character(len=*),    intent(in)    :: law

    select case (law)
    case ('index')
      call build_index_map(map, oldblocks, tgt, oldid)
    case ('multiple')
      call build_multiple_map(map, oldblocks, tgt, oldid)
    case ('minimum_distance')
      call build_distance_map(map, oldblocks, tgt, oldid)
    case ('spherical_minimum_distance')
      call build_spherical_distance_map(map, oldblocks, tgt, oldid)
    case ('outlaw')
      ! not given: the historical default of the interpolation
      call build_distance_map(map, oldblocks, tgt, oldid)
    case ('extrude')
      ! the source was revolved into a 3D sector when it was read (build_old_solution): nearest revolved cell
      call build_distance_map(map, oldblocks, tgt, oldid)
    case default
      write(*,'(A)') "[ERROR] interpolation-law = '"//trim(law)//"' is not a law (allowed: outlaw, index, multiple,"// &
                     " minimum_distance, spherical_minimum_distance, extrude)"
      stop 1
    end select

    if (verbose) then
      write(*,*) "[LOG] Interpolation map built (law = '", &
        trim(law), "', stencil = ", map%n_stencil, ")"
    endif
  end subroutine compute_interp_map


  !> Apply a precomputed interpolation map to a single scalar field.
  !> field_new(Ni,Nj,Nk) : target field (output)
  !> field_src(nblocks)   : source fields, one var_block per source
  !>                        block; field_src(b)%var(:,:,:) is the data.
  subroutine apply_interp_map(map, field_new, field_src)
    implicit none
    type(interp_map_t), intent(in)    :: map
    real(R8),           intent(inout) :: field_new(:,:,:)
    type(var_block),    intent(in)    :: field_src(:)
    ! Local
    integer  :: i, j, k, p, sb
    integer  :: si, sj, sk
    real(R8) :: val

    !$omp parallel do collapse(3) schedule(static) &
    !$omp& private(i,j,k,p,sb,si,sj,sk,val)
    do k = 1, map%dim(3)
      do j = 1, map%dim(2)
        do i = 1, map%dim(1)
          sb = map%src_blk(i,j,k)
          val = 0.0_R8
          do p = 1, map%n_stencil
            si = map%src_idx(1,p,i,j,k)
            sj = map%src_idx(2,p,i,j,k)
            sk = map%src_idx(3,p,i,j,k)
            val = val + map%weight(p,i,j,k) * field_src(sb)%var(si,sj,sk)
          enddo
          field_new(i,j,k) = val
        enddo
      enddo
    enddo
    !$omp end parallel do
  end subroutine apply_interp_map


  !> Deallocate map arrays.
  subroutine interp_map_destroy(self)
    implicit none
    class(interp_map_t), intent(inout) :: self
    if (allocated(self%src_blk)) deallocate(self%src_blk)
    if (allocated(self%src_idx)) deallocate(self%src_idx)
    if (allocated(self%weight))  deallocate(self%weight)
    self%dim = 0
    self%n_stencil = 0
  end subroutine interp_map_destroy

  ! ---------------------------------------------------------------
  !  2D -> 3D rotation of interpolated fields (index law)
  ! ---------------------------------------------------------------
  !> A one-k-cell source (pure-2D x-r plane, or 3-coordinate one-cell wedge)
  !> describes an axisymmetric field about the x axis. At its donor cell of
  !> azimuth th_d (0 for a pure-2D file: y is the radius and its imported z is
  !> a dummy) the stored components are (u, v_r, v_theta) [pure-2D: v_theta = 0
  !> after the read]. apply_interp_map copied them component-wise; at a target
  !> cell of azimuth th_t = atan2(z, y) they are rotated about x by
  !> dth = th_t - th_d:
  !>   vy = v cos(dth) - w sin(dth) ;  vz = v sin(dth) + w cos(dth)
  !> and the Reynolds-stress tensor (slots R11 R22 R33 R12 R13 R23, omega) by
  !> R' = Q R Q^T with the same Q (R11, omega invariant).
  !> Nothing is rotated for a one-cell target or when the target is a
  !> z-extrusion (y conserved along k: a planar case, plain copy is right); the
  !> two residuals max|dy| and max|dr| along k decide (the smaller wins, no
  !> tolerance). With a law other than 'index' a revolved target stops ICB with
  !> an ERROR (the donors are not on the target's meridian). A target whose r
  !> is conserved worse than the solver's own axisymmetry test (MOSE
  !> Lib_Metrics: 1e-5 r) stops ICB with an ERROR too: it needs a 3D source.
  subroutine rotate_2d_to_3d(map, oldblocks, tgt, src_pure2d, index_law, vel, rst)
    use global_mod, only: verbose
    implicit none
    type(interp_map_t), intent(in)    :: map
    type(IC_block),     intent(in)    :: oldblocks(:)
    type(IC_block),     intent(in)    :: tgt
    logical,            intent(in)    :: src_pure2d
    logical,            intent(in)    :: index_law     !< interpolation-law == 'index'
    real(R8),           intent(inout) :: vel(:,:,:,:)   !< (3,Ni,Nj,Nk) interpolated velocity
    real(R8), optional, intent(inout) :: rst(:,:,:,:)   !< (7,Ni,Nj,Nk) interpolated Reynolds stresses + omega
    ! Local
    integer  :: i, j, k, sb, si, sj
    real(R8) :: dth, c, s, v, w, dy, dr, rmax, r0, rk
    real(R8) :: Ryy, Rzz, Ryz, Rxy, Rxz

    if (tgt%dim(3) == 1) return                            ! one-cell target: nothing to revolve
    if (oldblocks(map%src_blk(1,1,1))%dim(3) /= 1) return   ! 3D source: the index map already did it all

    ! Target k-line geometry: a z-extrusion conserves y along k, a body of revolution conserves
    ! r = sqrt(y^2 + z^2). The smaller residual decides: both are exactly zero for their own
    ! geometry, so thin sectors and thin slabs are told apart without a tolerance.
    dy = 0.0_R8; dr = 0.0_R8; rmax = 0.0_R8
    do k = 0, tgt%dim(3); do j = 0, tgt%dim(2); do i = 0, tgt%dim(1)
      r0 = sqrt(tgt%node(i,j,0)%c(2)**2 + tgt%node(i,j,0)%c(3)**2)
      rk = sqrt(tgt%node(i,j,k)%c(2)**2 + tgt%node(i,j,k)%c(3)**2)
      dy = max(dy, abs(tgt%node(i,j,k)%c(2) - tgt%node(i,j,0)%c(2)))
      dr = max(dr, abs(rk - r0))
      rmax = max(rmax, rk)
    enddo; enddo; enddo
    if (dy <= dr) then
      if (verbose) write(*,*) "[LOG] Target block is a z-extrusion (planar case): no 2D -> 3D rotation applied"
      return
    endif
    ! the field written in these two cases is known to be wrong (up to 86 % away from the
    ! source azimuth): refused instead of written with a WARNING (only velocity / stress
    ! interpolations reach this point; scalar sources are never refused here)
    if (.not. index_law) then
      write(*,'(A)') "[ERROR] rotate_2d_to_3d: one-cell source on a revolved target with interpolation-law /= 'index':"
      write(*,'(A)') "        the velocity cannot be revolved (the donors are picked by Cartesian distance to the source"
      write(*,'(A)') "        plane) and the field is wrong away from the source azimuth. Use interpolation-law = index."
      stop 1
    endif
    if (dr > 1.0e-5_R8 * rmax) then
      write(*,'(A,ES12.5,A,ES12.5,A)') "[ERROR] rotate_2d_to_3d: the target k-lines are neither circles about x (max |dr| = ", &
        dr, ") nor z-lines (max |dy| = ", dy, "): a one-cell source can be revolved only onto a body of revolution about x"
      write(*,'(A)') "        or copied onto a z-extrusion; give a 3D source for this target"
      stop 1
    endif

    !$omp parallel do collapse(3) private(i,j,k,sb,si,sj,dth,c,s,v,w,Ryy,Rzz,Ryz,Rxy,Rxz)
    do k = 1, tgt%dim(3); do j = 1, tgt%dim(2); do i = 1, tgt%dim(1)
      dth = atan2(tgt%center(i,j,k)%c(3), tgt%center(i,j,k)%c(2))
      if (.not. src_pure2d) then
        ! one-cell wedge source: subtract the donor cell azimuth (0 for a wedge symmetric about z = 0)
        sb = map%src_blk(i,j,k); si = map%src_idx(1,1,i,j,k); sj = map%src_idx(2,1,i,j,k)
        dth = dth - atan2(oldblocks(sb)%center(si,sj,1)%c(3), oldblocks(sb)%center(si,sj,1)%c(2))
      endif
      c = cos(dth); s = sin(dth)
      v = vel(2,i,j,k); w = vel(3,i,j,k)
      vel(2,i,j,k) = v*c - w*s
      vel(3,i,j,k) = v*s + w*c
      if (present(rst)) then
        Ryy = rst(2,i,j,k)*c*c + rst(3,i,j,k)*s*s - 2.0_R8*rst(6,i,j,k)*s*c
        Rzz = rst(2,i,j,k)*s*s + rst(3,i,j,k)*c*c + 2.0_R8*rst(6,i,j,k)*s*c
        Ryz = (rst(2,i,j,k) - rst(3,i,j,k))*s*c + rst(6,i,j,k)*(c*c - s*s)
        Rxy = rst(4,i,j,k)*c - rst(5,i,j,k)*s
        Rxz = rst(4,i,j,k)*s + rst(5,i,j,k)*c
        rst(2,i,j,k) = Ryy; rst(3,i,j,k) = Rzz; rst(4,i,j,k) = Rxy; rst(5,i,j,k) = Rxz; rst(6,i,j,k) = Ryz
      endif
    enddo; enddo; enddo
    !$omp end parallel do
  end subroutine rotate_2d_to_3d



  ! =================================================================
  !  Map builders (private)
  ! =================================================================

  ! ---------------------------------------------------------------
  !  INDEX map builder
  ! ---------------------------------------------------------------
  subroutine build_index_map(map, oldblocks, tgt, oldid)
    use global_mod, only: verbose
    implicit none
    type(interp_map_t), intent(out) :: map
    type(IC_block),     intent(in)  :: oldblocks(:)
    type(IC_block),     intent(in)  :: tgt
    integer,            intent(in)  :: oldid
    ! Local
    integer :: b, i, j, k, ksrc
    character(2) :: sym_type

    b = tgt%id
    if (oldid > 0) b = oldid

    ! Determine 2D vs 3D
    if (oldblocks(b)%dim(3) == tgt%dim(3)) then
      sym_type = "3D"
    elseif (oldblocks(b)%dim(3) == 1) then
      sym_type = "2D"
    else
      write(*,*) "[ERROR] 3D Meshes with different Nz"
      write(*,*) " Can't use law = 'index' in this case"
      stop 1
    endif

    ! Validate Ni, Nj match
    if (oldblocks(b)%dim(1) /= tgt%dim(1) .or. oldblocks(b)%dim(2) /= tgt%dim(2)) then
      write(*,*) "[ERROR] 2D and 3D Mesh do not have the same Nx and Ny elements"
      stop 1
    endif

    if (verbose) then
      if (sym_type == "2D") then
        write(*,*) "[LOG] 2D-3D Index based interpolation"
      else
        write(*,*) "[LOG] 3D-3D Index based interpolation"
      endif
    endif

    map%dim = tgt%dim(1:3)
    map%n_stencil = 1
    allocate(map%src_blk(map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%src_idx(3, 1, map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%weight(1, map%dim(1), map%dim(2), map%dim(3)))

    map%src_blk = b
    map%weight  = 1.0_R8

    !$omp parallel do collapse(3) private(i,j,k,ksrc)
    do k = 1, tgt%dim(3)
      do j = 1, tgt%dim(2)
        do i = 1, tgt%dim(1)
          if (sym_type == "2D") then
            ksrc = 1
          else
            ksrc = k
          endif
          map%src_idx(1, 1, i, j, k) = i
          map%src_idx(2, 1, i, j, k) = j
          map%src_idx(3, 1, i, j, k) = ksrc
        enddo
      enddo
    enddo
    !$omp end parallel do
  end subroutine build_index_map


  ! ---------------------------------------------------------------
  !  MULTIPLE map builder
  ! ---------------------------------------------------------------
  subroutine build_multiple_map(map, oldblocks, tgt, oldid)
    use global_mod, only: verbose
    implicit none
    type(interp_map_t), intent(out) :: map
    type(IC_block),     intent(in)  :: oldblocks(:)
    type(IC_block),     intent(in)  :: tgt
    integer,            intent(in)  :: oldid
    ! Local
    integer      :: b, rap
    real(R8)     :: rapNx, rapNy, rapNz
    character(2) :: sym_type
    logical      :: xint_dimension

    b = tgt%id
    if (oldid > 0) b = oldid

    xint_dimension = .false.
    rapNx = real(tgt%dim(1), R8) / real(oldblocks(b)%dim(1), R8)
    rapNy = real(tgt%dim(2), R8) / real(oldblocks(b)%dim(2), R8)
    rapNz = real(tgt%dim(3), R8) / real(oldblocks(b)%dim(3), R8)
    if (rapNx == rapNy .and. &
        mod(max(tgt%dim(1), oldblocks(b)%dim(1)), min(tgt%dim(1), oldblocks(b)%dim(1))) == 0) then
      if (rapNz == rapNx) then
        sym_type = "3D"
        xint_dimension = .true.
        rap = nint(rapNx)
      elseif (tgt%dim(3) == 1 .and. oldblocks(b)%dim(3) == 1) then
        sym_type = "2D"
        xint_dimension = .true.
        rap = nint(rapNx)
      endif
    endif

    if (.not. xint_dimension) then
      write(*,*) "[ERROR] Interpolation with law='multiple' is impossible"
      write(*,*) "[ERROR] Meshes are not multiple of one another"
      stop 1
    endif

    if (verbose) then
      write(*,*) "[LOG] New mesh / Old mesh Ratio = ", rapNx
    endif

    if (rapNx == 0.5_R8) then
      call build_multiple_map_half(map, tgt, b, sym_type)
    elseif (rapNx == 2.0_R8) then
      call build_multiple_map_x2(map, oldblocks, tgt, b, rap, sym_type)
    elseif (rapNx == 3.0_R8) then
      call build_multiple_map_x3(map, oldblocks, tgt, b, rap, sym_type)
    else
      call build_multiple_map_generic(map, tgt, b, rap)
    endif
  end subroutine build_multiple_map


  ! --- ratio = 0.5 ---
  subroutine build_multiple_map_half(map, tgt, b, sym_type)
    use global_mod, only: verbose
    implicit none
    type(interp_map_t), intent(out) :: map
    type(IC_block),     intent(in)  :: tgt
    integer,            intent(in)  :: b
    character(2),       intent(in)  :: sym_type
    ! Local
    integer  :: i, j, k, i2, j2, k2, i2d, j2d, k2d
    real(R8) :: coeffs(8)

    if (verbose) then
      write(*,*) "[LOG] Mesh ratio = 0.5 - Specific algorithm"
    endif

    if (sym_type == "3D") then
      coeffs = 1.0_R8 / 8.0_R8
    else
      coeffs(1:4) = 1.0_R8 / 4.0_R8
      coeffs(5:8) = 0.0_R8
    endif

    map%dim = tgt%dim(1:3)
    map%n_stencil = 8
    allocate(map%src_blk(map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%src_idx(3, 8, map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%weight(8, map%dim(1), map%dim(2), map%dim(3)))

    map%src_blk = b

    !$omp parallel do collapse(3) &
    !$omp& private(i,j,k,i2,j2,k2,i2d,j2d,k2d)
    do k = 1, tgt%dim(3)
      do j = 1, tgt%dim(2)
        do i = 1, tgt%dim(1)
          i2 = 2*i;  i2d = i2 - 1
          j2 = 2*j;  j2d = j2 - 1
          k2 = 2*k;  k2d = k2 - 1
          if (sym_type == "2D") then
            k2 = 1; k2d = 1
          endif
          map%weight(:, i, j, k) = coeffs
          ! 8 stencil points: (i2d,j2d,k2d), (i2,j2d,k2d),
          !   (i2d,j2,k2d), (i2,j2,k2d),
          !   (i2d,j2d,k2), (i2,j2d,k2),
          !   (i2d,j2,k2), (i2,j2,k2)
          map%src_idx(:,1,i,j,k) = [i2d, j2d, k2d]
          map%src_idx(:,2,i,j,k) = [i2,  j2d, k2d]
          map%src_idx(:,3,i,j,k) = [i2d, j2,  k2d]
          map%src_idx(:,4,i,j,k) = [i2,  j2,  k2d]
          map%src_idx(:,5,i,j,k) = [i2d, j2d, k2 ]
          map%src_idx(:,6,i,j,k) = [i2,  j2d, k2 ]
          map%src_idx(:,7,i,j,k) = [i2d, j2,  k2 ]
          map%src_idx(:,8,i,j,k) = [i2,  j2,  k2 ]
        enddo
      enddo
    enddo
    !$omp end parallel do
  end subroutine build_multiple_map_half


  ! --- ratio = 2 ---
  subroutine build_multiple_map_x2(map, oldblocks, tgt, b, rap, sym_type)
    use global_mod, only: verbose
    implicit none
    type(interp_map_t), intent(out) :: map
    type(IC_block),     intent(in)  :: oldblocks(:)
    type(IC_block),     intent(in)  :: tgt
    integer,            intent(in)  :: b, rap
    character(2),       intent(in)  :: sym_type
    ! Local
    integer  :: i, j, k, ii, jj, kk, counter
    integer  :: i2, j2, k2, i2d, j2d, k2d
    integer  :: im, jm, km, ip, jp, kp
    integer  :: id(6), mask(3)
    real(R8) :: coeffs(8)
    real(R8) :: a1, a2, a3, a4

    if (verbose) then
      write(*,*) "[LOG] Mesh ratio = 2 - Specific algorithm"
    endif

    if (sym_type == "3D") then
      a1 = 27.0_R8/64.0_R8
      a2 =  9.0_R8/64.0_R8
      a3 =  3.0_R8/64.0_R8
      a4 =  1.0_R8/64.0_R8
      coeffs = [a1, a2, a2, a2, a3, a3, a3, a4]
    else
      a1 =  9.0_R8/16.0_R8
      a2 =  3.0_R8/16.0_R8
      a3 =  1.0_R8/16.0_R8
      a4 =  0.0_R8
      coeffs = [a1, a2, a2, a4, a3, a4, a4, a4]
    endif

    map%dim = tgt%dim(1:3)
    map%n_stencil = 8
    allocate(map%src_blk(map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%src_idx(3, 8, map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%weight(8, map%dim(1), map%dim(2), map%dim(3)))

    map%src_blk = b

    ! Loop over source cells, fill rap^3 target cells each
    !$omp parallel do collapse(3) &
    !$omp& private(i,j,k,i2,j2,k2,i2d,j2d,k2d, &
    !$omp&         im,jm,km,ip,jp,kp,id,counter, &
    !$omp&         ii,jj,kk,mask)
    do k = 1, oldblocks(b)%dim(3)
      do j = 1, oldblocks(b)%dim(2)
        do i = 1, oldblocks(b)%dim(1)
          i2  = rap*i;      i2d = i2 - (rap-1)
          j2  = rap*j;      j2d = j2 - (rap-1)
          k2  = rap*k;      k2d = k2 - (rap-1)
          if (sym_type == "2D") then
            k2 = 1; k2d = 1
          endif
          im = max(1, i-1)
          jm = max(1, j-1)
          km = max(1, k-1)
          ip = min(oldblocks(b)%dim(1), i+1)
          jp = min(oldblocks(b)%dim(2), j+1)
          kp = min(oldblocks(b)%dim(3), k+1)
          id = [im, jm, km, ip, jp, kp]
          counter = 1
          do kk = k2d, k2
            do jj = j2d, j2
              do ii = i2d, i2
                if (sym_type == "2D") then
                  if (counter==1) mask=[1,2,3]
                  if (counter==2) mask=[4,2,3]
                  if (counter==3) mask=[1,5,3]
                  if (counter==4) mask=[4,5,3]
                endif
                if (sym_type == "3D") then
                  if (counter==1) mask=[1,2,3]
                  if (counter==2) mask=[4,2,3]
                  if (counter==3) mask=[1,5,3]
                  if (counter==4) mask=[4,5,3]
                  if (counter==5) mask=[1,2,6]
                  if (counter==6) mask=[4,2,6]
                  if (counter==7) mask=[1,5,6]
                  if (counter==8) mask=[4,5,6]
                endif
                map%weight(:, ii, jj, kk) = coeffs
                ! 8 stencil points
                map%src_idx(:,1,ii,jj,kk) = [i, j, k]
                map%src_idx(:,2,ii,jj,kk) = [id(mask(1)), j, k]
                map%src_idx(:,3,ii,jj,kk) = [i, id(mask(2)), k]
                map%src_idx(:,4,ii,jj,kk) = [i, j, id(mask(3))]
                map%src_idx(:,5,ii,jj,kk) = [id(mask(1)), id(mask(2)), k]
                map%src_idx(:,6,ii,jj,kk) = [id(mask(1)), j, id(mask(3))]
                map%src_idx(:,7,ii,jj,kk) = [i, id(mask(2)), id(mask(3))]
                map%src_idx(:,8,ii,jj,kk) = [id(mask(1)), id(mask(2)), id(mask(3))]
                counter = counter + 1
              enddo
            enddo
          enddo
        enddo
      enddo
    enddo
    !$omp end parallel do
  end subroutine build_multiple_map_x2


  ! --- ratio = 3 ---
  subroutine build_multiple_map_x3(map, oldblocks, tgt, &
                                    b, rap, sym_type)
    use global_mod, only: verbose
    implicit none
    type(interp_map_t), intent(out) :: map
    type(IC_block),     intent(in)  :: oldblocks(:)
    type(IC_block),     intent(in)  :: tgt
    integer,            intent(in)  :: b, rap
    character(2),       intent(in)  :: sym_type
    ! Local
    integer  :: i, j, k, ii, jj, kk, counter
    integer  :: i2, j2, k2, i2d, j2d, k2d
    integer  :: im, jm, km, ip, jp, kp
    integer  :: id(6), mask(3)
    real(R8) :: coeffs(8)
    real(R8) :: a0, a1, a2, a3, a4
    real(R8) :: coeff_c(8), coeff_v(8)
    real(R8) :: coeff_cf_i(8), coeff_cf_j(8), coeff_cf_k(8)
    real(R8) :: coeff_cs_jk(8), coeff_cs_ik(8), coeff_cs_ij(8)

    if (verbose) then
      write(*,*) "[LOG] Mesh ratio = 3 - Specific Algorithm"
    endif

    a0 = 0.0_R8
    if (sym_type == "3D") then
      a1 = 1.0_R8
      coeff_c = [a1,a0,a0,a0,a0,a0,a0,a0]
      a1 = 2.0_R8/3.0_R8; a2 = 1.0_R8/3.0_R8
      coeff_cf_i = [a1,a2,a0,a0,a0,a0,a0,a0]
      coeff_cf_j = [a1,a0,a2,a0,a0,a0,a0,a0]
      coeff_cf_k = [a1,a0,a0,a2,a0,a0,a0,a0]
      a1 = 9.0_R8/16.0_R8
      a2 = 3.0_R8/16.0_R8
      a3 = 1.0_R8/16.0_R8
      coeff_cs_jk = [a1,a0,a2,a2,a0,a0,a2,a0]
      coeff_cs_ik = [a1,a2,a0,a2,a0,a2,a0,a0]
      coeff_cs_ij = [a1,a2,a2,a0,a2,a0,a0,a0]
      a1 = 27.0_R8/64.0_R8
      a2 =  9.0_R8/64.0_R8
      a3 =  3.0_R8/64.0_R8
      a4 =  1.0_R8/64.0_R8
      coeff_v = [a1,a2,a2,a2,a3,a3,a3,a4]
    else ! 2D
      a1 = 1.0_R8
      coeff_c = [a1,a0,a0,a0,a0,a0,a0,a0]
      a1 = 2.0_R8/3.0_R8; a2 = 1.0_R8/3.0_R8
      coeff_cf_i = [a1,a2,a0,a0,a0,a0,a0,a0]
      coeff_cf_j = [a1,a0,a2,a0,a0,a0,a0,a0]
      a1 = 9.0_R8/16.0_R8
      a2 = 3.0_R8/16.0_R8
      a3 = 1.0_R8/16.0_R8
      coeff_v = [a1,a2,a2,a0,a3,a0,a0,a0]
    endif

    map%dim = tgt%dim(1:3)
    map%n_stencil = 8
    allocate(map%src_blk(map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%src_idx(3, 8, map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%weight(8, map%dim(1), map%dim(2), map%dim(3)))

    map%src_blk = b

    !$omp parallel do collapse(3) &
    !$omp& private(i,j,k,i2,j2,k2,i2d,j2d,k2d, &
    !$omp&         im,jm,km,ip,jp,kp,id,counter, &
    !$omp&         ii,jj,kk,mask,coeffs)
    do k = 1, oldblocks(b)%dim(3)
      do j = 1, oldblocks(b)%dim(2)
        do i = 1, oldblocks(b)%dim(1)
          i2  = rap*i;      i2d = i2 - (rap-1)
          j2  = rap*j;      j2d = j2 - (rap-1)
          k2  = rap*k;      k2d = k2 - (rap-1)
          if (sym_type == "2D") then
            k2 = 1; k2d = 1
          endif
          im = max(1, i-1)
          jm = max(1, j-1)
          km = max(1, k-1)
          ip = min(oldblocks(b)%dim(1), i+1)
          jp = min(oldblocks(b)%dim(2), j+1)
          kp = min(oldblocks(b)%dim(3), k+1)
          id = [im, jm, km, ip, jp, kp]
          counter = 1
          do kk = k2d, k2
            do jj = j2d, j2
              do ii = i2d, i2
                ! Select coefficients per sub-cell position
                if (sym_type == "2D") then
                  if (counter==1) then
                    mask=[1,2,3]; coeffs=coeff_v
                  endif
                  if (counter==2) then
                    mask=[1,2,3]; coeffs=coeff_cf_j
                  endif
                  if (counter==3) then
                    mask=[4,2,3]; coeffs=coeff_v
                  endif
                  if (counter==4) then
                    mask=[1,2,3]; coeffs=coeff_cf_i
                  endif
                  if (counter==5) then
                    mask=[1,2,3]; coeffs=coeff_c
                  endif
                  if (counter==6) then
                    mask=[4,2,3]; coeffs=coeff_cf_i
                  endif
                  if (counter==7) then
                    mask=[1,5,3]; coeffs=coeff_v
                  endif
                  if (counter==8) then
                    mask=[1,5,3]; coeffs=coeff_cf_j
                  endif
                  if (counter==9) then
                    mask=[4,5,3]; coeffs=coeff_v
                  endif
                endif
                if (sym_type == "3D") then
                  ! k = 1
                  if (counter==1) then
                    mask=[1,2,3]; coeffs=coeff_v
                  endif
                  if (counter==2) then
                    mask=[1,2,3]; coeffs=coeff_cs_jk
                  endif
                  if (counter==3) then
                    mask=[4,2,3]; coeffs=coeff_v
                  endif
                  if (counter==4) then
                    mask=[1,2,3]; coeffs=coeff_cs_ik
                  endif
                  if (counter==5) then
                    mask=[1,2,3]; coeffs=coeff_cf_k
                  endif
                  if (counter==6) then
                    mask=[4,2,3]; coeffs=coeff_cs_ik
                  endif
                  if (counter==7) then
                    mask=[1,5,3]; coeffs=coeff_v
                  endif
                  if (counter==8) then
                    mask=[1,5,3]; coeffs=coeff_cs_jk
                  endif
                  if (counter==9) then
                    mask=[4,5,3]; coeffs=coeff_v
                  endif
                  ! k = 2
                  if (counter==10) then
                    mask=[1,2,3]; coeffs=coeff_cs_ij
                  endif
                  if (counter==11) then
                    mask=[1,2,3]; coeffs=coeff_cf_j
                  endif
                  if (counter==12) then
                    mask=[4,2,3]; coeffs=coeff_cs_ij
                  endif
                  if (counter==13) then
                    mask=[1,2,3]; coeffs=coeff_cf_i
                  endif
                  if (counter==14) then
                    mask=[1,2,3]; coeffs=coeff_c
                  endif
                  if (counter==15) then
                    mask=[4,2,3]; coeffs=coeff_cf_i
                  endif
                  if (counter==16) then
                    mask=[1,5,3]; coeffs=coeff_cs_ij
                  endif
                  if (counter==17) then
                    mask=[1,5,3]; coeffs=coeff_cf_j
                  endif
                  if (counter==18) then
                    mask=[4,5,3]; coeffs=coeff_cs_ij
                  endif
                  ! k = 3
                  if (counter==19) then
                    mask=[1,2,6]; coeffs=coeff_v
                  endif
                  if (counter==20) then
                    mask=[1,2,6]; coeffs=coeff_cs_jk
                  endif
                  if (counter==21) then
                    mask=[4,2,6]; coeffs=coeff_v
                  endif
                  if (counter==22) then
                    mask=[1,2,6]; coeffs=coeff_cs_ik
                  endif
                  if (counter==23) then
                    mask=[1,2,6]; coeffs=coeff_cf_k
                  endif
                  if (counter==24) then
                    mask=[4,2,6]; coeffs=coeff_cs_ik
                  endif
                  if (counter==25) then
                    mask=[1,5,6]; coeffs=coeff_v
                  endif
                  if (counter==26) then
                    mask=[1,5,6]; coeffs=coeff_cs_jk
                  endif
                  if (counter==27) then
                    mask=[4,5,6]; coeffs=coeff_v
                  endif
                endif

                map%weight(:, ii, jj, kk) = coeffs
                map%src_idx(:,1,ii,jj,kk) = [i, j, k]
                map%src_idx(:,2,ii,jj,kk) = [id(mask(1)), j, k]
                map%src_idx(:,3,ii,jj,kk) = [i, id(mask(2)), k]
                map%src_idx(:,4,ii,jj,kk) = [i, j, id(mask(3))]
                map%src_idx(:,5,ii,jj,kk) = [id(mask(1)), id(mask(2)), k]
                map%src_idx(:,6,ii,jj,kk) = [id(mask(1)), j, id(mask(3))]
                map%src_idx(:,7,ii,jj,kk) = [i, id(mask(2)), id(mask(3))]
                map%src_idx(:,8,ii,jj,kk) = [id(mask(1)), id(mask(2)), id(mask(3))]
                counter = counter + 1
              enddo
            enddo
          enddo
        enddo
      enddo
    enddo
    !$omp end parallel do
  end subroutine build_multiple_map_x3


  ! --- generic integer ratio ---
  subroutine build_multiple_map_generic(map, tgt, b, rap)
    use global_mod, only: verbose
    implicit none
    type(interp_map_t), intent(out) :: map
    type(IC_block),     intent(in)  :: tgt
    integer,            intent(in)  :: b, rap
    ! Local
    integer :: i, j, k, indi, indj, indk

    if (verbose) then
      write(*,*) "[LOG] Mesh ratio = ", rap, " - Generic algorithm"
    endif

    map%dim = tgt%dim(1:3)
    map%n_stencil = 1
    allocate(map%src_blk(map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%src_idx(3, 1, map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%weight(1, map%dim(1), map%dim(2), map%dim(3)))

    map%src_blk = b
    map%weight  = 1.0_R8

    !$omp parallel do collapse(3) private(i,j,k,indi,indj,indk)
    do k = 1, tgt%dim(3)
      do j = 1, tgt%dim(2)
        do i = 1, tgt%dim(1)
          indi = (i-1)/rap + 1
          indj = (j-1)/rap + 1
          indk = (k-1)/rap + 1
          map%src_idx(:, 1, i, j, k) = [indi, indj, indk]
        enddo
      enddo
    enddo
    !$omp end parallel do
  end subroutine build_multiple_map_generic


  ! ---------------------------------------------------------------
  !  MINIMUM DISTANCE map builder
  ! ---------------------------------------------------------------
  subroutine build_distance_map(map, oldblocks, tgt, oldid)
    use global_mod, only: verbose
    implicit none
    type(interp_map_t), intent(out) :: map
    type(IC_block),     intent(in)  :: oldblocks(:)
    type(IC_block),     intent(in)  :: tgt
    integer,            intent(in)  :: oldid
    ! Local
    integer  :: i, j, k, bb, b, maxdim(3)
    integer  :: ind(3), indold(3), trueb
    real(R8) :: truedist, mindist
    real(R8), allocatable :: dx(:,:,:), dy(:,:,:)
    real(R8), allocatable :: dz(:,:,:), dist(:,:,:)

    if (verbose) then
      write(*,*) "[LOG] Cell Centers Minimum Distance interpolation algorithm"
    endif

    b = tgt%id
    if (oldid > 0) b = oldid

    ! Pre-compute max dimensions
    if (oldid == 0) then
      maxdim = 0
      do bb = 1, size(oldblocks)
        maxdim(1) = max(maxdim(1), oldblocks(bb)%dim(1))
        maxdim(2) = max(maxdim(2), oldblocks(bb)%dim(2))
        maxdim(3) = max(maxdim(3), oldblocks(bb)%dim(3))
      enddo
    else
      maxdim(1) = oldblocks(oldid)%dim(1)
      maxdim(2) = oldblocks(oldid)%dim(2)
      maxdim(3) = oldblocks(oldid)%dim(3)
    endif

    map%dim = tgt%dim(1:3)
    map%n_stencil = 1
    allocate(map%src_blk(map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%src_idx(3, 1, map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%weight(1, map%dim(1), map%dim(2), map%dim(3)))
    map%weight = 1.0_R8

    !$omp parallel private(i,j,k,bb,dx,dy,dz,dist, &
    !$omp&   truedist,mindist,indold,ind,trueb)
    allocate(dx(maxdim(1), maxdim(2), maxdim(3)))
    allocate(dy(maxdim(1), maxdim(2), maxdim(3)))
    allocate(dz(maxdim(1), maxdim(2), maxdim(3)))
    allocate(dist(maxdim(1), maxdim(2), maxdim(3)))
    !$omp do collapse(3) schedule(dynamic)
    do k = 1, tgt%dim(3)
      do j = 1, tgt%dim(2)
        do i = 1, tgt%dim(1)
          truedist = 1.0e+5_R8
          trueb = 1
          if (oldid == 0) then
            do bb = 1, size(oldblocks)
              associate(ob => oldblocks(bb), d1 => oldblocks(bb)%dim(1), d2 => oldblocks(bb)%dim(2), d3 => oldblocks(bb)%dim(3))
              dx(1:d1,1:d2,1:d3) = (tgt%center(i,j,k)%c(1) - ob%center(1:d1,1:d2,1:d3)%c(1))**2
              dy(1:d1,1:d2,1:d3) = (tgt%center(i,j,k)%c(2) - ob%center(1:d1,1:d2,1:d3)%c(2))**2
              dz(1:d1,1:d2,1:d3) = (tgt%center(i,j,k)%c(3) - ob%center(1:d1,1:d2,1:d3)%c(3))**2
              dist(1:d1,1:d2,1:d3) = sqrt(dx(1:d1,1:d2,1:d3) + dy(1:d1,1:d2,1:d3) + dz(1:d1,1:d2,1:d3))
              indold = minloc( &
                dist(1:d1,1:d2,1:d3), MASK=.true.)
              mindist = dist(indold(1),indold(2),indold(3))
              if (mindist < truedist) then
                truedist = mindist
                ind = indold
                trueb = bb
              endif
              end associate
            enddo
          else
            associate(ob => oldblocks(oldid), d1 => oldblocks(oldid)%dim(1), d2 => oldblocks(oldid)%dim(2), d3 => oldblocks(oldid)%dim(3))
            dx(1:d1,1:d2,1:d3) = (tgt%center(i,j,k)%c(1) - ob%center(1:d1,1:d2,1:d3)%c(1))**2
            dy(1:d1,1:d2,1:d3) = (tgt%center(i,j,k)%c(2) - ob%center(1:d1,1:d2,1:d3)%c(2))**2
            dz(1:d1,1:d2,1:d3) = (tgt%center(i,j,k)%c(3) - ob%center(1:d1,1:d2,1:d3)%c(3))**2
            dist(1:d1,1:d2,1:d3) = sqrt(dx(1:d1,1:d2,1:d3) + dy(1:d1,1:d2,1:d3) + dz(1:d1,1:d2,1:d3))
            indold = minloc( &
              dist(1:d1,1:d2,1:d3), MASK=.true.)
            mindist = dist(indold(1),indold(2),indold(3))
            if (mindist < truedist) then
              truedist = mindist
              ind = indold
              trueb = oldid
            endif
            end associate
          endif
          map%src_blk(i,j,k) = trueb
          map%src_idx(:, 1, i, j, k) = ind
        enddo
      enddo
    enddo
    !$omp end do
    deallocate(dx, dy, dz, dist)
    !$omp end parallel
  end subroutine build_distance_map


  ! ---------------------------------------------------------------
  !  SPHERICAL MINIMUM DISTANCE map builder
  ! ---------------------------------------------------------------
  subroutine build_spherical_distance_map(map, oldblocks, tgt, oldid)
    use global_mod, only: verbose
    implicit none
    type(interp_map_t), intent(out) :: map
    type(IC_block),     intent(in)  :: oldblocks(:)
    type(IC_block),     intent(inout) :: tgt
    integer,            intent(in)  :: oldid
    ! Local
    integer  :: i, j, k, bb, c, ii, jj, kk, trueb
    integer  :: ind(3)
    real(R8) :: r, xc, yc, zc, x, y, z
    real(R8) :: ddx, ddy, ddz, dist_val, truedist

    if (verbose) write(*,*) "[LOG] Cell Centers Spherical Minimum Distance interpolation algorithm"

    call tgt%compute_bounding([0,0,0])

    map%dim = tgt%dim(1:3)
    map%n_stencil = 1
    allocate(map%src_blk(map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%src_idx(3, 1, map%dim(1), map%dim(2), map%dim(3)))
    allocate(map%weight(1, map%dim(1), map%dim(2), map%dim(3)))
    map%weight = 1.0_R8

    !$omp parallel private(i,j,k,c,ii,jj,kk,bb,r, &
    !$omp&   xc,yc,zc,x,y,z,ddx,ddy,ddz,dist_val, &
    !$omp&   truedist,trueb,ind)
    !$omp do collapse(3) schedule(dynamic)
    do k = 1, tgt%dim(3)
      do j = 1, tgt%dim(2)
        do i = 1, tgt%dim(1)
          xc = tgt%center(i,j,k)%c(1)
          yc = tgt%center(i,j,k)%c(2)
          zc = tgt%center(i,j,k)%c(3)
          ddx = tgt%bbmax(i,j,k)%c(1) - tgt%bbmin(i,j,k)%c(1)
          ddy = tgt%bbmax(i,j,k)%c(2) - tgt%bbmin(i,j,k)%c(2)
          ddz = tgt%bbmax(i,j,k)%c(3) - tgt%bbmin(i,j,k)%c(3)
          truedist = 1.0e+5_R8
          r = 0.0_R8
          c = 0
          trueb = 1
          ind = [1, 1, 1]

          if (oldid == 0) then
            do while (c == 0)
              r = r + max(ddx, ddy, ddz)
              do bb = 1, size(oldblocks)
                do kk = 1, oldblocks(bb)%dim(3)
                  do jj = 1, oldblocks(bb)%dim(2)
                    do ii = 1, oldblocks(bb)%dim(1)
                      x = oldblocks(bb)%center(ii,jj,kk)%c(1)
                      y = oldblocks(bb)%center(ii,jj,kk)%c(2)
                      z = oldblocks(bb)%center(ii,jj,kk)%c(3)
                      dist_val = sqrt((xc-x)**2 + (yc-y)**2 + (zc-z)**2)
                      if (dist_val < r) then
                        c = 1
                        if (dist_val < truedist) then
                          trueb = bb
                          ind = [ii, jj, kk]
                          truedist = dist_val
                        endif
                      endif
                    enddo
                  enddo
                enddo
              enddo
            enddo
          else
            do while (c == 0)
              r = r + max(ddx, ddy, ddz)
              do kk = 1, oldblocks(oldid)%dim(3)
                do jj = 1, oldblocks(oldid)%dim(2)
                  do ii = 1, oldblocks(oldid)%dim(1)
                    x = oldblocks(oldid)%center(ii,jj,kk)%c(1)
                    y = oldblocks(oldid)%center(ii,jj,kk)%c(2)
                    z = oldblocks(oldid)%center(ii,jj,kk)%c(3)
                    dist_val = sqrt((xc-x)**2 + (yc-y)**2 + (zc-z)**2)
                    if (dist_val < r) then
                      c = 1
                      if (dist_val < truedist) then
                        trueb = oldid
                        ind = [ii, jj, kk]
                        truedist = dist_val
                      endif
                    endif
                  enddo
                enddo
              enddo
            enddo
          endif

          map%src_blk(i,j,k) = trueb
          map%src_idx(:, 1, i, j, k) = ind
        enddo
      enddo
    enddo
    !$omp end parallel
  end subroutine build_spherical_distance_map


  ! =================================================================
  !  Private helpers for file-based interpolation
  ! =================================================================

  subroutine load_source(filename)
    use grid_mod,       only: import_nodes, mesh_config_type
    use read_mesh_mod,  only: has_ext_series
    use Lib_ORION_data, only: orion_data
    use Lib_Tecplot,    only: tec_read_structured_multiblock
    use Lib_PLOT3D,     only: p3d_read_multiblock
    implicit none
    character(len=*), intent(in) :: filename
    type(orion_data) :: IOfield
    type(mesh_config_type) :: scfg
    integer          :: error, b, i, j, k

    if (allocated(source_blocks)) deallocate(source_blocks)
    source_ready = .false.

    ! The extension (suffix, as in read_mesh) picks the reader; a .szplt needs a TecIO build:
    ! without the guard ORION's own stop returned 0 and no IC was written.
    if (has_ext_series(trim(filename), '.szplt')) then
#if defined(TECIO)
      IOfield%tec%node   = .false.
      IOfield%tec%bc     = .false.
      IOfield%tec%format = 'binary'
      error = tec_read_structured_multiblock(orion=IOfield, filename=trim(filename))
#else
      write(*,*) '[ERROR] interpolation_general: '//trim(filename)//' is a binary Tecplot file, but this ATLAS build'// &
        ' was configured without TecIO (USE_TECIO=false)'
      stop 1
#endif
    elseif (has_ext_series(trim(filename), '.tec')) then
      IOfield%tec%node   = .false.
      IOfield%tec%bc     = .false.
      IOfield%tec%format = 'ascii'
      error = tec_read_structured_multiblock(orion=IOfield, filename=trim(filename))
    else
      write(*,*) '[ERROR] interpolation_general: unsupported file format: ', trim(filename), &
        ' (expected .tec or .szplt, optionally numbered: .tec.NNN / .szplt.NNN)'
      stop 1
    endif

    if (error /= 0) then
      write(*,*) '[ERROR] interpolation_general: failed to read ', trim(filename)
      stop 1
    endif

    allocate(source_blocks(size(IOfield%block)))
    ! Secondary mesh: classify locally, do not overwrite the global mesh_cfg
    call import_nodes(input=IOfield, output=source_blocks, cfg=scfg)

    do b = 1, size(source_blocks)
      call source_blocks(b)%compute_centers(gc=[0, 0, 0])
      ! k extent = max(Nk,1): ORION returns Nk = 0 for a one-plane (K=1) file while the loop below
      ! and nearest_neighbor_file address k = 1 (dim(3) = max(Nk,1) in import_nodes)
      allocate(source_blocks(b)%var(1:IOfield%block(b)%Ni,1:IOfield%block(b)%Nj,1:max(IOfield%block(b)%Nk,1)))
      ! Shape assertion: the field array must have exactly the extents of the imported
      ! mesh cells and the file must hold data for every cell. A shorter extent is otherwise read and
      ! written through the same strides beyond the allocation: silent garbage or a crash, never a message.
      if (any(shape(source_blocks(b)%var) /= source_blocks(b)%dim) .or. &
          size(IOfield%block(b)%vars,2) < source_blocks(b)%dim(1) .or. &
          size(IOfield%block(b)%vars,3) < source_blocks(b)%dim(2) .or. &
          size(IOfield%block(b)%vars,4) < source_blocks(b)%dim(3)) then
        write(*,*) '[ERROR] interpolation_general: field source file '//trim(filename)//', block', b, ':'
        write(*,*) '        field array extents', shape(source_blocks(b)%var), ' / data extents', &
          shape(IOfield%block(b)%vars(1,:,:,:)), ' do not match the mesh cells', source_blocks(b)%dim
        stop 1
      endif
      do k = 1, source_blocks(b)%dim(3)
        do j = 1, source_blocks(b)%dim(2)
          do i = 1, source_blocks(b)%dim(1)
            source_blocks(b)%var(i,j,k) = IOfield%block(b)%vars(1,i,j,k)
          enddo
        enddo
      enddo
    enddo

    source_file  = filename
    source_ready = .true.
  end subroutine load_source


  subroutine nearest_neighbor_file(field, blk)
    implicit none
    type(IC_block), intent(in)  :: blk
    real(R8), intent(inout)     :: field(1:blk%dim(1), 1:blk%dim(2), 1:blk%dim(3))
    integer  :: i, j, k, b, maxdim(3)
    integer  :: ind(3), indold(3), bestb
    real(R8) :: truedist, mindist
    real(R8), dimension(:,:,:), allocatable :: dx, dy, dz, dist

    maxdim = 0
    do b = 1, size(source_blocks)
      maxdim(1) = max(maxdim(1), source_blocks(b)%dim(1))
      maxdim(2) = max(maxdim(2), source_blocks(b)%dim(2))
      maxdim(3) = max(maxdim(3), source_blocks(b)%dim(3))
    enddo

    !$omp parallel private(i,j,k,b,dx,dy,dz,dist, &
    !$omp&                 truedist,mindist,indold,ind,bestb)
    allocate(dx(1:maxdim(1), 1:maxdim(2), 1:maxdim(3)))
    allocate(dy(1:maxdim(1), 1:maxdim(2), 1:maxdim(3)))
    allocate(dz(1:maxdim(1), 1:maxdim(2), 1:maxdim(3)))
    allocate(dist(1:maxdim(1), 1:maxdim(2), 1:maxdim(3)))
    !$omp do collapse(3) schedule(dynamic)
    do k = 1, blk%dim(3)
      do j = 1, blk%dim(2)
        do i = 1, blk%dim(1)
          truedist = huge(1.0_R8)
          bestb    = 1
          do b = 1, size(source_blocks)
            associate(sb => source_blocks(b))
              dx(1:sb%dim(1),1:sb%dim(2),1:sb%dim(3)) = &
                (blk%center(i,j,k)%c(1) &
                 - sb%center(1:sb%dim(1), &
                             1:sb%dim(2), &
                             1:sb%dim(3))%c(1))**2
              dy(1:sb%dim(1),1:sb%dim(2),1:sb%dim(3)) = &
                (blk%center(i,j,k)%c(2) &
                 - sb%center(1:sb%dim(1), &
                             1:sb%dim(2), &
                             1:sb%dim(3))%c(2))**2
              dz(1:sb%dim(1),1:sb%dim(2),1:sb%dim(3)) = &
                (blk%center(i,j,k)%c(3) &
                 - sb%center(1:sb%dim(1), &
                             1:sb%dim(2), &
                             1:sb%dim(3))%c(3))**2
              dist(1:sb%dim(1),1:sb%dim(2),1:sb%dim(3)) = &
                sqrt( dx(1:sb%dim(1), &
                         1:sb%dim(2), &
                         1:sb%dim(3)) &
                    + dy(1:sb%dim(1), &
                         1:sb%dim(2), &
                         1:sb%dim(3)) &
                    + dz(1:sb%dim(1), &
                         1:sb%dim(2), &
                         1:sb%dim(3)) )
              indold = minloc( dist(1:sb%dim(1), 1:sb%dim(2), 1:sb%dim(3)), MASK=.true.)
              mindist = dist(indold(1), indold(2), indold(3))
              if (mindist < truedist) then
                truedist = mindist
                ind   = indold
                bestb = b
              endif
            end associate
          enddo
          field(i,j,k) = source_blocks(bestb)%var(ind(1), ind(2), ind(3))
        enddo
      enddo
    enddo
    !$omp end do
    deallocate(dx, dy, dz, dist)
    !$omp end parallel
  end subroutine nearest_neighbor_file

end module ic_interpolation_general_mod
