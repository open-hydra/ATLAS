!>@brief Decomposition bookkeeping for the Mesh Decomposition Builder.
!> A decomposition is a list of *pieces*: axis-aligned cell ranges carved out of
!> the original (parent) blocks. Pieces of the same parent tile it exactly, but
!> they are not required to form a tensor product of cut planes: because MOSE
!> stores block connectivity per boundary *cell*, T-junctions between pieces are
!> perfectly legal and need no special treatment.
module decomposition_mod
  implicit none
  private

  integer, parameter, public :: NFACES = 6

  !> One sub-block: an inclusive cell range [lo,hi] inside its parent block.
  type, public :: piece_t
    integer :: parent = 0
    integer :: lo(3)  = 1
    integer :: hi(3)  = 1
    logical :: dead   = .false.   !< no admissible split direction left
  end type piece_t

  type, public :: decomposition_t
    integer                    :: nparent = 0
    integer                    :: npieces = 0
    integer, allocatable       :: pdim(:,:)          !< (3,nparent) parent cell dimensions
    type(piece_t), allocatable :: piece(:)
    integer, allocatable       :: pfirst(:), plast(:) !< piece range of each parent (after finalize)
    integer, allocatable       :: hint(:)             !< per-parent last-hit cache for dec_locate
  end type decomposition_t

  public :: dec_init, dec_split_piece, dec_finalize
  public :: piece_dim, piece_cells, dec_locate
  public :: face_dir, face_side, face_opposite
  public :: fmn2ijk, ijk2mn, face_extent
  public :: dec_write_map

