!>
!> Initial Conditions Builder
!>

program ICB
  use variables
  use ATLAS_high_level
  use ATLAS_IO
  use Lib_ORION_data
  use input_ini
  use lib_ic
  use Interpolator, only: intersol
  use finer, only: file_ini
  implicit none
  type(phase_type), allocatable  :: phase(:)
  type(ATLAS_block), allocatable :: block(:)
  type(orion_data)               :: orion
  character(len=30)              :: ICformat
  character(len=llen)            :: filename
  type(file_ini)                 :: sourceini
  integer                        :: b

  write(*,*)
  write(*,*) ' ATLAS - Initial Conditions Builder'
  write(*,*)

  call command_line_argument()

  ! Geometry import
  filename = 'mesh.tec'
  write(*,*)' Reading mesh file'
  call read_TECmesh(orion,filename)
  call import_nodes(input=orion,output=block)
  do b = 1, size(block)
    call block(b)%compute_centers(0)
  enddo

  ! INI handling
  call build_INI('ICB',size(block),sourceini,ICformat)

  ! Phase properties import
  call read_phase(phase)

  ! IC computation
  call build_IC(phase,sourceini,block)

  ! IC writing
  call execute_command_line('mkdir -p '//trim(outpath))
  if (index(ICformat,'native')>0) then
    call write_solfile(block)
  else
    call write_vtk_tec(phase, ICformat, block)
  endif

  contains

  subroutine command_line_argument()
    implicit none
    character(99):: arg
    integer      :: arg_count, i

    verbose = .false.

    arg_count = COMMAND_ARGUMENT_COUNT()

    do i = 1, arg_count
      call GET_COMMAND_ARGUMENT(i, arg)
      if (arg == '-v' .or. arg == '--verbose') then
        verbose = .true.
      end if
    end do

  end subroutine command_line_argument


end program ICB