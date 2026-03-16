!> Shared 1-D linear and 2-D bilinear interpolation utilities.
module interpolation_mod
  implicit none
  private
  public :: interp_1d, interp_2d

contains

  !> 1-D linear interpolation.
  !> Given arrays xArr(1:n) and yArr(1:n) and a query point x,
  !> returns the interpolated value y.  Returns .false. if x is
  !> outside the data range.
  function interp_1d(x, xArr, yArr, n, y) result(found)
    implicit none
    real(8), intent(in)  :: x
    integer, intent(in)  :: n
    real(8), intent(in)  :: xArr(n), yArr(n)
    real(8), intent(out) :: y
    logical :: found
    integer :: i

    found = .false.
    if (x > xArr(1) .and. x <= xArr(n)) then
      do i = 2, n
        if (x > xArr(i-1) .and. x <= xArr(i)) then
          y = (yArr(i) - yArr(i-1)) / (xArr(i) - xArr(i-1)) &
              * (x - xArr(i-1)) + yArr(i-1)
          found = .true.
          return
        endif
      enddo
    endif
  end function interp_1d


  !> 2-D bilinear interpolation.
  !> Given arrays xArr(1:nx), yArr(1:ny), data(1:nx,1:ny) and a
  !> query point (x,y), returns interpolated value z.
  !> Returns .false. if (x,y) is outside the data range.
  function interp_2d(x, y, xArr, yArr, data, nx, ny, z) result(found)
    implicit none
    real(8), intent(in)  :: x, y
    integer, intent(in)  :: nx, ny
    real(8), intent(in)  :: xArr(nx), yArr(ny), data(nx, ny)
    real(8), intent(out) :: z
    logical :: found
    integer :: i, j
    real(8) :: a1, a2, b1, b2, c11, c12, c21, c22

    found = .false.
    do i = 2, nx
      if (x >= xArr(i-1) .and. x <= xArr(i)) then
        do j = 2, ny
          if (y > yArr(j-1) .and. y <= yArr(j)) then
            a1 = xArr(i-1); a2 = xArr(i)
            b1 = yArr(j-1); b2 = yArr(j)
            c11 = data(i-1, j-1); c12 = data(i-1, j)
            c21 = data(i,   j-1); c22 = data(i,   j)
            z = ((b2 - y)/(b2 - b1)*c11 + (y - b1)/(b2 - b1)*c12) &
                * (a2 - x)/(a2 - a1) &
              + ((b2 - y)/(b2 - b1)*c21 + (y - b1)/(b2 - b1)*c22) &
                * (x - a1)/(a2 - a1)
            found = .true.
            return
          endif
        enddo
      endif
    enddo
  end function interp_2d

end module interpolation_mod
