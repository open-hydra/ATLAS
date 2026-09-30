!>@brief Search for the decomposition that scores best, instead of the greedy
!> path build_decomposition walks.
!>
!> The greedy loop cuts the heaviest piece along its longest axis into as many
!> slabs as it takes to reach the ideal load, so it never sees a 3 x 2 x 2 cut
!> of a cube: for 12 ranks it makes twelve slabs (or 4 x 3 x 1 with a swept
!> min-cells), never the shape with the least new surface. This module
!> enumerates, for every admissible number of parts, how those parts are
!> apportioned to the parents by weight and every factorisation Px x Py x Pz
!> of each parent's share on the granule lattice, builds the tensor-product cut
!> with the equal-as-possible positions dec_split_piece uses, and keeps the
!> candidate that scores best under the objective:
!>
!>   halo   balance / (1 + halo_weight * ghost_overhead), the greedy's own score
!>   cost   the smallest predicted rank time of cost_mod
!>
!> Every candidate is judged as the solver will see it: pieces in their final
!> numbering, assigned by the solver's own LPT on cell counts (lpt_assign). The
!> search only shapes blocks; it never assumes an assignment the solver will
!> not make.
module search_mod
  use decomposition_mod
  use partition_mod, only: lpt_assign, halo_overhead, max_subdivisions
  use bc_scan_mod,   only: bc_scan_t
  use cost_mod,      only: cost_coef_t, cost_evaluate
  implicit none
  private

  public :: search_decomposition

  integer, parameter :: GC = 2    ! MOSE_Global_m::gc, as in halo_overhead

  !> One factorisation of a parent's share of the parts.
  type :: fact_t
    integer :: p(3)  = 1
    integer :: ghost = 0    !< ghost cells this shape adds to the parent
  end type fact_t

  !> The factorisations admissible for one parent, least ghost first.
  type :: flist_t
    integer                   :: n = 0
    type(fact_t), allocatable :: f(:)
  end type flist_t

