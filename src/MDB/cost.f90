!>@brief Predicted time per rank of a decomposition, the cost objective.
!>
!> Cell balance is what MOSE and ICE assign blocks by, but not what a rank
!> spends its step on: every boundary cell is priced by the BC it carries,
!> every ghost cell is filled at every stage, and every cut face whose
!> neighbour sits on another rank costs a message and its bytes. The SWBLI
!> campaign measured an 8% spread of compute time at 100% cell balance. The
!> model here, with the coefficients of [MDB-Cost],
!>
!>   T(rank) = sum over the rank's blocks of
!>               c_cell * cells
!>             + sum over the block's faces of c_face(class) * face cells
!>             + c_ghost * ghost cells (GC layers on every face)
!>           + c_msg  * messages to other ranks
!>           + c_byte * bytes exchanged with other ranks
!>
!> is evaluated AFTER the solvers' own LPT on cell counts (lpt_assign): the
!> ranks are the ones the solver will form, so MDB lowers the predicted spread
!> only by shaping blocks whose equal cell counts carry equal work, never by
!> assuming an assignment the solver will not make. The unit defaults are
!> placeholders: the measured values come from ICE's timers, per BC class, and
!> enter through the [MDB-Cost] keys or cost-file. Data-dependent cost (a
!> shock detector, a stiff cell) is not modelled.
module cost_mod
  use decomposition_mod
  use bc_scan_mod, only: bc_scan_t
  implicit none
  private

  public :: cost_evaluate, face_class, read_cost_file

  integer, parameter :: GC = 2    ! MOSE_Global_m::gc

  integer, parameter, public :: NCLASS = 7
  integer, parameter, public :: CL_CONNECTION = 1, CL_COUPLED = 2, CL_CHIMERA = 3, CL_SYMMETRY = 4, &
                                CL_WALL = 5, CL_INOUT = 6, CL_SPECIAL = 7
  character(len=10), parameter, public :: CLASS_NAME(NCLASS) = &
    [character(len=10) :: 'connection', 'coupled', 'chimera', 'symmetry', 'wall', 'inout', 'special']

  !> The coefficients of the model, all 1 until calibrated.
  type, public :: cost_coef_t
    real(8) :: c_cell         = 1.0d0   !< per interior cell
    real(8) :: c_face(NCLASS) = 1.0d0   !< per boundary cell, by BC class
    real(8) :: c_ghost        = 1.0d0   !< per ghost cell filled
    real(8) :: c_msg          = 1.0d0   !< per message to another rank
    real(8) :: c_byte         = 1.0d0   !< per byte exchanged with another rank
    real(8) :: bytes_per_cell = 1.0d0   !< bytes a ghost cell carries (1: the term counts cells)
  end type cost_coef_t

  !> Partner pieces of one face and the cells each one exchanges.
  integer, parameter :: MAXPART = 64

