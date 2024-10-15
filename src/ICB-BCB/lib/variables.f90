module variables
  implicit none

  integer, parameter :: llen = 200
  integer :: unitfile

  !> Turbulent
  integer:: nrans=0

  !> Tab properties
  real(8) :: runi=8314.51
  real(8), allocatable:: cp(:,:), dcp(:,:), h(:,:), w(:)

  !> Switches
  logical:: threedim

end module variables 
