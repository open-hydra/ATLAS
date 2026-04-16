!>
!> Source Terms Builder
!>

program STB
  use variables
  use grid_mod
  use read_mesh_mod
  use Lib_ORION_data
  use io_ini_mod
  use area_variation_mod
  use finer, only: file_ini
  implicit none
  type(block_type), allocatable  :: blk(:)
  type(orion_data)               :: orion 
  type(file_ini)                 :: sourceini
  integer                        :: b

  write(*,*)
  write(*,*) ' ATLAS - Source Terms Builder'
  write(*,*)

  call command_line_argument()
  call execute_command_line('mkdir -p '//trim(outpath))

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

  ! Build Q2D Area variation files, if any
  call build_area_variation(sourceini,blk)

contains

  subroutine command_line_argument()
    implicit none
    character(99):: arg
    integer      :: arg_count, i

    cfg%verbose = .false.

    arg_count = COMMAND_ARGUMENT_COUNT()

    do i = 1, arg_count
      call GET_COMMAND_ARGUMENT(i, arg)
      if (arg == '-v' .or. arg == '--verbose') then
        cfg%verbose = .true.
      end if
    end do

  end subroutine command_line_argument

end program STB
