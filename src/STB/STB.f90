!>
!> Source Terms Builder
!>

program STB
  use global_mod
  use grid_mod
  use read_mesh_mod
  use Lib_ORION_data
  use io_ini_mod
  use area_variation_mod
  use st_block_mod
  use st_builder_mod
  use st_io_mod
  use config_stb_mod
  use finer, only: file_ini
  implicit none
  type(block_type), allocatable  :: blk(:)
  type(st_block), allocatable    :: var_blk(:)
  type(orion_data)               :: orion 
  type(file_ini)                 :: sourceini
  character(len=256)             :: output_fmt
  logical                        :: write_config_doc
  integer                        :: b

  write(*,*)
  write(*,*) ' ATLAS - Source Terms Builder'
  write(*,*)

  call command_line_argument(output_fmt, write_config_doc)

  if (write_config_doc) then
    call write_stb_registry_markdown('stb-input.md')
    write(*,*) ' STB input documentation written to stb-input.md'
    stop
  endif

  ! Geometry import
  write(*,*)' Reading mesh file ...'
  call read_mesh(orion)
  write(*,*)' Done!'
  allocate(blk(size(orion%block)))
  call import_nodes(input=orion,output=blk)
  do b = 1, size(blk)
    call blk(b)%build_geometry()
  enddo
  
  ! INI handling
  call build_INI(prog='STB',nb=size(orion%block),inisource=sourceini)

  ! Build Q2D area variation files, if any
  call build_area_variation(sourceini,blk)

  ! Build source terms fields
  call build_st(sourceini, blk, var_blk)

  ! Write source terms output files
  call write_st_vtk_tec(var_blk, blk, trim(output_fmt))

contains

  subroutine command_line_argument(output_fmt, write_config_doc)
    implicit none
    character(len=256), intent(out) :: output_fmt
    logical, intent(out) :: write_config_doc
    character(len=99) :: arg
    integer :: arg_count, i

    verbose = .false.
    write_config_doc = .false.
    output_fmt = 'tec-ascii'  ! Default output format

    arg_count = COMMAND_ARGUMENT_COUNT()

    do i = 1, arg_count
      call GET_COMMAND_ARGUMENT(i, arg)
      if (arg == '-v' .or. arg == '--verbose') then
        verbose = .true.
      else if (arg == '-o' .or. arg == '--output') then
        if (i < arg_count) call GET_COMMAND_ARGUMENT(i+1, output_fmt)
      else if (arg == '--write-config-doc') then
        write_config_doc = .true.
      end if
    end do

  end subroutine command_line_argument

end program STB
