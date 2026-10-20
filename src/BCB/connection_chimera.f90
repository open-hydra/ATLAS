!> Uniform spatial hash grid over donor cells, used as a broad phase for the
!> chimera overlap search. Replaces the per-receiver O(all-donor-cells) scan
!> with an O(local) query, which is what makes the search tractable on large
!> 3D meshes (receivers scale as surface area, donors as volume).
module chimera_grid_mod
  use bc_block_mod, only: BC_block
  implicit none
  private
  public :: donor_grid_t, build_donor_grid, query_donor_grid

  type :: donor_grid_t
    real(8)              :: origin(3)      ! grid lower corner
    real(8)              :: h(3)           ! bucket size per dim
    integer              :: n(3)           ! number of buckets per dim
    integer, allocatable :: head(:)        ! nbuckets: first entry index, -1 if empty
    integer, allocatable :: nxt(:)         ! nentries: linked-list next
    integer, allocatable :: eb(:), ei(:), ej(:), ek(:)  ! donor cell (block,i,j,k) per entry
    integer              :: nentries = 0
  end type donor_grid_t

  integer, parameter :: MAXN = 128         ! cap on buckets per dimension

contains

  !> Build the grid over all interior donor cells of every block.
  subroutine build_donor_grid(block, grid)
    type(BC_block), intent(in)      :: block(:)
    type(donor_grid_t), intent(out) :: grid
    real(8) :: gmin(3), gmax(3), ext(3), avg(3)
    integer :: b, i, j, k, d, ncell, nb, e
    integer :: lo(3), hi(3), ix, jy, kz, bkt

    ! Global bounding box and average cell size over interior cells
    gmin =  huge(1.d0); gmax = -huge(1.d0); avg = 0.d0; ncell = 0
    do b = 1, size(block)
      do k = 1, block(b)%dim(3); do j = 1, block(b)%dim(2); do i = 1, block(b)%dim(1)
        do d = 1, 3
          gmin(d) = min(gmin(d), block(b)%bbmin(i,j,k)%c(d))
          gmax(d) = max(gmax(d), block(b)%bbmax(i,j,k)%c(d))
          avg(d)  = avg(d) + (block(b)%bbmax(i,j,k)%c(d)-block(b)%bbmin(i,j,k)%c(d))
        end do
        ncell = ncell + 1
      end do; end do; end do
    end do
    if (ncell == 0) then
      grid%n = 1; grid%nentries = 0
      allocate(grid%head(1)); grid%head = -1
      allocate(grid%nxt(0), grid%eb(0), grid%ei(0), grid%ej(0), grid%ek(0))
      return
    end if
    avg = avg / real(ncell,8)
    ext = gmax - gmin

    do d = 1, 3
      if (avg(d) <= 0.d0) avg(d) = max(ext(d), 1.d0)
      grid%n(d) = min(MAXN, max(1, int(ext(d)/avg(d)) + 1))
      grid%h(d) = ext(d)/real(grid%n(d),8)
      if (grid%h(d) <= 0.d0) grid%h(d) = 1.d0
    end do
    grid%origin = gmin
    nb = grid%n(1)*grid%n(2)*grid%n(3)

    ! Pass 1: count entries (each cell inserted into every bucket its AABB spans)
    grid%nentries = 0
    do b = 1, size(block)
      do k = 1, block(b)%dim(3); do j = 1, block(b)%dim(2); do i = 1, block(b)%dim(1)
        call bucket_range(grid, block(b)%bbmin(i,j,k)%c(1:3), block(b)%bbmax(i,j,k)%c(1:3), lo, hi)
        grid%nentries = grid%nentries + (hi(1)-lo(1)+1)*(hi(2)-lo(2)+1)*(hi(3)-lo(3)+1)
      end do; end do; end do
    end do

    allocate(grid%head(nb)); grid%head = -1
    allocate(grid%nxt(grid%nentries))
    allocate(grid%eb(grid%nentries), grid%ei(grid%nentries), &
             grid%ej(grid%nentries), grid%ek(grid%nentries))

    ! Pass 2: fill linked lists
    e = 0
    do b = 1, size(block)
      do k = 1, block(b)%dim(3); do j = 1, block(b)%dim(2); do i = 1, block(b)%dim(1)
        call bucket_range(grid, block(b)%bbmin(i,j,k)%c(1:3), block(b)%bbmax(i,j,k)%c(1:3), lo, hi)
        do kz = lo(3), hi(3); do jy = lo(2), hi(2); do ix = lo(1), hi(1)
          bkt = 1 + ix + grid%n(1)*(jy + grid%n(2)*kz)
          e = e + 1
          grid%eb(e) = b; grid%ei(e) = i; grid%ej(e) = j; grid%ek(e) = k
          grid%nxt(e) = grid%head(bkt); grid%head(bkt) = e
        end do; end do; end do
      end do; end do; end do
    end do

  end subroutine build_donor_grid

  !> Clamp an AABB to integer bucket index ranges [lo,hi] (0-based).
  pure subroutine bucket_range(grid, bmin, bmax, lo, hi)
    type(donor_grid_t), intent(in) :: grid
    real(8), intent(in)  :: bmin(3), bmax(3)
    integer, intent(out) :: lo(3), hi(3)
    integer :: d
    do d = 1, 3
      lo(d) = int((bmin(d)-grid%origin(d))/grid%h(d))
      hi(d) = int((bmax(d)-grid%origin(d))/grid%h(d))
      lo(d) = max(0, min(grid%n(d)-1, lo(d)))
      hi(d) = max(0, min(grid%n(d)-1, hi(d)))
    end do
  end subroutine bucket_range

  !> Return the deduplicated candidate donor cells whose bucket overlaps the
  !> receiver AABB, excluding block `br`, sorted in (bd,kd,jd,id) order so the
  !> downstream record order is identical to the original full scan.
  subroutine query_donor_grid(grid, br, rbmin, rbmax, cb, ci, cj, ck, ncand)
    type(donor_grid_t), intent(in)   :: grid
    integer, intent(in)              :: br
    real(8), intent(in)              :: rbmin(3), rbmax(3)
    integer, allocatable, intent(inout) :: cb(:), ci(:), cj(:), ck(:)
    integer, intent(out)             :: ncand
    integer :: lo(3), hi(3), ix, jy, kz, bkt, e, nraw, m
    integer(8), allocatable :: key(:)
    integer(8) :: P

    P = 100000_8
    call bucket_range(grid, rbmin, rbmax, lo, hi)

    ! Count raw entries in the bucket window
    nraw = 0
    do kz = lo(3), hi(3); do jy = lo(2), hi(2); do ix = lo(1), hi(1)
      bkt = 1 + ix + grid%n(1)*(jy + grid%n(2)*kz)
      e = grid%head(bkt)
      do while (e /= -1)
        if (grid%eb(e) /= br) nraw = nraw + 1
        e = grid%nxt(e)
      end do
    end do; end do; end do

    if (allocated(cb)) then
      if (size(cb) < nraw) deallocate(cb, ci, cj, ck)
    end if
    if (.not. allocated(cb) .and. nraw > 0) &
      allocate(cb(nraw), ci(nraw), cj(nraw), ck(nraw))
    ncand = 0
    if (nraw == 0) return
    allocate(key(nraw))

    ! Gather with sort key = (bd,kd,jd,id) packed big-endian
    m = 0
    do kz = lo(3), hi(3); do jy = lo(2), hi(2); do ix = lo(1), hi(1)
      bkt = 1 + ix + grid%n(1)*(jy + grid%n(2)*kz)
      e = grid%head(bkt)
      do while (e /= -1)
        if (grid%eb(e) /= br) then
          m = m + 1
          cb(m) = grid%eb(e); ci(m) = grid%ei(e)
          cj(m) = grid%ej(e); ck(m) = grid%ek(e)
          key(m) = ((int(cb(m),8)*P + int(ck(m),8))*P + int(cj(m),8))*P + int(ci(m),8)
        end if
        e = grid%nxt(e)
      end do
    end do; end do; end do

    call heapsort_payload(nraw, key, cb, ci, cj, ck)

    ! Remove duplicates (a cell may sit in several buckets)
    ncand = 1
    do m = 2, nraw
      if (key(m) /= key(m-1)) then
        ncand = ncand + 1
        cb(ncand) = cb(m); ci(ncand) = ci(m); cj(ncand) = cj(m); ck(ncand) = ck(m)
      end if
    end do

    deallocate(key)
  end subroutine query_donor_grid

  !> In-place heapsort of key(:) carrying four integer payload arrays.
  subroutine heapsort_payload(n, key, a, b, c, d)
    integer, intent(in)       :: n
    integer(8), intent(inout) :: key(:)
    integer, intent(inout)    :: a(:), b(:), c(:), d(:)
    integer :: i, e
    do i = n/2, 1, -1
      call siftdown(i, n)
    end do
    do e = n, 2, -1
      call swap(1, e)
      call siftdown(1, e-1)
    end do
  contains
    subroutine siftdown(start, en)
      integer, intent(in) :: start, en
      integer :: root, child
      root = start
      do
        child = 2*root
        if (child > en) exit
        if (child < en) then
          if (key(child) < key(child+1)) child = child + 1
        end if
        if (key(root) < key(child)) then
          call swap(root, child); root = child
        else
          exit
        end if
      end do
    end subroutine siftdown
    subroutine swap(x, y)
      integer, intent(in) :: x, y
      integer(8) :: tk
      integer :: t
      tk = key(x); key(x) = key(y); key(y) = tk
      t = a(x); a(x) = a(y); a(y) = t
      t = b(x); b(x) = b(y); b(y) = t
      t = c(x); c(x) = c(y); c(y) = t
      t = d(x); d(x) = d(y); d(y) = t
    end subroutine swap
  end subroutine heapsort_payload