contains

  !> Start from the trivial decomposition: one piece per original block.
  subroutine dec_init(dec, nparent, pdim)
    type(decomposition_t), intent(out) :: dec
    integer,               intent(in)  :: nparent
    integer,               intent(in)  :: pdim(3,nparent)
    integer :: b

    dec%nparent = nparent
    dec%npieces = nparent
    allocate(dec%pdim(3,nparent))
    dec%pdim = pdim
    allocate(dec%piece(max(nparent,1)))
    do b = 1, nparent
      dec%piece(b)%parent = b
      dec%piece(b)%lo     = 1
      dec%piece(b)%hi     = pdim(:,b)
      dec%piece(b)%dead   = .false.
    enddo

  end subroutine dec_init


  !> Replace piece p by nsub pieces cut along direction dir.
  !> The extent is divided into nsub nearly equal parts, each an integer number
  !> of granules of size gran (so that every multigrid level cuts at an integer
  !> index too). The first part keeps slot p, the others are appended.
  subroutine dec_split_piece(dec, p, dir, nsub, gran)
    type(decomposition_t), intent(inout) :: dec
    integer,               intent(in)    :: p, dir, nsub, gran
    integer :: ng, base, rem, s, start, nseg, slot
    type(piece_t) :: src

    src = dec%piece(p)
    ng   = piece_dim(src, dir) / gran
    base = ng / nsub
    rem  = mod(ng, nsub)

    call grow_pieces(dec, dec%npieces + nsub - 1)

    start = src%lo(dir)
    do s = 1, nsub
      nseg = base
      if (s <= rem) nseg = base + 1

      if (s == 1) then
        slot = p
      else
        dec%npieces = dec%npieces + 1
        slot = dec%npieces
      endif

      dec%piece(slot)          = src
      dec%piece(slot)%dead     = .false.
      dec%piece(slot)%lo(dir)  = start
      dec%piece(slot)%hi(dir)  = start + nseg*gran - 1
      start = start + nseg*gran
    enddo

  end subroutine dec_split_piece


  subroutine grow_pieces(dec, needed)
    type(decomposition_t), intent(inout) :: dec
    integer,               intent(in)    :: needed
    type(piece_t), allocatable :: tmp(:)
    integer :: newsize

    if (needed <= size(dec%piece)) return
    newsize = max(needed, 2*size(dec%piece))
    allocate(tmp(newsize))
    tmp(1:dec%npieces) = dec%piece(1:dec%npieces)
    call move_alloc(tmp, dec%piece)

  end subroutine grow_pieces


  !> Sort pieces so that all pieces of a parent are contiguous and ordered by
  !> (k,j,i) origin, then build the per-parent index ranges and the lookup cache.
  !> The resulting piece order is the new global block numbering.
  subroutine dec_finalize(dec)
    type(decomposition_t), intent(inout) :: dec
    type(piece_t) :: tmp
    integer :: i, j, b

    ! Insertion sort: piece counts are small (hundreds), and it is stable.
    do i = 2, dec%npieces
      tmp = dec%piece(i)
      j = i - 1
      do while (j >= 1)
        if (.not. piece_before(tmp, dec%piece(j))) exit
        dec%piece(j+1) = dec%piece(j)
        j = j - 1
      enddo
      dec%piece(j+1) = tmp
    enddo

    if (allocated(dec%pfirst)) deallocate(dec%pfirst)
    if (allocated(dec%plast))  deallocate(dec%plast)
    if (allocated(dec%hint))   deallocate(dec%hint)
    allocate(dec%pfirst(dec%nparent), dec%plast(dec%nparent), dec%hint(dec%nparent))
    dec%pfirst = 0
    dec%plast  = -1

    do i = 1, dec%npieces
      b = dec%piece(i)%parent
      if (dec%pfirst(b) == 0) dec%pfirst(b) = i
      dec%plast(b) = i
    enddo
    dec%hint = dec%pfirst

  end subroutine dec_finalize


  !> Ordering predicate: parent, then k, then j, then i origin.
  pure logical function piece_before(a, b) result(res)
    type(piece_t), intent(in) :: a, b

    res = .false.
    if (a%parent /= b%parent) then
      res = (a%parent < b%parent); return
    endif
    if (a%lo(3) /= b%lo(3)) then
      res = (a%lo(3) < b%lo(3)); return
    endif
    if (a%lo(2) /= b%lo(2)) then
      res = (a%lo(2) < b%lo(2)); return
    endif
    res = (a%lo(1) < b%lo(1))

  end function piece_before


  pure integer function piece_dim(pc, d) result(n)
    type(piece_t), intent(in) :: pc
    integer,       intent(in) :: d
    n = pc%hi(d) - pc%lo(d) + 1
  end function piece_dim


  pure integer function piece_cells(pc) result(n)
    type(piece_t), intent(in) :: pc
    n = (pc%hi(1)-pc%lo(1)+1) * (pc%hi(2)-pc%lo(2)+1) * (pc%hi(3)-pc%lo(3)+1)
  end function piece_cells


  !> Piece owning cell (i,j,k) of parent block b, in *fine* parent indices.
  !> Returns 0 if the cell is outside the parent. Uses a per-parent hit cache:
  !> BC records are walked in block order, so consecutive queries mostly repeat.
  integer function dec_locate(dec, b, i, j, k) result(p)
    type(decomposition_t), intent(inout) :: dec
    integer,               intent(in)    :: b, i, j, k
    integer :: q

    p = 0
    if (b < 1 .or. b > dec%nparent) return

    q = dec%hint(b)
    if (q >= 1) then
      if (in_piece(dec%piece(q), b, i, j, k)) then
        p = q; return
      endif
    endif

    do q = dec%pfirst(b), dec%plast(b)
      if (in_piece(dec%piece(q), b, i, j, k)) then
        p = q
        dec%hint(b) = q
        return
      endif
    enddo

  end function dec_locate


  pure logical function in_piece(pc, b, i, j, k) result(res)
    type(piece_t), intent(in) :: pc
    integer,       intent(in) :: b, i, j, k

    res = pc%parent == b                        .and. &
          i >= pc%lo(1) .and. i <= pc%hi(1)     .and. &
          j >= pc%lo(2) .and. j <= pc%hi(2)     .and. &
          k >= pc%lo(3) .and. k <= pc%hi(3)

  end function in_piece


  !─────────────────────────────────────────────────────────────────────────────
  ! Face conventions, identical to ATLAS/MOSE:
  !   1 = i-min   2 = i-max   3 = j-min   4 = j-max   5 = k-min   6 = k-max

  pure integer function face_dir(f) result(d)
    integer, intent(in) :: f
    d = (f + 1) / 2
  end function face_dir


  !> 1 on the low-index side of the block, 2 on the high-index side.
  pure integer function face_side(f) result(s)
    integer, intent(in) :: f
    s = 2 - mod(f, 2)
  end function face_side


  !> The face of the neighbouring block that touches face f.
  pure integer function face_opposite(f) result(fo)
    integer, intent(in) :: f
    fo = f - 1 + 2*mod(f, 2)
  end function face_opposite


  !> Number of boundary cells along the two tangential directions of face f.
  pure subroutine face_extent(f, dim, nm, nn)
    integer, intent(in)  :: f, dim(3)
    integer, intent(out) :: nm, nn

    select case(f)
    case(1,2)
      nm = dim(2); nn = dim(3)
    case(3,4)
      nm = dim(1); nn = dim(3)
    case default
      nm = dim(1); nn = dim(2)
    end select

  end subroutine face_extent


  !> Face-local (m,n) to block-local (i,j,k). Mirrors ATLAS grid_mod::fmn2ijk.
  pure subroutine fmn2ijk(f, m, n, dim, i, j, k)
    integer, intent(in)  :: f, m, n, dim(3)
    integer, intent(out) :: i, j, k

    select case(f)
    case(1)
      i = 1;      j = m;      k = n
    case(2)
      i = dim(1); j = m;      k = n
    case(3)
      i = m;      j = 1;      k = n
    case(4)
      i = m;      j = dim(2); k = n
    case(5)
      i = m;      j = n;      k = 1
    case default
      i = m;      j = n;      k = dim(3)
    end select

  end subroutine fmn2ijk


  !> Inverse of fmn2ijk: block-local (i,j,k) on face f to face-local (m,n).
  pure subroutine ijk2mn(f, i, j, k, m, n)
    integer, intent(in)  :: f, i, j, k
    integer, intent(out) :: m, n

    select case(f)
    case(1,2)
      m = j; n = k
    case(3,4)
      m = i; n = k
    case default
      m = i; n = j
    end select

  end subroutine ijk2mn


  !> Human- and script-readable record of the decomposition, needed to map new
  !> block numbers back to the original ones when post-processing.
  subroutine dec_write_map(dec, filename, owner)
    type(decomposition_t), intent(in) :: dec
    character(len=*),      intent(in) :: filename
    integer, optional,     intent(in) :: owner(:)   !< rank owning each piece
    integer :: u, p, b

    open(newunit=u, file=filename, action='write', status='replace')
    write(u,'(A)') '# ATLAS MDB decomposition map'
    write(u,'(A)') '# parent blocks: ' // itoa(dec%nparent) // '  ->  new blocks: ' // itoa(dec%npieces)
    write(u,'(A)') '#'
    write(u,'(A)') '# new  parent   i0   i1    j0   j1    k0   k1      ni   nj   nk        cells  rank'
    do p = 1, dec%npieces
      b = dec%piece(p)%parent
      if (present(owner)) then
        write(u,'(2I6,3(2I6,2X),3X,3I5,I13,I6)') p, b, &
          dec%piece(p)%lo(1), dec%piece(p)%hi(1), &
          dec%piece(p)%lo(2), dec%piece(p)%hi(2), &
          dec%piece(p)%lo(3), dec%piece(p)%hi(3), &
          piece_dim(dec%piece(p),1), piece_dim(dec%piece(p),2), piece_dim(dec%piece(p),3), &
          piece_cells(dec%piece(p)), owner(p)
      else
        write(u,'(2I6,3(2I6,2X),3X,3I5,I13)') p, b, &
          dec%piece(p)%lo(1), dec%piece(p)%hi(1), &
          dec%piece(p)%lo(2), dec%piece(p)%hi(2), &
          dec%piece(p)%lo(3), dec%piece(p)%hi(3), &
          piece_dim(dec%piece(p),1), piece_dim(dec%piece(p),2), piece_dim(dec%piece(p),3), &
          piece_cells(dec%piece(p))
      endif
    enddo
    close(u)

  end subroutine dec_write_map


  pure function itoa(n) result(s)
    integer, intent(in) :: n
    character(len=12)   :: buf
    character(len=:), allocatable :: s
    write(buf,'(I0)') n
    s = trim(adjustl(buf))
  end function itoa

end module decomposition_mod