contains

  !> Replace the trivial decomposition `dec` by the best-scoring one.
  !>
  !> nranks, max_blocks, min_cells, gran, allow_dir : as for build_decomposition
  !> objective       : 'halo' or 'cost'
  !> blocks_per_rank : the search starts at nranks * blocks_per_rank parts
  !> balance_tol     : a parent within this percentage above the ideal load per
  !>                   part is left whole
  !> scan, coef      : the scanned fine-level BC file and the [MDB-Cost]
  !>                   coefficients, needed by objective = cost
  !> quiet           : no summary line and no target warning (the sweep table)
  subroutine search_decomposition(dec, nranks, objective, target_bal, halo_weight, max_blocks, min_cells, &
                                  gran, allow_dir, blocks_per_rank, balance_tol, verb, scan, coef, quiet)
    type(decomposition_t), intent(inout) :: dec
    integer,               intent(in)    :: nranks, max_blocks, min_cells, gran, blocks_per_rank
    character(len=*),      intent(in)    :: objective
    real(8),               intent(in)    :: target_bal, halo_weight, balance_tol
    logical,               intent(in)    :: allow_dir(:,:)
    logical,               intent(in)    :: verb
    type(bc_scan_t),       intent(in), optional :: scan
    type(cost_coef_t),     intent(in), optional :: coef
    logical,               intent(in), optional :: quiet
    ! Local
    integer :: nb, b, d, nparts, n_lo, n_hi, nvec, ntried, neval, sweep, k
    integer :: total, best_nparts
    real(8) :: value, best_value, bal, halo, best_bal, best_halo, trial
    logical :: improved, talk
    integer, allocatable :: w(:), nmax(:,:), nshare(:), tried(:,:), choice(:), tchoice(:)
    type(flist_t), allocatable :: fl(:)
    type(decomposition_t) :: cand, best

    nb = dec%nparent
    allocate(w(nb), nmax(3,nb), nshare(nb), fl(nb), choice(nb), tchoice(nb))

    ! Weight of every parent and the most parts each axis admits on the
    ! granule lattice with min_cells per part.
    total = 0
    do b = 1, nb
      w(b) = piece_cells(dec%piece(b))
      total = total + w(b)
      do d = 1, 3
        nmax(d,b) = 1
        if (allow_dir(d,b)) nmax(d,b) = max(1, max_subdivisions(dec%pdim(d,b), gran, min_cells))
      enddo
    enddo

    n_lo = max(nb, nranks * max(blocks_per_rank, 1))
    n_hi = max(n_lo, max_blocks)
    allocate(tried(nb, n_hi - n_lo + 1))
    nvec = 0; ntried = 0; neval = 0

    best_value  = -huge(1.0d0)
    best_nparts = 0
    best_bal    = 0.0d0
    best_halo   = 0.0d0

    do nparts = n_lo, n_hi

      call apportion(nparts, w, total, nmax, balance_tol, nshare)

      ! The same share vector comes back for many part counts once the parents
      ! are clamped or left whole: judge it once.
      if (seen(nshare)) cycle
      nvec = nvec + 1
      tried(:,nvec) = nshare

      do b = 1, nb
        call factorisations(nshare(b), nmax(:,b), w(b), dec%pdim(:,b), fl(b))
      enddo

      ! Coordinate descent over the factorisations, starting from the least
      ! ghost of every parent: for a single parent this is exhaustive, for
      ! many parents it is bounded and deterministic (fixed sweep order,
      ! strict improvement only, ties keep the incumbent).
      choice = 1
      call evaluate(choice, value, bal, halo)
      do sweep = 1, 2
        improved = .false.
        do b = 1, nb
          do k = 1, fl(b)%n
            if (k == choice(b)) cycle
            tchoice    = choice
            tchoice(b) = k
            call evaluate(tchoice, trial, bal, halo)
            if (trial > value) then
              choice   = tchoice
              value    = trial
              improved = .true.
            endif
          enddo
        enddo
        if (.not. improved) exit
      enddo
      call evaluate(choice, value, bal, halo)
      ntried = ntried + 1

      if (verb) then
        if (trim(objective) == 'cost') then
          write(*,'(A,I0,A,F0.1,A,F0.1,A,F0.1,A)') '    ', nparts, ' parts: predicted rank time ', -value, &
            '  (balance ', bal, '%, ghost ', halo, '%)'
        else
          write(*,'(A,I0,A,F0.1,A,F0.1,A,F0.1,A)') '    ', nparts, ' parts: score ', value, &
            '  (balance ', bal, '%, ghost ', halo, '%)'
        endif
      endif

      if (value > best_value) then
        best_value  = value
        best_nparts = nparts
        best_bal    = bal
        best_halo   = halo
        call build_candidate(choice, best)
      endif
    enddo

    talk = .true.
    if (present(quiet)) talk = .not. quiet
    if (talk) then
      write(*,'(A,I0,A,I0,A,I0,A)') '   search: ', ntried, ' part counts, ', neval, ' candidates; best ', &
        best%npieces, ' blocks'
      if (best_bal < target_bal) &
        write(*,'(A,F0.1,A,F0.1,A)') '   [WARNING] the best candidate balances at ', best_bal, &
          '%, below target-balance ', target_bal, '%'
    endif

    if (size(dec%piece) < best%npieces) then
      deallocate(dec%piece)
      allocate(dec%piece(best%npieces))
    endif
    dec%piece(1:best%npieces) = best%piece(1:best%npieces)
    dec%npieces = best%npieces

  contains

    logical function seen(v) result(res)
      integer, intent(in) :: v(:)
      integer :: t
      res = .false.
      do t = 1, nvec
        if (all(tried(:,t) == v)) then
          res = .true.; return
        endif
      enddo
    end function seen

    !> Build the candidate of one choice of factorisations, pieces already in
    !> the final numbering (parent, then k, j, i origin), so that dec_finalize
    !> leaves the order untouched and LPT breaks ties as it will at run time.
    subroutine build_candidate(ch, c)
      integer,               intent(in)  :: ch(:)
      type(decomposition_t), intent(out) :: c
      integer :: b, ip, ix, jy, kz, np, p(3)
      integer, allocatable :: lo1(:), hi1(:), lo2(:), hi2(:), lo3(:), hi3(:)

      np = 0
      do b = 1, nb
        np = np + product(fl(b)%f(ch(b))%p)
      enddo
      c%nparent = nb
      c%pdim    = dec%pdim
      allocate(c%piece(np))
      ip = 0
      do b = 1, nb
        p = fl(b)%f(ch(b))%p
        call segments(dec%pdim(1,b), gran, p(1), lo1, hi1)
        call segments(dec%pdim(2,b), gran, p(2), lo2, hi2)
        call segments(dec%pdim(3,b), gran, p(3), lo3, hi3)
        do kz = 1, p(3)
          do jy = 1, p(2)
            do ix = 1, p(1)
              ip = ip + 1
              c%piece(ip)%parent = b
              c%piece(ip)%lo     = [lo1(ix), lo2(jy), lo3(kz)]
              c%piece(ip)%hi     = [hi1(ix), hi2(jy), hi3(kz)]
              c%piece(ip)%dead   = .false.
            enddo
          enddo
        enddo
      enddo
      c%npieces = ip
      call dec_finalize(c)

    end subroutine build_candidate

    !> Score of one choice, higher is better, with the balance and ghost
    !> overhead the report will print for it.
    subroutine evaluate(ch, v, b, h)
      integer, intent(in)  :: ch(:)
      real(8), intent(out) :: v, b, h
      integer, allocatable :: owner(:)
      real(8) :: tmax, tmean

      call build_candidate(ch, cand)
      call lpt_assign(cand, nranks, owner, b)
      h = halo_overhead(cand)
      select case (trim(objective))
      case ('cost')
        ! Lower time is better: the search maximises its negative
        call cost_evaluate(cand, owner, nranks, scan, coef, tmax, tmean)
        v = -tmax
      case default   ! 'halo'
        v = b / (1.0d0 + halo_weight * h / 100.0d0)
      end select
      neval = neval + 1

    end subroutine evaluate

  end subroutine search_decomposition


  !> Parts per parent for a total of nparts: every parent at least one, the
  !> rest by the largest remainder of the quotas nparts * w / total, never more
  !> than its axes admit. A parent within balance_tol percent above the ideal
  !> load per part is left whole: a cut there buys no balance.
  subroutine apportion(nparts, w, total, nmax, balance_tol, n)
    integer, intent(in)  :: nparts, w(:), total, nmax(:,:)
    real(8), intent(in)  :: balance_tol
    integer, intent(out) :: n(:)
    integer :: b, nb, left, pick, cap(size(w))
    real(8) :: q(size(w)), ideal, rem, best

    nb    = size(w)
    ideal = real(total,8) / real(nparts,8)
    do b = 1, nb
      cap(b) = product(nmax(:,b))
      q(b)   = real(nparts,8) * real(w(b),8) / real(total,8)
      n(b)   = min(max(1, int(q(b))), cap(b))
    enddo

    left = nparts - sum(n)
    do while (left > 0)
      pick = 0; best = -1.0d0
      do b = 1, nb
        if (n(b) >= cap(b)) cycle
        rem = q(b) - real(n(b),8)
        if (rem > best) then
          best = rem; pick = b
        endif
      enddo
      if (pick == 0) exit
      n(pick) = n(pick) + 1
      left    = left - 1
    enddo

    do b = 1, nb
      if (n(b) > 1 .and. real(w(b),8) <= ideal * (1.0d0 + balance_tol / 100.0d0)) n(b) = 1
    enddo

  end subroutine apportion


  !> Every ordered factorisation p1 x p2 x p3 = n with p_d <= nmax(d), least
  !> ghost first; among equal ghost the most cuts on i come first, as the
  !> greedy's longest-axis rule would order a cube. A share no factorisation
  !> reaches (a prime beyond one axis, say) is lowered until one does.
  subroutine factorisations(nshare, nmax, w, dim, fl)
    integer,       intent(in)  :: nshare, nmax(3), w, dim(3)
    type(flist_t), intent(out) :: fl
    integer :: n, p1, p2, p3, m, i, j
    type(fact_t) :: t
    type(fact_t), allocatable :: tmp(:)

    n = nshare
    do
      allocate(tmp(max(1, n)))
      fl%n = 0
      do p1 = min(n, nmax(1)), 1, -1
        if (mod(n, p1) /= 0) cycle
        m = n / p1
        do p2 = min(m, nmax(2)), 1, -1
          if (mod(m, p2) /= 0) cycle
          p3 = m / p2
          if (p3 > nmax(3)) cycle
          if (fl%n == size(tmp)) call grow(tmp)
          fl%n = fl%n + 1
          tmp(fl%n)%p     = [p1, p2, p3]
          tmp(fl%n)%ghost = GC * 2 * ((p1-1) * (w/dim(1)) + (p2-1) * (w/dim(2)) + (p3-1) * (w/dim(3)))
        enddo
      enddo
      if (fl%n > 0 .or. n == 1) exit
      deallocate(tmp)
      n = n - 1
    enddo

    ! Insertion sort by ghost, stable
    do i = 2, fl%n
      t = tmp(i)
      j = i - 1
      do while (j >= 1)
        if (tmp(j)%ghost <= t%ghost) exit
        tmp(j+1) = tmp(j)
        j = j - 1
      enddo
      tmp(j+1) = t
    enddo

    allocate(fl%f(fl%n))
    fl%f = tmp(1:fl%n)

  contains

    subroutine grow(a)
      type(fact_t), allocatable, intent(inout) :: a(:)
      type(fact_t), allocatable :: g(:)
      allocate(g(2*size(a)))
      g(1:size(a)) = a
      call move_alloc(g, a)
    end subroutine grow

  end subroutine factorisations


  !> Cell ranges of `len` cells cut into np nearly equal parts, each an integer
  !> number of granules: the positions dec_split_piece would produce.
  subroutine segments(len, gran, np, lo, hi)
    integer,              intent(in)  :: len, gran, np
    integer, allocatable, intent(out) :: lo(:), hi(:)
    integer :: ng, base, rem, s, start, nseg

    allocate(lo(np), hi(np))
    if (np == 1) then
      lo(1) = 1; hi(1) = len
      return
    endif
    ng   = len / gran
    base = ng / np
    rem  = mod(ng, np)
    start = 1
    do s = 1, np
      nseg = base
      if (s <= rem) nseg = base + 1
      lo(s) = start
      hi(s) = start + nseg*gran - 1
      start = hi(s) + 1
    enddo

  end subroutine segments

end module search_mod
