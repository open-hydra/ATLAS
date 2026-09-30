!>@brief One pass over the fine-level boundary-condition file before anything
!> is cut: what every boundary cell of the original mesh carries, keyed by the
!> canonical ordinal split_bc_mod uses.
!>
!> Two consumers. The manifold check needs the type-501 pairs before the
!> decomposition is fixed: MOSE aborts at start-up when the two blocks of a
!> manifold land on different ranks (MOSE_Mod_Allocate_Data::abort_if_split),
!> and its BC_Manifold integrates over both faces whole, so neither may be cut
!> tangentially. The cost objective needs the type of every boundary cell to
!> price the faces of a candidate piece.
module bc_scan_mod
  use decomposition_mod
  implicit none
  private

  public :: bc_scan_fine, check_manifold_pairs, prop_lines, ordinal_layout

  integer, parameter :: MAXLINE = 8192

  type, public :: bc_scan_t
    logical              :: ok   = .false.  !< the fine file was found and read
    integer              :: ntot = 0        !< boundary cells of one copy of the table
    integer, allocatable :: obase(:), fbase(:,:), pnm(:,:), pnn(:,:)
    integer, allocatable :: ctype(:)        !< BC id of every boundary cell (first copy)
    integer, allocatable :: donor(:,:)      !< (4,ntot) donor block,i,j,k of a 101/103/201 record, 0 otherwise
    integer              :: nman = 0        !< distinct manifold pairs
    integer, allocatable :: man(:,:)        !< (4,nman) target block, target face, source block, source face
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
    allocate(scan%ctype(scan%ntot), scan%donor(4,scan%ntot), scan%man(4,8))
    scan%ctype = 0
    scan%donor = 0
    scan%nman  = 0

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
        case(501)
          read(u,'(A)',iostat=ios) line
          il = il + 1
          if (ios == 0) read(line,*,iostat=ios) d(1:2)
          if (ios /= 0) then
            write(*,'(A,I0)') ' [ERROR] malformed manifold record at line ', il
            write(*,'(A)')    '         (the solvers read two integers: source block, source face)'
            ierr = 1; exit
          endif
          call add_manifold(scan, h(1), h(5), d(1), d(2))
          np = np - 1
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


  subroutine add_manifold(scan, bm, fm, bs, fs)
    type(bc_scan_t), intent(inout) :: scan
    integer,         intent(in)    :: bm, fm, bs, fs
    integer, allocatable :: tmp(:,:)
    integer :: m

    do m = 1, scan%nman
      if (all(scan%man(:,m) == [bm, fm, bs, fs])) return
    enddo
    if (scan%nman == size(scan%man, 2)) then
      allocate(tmp(4, 2*scan%nman))
      tmp(:,1:scan%nman) = scan%man(:,1:scan%nman)
      call move_alloc(tmp, scan%man)
    endif
    scan%nman = scan%nman + 1
    scan%man(:,scan%nman) = [bm, fm, bs, fs]

  end subroutine add_manifold


  !> A manifold (BC 501) names a whole source face, not a cell: BC_Manifold
  !> averages the state over the entire source face and scales the mass flux
  !> by the entire target face, so a cut tangential to either face changes the
  !> answer. And MOSE refuses the two blocks on different ranks (abort_if_split),
  !> so the decomposition is checked here, with the same LPT the solver applies,
  !> rather than discovered at the first time step.
  subroutine check_manifold_pairs(scan, dec, owner, ierr)
    type(bc_scan_t),       intent(in)  :: scan
    type(decomposition_t), intent(in)  :: dec
    integer,               intent(in)  :: owner(:)
    integer,               intent(out) :: ierr
    integer :: m, bm, fm, bs, fs, pm, ps

    ierr = 0
    do m = 1, scan%nman
      bm = scan%man(1,m); fm = scan%man(2,m)
      bs = scan%man(3,m); fs = scan%man(4,m)

      if (bs < 1 .or. bs > dec%nparent .or. fs < 1 .or. fs > NFACES) then
        write(*,'(A,I0,A,I0,A,I0,A,I0)') ' [ERROR] manifold (BC 501) on block ', bm, ' face ', fm, &
          ' draws from block ', bs, ' face ', fs
        write(*,'(A)') '         which the grid does not have: the BC file does not belong to this grid'
        ierr = 1; cycle
      endif

      pm = face_piece(dec, bm, fm)
      ps = face_piece(dec, bs, fs)
      if (pm == 0) then
        write(*,'(A,I0,A,I0,A)') ' [ERROR] manifold (BC 501) on block ', bm, ' face ', fm, &
          ' is cut across new blocks: MOSE''s BC_Manifold scales the'
        write(*,'(A)') '         mass flux by the whole target face, so that face must stay inside one block.'
        write(*,'(A,I0,A,A)') '         Forbid the cuts tangential to it with [MDB-Block', bm, &
          '] split-directions = ', dirname(face_dir(fm))
        ierr = 1
      endif
      if (ps == 0) then
        write(*,'(A,I0,A,I0,A,I0,A,I0,A)') ' [ERROR] manifold (BC 501) on block ', bm, ' face ', fm, &
          ' draws from block ', bs, ' face ', fs, ', which is cut across new blocks:'
        write(*,'(A)') '         MOSE''s BC_Manifold averages the whole source face, so it must stay inside one block.'
        write(*,'(A,I0,A,A)') '         Forbid the cuts tangential to it with [MDB-Block', bs, &
          '] split-directions = ', dirname(face_dir(fs))
        ierr = 1
      endif
      if (pm == 0 .or. ps == 0) cycle

      if (owner(pm) /= owner(ps)) then
        write(*,'(A,I0,A,I0,A,I0,A,I0,A)') ' [ERROR] manifold (BC 501): block ', bm, ' face ', fm, &
          ' (new block ', pm, ', rank ', owner(pm), ')'
        write(*,'(A,I0,A,I0,A,I0,A,I0,A)') '         draws from block ', bs, ' face ', fs, &
          ' (new block ', ps, ', rank ', owner(ps), ').'
        write(*,'(A)') '         MOSE aborts at start-up when the two blocks of a manifold sit on different ranks'
        write(*,'(A)') '         (abort_if_split): change ranks, or restrict the cuts with [MDB-Block#] split-directions'
        ierr = 1
      endif
    enddo

  end subroutine check_manifold_pairs


  pure function dirname(d) result(s)
    integer, intent(in) :: d
    character(len=1) :: s
    select case(d)
    case(1);      s = 'i'
    case(2);      s = 'j'
    case default; s = 'k'
    end select
  end function dirname

end module bc_scan_mod
