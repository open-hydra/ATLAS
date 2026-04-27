module area_law
  implicit none

  real(8), parameter :: Runi = 8314.51d0  !< Universal gas constant [J/(kmol·K)]

contains

  !> Newton-Raphson procedure for area-Mach relation
  pure subroutine legge_aree(a, x0, m2, at, gamma)
    implicit none
    real(8), intent(in)  :: a, x0, at, gamma
    real(8), intent(out) :: m2
    real(8) :: m_new, m_old, m_aux, f, fprime, k, d
    integer :: iter

    k = 0.5d0*(gamma+1.d0)
    d = 0.5d0*(gamma-1.d0)
    m_old = x0
    m_aux = x0
    m_new = 1.d0
    iter = 0

    do while (abs(m_new-m_aux) >= 1.d-10)
      m_aux = m_old
      f = (((1.d0+d*(m_old**2))/k)**(0.5d0*k/d))/m_old - (a/at)
      fprime = -(((1.d0+d*(m_old**2))/k)**(0.5d0*k/d))/(m_old**2) + &
               ((1.d0+d*(m_old**2))/k)**(0.5d0*k/d-1.d0)
      m_new = m_old - (f/fprime)
      m_old = m_new
      iter = iter + 1
      if (iter > 100000) error stop '--- legge_aree: Max iterations reached ---'
    end do

    m2 = m_new
  end subroutine legge_aree

end module area_law
