module variables
  implicit none

  logical :: verbose = .false.
  integer, parameter :: llen = 200
  character(len=18), parameter :: outpath = 'fromATLAStoSolver/'

  ! Gas-phase | Turbulent variables number
  integer:: nrans=0

end module variables 
