module area_law
  implicit none

  real(8), parameter :: Runi = 8314.46261815324d0  !< Universal gas constant [J/(kmol·K)], exact SI 2019 (N_A k_B)

contains

  !> Mach number m2 of the area ratio a/at of the quasi-1-D isentropic law, on the branch of the initial
  !> guess x0 (subsonic for x0 < 1, supersonic otherwise): Newton's method, kept inside a bracket of the
  !> root that it bisects whenever a step leaves it. At the throat (a <= at) the two branches meet at
  !> M = 1, a double root of A/A* = a/at: Newton alone crawls towards it and, near it, stalls on the
  !> rounding of A/A* (it stopped ICB on a duct of constant section), so M = 1 is returned exactly.
  pure subroutine legge_aree(a, x0, m2, at, gamma)
    implicit none
    real(8), intent(in)  :: a, x0, at, gamma
    real(8), intent(out) :: m2
    real(8) :: k, d, ratio, lo, hi, m, m_new, f, fprime
    logical :: subsonic
    integer :: iter

    k = 0.5d0*(gamma+1.d0)
    d = 0.5d0*(gamma-1.d0)
    ratio = a/at
    if (.not. (ratio > 1.d0)) then
      m2 = 1.d0
      return
    endif
    ! the bracket: f = A/A*(M) - a/at is negative at M = 1 and grows without bound towards M = 0
    ! (subsonic branch) and towards large M (supersonic branch)
    subsonic = x0 < 1.d0
    if (subsonic) then
      lo = 0.d0
      hi = 1.d0
    else
      lo = 1.d0
      hi = 2.d0
      do while (area_ratio(hi) < ratio .and. hi < 1.d10)
        lo = hi
        hi = 2.d0*hi
      end do
    endif
    m = x0
    if (.not. (m > lo .and. m < hi)) m = 0.5d0*(lo+hi)
    do iter = 1, 200
      f = area_ratio(m) - ratio
      if (f == 0.d0) exit
      ! f falls with M on the subsonic branch and rises on the supersonic one
      if ((f > 0.d0) .eqv. subsonic) then
        lo = m
      else
        hi = m
      endif
      fprime = ((1.d0+d*m*m)/k)**(0.5d0*k/d-1.d0) - area_ratio(m)/m
      m_new = m - f/fprime
      if (.not. (m_new > lo .and. m_new < hi)) m_new = 0.5d0*(lo+hi)
      if (abs(m_new-m) <= 1.d-14*m) then
        m = m_new
        exit
      endif
      m = m_new
    end do
    m2 = m

  contains

    pure real(8) function area_ratio(mach)
      real(8), intent(in) :: mach
      area_ratio = (((1.d0+d*mach*mach)/k)**(0.5d0*k/d))/mach
    end function area_ratio

  end subroutine legge_aree

end module area_law
