module variables
  implicit none

  type :: config_type
    logical :: verbose = .false.
    integer :: nrans  = 0   !> Gas-phase | Turbulent variables number
    integer :: neuler = 0   !> Eulerian condensed-phase | Model switch number
  end type config_type

  type(config_type) :: cfg

  integer, parameter           :: llen = 200
  character(len=18), parameter :: outpath = 'fromATLAStoSolver/'

end module variables