contains

  !> BC class of a record type: which c_face applies.
  pure integer function face_class(t) result(c)
    integer, intent(in) :: t

    select case(t)
    case(101, 201);   c = CL_CONNECTION
    case(103);        c = CL_COUPLED
    case(102, 104);   c = CL_CHIMERA
    case(300);        c = CL_SYMMETRY
    case(301:309);    c = CL_WALL
    case(400:499);    c = CL_INOUT
    case(500:599);    c = CL_SPECIAL
    case default;     c = CL_WALL
    end select

  end function face_class


  !> Predicted time of every rank for a finalized decomposition and the
  !> owners lpt_assign gave it. tmean is the ideal (perfectly spread) time.
  subroutine cost_evaluate(dec, owner, nranks, scan, coef, tmax, tmean, rank_time)
    type(decomposition_t), intent(inout) :: dec        !< dec_locate keeps a hit cache
    integer,               intent(in)    :: owner(:), nranks
    type(bc_scan_t),       intent(in)    :: scan
    type(cost_coef_t),     intent(in)    :: coef
    real(8),               intent(out)   :: tmax, tmean
    real(8), allocatable,  intent(out), optional :: rank_time(:)
    ! Local
    integer :: p, b, f, dir, side, nm, nn, m, n, li, lj, lk, pi, pj, pk, pm, pn, ord, t, q, k
    integer :: pd(3), npart, part(MAXPART), pcount(MAXPART), ti, tj, tk
    real(8), allocatable :: tr(:)
    real(8) :: work, msgs, bytes

    allocate(tr(0:max(nranks,1)-1))
    tr = 0.0d0

    do p = 1, dec%npieces
      b     = dec%piece(p)%parent
      pd(1) = piece_dim(dec%piece(p), 1)
      pd(2) = piece_dim(dec%piece(p), 2)
      pd(3) = piece_dim(dec%piece(p), 3)

      work  = coef%c_cell * real(piece_cells(dec%piece(p)),8)
      msgs  = 0.0d0
      bytes = 0.0d0

      do f = 1, NFACES
        call face_extent(f, pd, nm, nn)
        dir  = face_dir(f)
        side = face_side(f)
        work = work + coef%c_ghost * real(GC * nm * nn, 8)

        npart = 0
        do n = 1, nn
          do m = 1, nm
            call fmn2ijk(f, m, n, pd, li, lj, lk)
            pi = dec%piece(p)%lo(1) + li - 1
            pj = dec%piece(p)%lo(2) + lj - 1
            pk = dec%piece(p)%lo(3) + lk - 1

            if (inherited(side, dir, p, b)) then
              call ijk2mn(f, pi, pj, pk, pm, pn)
              ord = scan%obase(b) + scan%fbase(f,b) + (pn-1)*scan%pnm(f,b) + pm
              t   = scan%ctype(ord)
              work = work + coef%c_face(face_class(t))
              if (t == 101 .or. t == 201) then
                q = dec_locate(dec, scan%donor(1,ord), scan%donor(2,ord), scan%donor(3,ord), scan%donor(4,ord))
                if (q > 0) call note_partner(q)
              endif
            else
              ! A cut face is a connection to the piece across the plane
              work = work + coef%c_face(CL_CONNECTION)
              call across(dir, side, pi, pj, pk, ti, tj, tk)
              q = dec_locate(dec, b, ti, tj, tk)
              if (q > 0) call note_partner(q)
            endif
          enddo
        enddo

        do k = 1, npart
          if (owner(part(k)) /= owner(p)) then
            msgs  = msgs + 1.0d0
            bytes = bytes + real(GC * pcount(k), 8) * coef%bytes_per_cell
          endif
        enddo
      enddo

      tr(owner(p)) = tr(owner(p)) + work + coef%c_msg * msgs + coef%c_byte * bytes
    enddo

    tmax  = maxval(tr)
    tmean = sum(tr) / real(max(nranks,1),8)
    if (present(rank_time)) then
      allocate(rank_time(0:max(nranks,1)-1))
      rank_time = tr
    endif

  contains

    logical function inherited(sd, dr, pp, bb) result(res)
      integer, intent(in) :: sd, dr, pp, bb
      if (sd == 1) then
        res = (dec%piece(pp)%lo(dr) == 1)
      else
        res = (dec%piece(pp)%hi(dr) == dec%pdim(dr,bb))
      endif
    end function inherited

    subroutine note_partner(q)
      integer, intent(in) :: q
      integer :: i
      do i = 1, npart
        if (part(i) == q) then
          pcount(i) = pcount(i) + 1
          return
        endif
      enddo
      if (npart < MAXPART) then
        npart = npart + 1
        part(npart)   = q
        pcount(npart) = 1
      else
        pcount(MAXPART) = pcount(MAXPART) + 1   ! beyond the buffer: still counted in bytes
      endif
    end subroutine note_partner

  end subroutine cost_evaluate


  !> Cell just outside face (dir,side) of the cell.
  pure subroutine across(dir, side, i, j, k, oi, oj, ok)
    integer, intent(in)  :: dir, side, i, j, k
    integer, intent(out) :: oi, oj, ok
    integer :: step

    step = 1
    if (side == 1) step = -1
    oi = i; oj = j; ok = k
    select case(dir)
    case(1);      oi = i + step
    case(2);      oj = j + step
    case default; ok = k + step
    end select

  end subroutine across


  !> A measured table overriding the coefficients: one `key value` per line,
  !> the keys of [MDB-Cost], comments after # or ;.
  subroutine read_cost_file(filename, coef, ierr)
    character(len=*),  intent(in)    :: filename
    type(cost_coef_t), intent(inout) :: coef
    integer,           intent(out)   :: ierr
    character(len=256) :: line, key
    real(8) :: val
    integer :: u, ios, ic, c
    logical :: ex, known

    ierr = 0
    inquire(file=filename, exist=ex)
    if (.not. ex) then
      write(*,'(A)') ' [ERROR] [MDB-Cost] cost-file not found: '//trim(filename)
      ierr = 1; return
    endif
    open(newunit=u, file=filename, status='old', action='read')
    do
      read(u,'(A)',iostat=ios) line
      if (ios /= 0) exit
      ic = scan(line, '#;')
      if (ic > 0) line = line(1:ic-1)
      if (len_trim(line) == 0) cycle
      read(line,*,iostat=ios) key, val
      if (ios /= 0) then
        write(*,'(A)') ' [ERROR] cost-file line is not `key value`: '//trim(line)
        ierr = 1; exit
      endif
      known = .true.
      select case (trim(key))
      case ('c-cell');         coef%c_cell  = val
      case ('c-ghost');        coef%c_ghost = val
      case ('c-msg');          coef%c_msg   = val
      case ('c-byte');         coef%c_byte  = val
      case ('bytes-per-cell'); coef%bytes_per_cell = val
      case default
        known = .false.
        do c = 1, NCLASS
          if (trim(key) == 'c-face-'//trim(CLASS_NAME(c))) then
            coef%c_face(c) = val
            known = .true.
          endif
        enddo
      end select
      if (.not. known) then
        write(*,'(A)') ' [ERROR] cost-file names a coefficient [MDB-Cost] does not have: '//trim(key)
        ierr = 1; exit
      endif
    enddo
    close(u)

  end subroutine read_cost_file

end module cost_mod
