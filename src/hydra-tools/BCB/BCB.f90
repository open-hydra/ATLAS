!>
!> Boundary Conditions Builder
!>

program BCB
  use global_mod
  use bc_block_mod
  use phase_mod
  use read_mesh_mod
  use io_phase_mod
  use io_write_bc_mod
  use Lib_ORION_data
  use io_ini_mod
  use bc_builder_mod
  use bc_chimera_mod
  use bc_connection_mod
  use finer, only: file_ini
  implicit none
  type(phase_t),  allocatable :: phase(:)
  type(BC_block), allocatable :: blk(:)
  type(orion_data)            :: orion 
  type(file_ini)              :: sourceini
  integer                     :: b
  logical                     :: force_connect, chimeraon

  write(*,*)
  write(*,*) ' ATLAS - Boundary Conditions Builder'
  write(*,*)

  call command_line_argument()

  ! Geometry import
  write(*,*)' Reading mesh file ...'
  call read_mesh(orion)
  write(*,*)' Done!'
  allocate(blk(size(orion%block)))
  call import_nodes(input=orion,output=blk)
  do b = 1, size(blk)
    call blk(b)%build_geometry()
    call blk(b)%compute_face_centers()
  enddo
  
  ! INI handling
  call build_INI(prog='BCB',nb=size(orion%block),inisource=sourceini,force_connect=force_connect,chimeraon=chimeraon)

  ! Phase properties import
  call read_phase(phase)

  ! BC computation
  call build_BC(phase,sourceini,blk)

  ! Multiblock operations
  call find_periodic(blk)
  if (size(blk)>1) then
    if (chimeraon) then
      call chimera_wrapper(blk)
    else
      call find_connect(blk,force_connect)
    endif
  endif

  write(*,*)' Writing BC files ...'

  ! BC writing
  do b = 1, size(phase)
    select case(phase(b)%type)
    case('IG')
      call write_ig_bc(phase(b)%name,blk)
    case('DP')
      call write_dp_bc(phase(b)%name,blk)
    case('SP')
      call write_sp_bc(phase(b)%name,blk)
    end select
  enddo

  write(*,*)' Done!'

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
