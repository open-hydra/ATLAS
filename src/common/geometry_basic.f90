!> Geometry helper functions: face area and outward-normal calculations
!> for structured hexahedral cells.
module geometry_mod
  implicit none
  private
  public :: CalculateArea, CalculateNormal

contains

  pure function CalculateArea(A,B,C,D) result(Area)
    implicit none

    ! Declare variables
    real(8), dimension(3), intent(in) :: A, B, C, D
    real(8)                           :: Area
    real(8)                           :: dumx, dumy, dumz
    real(8)                           :: DAx, DAy, DAz, BCx, BCy, BCz

    ! Calculate vectors AD and BC
    DAx = D(1) - A(1)
    DAy = D(2) - A(2)
    DAz = D(3) - A(3)
    BCx = C(1) - B(1)
    BCy = C(2) - B(2)
    BCz = C(3) - B(3)

    ! Calculate the half cross product 
    dumx = (DAy * BCz - DAz * BCy) * 0.5d0
    dumy = (DAz * BCx - DAx * BCz) * 0.5d0
    dumz = (DAx * BCy - DAy * BCx) * 0.5d0

    ! Compute the area
    Area = sqrt(dumx**2 + dumy**2 + dumz**2)

  end function CalculateArea

  pure function CalculateNormal(A,B,C,D) result(n)
    implicit none

    ! Declare variables
    real(8), dimension(3), intent(in) :: A, B, C, D
    real(8), dimension(3)             :: n
    real(8)                           :: nx, ny, nz
    real(8)                           :: ABx, ABy, ABz, BCx, BCy, BCz
    real(8)                           :: ADx, ADy, ADz
    real(8)                           :: Magnitude

    ! Calculate vectors AB and BC
    ABx = B(1) - A(1)
    ABy = B(2) - A(2)
    ABz = B(3) - A(3)
    BCx = C(1) - B(1)
    BCy = C(2) - B(2)
    BCz = C(3) - B(3)

    ! Calculate the cross product AB x BC
    nx = ABy * BCz - ABz * BCy
    ny = ABz * BCx - ABx * BCz
    nz = ABx * BCy - ABy * BCx

    ! Normalize the normal vector
    Magnitude = sqrt(nx**2 + ny**2 + nz**2)
    if (Magnitude > 0.0d0) then
      nx = nx / Magnitude
      ny = ny / Magnitude
      nz = nz / Magnitude
    else
      ! Degenerate face (e.g. axis node where A==C): fall back to AB x AD
      ADx = D(1) - A(1)
      ADy = D(2) - A(2)
      ADz = D(3) - A(3)
      nx = ABy * ADz - ABz * ADy
      ny = ABz * ADx - ABx * ADz
      nz = ABx * ADy - ABy * ADx
      Magnitude = sqrt(nx**2 + ny**2 + nz**2)
      if (Magnitude > 0.0d0) then
        nx = nx / Magnitude
        ny = ny / Magnitude
        nz = nz / Magnitude
      else
        nx = 0.0d0
        ny = 0.0d0
        nz = 0.0d0
      end if
    end if

    n = [nx, ny, nz]

  end function CalculateNormal

end module geometry_mod
