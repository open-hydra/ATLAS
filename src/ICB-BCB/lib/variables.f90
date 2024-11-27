module variables
  implicit none

  integer, parameter :: llen = 200

  character(len=17), parameter :: outpath = 'fromATLAStoSolver'

  !> Turbulent
  integer:: nrans=0

  !> Tab properties
  real(8) :: runi=8314.51

  !> Switches
  logical :: verbose

end module variables 
