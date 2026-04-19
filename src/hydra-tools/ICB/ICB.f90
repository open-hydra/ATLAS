!>
!> Initial Conditions Builder
!>

program ICB
  use global_mod
  use ic_block_mod
  use phase_mod
  use read_mesh_mod
  use io_fields_mod
  use io_phase_mod
  use Lib_ORION_data
  use io_ini_mod
  use ic_builder_mod
  use finer, only: file_ini
  use grid_mod, only: mesh_cfg

  implicit none
  type(phase_t), allocatable   :: phase(:)
  type(IC_block), allocatable  :: block(:)
  type(orion_data)             :: orion
  character(len=30)            :: ICformat
  type(file_ini)               :: sourceini
  integer                      :: b

  write(*,*)
  write(*,*) ' ATLAS - Initial Conditions Builder'
  write(*,*)

  call command_line_argument()

  ! Geometry import
  write(*,*)' Reading mesh file ...'
  call read_mesh(orion)
  allocate(block(size(orion%block)))
  call import_nodes(input=orion,output=block)
  do b = 1, size(block)
    if (mesh_cfg%meshType == -2) then
      call block(b)%extrapolate_nodes([0,0,0])
      call block(b)%compute_centers([1,0,0])
    else
      call block(b)%extrapolate_nodes([1,1,1])
      call block(b)%compute_centers([1,1,1])
      call block(b)%compute_volume([0,0,0])
      call block(b)%compute_bounding([0,0,0])
    endif
  enddo
  write(*,*)' Done!'

  ! INI handling
  call build_INI(prog='ICB',nb=size(block),inisource=sourceini,ICformat=ICformat)

  ! Phase properties import
  write(*,*) ' Phase properties import'
  call read_phase(phase)
  write(*,*)

  ! IC computation
  write(*,*) ' IC computation'
  call build_IC(phase=phase,sini=sourceini,blocks=block)

  ! IC writing
  write(*,*)' IC writing'
  call write_vtk_tec(phase, ICformat, block)

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