end module chimera_grid_mod


module bc_chimera_mod
  use intersection_mod, only: intersection_type
  implicit none
  private
  public:: chimera_wrapper

  !> Growable, thread-local buffer of intersection records.
  type :: rec_buffer
    type(intersection_type), allocatable :: rec(:)
    integer :: n = 0
  end type rec_buffer

  !> BC ids of the facelets of one face, as they were before the chimera search.
  type :: face_ids
    integer, allocatable :: id(:,:)
  end type face_ids

  !> The records grouped by receiver cell after the search: those of the cell with
  !> linear key k (rec_key) are intersection(rec_off(k):rec_off(k+1)-1).
  integer, allocatable :: rec_off(:), rec_blkoff(:)
  integer              :: rec_gc(3) = 0

contains

  !> Linear key of a receiver cell (block, i, j, k with the ghost layers) in rec_off
  integer function rec_key(block, id)
    use bc_block_mod, only: BC_block
    type(BC_block), intent(in) :: block(:)
    integer, intent(in)        :: id(4)
    integer :: n1, n2
    n1 = block(id(1))%dim(1) + 2*rec_gc(1)
    n2 = block(id(1))%dim(2) + 2*rec_gc(2)
    rec_key = rec_blkoff(id(1)) + ((id(4)-1+rec_gc(3))*n2 + (id(3)-1+rec_gc(2)))*n1 + (id(2)+rec_gc(1))
  end function rec_key

  !> Receivers claimed by the overset search: the faces declared 'chimera', plus
  !> the faces declared 'connection' that find_connect could not match. With
  !> `force` every still unresolved facelet is searched, whatever its declared
  !> type; the ones without donors simply keep their own BC.
  logical function is_chimera_face(block, br, fr, ir, jr, kr, force)
    use bc_block_mod, only: BC_block
    use bc_names_mod, only: MARKER_Chim, MARKER_CONN
    use grid_mod,     only: ijk2mn
    implicit none
    type(BC_block), intent(in) :: block(:)
    integer, intent(in)        :: br, fr, ir, jr, kr
    logical, intent(in)        :: force
    integer :: m, n

    is_chimera_face = .false.
    if (fr > block(br)%nfaces) return
    call ijk2mn(ir,jr,kr,fr,m,n)
    if (m<1 .or. m>block(br)%face(fr)%Nm) return
    if (n<1 .or. n>block(br)%face(fr)%Nn) return
    associate (bc => block(br)%face(fr)%center(m,n)%bc)
      if (bc%adj_assigned) return
      is_chimera_face = force .or. &
                        trim(bc%definition)==trim(MARKER_Chim) .or. &
                        trim(bc%definition)==trim(MARKER_CONN)
    end associate
  end function is_chimera_face

  !> chimera.log lists the closure of every receiver of the level (chimera<level>.log
  !> above level 1, like bc<level>.txt).
  subroutine chimera_wrapper(block,force_chimera,level)
    use intersection_mod
    use bc_block_mod
    use grid_mod, only: mesh_cfg
    use chimera_grid_mod, only: donor_grid_t, build_donor_grid
    !$ use omp_lib, only: omp_get_max_threads, omp_get_thread_num
    implicit none
    type(BC_block), intent(inout) :: block(:)
    logical, intent(in), optional :: force_chimera
    integer, intent(in), optional :: level
    logical                 :: force
    character(len=32)       :: logname
    integer                 :: ir,jr,kr,br,fr,ni
    integer                 :: unitlog
    integer                 :: gc(3)
    integer                 :: procStart(3)
    integer                 :: nthreads, t, off
    type(intersection_type), allocatable :: intersection(:)
    logical, allocatable                 :: nodeinside(:,:,:,:)
    logical, allocatable                 :: processed(:,:,:)
    type(donor_grid_t)                   :: grid
    type(rec_buffer), allocatable        :: tbuf(:)
    type(face_ids), allocatable          :: gp0(:,:)

    gc = mesh_cfg%gc
    procStart = [1-gc(1),1-gc(2),1-gc(3)]
    force = .false.
    if (present(force_chimera)) force = force_chimera

    ! Broad-phase acceleration structure over all donor cells
    call build_donor_grid(block, grid)

    ! One record buffer per thread (detection appends lock-free into its own)
    nthreads = 1
    !$ nthreads = omp_get_max_threads()
    allocate(tbuf(0:nthreads-1))

    logname = 'chimera.log'
    if (present(level)) then
      if (level > 1) write(logname,'(A,I0,A)') 'chimera', level, '.log'
    endif
    open(newunit=unitlog,file=trim(logname),status='replace',action='write')

    ! Loop over the receiver block cells
    do br = 1, size(block)

      if (allocated(processed)) deallocate(processed)
      allocate(processed(1-gc(1):block(br)%dim(1)+gc(1),                              &
                         1-gc(2):block(br)%dim(2)+gc(2),                              &
                         1-gc(3):block(br)%dim(3)+gc(3)))
      processed = .false.

      allocate(block(br)%face(1)%cell(1-gc(1):0,                                 1-gc(2):block(br)%dim(2)+gc(2),            1-gc(3):block(br)%dim(3)+gc(3)))
      allocate(block(br)%face(2)%cell(block(br)%dim(1)+1:block(br)%dim(1)+gc(1), 1-gc(2):block(br)%dim(2)+gc(2),            1-gc(3):block(br)%dim(3)+gc(3)))
      if (block(br)%nfaces >= 4) then
        allocate(block(br)%face(3)%cell(1-gc(1):block(br)%dim(1)+gc(1),            1-gc(2):0,                                 1-gc(3):block(br)%dim(3)+gc(3)))
        allocate(block(br)%face(4)%cell(1-gc(1):block(br)%dim(1)+gc(1),            block(br)%dim(2)+1:block(br)%dim(2)+gc(2), 1-gc(3):block(br)%dim(3)+gc(3)))
      endif
      if (block(br)%nfaces >= 6) then
        allocate(block(br)%face(5)%cell(1-gc(1):block(br)%dim(1)+gc(1),            1-gc(2):block(br)%dim(2)+gc(2),            1-gc(3):0))
        allocate(block(br)%face(6)%cell(1-gc(1):block(br)%dim(1)+gc(1),            1-gc(2):block(br)%dim(2)+gc(2),            block(br)%dim(3)+1:block(br)%dim(3)+gc(3)))
      endif

      ! Face 1
      if (allocated(nodeinside)) deallocate(nodeinside)
      allocate(nodeinside(8,1-gc(1):0,1-gc(2):block(br)%dim(2)+gc(2),1-gc(3):block(br)%dim(3)+gc(3)))
      nodeinside = .false.
      !$omp parallel do collapse(3) private(ir,jr,kr) schedule(dynamic)
      do kr = 1, block(br)%dim(3); do jr = 1, block(br)%dim(2); do ir = 1-gc(1), 0
        call LoopOverDonors(block,grid,tbuf,br,1,force,ir,jr,kr,nodeinside,processed, &
                           [1-gc(1),1-gc(2),1-gc(3)],procStart)
      enddo; enddo; enddo
      !$omp end parallel do

      ! Face 2
      if (allocated(nodeinside)) deallocate(nodeinside)
      allocate(nodeinside(8,block(br)%dim(1)+1:block(br)%dim(1)+gc(1),1-gc(2):block(br)%dim(2)+gc(2),1-gc(3):block(br)%dim(3)+gc(3)))
      nodeinside = .false.
      !$omp parallel do collapse(3) private(ir,jr,kr) schedule(dynamic)
      do kr = 1, block(br)%dim(3); do jr = 1, block(br)%dim(2); do ir = block(br)%dim(1)+1,block(br)%dim(1)+gc(1)
        call LoopOverDonors(block,grid,tbuf,br,2,force,ir,jr,kr,nodeinside,processed, &
                           [block(br)%dim(1)+1,1-gc(2),1-gc(3)],procStart)
      enddo; enddo; enddo
      !$omp end parallel do

      ! Face 3
      if (allocated(nodeinside)) deallocate(nodeinside)
      allocate(nodeinside(8,1-gc(1):block(br)%dim(1)+gc(1),1-gc(2):0,1-gc(3):block(br)%dim(3)+gc(3)))
      nodeinside = .false.
      !$omp parallel do collapse(3) private(ir,jr,kr) schedule(dynamic)
      do kr = 1, block(br)%dim(3); do jr = 1-gc(2), 0; do ir = 1, block(br)%dim(1)
        call LoopOverDonors(block,grid,tbuf,br,3,force,ir,jr,kr,nodeinside,processed, &
                           [1-gc(1),1-gc(2),1-gc(3)],procStart)
      enddo; enddo; enddo
      !$omp end parallel do

      ! Face 4
      if (allocated(nodeinside)) deallocate(nodeinside)
      allocate(nodeinside(8,1-gc(1):block(br)%dim(1)+gc(1),block(br)%dim(2)+1:block(br)%dim(2)+gc(2),1-gc(3):block(br)%dim(3)+gc(3)))
      nodeinside = .false.
      !$omp parallel do collapse(3) private(ir,jr,kr) schedule(dynamic)
      do kr = 1, block(br)%dim(3); do jr = block(br)%dim(2)+1, block(br)%dim(2)+gc(2); do ir = 1, block(br)%dim(1)
        call LoopOverDonors(block,grid,tbuf,br,4,force,ir,jr,kr,nodeinside,processed, &
                           [1-gc(1),block(br)%dim(2)+1,1-gc(3)],procStart)
      enddo; enddo; enddo
      !$omp end parallel do

      if (mesh_cfg%meshType==3) then

        ! Face 5
        if (allocated(nodeinside)) deallocate(nodeinside)
        allocate(nodeinside(8,1-gc(1):block(br)%dim(1)+gc(1),1-gc(2):block(br)%dim(2)+gc(2),1-gc(3):0))
        nodeinside = .false.
        !$omp parallel do collapse(3) private(ir,jr,kr) schedule(dynamic)
        do kr = 1-gc(3), 0; do jr = 1, block(br)%dim(2); do ir = 1, block(br)%dim(1)
          call LoopOverDonors(block,grid,tbuf,br,5,force,ir,jr,kr,nodeinside,processed, &
                            [1-gc(1),1-gc(2),1-gc(3)],procStart)
        enddo; enddo; enddo
        !$omp end parallel do

        !Face 6
        if (allocated(nodeinside)) deallocate(nodeinside)
        allocate(nodeinside(8,1-gc(1):block(br)%dim(1)+gc(1),1-gc(2):block(br)%dim(2)+gc(2),block(br)%dim(3)+1:block(br)%dim(3)+gc(3)))
        nodeinside = .false.
        !$omp parallel do collapse(3) private(ir,jr,kr) schedule(dynamic)
        do kr = block(br)%dim(3)+1,block(br)%dim(3)+gc(3); do jr = 1, block(br)%dim(2); do ir = 1, block(br)%dim(1)
          call LoopOverDonors(block,grid,tbuf,br,6,force,ir,jr,kr,nodeinside,processed, &
                            [1-gc(1),1-gc(2),block(br)%dim(3)+1],procStart)
        enddo; enddo; enddo
        !$omp end parallel do

      endif
      
    enddo

    ! Concatenate the per-thread record buffers into the global list. Records of
    ! any given receiver stay in their original (bd,kd,jd,id) order because each
    ! receiver cell is handled entirely by one thread.
    ni = 0
    do t = 0, nthreads-1
      ni = ni + tbuf(t)%n
    end do
    allocate(intersection(max(ni,1)))
    off = 0
    do t = 0, nthreads-1
      if (tbuf(t)%n > 0) intersection(off+1:off+tbuf(t)%n) = tbuf(t)%rec(1:tbuf(t)%n)
      off = off + tbuf(t)%n
    end do

    ! Group the records by receiver cell (stable counting sort on the linear cell
    ! key), so that VolumeFractions reads only the records of its receiver instead
    ! of scanning them all for every boundary ghost cell: that scan cost
    ! O(N_ghost_cells x N_records), 574 s of the 657 s of a 48 000-receiver case at 1
    ! thread. The records of a receiver keep their order, so its sums are the same.
    block
      integer :: b, r, lin, nkeys
      integer, allocatable :: cnt(:)
      type(intersection_type), allocatable :: sorted(:)
      rec_gc = gc
      if (allocated(rec_blkoff)) deallocate(rec_blkoff)
      if (allocated(rec_off)) deallocate(rec_off)
      allocate(rec_blkoff(size(block)+1))
      rec_blkoff(1) = 0
      do b = 1, size(block)
        rec_blkoff(b+1) = rec_blkoff(b) + (block(b)%dim(1)+2*gc(1))*(block(b)%dim(2)+2*gc(2))*(block(b)%dim(3)+2*gc(3))
      enddo
      nkeys = rec_blkoff(size(block)+1)
      allocate(cnt(nkeys), rec_off(nkeys+1))
      cnt = 0
      do r = 1, ni
        lin = rec_key(block, intersection(r)%receiverID)
        cnt(lin) = cnt(lin) + 1
      enddo
      rec_off(1) = 1
      do lin = 1, nkeys
        rec_off(lin+1) = rec_off(lin) + cnt(lin)
      enddo
      allocate(sorted(size(intersection)))
      cnt = 0
      do r = 1, ni
        lin = rec_key(block, intersection(r)%receiverID)
        sorted(rec_off(lin)+cnt(lin)) = intersection(r)
        cnt(lin) = cnt(lin) + 1
      enddo
      call move_alloc(sorted, intersection)
    end block

    ! BC ids before VolumeFractions turns the receivers into 102/104
    allocate(gp0(size(block),6))
    do br = 1, size(block)
      do fr = 1, block(br)%nfaces
        gp0(br,fr)%id = block(br)%face(fr)%center(1:block(br)%face(fr)%Nm,1:block(br)%face(fr)%Nn)%bc%gp_id
      enddo
    enddo

    !% Check volume division for receivers
    do br = 1, size(block)
      ! Face 1
      !$omp parallel private(ir,jr,kr)
      !$omp do collapse(3) schedule(dynamic)
      do kr = 1, block(br)%dim(3); do jr = 1, block(br)%dim(2); do ir = 1-gc(1), 0
          call VolumeFractions(block,br,1,ir,jr,kr,ni,intersection,unitlog)
      enddo; enddo; enddo
      !$omp end parallel
      ! Face 2
      !$omp parallel private(ir,jr,kr)
      !$omp do collapse(3) schedule(dynamic)
      do kr = 1, block(br)%dim(3); do jr = 1, block(br)%dim(2); do ir = block(br)%dim(1)+1,block(br)%dim(1)+gc(1)
          call VolumeFractions(block,br,2,ir,jr,kr,ni,intersection,unitlog)
      enddo; enddo; enddo
      !$omp end parallel
      ! Face 3
      !$omp parallel private(ir,jr,kr)
      !$omp do collapse(3) schedule(dynamic)
      do kr = 1, block(br)%dim(3); do jr = 1-gc(2), 0; do ir = 1, block(br)%dim(1)
          call VolumeFractions(block,br,3,ir,jr,kr,ni,intersection,unitlog)
      enddo; enddo; enddo
      !$omp end parallel
      ! Face 4
      !$omp parallel private(ir,jr,kr)
      !$omp do collapse(3) schedule(dynamic)
      do kr = 1, block(br)%dim(3); do jr = block(br)%dim(2)+1, block(br)%dim(2)+gc(2); do ir = 1, block(br)%dim(1)
          call VolumeFractions(block,br,4,ir,jr,kr,ni,intersection,unitlog)
      enddo; enddo; enddo
      !$omp end parallel
      ! Face 5
      !$omp parallel private(ir,jr,kr)
      !$omp do collapse(3) schedule(dynamic)
      do kr = 1-gc(3), 0; do jr = 1, block(br)%dim(2); do ir = 1, block(br)%dim(1)
          call VolumeFractions(block,br,5,ir,jr,kr,ni,intersection,unitlog)
      enddo; enddo; enddo
      !$omp end parallel
      ! Face 6
      !$omp parallel private(ir,jr,kr)
      !$omp do collapse(3) schedule(dynamic)
      do kr = block(br)%dim(3)+1,block(br)%dim(3)+gc(3); do jr = 1, block(br)%dim(2); do ir = 1, block(br)%dim(1)
          call VolumeFractions(block,br,6,ir,jr,kr,ni,intersection,unitlog)
      enddo; enddo; enddo
      !$omp end parallel
      enddo

      close(unitlog)

      call CompleteReceivers(block,gp0)
      deallocate(rec_off, rec_blkoff)

  end subroutine chimera_wrapper

  subroutine LoopOverDonors(block,grid,tbuf,br,fr,force,ir,jr,kr,nodeinside,processed,startingIndexes,procStart)
    use bc_block_mod, only: BC_block
    use intersection_mod
    use chimera_grid_mod, only: donor_grid_t, query_donor_grid
    !$ use omp_lib, only: omp_get_thread_num
    implicit none
    type(BC_block), intent(in)     :: block(:)
    type(donor_grid_t), intent(in) :: grid
    type(rec_buffer), intent(inout) :: tbuf(0:)
    integer, intent(in)    :: br,fr,ir,jr,kr
    logical, intent(in)    :: force
    integer, intent(in)    :: startingIndexes(3)
    integer, intent(in)    :: procStart(3)
    logical, intent(inout) :: nodeinside(:,startingIndexes(1):,startingIndexes(2):,startingIndexes(3):)
    logical, intent(inout) :: processed(procStart(1):,procStart(2):,procStart(3):)

    integer                :: bd,id,jd,kd,d,m,n,nd,ncand,tid
    logical                :: next, inside
    real(8)                :: receiver(3,8), donor(3,8), vr, vr_tet, vclip
    integer, allocatable   :: cb(:), ci(:), cj(:), ck(:)
    integer, allocatable   :: keep(:)

    if (.not.is_chimera_face(block,br,fr,ir,jr,kr,force)) return
    if (processed(ir,jr,kr)) return
    processed(ir,jr,kr) = .true.

    tid = 0
    !$ tid = omp_get_thread_num()

    ! Broad phase: only donor cells whose bucket overlaps this receiver cell.
    ! Candidates are returned in (bd,kd,jd,id) order, so the records appended
    ! below are in the same order as the former exhaustive donor scan.
    call query_donor_grid(grid, br, block(br)%bbmin(ir,jr,kr)%c(1:3), &
                          block(br)%bbmax(ir,jr,kr)%c(1:3), cb, ci, cj, ck, ncand)

    ! Narrow-phase cell bounding-box test (III level)
    allocate(keep(ncand))
    nd = 0
    do m = 1, ncand
      bd = cb(m); id = ci(m); jd = cj(m); kd = ck(m)
      next = .false.
      do d = 1, 3
        if( (block(bd)%bbmin(id,jd,kd)%c(d)>block(br)%bbmax(ir,jr,kr)%c(d)) .and. &
            (block(bd)%bbmax(id,jd,kd)%c(d)>block(br)%bbmax(ir,jr,kr)%c(d)) ) next = .true.
        if( (block(bd)%bbmin(id,jd,kd)%c(d)<block(br)%bbmin(ir,jr,kr)%c(d)) .and. &
            (block(bd)%bbmax(id,jd,kd)%c(d)<block(br)%bbmin(ir,jr,kr)%c(d)) ) next = .true.
      enddo
      if (next) cycle
      nd = nd + 1
      keep(nd) = m
    enddo
    if (nd == 0) return

    receiver(:,1) = block(br)%node(ir-1,jr-1,kr-1)%c(1:3)*fs
    receiver(:,2) = block(br)%node(ir-1, jr ,kr-1)%c(1:3)*fs
    receiver(:,3) = block(br)%node(ir-1,jr-1, kr )%c(1:3)*fs
    receiver(:,4) = block(br)%node(ir-1, jr , kr )%c(1:3)*fs
    receiver(:,5) = block(br)%node( ir ,jr-1,kr-1)%c(1:3)*fs
    receiver(:,6) = block(br)%node( ir , jr ,kr-1)%c(1:3)*fs
    receiver(:,7) = block(br)%node( ir ,jr-1, kr )%c(1:3)*fs
    receiver(:,8) = block(br)%node( ir , jr , kr )%c(1:3)*fs

    ! Receiver nodes inside any donor (IV level): a receiver with all eight nodes
    ! covered must be closed by its donors, the others are only "not checkable"
    do n = 1, nd
      call donor_nodes(keep(n))
      do d = 1, 8
        if (nodeinside(d,ir,jr,kr)) cycle
        call pointInsideHexahedron(receiver(:,d), donor, inside)
        nodeinside(d,ir,jr,kr) = inside
      enddo
    enddo

    ! Overlap volumes by clipping the two cells split into tetrahedra, as the fraction
    ! of the receiver each donor covers times its volume (block%vol, the 5-tetrahedron
    ! volume of the solver: the weights are ratios, so the factor cancels). Exact for
    ! planar faces, a consistent planar model of warped ones, accurate on thin overlaps.
    vr = block(br)%vol(ir,jr,kr)
    do n = 1, nd
      m = keep(n)
      call donor_nodes(m)
      call hexOverlapVolume(receiver, donor, vclip, vr_tet)
      if (vr > 0.d0 .and. vr_tet > 0.d0) then
        vclip = vclip/vr_tet*vr
      else
        vclip = vclip/(fs**3)
      endif
      if (vclip > 0.d0) call append_record(tbuf(tid), [br,ir,jr,kr], [cb(m),ci(m),cj(m),ck(m)], &
                                           nodeinside(:,ir,jr,kr), vclip)
    enddo

  contains

    subroutine donor_nodes(m)
      integer, intent(in) :: m
      integer :: bd, id, jd, kd
      bd = cb(m); id = ci(m); jd = cj(m); kd = ck(m)
      donor(:,1) = block(bd)%node(id-1,jd-1,kd-1)%c(1:3)*fs
      donor(:,2) = block(bd)%node(id-1, jd ,kd-1)%c(1:3)*fs
      donor(:,3) = block(bd)%node(id-1,jd-1, kd )%c(1:3)*fs
      donor(:,4) = block(bd)%node(id-1, jd , kd) %c(1:3)*fs
      donor(:,5) = block(bd)%node( id ,jd-1,kd-1)%c(1:3)*fs
      donor(:,6) = block(bd)%node( id , jd ,kd-1)%c(1:3)*fs
      donor(:,7) = block(bd)%node( id ,jd-1, kd )%c(1:3)*fs
      donor(:,8) = block(bd)%node( id , jd , kd )%c(1:3)*fs
    end subroutine donor_nodes

  end subroutine LoopOverDonors

  !> A facelet is a chimera receiver when both of its ghost layers found donors. One
  !> that reaches the donor block with a single layer, a sliver at the rim of an
  !> overlap thinner than the sampling resolution in the other layer, would be written
  !> with a donor count of 0, which MOSE refuses at read time. A facelet claimed by
  !> BC-force-chimera alone (declared neither chimera nor connection) then keeps its own
  !> BC, as when it finds no donor at all. A declared one keeps what it found and is
  !> reported, as are the declared facelets left without any donor: these keep ID 100,
  !> on which MOSE applies no boundary flux.
  subroutine CompleteReceivers(block,gp0)
    use bc_block_mod, only: BC_block
    use bc_names_mod, only: MARKER_Chim, MARKER_CONN
    use grid_mod,     only: mesh_cfg, fmn2ijk
    implicit none
    type(BC_block), intent(inout) :: block(:)
    type(face_ids), intent(in)    :: gp0(:,:)
    integer :: br, fr, nf, m, n, g, Ai, Aj, Ak, gi(2), gj(2), gk(2), n100, none
    logical :: has(2), declared

    do br = 1, size(block)
      nf = block(br)%nfaces
      if (mesh_cfg%meshType /= 3) nf = min(nf, 4)   ! k faces are searched on a full 3-D mesh only
      do fr = 1, nf
        n100 = 0
        none = 0
        do n = 1, block(br)%face(fr)%Nn
          do m = 1, block(br)%face(fr)%Nm
            call fmn2ijk(fr,m,n,block(br)%dim(1),block(br)%dim(2),block(br)%dim(3),Ai,Aj,Ak)
            do g = 1, 2
              gi(g) = Ai; gj(g) = Aj; gk(g) = Ak
              select case(fr)
                case(1); gi(g) = Ai-g
                case(2); gi(g) = Ai+g
                case(3); gj(g) = Aj-g
                case(4); gj(g) = Aj+g
                case(5); gk(g) = Ak-g
                case(6); gk(g) = Ak+g
              end select
              has(g) = allocated(block(br)%face(fr)%cell(gi(g),gj(g),gk(g))%chimerainfo)
            enddo
            declared = trim(block(br)%face(fr)%center(m,n)%bc%definition)==trim(MARKER_Chim) .or. &
                       trim(block(br)%face(fr)%center(m,n)%bc%definition)==trim(MARKER_CONN)
            if (has(1) .neqv. has(2)) then
              if (declared) then
                none = none + 1
              else
                do g = 1, 2
                  if (has(g)) deallocate(block(br)%face(fr)%cell(gi(g),gj(g),gk(g))%chimerainfo)
                enddo
                block(br)%face(fr)%center(m,n)%bc%gp_id = gp0(br,fr)%id(m,n)
              endif
            endif
            if (block(br)%face(fr)%center(m,n)%bc%gp_id == 100) n100 = n100 + 1
          enddo
        enddo
        if (none > 0) write(*,'(A,I0,A,I0,A,I0,A)') '[WARNING] chimera: block ', br, ' face ', fr, ': ', none, &
          ' facelet(s) found donors for one ghost layer only; the other is written with 0 donors, which MOSE refuses'
        if (n100 > 0) write(*,'(A,I0,A,I0,A,I0,A)') '[WARNING] chimera: block ', br, ' face ', fr, ': ', n100, &
          ' facelet(s) found no donor and keep ID 100, on which MOSE applies no boundary flux'
      enddo
    enddo

  end subroutine CompleteReceivers

  !> Append one intersection record to a buffer, doubling capacity as needed.
  subroutine append_record(buf, rid, did, nin, vol)
    use intersection_mod, only: intersection_type
    type(rec_buffer), intent(inout) :: buf
    integer, intent(in) :: rid(4), did(4)
    logical, intent(in) :: nin(8)
    real(8), intent(in) :: vol
    type(intersection_type), allocatable :: tmp(:)
    integer :: cap

    if (.not. allocated(buf%rec)) allocate(buf%rec(256))
    cap = size(buf%rec)
    if (buf%n >= cap) then
      allocate(tmp(2*cap))
      tmp(1:buf%n) = buf%rec(1:buf%n)
      call move_alloc(tmp, buf%rec)
    endif
    buf%n = buf%n + 1
    buf%rec(buf%n)%receiverID      = rid
    buf%rec(buf%n)%donorID         = did
    buf%rec(buf%n)%nodeinside      = nin
    buf%rec(buf%n)%inter_volume    = vol
    buf%rec(buf%n)%volume_fraction = 0.d0
  end subroutine append_record


  subroutine VolumeFractions(block,br,fr,ir,jr,kr,ni,intersection,unitlog)
    use bc_block_mod, only: BC_block
    use intersection_mod
    use grid_mod, only: ijk2mn
    implicit none
    type(BC_block), intent(inout)       :: block(:)
    integer, intent(in)                    :: ir,jr,kr,fr,br,ni,unitlog
    type(intersection_type), intent(inout) :: intersection(:)
    
    integer                 :: localID(4)
    real(8)                 :: volume
    real(8)                 :: vol_tol
    integer                 :: k,i,m,n,t
    integer                 :: ni_per_receiver
    logical                 :: nodeinside_local(8)
    integer                 :: p1, p2
    integer                 :: i0, i1, key, b, nbdon
    real(8)                 :: vr, vmax
    real(8), allocatable    :: volb(:)
    logical                 :: closed

    localID = [br,ir,jr,kr]
    key = rec_key(block, localID)
    i0  = rec_off(key)
    i1  = rec_off(key+1) - 1
    volume = 0.d0
    ni_per_receiver = 0
    vol_tol = max(1d-18, 1d-6*block(br)%vol(ir,jr,kr))
    t = 0
    nodeinside_local = .false.
    allocate(volb(size(block)))
    volb = 0.d0
    do i = i0, i1
      if (all(intersection(i)%receiverID==localID)) then
        t = t + 1
        if (intersection(i)%inter_volume>vol_tol) then
          volume = volume+intersection(i)%inter_volume
          volb(intersection(i)%donorID(1)) = volb(intersection(i)%donorID(1)) + intersection(i)%inter_volume
          ni_per_receiver = ni_per_receiver+1
        endif
        nodeinside_local = intersection(i)%nodeinside
      endif
    enddo

    if (t==0) return
    if (volume==0.d0) return
    if (ni_per_receiver==0) return

    do i = i0, i1
      if (all(intersection(i)%receiverID==localID)) then
        if (intersection(i)%inter_volume>vol_tol) then
          intersection(i)%volume_fraction = intersection(i)%inter_volume/volume
        else
          intersection(i)%volume_fraction = 0.d0
        endif
      endif
    enddo
    
    allocate(block(br)%face(fr)%cell(ir,jr,kr)%chimerainfo(1:ni_per_receiver,1:5))
    call ijk2mn(ir,jr,kr,fr,m,n)
    
    ! 102 when a donor shares a phase with the receiver, 104 otherwise. Only the donors
    ! written below count: a ghost cell that merely touches a block of its own phase
    ! (zero intersection volume, as the solid row along a corner block) stays 104
    block(br)%face(fr)%center(m,n)%bc%gp_id = 104
    do i = i0, i1
      if (all(intersection(i)%receiverID==localID) .and. intersection(i)%inter_volume>vol_tol) then
        do p1 = 1, size(block(br)%associated_phase)
          do p2 = 1, size(block(intersection(i)%donorID(1))%associated_phase)
              if (block(br)%associated_phase(p1)%name==block(intersection(i)%donorID(1))%associated_phase(p2)%name) then
                block(br)%face(fr)%center(m,n)%bc%gp_id = 102
            endif
          enddo
        enddo
      endif
    enddo

    k = 0
    do i = i0, i1
      if (all(intersection(i)%receiverID==localID)) then
        if (intersection(i)%inter_volume>vol_tol) then
          k = k+1
          ! donorID(1) indexes block(:), all phases together: the bc files number blocks
          ! per phase (block%id, as the receiver header and a 101/103 partner), and the
          ! two differ as soon as another phase comes first (every 104 donor, 102 too)
          block(br)%face(fr)%cell(ir,jr,kr)%chimerainfo(k,1)   = real(block(intersection(i)%donorID(1))%id)
          block(br)%face(fr)%cell(ir,jr,kr)%chimerainfo(k,2:4) = real(intersection(i)%donorID(2:4))
          block(br)%face(fr)%cell(ir,jr,kr)%chimerainfo(k,5) = intersection(i)%volume_fraction
        endif
      endif
    enddo

    ! Closure: the donors of one block tile the receiver at most once, but two donor
    ! blocks that overlap each other both cover it (RL36: block 1 face 6 under B2 and
    ! B8), so their sum reaches 2 V_r while every weight is right. The receiver closes
    ! when the sum, or with several donor blocks the largest per-block sum, is within
    ! 1e-3 of its volume; the per-block sums are logged whenever more than one block donates.
    vr     = block(br)%vol(ir,jr,kr)
    vmax   = maxval(volb)
    nbdon  = count(volb > 0.d0)
    closed = abs(volume-vr) <= 1d-3*vr
    if (nbdon > 1 .and. abs(vmax-vr) <= 1d-3*vr) closed = .true.
    !$omp critical(chimera_print)
    if (closed) then
      write(unitlog,*) 'Volume division succesful'
    elseif (all(nodeinside_local)) then
      write(unitlog,*) 'Chimera volume division failed'
    else
      write(unitlog,*) 'Volume division succesful (not checkable)'
    endif
    write(unitlog,*) ' - Receiver ID           = ', br,ir,jr,kr
    write(unitlog,*) ' - Receiver total volume = ', volume
    write(unitlog,*) ' - Receiver real volume  = ', vr
    if (nbdon > 1) then
      write(unitlog,'(A)',advance='no') '  - Volume per donor block ='
      do b = 1, size(block)
        if (volb(b) > 0.d0) write(unitlog,'(A,I0,A,ES14.6)',advance='no') ' ', b, ':', volb(b)
      enddo
      write(unitlog,*)
    endif
    !$omp end critical(chimera_print)

  end subroutine VolumeFractions

end module bc_chimera_mod
