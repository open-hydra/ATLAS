!>
!> Initial Conditions Builder
!>

program ICB
  use CEA_module
  use variables
  use ATLAS_high_level
  use IO
  use input_ini
  use lib_ic
  use Interpolator, only: intersol
  implicit none
  character(len=2)             :: method
  type(ATLAS_block), allocatable            :: block(:)
  type(obj_species)            :: species
  character(len=llen)          :: meshfile, oldmeshfile, oldsolutionfile, oldspeciesfile, inifile
  integer                      :: b, nb, ncelltot
  logical                      :: is_present

  write(*,*)
  write(*,*) ' ATLAS - Initial Conditions Builder'
  write(*,*)

  inifile = 'input.ini'
  meshfile = 'mesh.tec'

  call read_species('species.data',species%n,species%name)

  !> read general input
  call read_ICB_input(inifile, method,oldmeshfile,oldspeciesfile,oldsolutionfile)

  select case (method)

  !> Cell-based IC
  case('CB')

    !> read mixture properties
    call read_MISCELA(w,cp,dcp,h)
    !> read mesh
    write(*,*)' Reading mesh file: ',trim(meshfile)
    call read_TECmesh(block,meshfile)
    nb = size(block)
    ncelltot = 0
    do b = 1, nb
      ncelltot = ncelltot+block(b)%dim(1)*block(b)%dim(2)*block(b)%dim(3)
      write(*,*) ' Block size = ', block(b)%dim(1), block(b)%dim(2), block(b)%dim(3)
    end do
    write(*,*)' Overall number of grid cells:', ncelltot
    write(*,*)
    do b = 1, nb
      call build_IC(block,species,method)
    enddo

  !> Interpolation
  case('IB')

    call intersol(species,oldspeciesfile,meshfile,oldmeshfile,oldsolutionfile)

  end select

  !> write media.init
  call write_solfile(block)
  call write_vtk_tec(block)

end program ICB