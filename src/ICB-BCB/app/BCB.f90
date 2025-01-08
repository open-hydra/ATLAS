!>
!> Boundary Conditions Builder
!>

program BCB
  use TOM, only: check_mesh_type
  use variables
  use ATLAS_high_level
  use ATLAS_IO
  use Lib_ORION_data
  use input_ini
  use lib_bc
  use finer, only: file_ini
  implicit none
  type(phase_type), allocatable  :: phase(:)
  type(ATLAS_block), allocatable :: block(:)
  type(orion_data)               :: orion
  character(len=llen)            :: filename
  type(file_ini)                 :: sourceini
  integer                        :: b
  logical                        :: force_connect, chimeraon

  write(*,*)
  write(*,*) ' ATLAS - Boundary Conditions Builder'
  write(*,*)

  call command_line_argument()

  ! Geometry import
  filename = 'mesh.tec'
  write(*,*)' Reading mesh file'
  call read_TECmesh(orion,filename)
  call import_nodes(input=orion,output=block)
  do b = 1, size(block)
    call block(b)%extrapolate_nodes(2)
    call block(b)%compute_centers(2)
    call block(b)%compute_face_centers()
  enddo
  call check_mesh_type(block(1))

  ! INI handling
  call build_INI(prog='BCB',nb=size(block),inisource=sourceini,force_connect=force_connect,chimeraon=chimeraon)

  ! Phase properties import
  call read_phase(phase)

  ! BC computation
  call build_BC(phase,sourceini,block)

  ! Multiblock operations
  call find_periodic(block)
  if (size(block)>1) then
    if (chimeraon) then
      call chimera_wrapper(block)
    else
      call find_connect(block,force_connect)
    endif
  endif

  ! BC writing
  call execute_command_line('mkdir -p '//trim(outpath))
  do b = 1, size(phase)
    select case(phase(b)%type)
    case('IG')
      call write_idealgas_bc_file(phase(b)%name,block)
    case('CD')
      call write_cdp_bc_file(phase(b)%name,block)
    case('SP')
      ! Currently the solid phase shares the same boundaries and file format as the ideal-gas phase.
      ! Indeed, only imposed heat flux and temnperature are considered along with connectivity.
      call write_idealgas_bc_file(phase(b)%name,block)
    end select
  enddo

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


end program BCB
