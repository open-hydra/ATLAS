module variables
  implicit none

  integer, parameter :: llen = 200

  character(len=17), parameter :: outpath = 'fromATLAStoSolver'

  !> Turbulent
  integer:: nrans=0

  !> Tab properties
  real(8) :: runi=8314.51
  real(8), allocatable:: cp(:,:), dcp(:,:), h(:,:), w(:)

  !> Switches
  logical :: verbose

end module variables 
