module bc_names_mod
  implicit none

  integer, parameter :: MARKER_NUM = 12

  character(len=20), parameter :: MARKER_NULL     = 'null'
  character(len=20), parameter :: MARKER_AXIS     = 'axisymmetric'
  character(len=20), parameter :: MARKER_EXTRA    = 'extrapolation'
  character(len=20), parameter :: MARKER_CONN     = 'connection'
  character(len=20), parameter :: MARKER_Chim     = 'chimera'
  character(len=20), parameter :: MARKER_SYM      = 'symmetry'
  character(len=20), parameter :: MARKER_PER      = 'periodic'
  character(len=20), parameter :: MARKER_WALL     = 'wall'
  character(len=20), parameter :: MARKER_INLET    = 'inlet'
  character(len=20), parameter :: MARKER_OUTLET   = 'outlet'
  character(len=20), parameter :: MARKER_MANIFOLD = 'manifold'
  character(len=20), parameter :: MARKER_SRM      = 'srm'

  logical, parameter :: bc_with_input(MARKER_NUM) = [ &
    .false., & ! null
    .false., & ! axisymmetric
    .false., & ! extrapolation
    .false., & ! connection
    .false., & ! chimera
    .false., & ! symmetry
    .true.,  & ! periodic
    .true. , & ! wall
    .true.,  & ! inlet
    .true.,  & ! outlet
    .true.,  & ! manifold
    .true.   & ! srm
  ]

    character(len=20), parameter :: MARKER_NAMES(MARKER_NUM) = [ &
    MARKER_NULL, &
    MARKER_AXIS, &
    MARKER_EXTRA, &
    MARKER_CONN, &
    MARKER_Chim, &
    MARKER_SYM, &
    MARKER_PER, &
    MARKER_WALL, &
    MARKER_INLET, &
    MARKER_OUTLET, &
    MARKER_MANIFOLD, &
    MARKER_SRM &
  ]

contains

  subroutine check_assignment_no_input(try, def)
    implicit none
    character(*), intent(in)    :: try
    character(*), intent(inout) :: def
    integer :: m

    do m = 1, MARKER_NUM
      if (trim(try) == trim(MARKER_NAMES(m))) then
        if (bc_with_input(m)) then
          write(*,'(2A)')'[ERROR] Missing input data for bc: ', trim(try)
          write(*,'(A)') '        You have chosen a known bc, but it requires input data'
          stop
        else
          def = MARKER_NAMES(m)
          return
        endif
      endif
    enddo

    write(*,'(2A)')'[ERROR] Missing type entry for bc: ', trim(try)
    write(*,'(A)') '        Available options without input data'
    do m = 1, MARKER_NUM
      if (.not. bc_with_input(m)) then
        write(*,'(2A)')   '        - ', trim(MARKER_NAMES(m))
      endif
    enddo
    stop

  end subroutine check_assignment_no_input


  subroutine check_assignment_with_input(try, def)
    implicit none
    character(*), intent(in)    :: try
    character(*), intent(inout) :: def
    integer :: m

    do m = 1, MARKER_NUM
      if (trim(try) == trim(MARKER_NAMES(m))) then
        def = MARKER_NAMES(m)
        return
      endif
    enddo

    write(*,'(2A)')'[ERROR] Missing type entry for bc: ', trim(try)
    write(*,'(A)') '        Available options with input data'
    do m = 1, MARKER_NUM
      if (bc_with_input(m)) then
        write(*,'(2A)')   '        - ', trim(MARKER_NAMES(m))
      endif
    enddo
    stop

  end subroutine check_assignment_with_input

end module bc_names_mod