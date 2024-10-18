!>
!> Initial Conditions Builder
!>

program ICB
  use CEA_module
  use variables
  use ATLAS_high_level
  use IO
  use Lib_ORION_data
  use input_ini
  use lib_ic
  use Interpolator, only: intersol
  implicit none
  type(ATLAS_block), allocatable :: block(:)
  type(orion_data)               :: orion
  character(len=2)             :: method
  character(len=30)            :: ICformat
  type(obj_species)            :: species
  character(len=llen)          :: meshfile, oldmeshfile, oldsolutionfile, oldspeciesfile, inifile
  integer                      :: b!, ncelltot

  write(*,*)
  write(*,*) ' ATLAS - Initial Conditions Builder'
  write(*,*)

  inifile = 'input.ini'
  meshfile = 'mesh.tec'

  call execute_command_line('mkdir -p '//trim(outpath))

  call read_species('species.data',species%n,species%name)

  !> read general input
  call read_ICB_input(inifile,method,ICformat,oldmeshfile,oldspeciesfile,oldsolutionfile)

  select case (method)

  !> Cell-based IC
  case('CB')

    !> read mixture properties
    call read_MISCELA(w,cp,dcp,h)
    !> read mesh
    write(*,*)' Reading mesh file: ',trim(meshfile)
    call read_TECmesh(orion,meshfile)
    call build_geometry(input=orion,output=block)
    ! ncelltot = 0
    ! do b = 1, size(block)
    !   ncelltot = ncelltot+block(b)%dim(1)*block(b)%dim(2)*block(b)%dim(3)
    !   write(*,*) ' Block size = ', block(b)%dim(1), block(b)%dim(2), block(b)%dim(3)
    ! end do
    ! write(*,*)' Overall number of grid cells:', ncelltot
    ! write(*,*)
    do b = 1, size(block)
      call build_IC(block,species,method)
    enddo

  !> Interpolation
  case('IB')

    call intersol(species,oldspeciesfile,meshfile,oldmeshfile,oldsolutionfile)

  end select

  !> write media.init
  if (index(ICformat,'native')>0) then
    call write_solfile(block)
  else
    call write_vtk_tec(ICformat, block, orion)
  endif

end program ICB