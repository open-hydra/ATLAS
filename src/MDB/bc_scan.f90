!>@brief One pass over the fine-level boundary-condition file before anything
!> is cut: what every boundary cell of the original mesh carries, keyed by the
!> canonical ordinal split_bc_mod uses.
!>
!> One consumer: the cost objective needs the type of every boundary cell to
!> price the faces of a candidate piece. A manifold (501) record names no block
!> or cell (its payload is the group id, the role of the face and the group's
!> parameters: the solvers sum over the faces of a group wherever they lie), so
!> the split needs nothing from it: it is copied like any other property line.
module bc_scan_mod
  use decomposition_mod
  implicit none
  private

  public :: bc_scan_fine, prop_lines, ordinal_layout

  integer, parameter :: MAXLINE = 8192

  type, public :: bc_scan_t
    logical              :: ok   = .false.  !< the fine file was found and read
    integer              :: ntot = 0        !< boundary cells of one copy of the table
    integer, allocatable :: obase(:), fbase(:,:), pnm(:,:), pnn(:,:)
    integer, allocatable :: ctype(:)        !< BC id of every boundary cell (first copy)
    integer, allocatable :: cell(:,:)       !< (4,ntot) block,i,j,k of every boundary cell
    integer, allocatable :: donor(:,:)      !< (4,ntot) donor block,i,j,k of a 101/103/201 record, the first
                                            !< donor of a 102/104 one, 0 otherwise
  end type bc_scan_t

contains

  !> Canonical ordinal layout of a boundary table: cells numbered block by block,
  !> face by face, n outer and m inner. Identical to the one split_bc_level
  !> builds for the input file.
  pure subroutine ordinal_layout(nb, dim, obase, fbase, pnm, pnn, ntot)
    integer,              intent(in)  :: nb, dim(3,nb)
    integer, allocatable, intent(out) :: obase(:), fbase(:,:), pnm(:,:), pnn(:,:)
    integer,              intent(out) :: ntot
    integer :: b, f, nm, nn, ord

    allocate(obase(nb), fbase(NFACES,nb), pnm(NFACES,nb), pnn(NFACES,nb))
    ord = 0
    do b = 1, nb
      obase(b) = ord
      do f = 1, NFACES
        call face_extent(f, dim(:,b), nm, nn)
        pnm(f,b)   = nm
        pnn(f,b)   = nn
        fbase(f,b) = ord - obase(b)
        ord = ord + nm*nn
      enddo
    enddo
    ntot = ord

  end subroutine ordinal_layout


  !> Number of property lines following a header. The gas and solid files match
  !> the dispatch of MOSE_IO_BC::Check_BC exactly; a dispersed-phase file is
  !> written by ATLAS_BCB::write_dp_bc, which emits a property line only for a
  !> connection, a chimera and a 401-403 inlet -- its walls and symmetries are a
  !> bare header. A chimera (102/104) carries 1 + the donor count: the caller
  !> reads that header line itself.
  pure integer function prop_lines(t, dispersed) result(np)
    integer, intent(in) :: t
    logical, intent(in) :: dispersed

    select case(t)
    case(102, 104)
      np = 1      ! caller replaces this with 1 + ni(1) + ni(2)
    case(101, 103, 201)
      np = 1
    case default
      if (dispersed) then
        select case(t)
        case(401:403); np = 1
        case default;  np = 0
        end select
      else
        select case(t)
        case(301:309, 401:408, 410, 420, 501:506); np = 1   ! gsi 503-506 carry one property line
        case default;                              np = 0
        end select
      endif
    end select

  end function prop_lines


  !> Read the fine-level file of one phase. A missing file is not an error here
  !> (stage 2 reports it); a malformed one is.
  subroutine bc_scan_fine(infile, nb, dim, dispersed, scan, ierr)
    character(len=*), intent(in)  :: infile
    integer,          intent(in)  :: nb, dim(3,nb)
    logical,          intent(in)  :: dispersed
    type(bc_scan_t),  intent(out) :: scan
    integer,          intent(out) :: ierr
    ! Local
    integer :: u, ios, il, h(6), np, nb1, nb2, c, pm, pn, ord, d(4)
    logical :: ex
    character(len=MAXLINE) :: line

    ierr = 0
    inquire(file=infile, exist=ex)
    if (.not. ex) return

    call ordinal_layout(nb, dim, scan%obase, scan%fbase, scan%pnm, scan%pnn, scan%ntot)
    allocate(scan%ctype(scan%ntot), scan%cell(4,scan%ntot), scan%donor(4,scan%ntot))
    scan%ctype = 0
    scan%cell  = 0
    scan%donor = 0

    open(newunit=u, file=infile, status='old', action='read', iostat=ios)
    if (ios /= 0) then
      write(*,'(A)') ' [ERROR] cannot open '//trim(infile)
      ierr = 1; return
    endif

    il = 0
    do
      read(u,'(A)',iostat=ios) line
      if (ios /= 0) exit
      il = il + 1
      if (len_trim(line) == 0) cycle

      read(line,*,iostat=ios) h(1:6)
      if (ios /= 0) then
        write(*,'(A,I0,A)') ' [ERROR] cannot read a BC header (b i j k f type) at line ', il, ' of '//trim(infile)
        write(*,'(A)')      '         '//trim(line)
        ierr = 1; exit
      endif
      if (h(1) < 1 .or. h(1) > nb .or. h(5) < 1 .or. h(5) > NFACES) then
        write(*,'(A,I0,A)') ' [ERROR] BC record at line ', il, ' names a block or face the grid does not have'
        ierr = 1; exit
      endif

      np = prop_lines(h(6), dispersed)
      if (h(6) == 102 .or. h(6) == 104) then
        read(u,*,iostat=ios) nb1, nb2
        il = il + 1
        if (ios /= 0) then
          write(*,'(A,I0)') ' [ERROR] malformed chimera header at line ', il
          ierr = 1; exit
        endif
        np = nb1 + nb2
      endif

      ! First copy of the table only: a dispersed file repeats it per
      ! (material, population) pair with the same geometry.
      call ijk2mn(h(5), h(2), h(3), h(4), pm, pn)
      ord = scan%obase(h(1)) + scan%fbase(h(5),h(1)) + (pn-1)*scan%pnm(h(5),h(1)) + pm
      if (ord < 1 .or. ord > scan%ntot) then
        write(*,'(A,I0)') ' [ERROR] BC record out of range at line ', il
        ierr = 1; exit
      endif
      if (scan%ctype(ord) == 0) then
        scan%ctype(ord) = h(6)
        scan%cell(:,ord) = h(1:4)
        select case(h(6))
        case(101, 103, 201)
          read(u,'(A)',iostat=ios) line
          il = il + 1
          if (ios == 0) read(line,*,iostat=ios) d(1:4)
          if (ios /= 0) then
            write(*,'(A,I0)') ' [ERROR] malformed connection record at line ', il
            ierr = 1; exit
          endif
          scan%donor(:,ord) = d
          np = np - 1
        case(102, 104)
          if (np >= 1) then
            read(u,'(A)',iostat=ios) line
            il = il + 1
            if (ios == 0) read(line,*,iostat=ios) d(1:4)
            if (ios /= 0) then
              write(*,'(A,I0)') ' [ERROR] malformed chimera donor at line ', il
              ierr = 1; exit
            endif
            scan%donor(:,ord) = d
            np = np - 1
          endif
        end select
      endif

      do c = 1, np
        read(u,'(A)',iostat=ios) line
        il = il + 1
      enddo
    enddo
    close(u)

    scan%ok = (ierr == 0)

  end subroutine bc_scan_fine

end module bc_scan_mod
