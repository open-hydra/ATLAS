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
  character(len=30)            :: ICformat
  type(obj_species)            :: species
  character(len=llen)          :: meshfile, inifile
  integer                      :: b!, ncelltot

  write(*,*)
  write(*,*) ' ATLAS - Initial Conditions Builder'
  write(*,*)

  meshfile = 'mesh.tec'
  !call read_MISCELA(w,cp,dcp,h)
  call read_species('species.data',species%n,species%name)

  call execute_command_line('mkdir -p '//trim(outpath))

  call read_ATLAS_general(inifile, ICformat)

  call read_ICB_input(inifile)

  write(*,*)' Reading mesh file: ',trim(meshfile)
  call read_TECmesh(orion,meshfile)
  call import_nodes(input=orion,output=block)
  do b = 1, size(block)
    call block(b)%compute_centers(0)
  enddo

  do b = 1, size(block)
    call build_IC(block,species)
  enddo

  !> write media.init
  if (index(ICformat,'native')>0) then
    call write_solfile(block)
  else
    call write_vtk_tec(ICformat, block, orion)
  endif

end program ICB