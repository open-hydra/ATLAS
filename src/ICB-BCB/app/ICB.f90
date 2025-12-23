!>
!> Initial Conditions Builder
!>

program ICB
  use variables
  use ATLAS_high_level
  use phase_module
  use ATLAS_IO
  use Lib_ORION_data
  use ATLAS_IO_INI
  use build_IC_mod
  use finer, only: file_ini
  use IC_lib_POWER
  use TOM, only: meshType

  implicit none
  type(phase_type), allocatable  :: phase(:)
  type(ATLAS_block), allocatable :: block(:)
  type(orion_data)               :: orion
  character(len=30)              :: ICformat
  type(file_ini)                 :: sourceini
  integer                        :: b
  logical                        :: poweron
  character(len=200)             :: powerfile
  type(var_block)                :: powerblock

  write(*,*)
  write(*,*) ' ATLAS - Initial Conditions Builder'
  write(*,*)

  call command_line_argument()

  ! Geometry import
  write(*,*)' Reading mesh file ...'
  call read_mesh(orion)
  call import_nodes(input=orion,output=block)
  do b = 1, size(block)
    if (meshType == -2) then
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
  call build_INI(prog='ICB',nb=size(block),inisource=sourceini,ICformat=ICformat,poweron=poweron,powerfile=powerfile)

  ! Phase properties import
  write(*,*) ' Phase properties import'
  call read_phase(phase)
  write(*,*)

  ! Read power.tec
  if (poweron) then
    write(*,*) ' Reading power file'
    call read_power(powerfile, powerblock)
    write(*,*) ' Rescaling power volumes'
    call rescale_volumes_power(powerblock, block)
    write(*,*) ' '
  endif

  ! IC computation
  write(*,*) ' IC computation'
  call build_IC(phase=phase,sini=sourceini,blocks=block,powerblock=powerblock)

  ! IC writing
  write(*,*)' IC writing'
  call execute_command_line('mkdir -p '//trim(outpath))
  if (index(ICformat,'native')>0) then
    if (phase(1)%type=='IG') call write_solfile(phase(1),block)
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