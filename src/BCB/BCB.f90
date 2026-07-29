!>
!> Boundary Conditions Builder
!>

program BCB
  use bcb_config_mod, only: write_bcb_registry_markdown
  use global_mod
  use bc_block_mod
  use phase_mod
  use read_mesh_mod
  use io_phase_mod
  use io_write_bc_mod
  use io_multigrid_mod
  use Lib_ORION_data
  use io_ini_mod
  use bc_builder_mod
  use bc_chimera_mod
  use bc_connection_mod
  use finer, only: file_ini
  implicit none
  type(phase_t),  allocatable :: phase(:)
  type(BC_block), allocatable :: blk(:)
  type(orion_data)            :: fine_orion, coarse_orion 
  type(file_ini)              :: sourceini
  integer                     :: b, m, MG_levels
  logical                     :: force_connect, chimeraon, force_chimera
  logical                     :: write_config_doc
  character(len=256)          :: input_file

  write(*,*)
  write(*,*) ' ATLAS - Boundary Conditions Builder'
  write(*,*)

  call command_line_argument()

  if (write_config_doc) then
    call write_bcb_registry_markdown()
    write(*,*) ' BCB input documentation succesfully written'
    stop
  endif

  ! Geometry import
  write(*,*)' Reading mesh file ...'
  call read_mesh(fine_orion)
  write(*,*)' Done!'
  
  ! INI handling
  call build_INI(prog='BCB',nb=size(fine_orion%block),inisource=sourceini,MG_levels=MG_levels,&
               force_connect=force_connect,chimeraon=chimeraon,force_chimera=force_chimera,&
               input_file=trim(input_file))

  ! Phase properties import
  call read_phase(phase)

  do m = 1, MG_levels

    write(*,*)
    write(*,*) ' Writing BC file for grid Level ', m
    write(*,*)

    if ( m == 1 ) then
      allocate(blk(size(fine_orion%block)))
      call import_nodes(input=fine_orion,output=blk)
      call check_multigrid ( fine_orion, MG_levels )
    else
      do b = 1, size(blk)
        call blk(b)%destroy
      enddo
      call coarse_mesh ( fine_orion, coarse_orion )
      deallocate(blk)
      allocate(blk(size(coarse_orion%block)))
      call import_nodes(input=coarse_orion,output=blk)
      call copyORION ( coarse_orion, fine_orion )
    endif

    do b = 1, size(blk)
      call blk(b)%build_geometry()
      call blk(b)%compute_face_centers()
    enddo

    ! BC computation
    call build_BC(phase,sourceini,blk)

    ! Multiblock operations. Faces declared 'connection' are always resolved by
    ! face-center matching; chimera only claims the faces declared 'chimera'.
    call find_periodic(blk)
    if (size(blk)>1) then
      call find_connect(blk,force_connect,chimeraon)
      if (chimeraon) call chimera_wrapper(blk,force_chimera)
    endif

    ! BC writing
    do b = 1, size(phase)
      select case(phase(b)%type)
      case('IG', 'RF')
        call write_ig_bc(phase(b)%name,blk,m)
      case('DP')
        call write_dp_bc(phase(b)%name,blk)
      case('SP')
        call write_sp_bc(phase(b)%name,blk,m)
      end select
    enddo

  enddo

  write(*,*)' Done!'

contains

  subroutine command_line_argument()
    implicit none
    character(99):: arg
    integer      :: arg_count, i

    verbose = .false.
    write_config_doc = .false.
    input_file = 'input.ini'

    arg_count = COMMAND_ARGUMENT_COUNT()

    do i = 1, arg_count
      call GET_COMMAND_ARGUMENT(i, arg)
      if (arg == '-v' .or. arg == '--verbose') then
        verbose = .true.
      elseif (arg == '--write-config-doc') then
        write_config_doc = .true.
      elseif (arg == '-i' .or. arg == '--input') then
        if (i < arg_count) call GET_COMMAND_ARGUMENT(i+1, input_file)
      end if
    end do

  end subroutine command_line_argument


end program BCB
