!>
!> Boundary Conditions Builder
!>

program BCB
  use TOM, only: check_mesh_type
  use species
  use variables
  use ATLAS_high_level
  use ATLAS_IO
  use Lib_ORION_data
  use input_ini
  use lib_bc
  use finer, only: file_ini
  implicit none
  type(ATLAS_block), allocatable :: block(:)
  type(orion_data)               :: orion
  type(obj_species)              :: sp
  character(len=llen)            :: filename
  type(file_ini)                 :: sourceini
  integer                        :: b
  logical                        :: force_connect, chimeraon

  write(*,*)
  write(*,*) ' ATLAS - Boundary Conditions Builder'
  write(*,*)

  call command_line_argument()

  ! Phase properties import
  ! maybe not necessary

  ! Geometry import
  filename = 'mesh.tec'
  write(*,*)' Reading mesh file: ',trim(filename)
  call read_TECmesh(orion,filename)
  call import_nodes(input=orion,output=block)
  do b = 1, size(block)
    call block(b)%extrapolate_nodes(2)
    call block(b)%compute_centers(2)
    call block(b)%compute_face_centers()
    call block(b)%compute_norm_area()
  enddo
  call check_mesh_type(block(1))

  ! INI handling
  call build_INI(prog='BCB',nb=size(block),inisource=sourceini,force_connect=force_connect,chimeraon=chimeraon)

  ! BC computation
  call build_BC(sourceini,block,sp)
  !call read_CP_input(CP_present)
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
  call write_idealgas_bc_file('',block)
  ! if (CP_present .and. nb>1) close(1)

  ! if (CP_present) then
  !   open(newunit=unitbound,FILE='toAFFS/CPM.bound',STATUS='unknown')
  !   open(newunit=unitbound_cp,file='toAFFS/particles-bc-input.txt',status='unknown')
  !   do b = 1, nb
  !     !call import_bc_cpm(npop,b)
  !     call write_CPMbound(unitbound,b)
  !     call write_cp_bc_file(unitbound_cp,b,npCP)
  !   enddo
  !   close(unitbound)
  !   close(unitbound_cp)
  ! endif

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
