!>@brief Load-balancing driver: decides how the original blocks must be cut.
!>
!> MOSE assigns whole blocks to ranks with a largest-processing-time-first
!> greedy (MOSE_Mod_MPI::partition_blocks), so the balance a decomposition will
!> actually achieve is fully predictable here. lpt_assign below is a faithful
!> reimplementation of that routine — including its tie-breaking — so the number
!> MDB reports is the number MOSE will print at run time.
!>
!> The splitting strategy is the classical one used for structured multi-block
!> solvers: repeatedly take the heaviest block and cut it, until the predicted
!> balance meets the target or no admissible cut is left.
!>
!> Balance on its own is the wrong thing to maximise, though. Every cut adds two
!> ghost layers on the new interface, and those cells are filled and exchanged at
!> every RK stage, so chasing the last points of balance can cost more than the
!> imbalance it removes. Each candidate is therefore scored as
!>
!>     score = balance / (1 + halo_weight * halo_overhead)
!>
!> and the best-scoring one is returned, not the last one visited (the search is
!> greedy and monotone in block count, so those differ). halo_weight = 0 restores
!> the historical balance-only behaviour.
module partition_mod
  use decomposition_mod
  implicit none
  private

  public :: build_decomposition, lpt_assign, report_decomposition

contains

  !> Grow the decomposition until the predicted LPT balance reaches target_bal
  !> (percent of ideal) on nranks ranks.
  !>
  !> gran      : cut granularity, 2**(MG_levels-1); every cut index is a multiple
  !> min_cells : smallest admissible sub-block extent along a split direction
  !> allow_dir : (3,nparent) directions the user permits to be cut
  subroutine build_decomposition(dec, nranks, target_bal, halo_weight, max_blocks, min_cells, gran, allow_dir, verb)
    type(decomposition_t), intent(inout) :: dec
    integer,  intent(in) :: nranks, max_blocks, min_cells, gran
    real(8),  intent(in) :: target_bal, halo_weight
    logical,  intent(in) :: allow_dir(:,:)
    logical,  intent(in) :: verb
    ! Local
    integer :: p, d, dir, nsub, nsub_max, best, iter
    integer :: total, wmax
    real(8) :: bal, ideal, halo, score, best_score
    integer, allocatable :: owner(:)
    type(piece_t), allocatable :: best_piece(:)
    integer :: best_npieces

    total = 0
    do p = 1, dec%npieces
      total = total + piece_cells(dec%piece(p))
    enddo
    ideal = real(total,8) / real(max(nranks,1),8)

    best_score   = -1.0d0
    best_npieces = 0

    iter = 0
    do
      iter = iter + 1
      call lpt_assign(dec, nranks, owner, bal)

      ! Score this candidate.  Balance alone is not the objective: reaching it
      ! costs cuts, every cut adds two ghost layers, and those ghost cells are
      ! filled and exchanged every RK stage.  Splitting until the balance target
      ! is met regardless of that price is what produced 592 blocks for 80 ranks
      ! (95.8 % balance bought with 34.5 % ghost) on the SWBLI case -- a worse
      ! decomposition, by this measure, than the 96-block one it passed through
      ! on the way.  halo_weight = 0 restores the old balance-only behaviour.
      halo  = halo_overhead(dec)
      score = bal / (1.0d0 + halo_weight * halo / 100.0d0)

      if (dec%npieces >= nranks .and. score > best_score) then
        best_score   = score
        best_npieces = dec%npieces
        if (allocated(best_piece)) deallocate(best_piece)
        allocate(best_piece(dec%npieces))
        best_piece = dec%piece(1:dec%npieces)
      endif

      if (dec%npieces >= nranks .and. bal >= target_bal) exit

      if (dec%npieces >= max_blocks) then
        write(*,'(A,I0,A)') '  [WARNING] block cap reached (', max_blocks, &
          ') before the balance target; raise max-blocks or lower target-balance'
        exit
      endif

      ! Heaviest piece that still has an admissible cut
      p = 0; wmax = -1
      do d = 1, dec%npieces
        if (dec%piece(d)%dead) cycle
        if (piece_cells(dec%piece(d)) > wmax) then
          wmax = piece_cells(dec%piece(d))
          p = d
        endif
      enddo
      if (p == 0) then
        write(*,'(A)') '  [WARNING] no further admissible cut: the decomposition is limited by'
        write(*,'(A)') '            min-cells / split-directions / multigrid granularity'
        exit
      endif

      ! Longest admissible direction: for a fixed cell count that is also the
      ! cut with the smallest new interface area.
      dir = 0; best = 0
      do d = 1, 3
        if (.not. allow_dir(d, dec%piece(p)%parent)) cycle
        if (max_subdivisions(piece_dim(dec%piece(p),d), gran, min_cells) < 2) cycle
        if (piece_dim(dec%piece(p),d) > best) then
          best = piece_dim(dec%piece(p),d)
          dir  = d
        endif
      enddo
      if (dir == 0) then
        dec%piece(p)%dead = .true.
        cycle
      endif

      ! Cut straight down to the ideal rank load where possible: bisecting a
      ! block that is 8x too heavy would cost three passes for the same result.
      nsub_max = max_subdivisions(piece_dim(dec%piece(p),dir), gran, min_cells)
      nsub     = max(2, nint(real(wmax,8) / ideal))
      nsub     = min(nsub, nsub_max)
      nsub     = min(nsub, max_blocks - dec%npieces + 1)
      if (nsub < 2) then
        dec%piece(p)%dead = .true.
        cycle
      endif

      if (verb) write(*,'(A,I0,A,I0,A,A,A,I0,A)') '    split piece ', p, ' (parent ', &
        dec%piece(p)%parent, ') along ', dirname(dir), ' into ', nsub, ' parts'

      call dec_split_piece(dec, p, dir, nsub, gran)
    enddo

    ! Fall back to the best-scoring candidate seen along the way.  The search is
    ! greedy and monotone in block count, so the state it stops on is not
    ! generally the best one it visited.
    if (best_npieces > 0 .and. best_npieces < dec%npieces) then
      if (verb) write(*,'(A,I0,A,I0,A)') '    reverting ', dec%npieces, ' -> ', &
        best_npieces, ' blocks (better balance/halo trade)'
      dec%piece(1:best_npieces) = best_piece
      dec%npieces = best_npieces
    endif

  end subroutine build_decomposition


  !> Largest extent, in granules, that a piece of `len` cells can be cut into
  !> while keeping every part at least min_cells long.
  pure integer function max_subdivisions(len, gran, min_cells) result(n)
    integer, intent(in) :: len, gran, min_cells
    integer :: ngran, mingran

    ngran   = len / gran
    mingran = (min_cells + gran - 1) / gran
    mingran = max(mingran, 1)
    n       = ngran / mingran

  end function max_subdivisions


  !> Faithful copy of MOSE_Mod_MPI::partition_blocks: blocks walked largest
  !> first, each assigned to the least loaded rank, ties keeping block order.
  !> Returns the owner of every piece and the balance as a percentage of ideal.
  subroutine lpt_assign(dec, nranks, owner, balance)
    type(decomposition_t), intent(in)  :: dec
    integer,               intent(in)  :: nranks
    integer, allocatable,  intent(out) :: owner(:)
    real(8),               intent(out) :: balance
    ! Local
    integer :: i, j, b, r, tmp, nb
    integer, allocatable :: w(:), order(:), load(:)
    real(8) :: ideal

    nb = dec%npieces
    allocate(owner(nb), w(nb), order(nb), load(0:max(nranks,1)-1))
    load = 0

    do b = 1, nb
      w(b)     = piece_cells(dec%piece(b))
      order(b) = b
    enddo

    do i = 2, nb
      tmp = order(i)
      j = i - 1
      do while (j >= 1)
        if (w(order(j)) >= w(tmp)) exit
        order(j+1) = order(j)
        j = j - 1
      enddo
      order(j+1) = tmp
    enddo

    do i = 1, nb
      b = order(i)
      r = minloc(load, dim=1) - 1
      owner(b) = r
      load(r)  = load(r) + w(b)
    enddo

    ideal   = real(sum(w),8) / real(max(nranks,1),8)
    balance = ideal / real(max(maxval(load),1),8) * 100.0d0

  end subroutine lpt_assign


  subroutine report_decomposition(dec, nranks, owner, orig_cells)
    type(decomposition_t), intent(in) :: dec
    integer,               intent(in) :: nranks, owner(:)
    integer,               intent(in) :: orig_cells
    ! Local
    integer :: p, r, cells, wmin, wmax
    integer, allocatable :: load(:)
    real(8) :: bal, ideal, halo

    allocate(load(0:max(nranks,1)-1))
    load = 0
    cells = 0
    wmin = huge(1); wmax = 0
    do p = 1, dec%npieces
      load(owner(p)) = load(owner(p)) + piece_cells(dec%piece(p))
      cells = cells + piece_cells(dec%piece(p))
      wmin = min(wmin, piece_cells(dec%piece(p)))
      wmax = max(wmax, piece_cells(dec%piece(p)))
    enddo

    ideal = real(cells,8) / real(max(nranks,1),8)
    bal   = ideal / real(max(maxval(load),1),8) * 100.0d0
    halo  = halo_overhead(dec)

    write(*,*)
    write(*,'(A)')          ' Decomposition'
    write(*,'(A,T35,I0)')   '   Original blocks', dec%nparent
    write(*,'(A,T35,I0)')   '   New blocks', dec%npieces
    write(*,'(A,T35,I0)')   '   MPI ranks', nranks
    write(*,'(A,T35,I0)')   '   Total cells', cells
    if (cells /= orig_cells) &
      write(*,'(A,T35,I0)') '   [ERROR] cell count changed!', orig_cells
    write(*,'(A,T35,I0)')   '   Smallest block', wmin
    write(*,'(A,T35,I0)')   '   Largest block', wmax
    write(*,'(A,T35,F0.1)') '   Ideal load per rank', ideal
    write(*,'(A,T35,I0)')   '   Heaviest rank', maxval(load)
    write(*,'(A,T35,I0)')   '   Lightest rank', minval(load)
    write(*,'(A,T35,F5.1,A)') '   Predicted MOSE balance', bal, '% of ideal'
    write(*,'(A,T35,F5.1,A)') '   Ghost-cell overhead', halo, '%'

    if (dec%npieces < nranks) &
      write(*,'(A,I0,A,I0,A)') '   [WARNING] only ', dec%npieces, ' of ', nranks, ' ranks will have work'

    if (any(load == 0)) &
      write(*,'(A,I0,A)') '   [WARNING] ', count(load == 0), ' rank(s) idle'

    if (verbose_ranks(nranks)) then
      write(*,*)
      write(*,'(A)') '   rank      cells   blocks'
      do r = 0, nranks-1
        write(*,'(I7,I11,I9)') r, load(r), count(owner == r)
      enddo
    endif

  end subroutine report_decomposition


  pure logical function verbose_ranks(n) result(res)
    integer, intent(in) :: n
    res = (n <= 32)
  end function verbose_ranks


  !> Extra cells introduced by the two ghost layers on every new internal face,
  !> as a percentage of the physical cell count. This is the price of splitting:
  !> both extra work and extra communication scale with it.
  pure real(8) function halo_overhead(dec) result(pct)
    type(decomposition_t), intent(in) :: dec
    integer, parameter :: GC = 2      ! MOSE_Global_m::gc
    integer :: p, d, cells, ghost, area

    cells = 0; ghost = 0
    do p = 1, dec%npieces
      cells = cells + piece_cells(dec%piece(p))
      do d = 1, 3
        area = piece_cells(dec%piece(p)) / max(piece_dim(dec%piece(p),d),1)
        ! low side
        if (dec%piece(p)%lo(d) > 1) ghost = ghost + GC*area
        ! high side
        if (dec%piece(p)%hi(d) < dec%pdim(d,dec%piece(p)%parent)) ghost = ghost + GC*area
      enddo
    enddo
    pct = 100.0d0 * real(ghost,8) / real(max(cells,1),8)

  end function halo_overhead


  pure function dirname(d) result(s)
    integer, intent(in) :: d
    character(len=1) :: s
    select case(d)
    case(1);      s = 'i'
    case(2);      s = 'j'
    case default; s = 'k'
    end select
  end function dirname

end module partition_mod
