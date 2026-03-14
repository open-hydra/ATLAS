!>
!> Boundary Conditions Builder
!>

program BCB
  use variables
  use ATLAS_high_level
  use phase_module
  use ATLAS_IO_fields
  use ATLAS_read_phase
  use ATLAS_write_bc
  use ATLAS_IO_multigrid
  use Lib_ORION_data
  use ATLAS_IO_INI
  use build_BC_mod
  use chimera
  use BC_connection
  use BC_area_variation
  use finer, only: file_ini
  implicit none
  type(phase_type), allocatable  :: phase(:)
  type(ATLAS_block), allocatable :: block(:)
  type(orion_data)               :: fine_orion, coarse_orion 
  type(file_ini)                 :: sourceini
  integer                        :: b, m, MG_levels
  logical                        :: force_connect, chimeraon

  write(*,*)
  write(*,*) ' ATLAS - Boundary Conditions Builder'
  write(*,*)

  call command_line_argument()
  call execute_command_line('mkdir -p '//trim(outpath))

  ! Geometry import
  write(*,*)' Reading mesh file ...'
  call read_mesh(fine_orion)
  write(*,*)' Done!'
  
  ! INI handling
  call build_INI(prog='BCB',nb=size(fine_orion%block),inisource=sourceini,MG_levels=MG_levels,force_connect=force_connect,chimeraon=chimeraon)

  ! Phase properties import
  call read_phase(phase)

  do m = 1, MG_levels

    write(*,*)
    write(*,*) ' Grid Level ', m
    write(*,*)

    if ( m == 1 ) then
      call import_nodes ( input=fine_orion, output=block )
      call check_multigrid ( fine_orion, MG_levels )
    else
      do b = 1, size(block)
        call block(b)%destroy
      enddo
      call coarse_mesh ( fine_orion, coarse_orion)
      call import_nodes ( input=coarse_orion, output=block )
      call copyORION ( coarse_orion, fine_orion )
    endif

    call build_geometry(block)

    ! BC computation
    call build_BC(phase,sourceini,block)

    ! Build Q2D Area variation files, if any
    call build_area_variation(sourceini,block)

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
    do b = 1, size(phase)
      select case(phase(b)%type)
      case('IG')
        call write_idealgas_bc_file(phase(b)%name,block,m)
      case('CD')
        call write_cdp_bc_file(phase(b)%name,block)
      case('SP')
        ! Currently the solid phase shares the same boundaries and file format as the ideal-gas phase.
        ! Indeed, only imposed heat flux and temnperature are considered along with connectivity.
        call write_idealgas_bc_file(phase(b)%name,block,m)
      end select
    enddo

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
