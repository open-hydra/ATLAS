!>
!> Boundary Conditions Builder
!>

program BCB
  use CEA_module
  use variables
  use ATLAS_high_level
  use IO
  use Lib_ORION_data
  use input_ini
  use Interpolator, only: intersol
  use finer, only: file_ini
  implicit none
  type(ATLAS_block), allocatable :: block(:)
  type(orion_data)               :: orion
  type(obj_species)              :: species
  character(len=llen)            :: filename
  type(file_ini)                 :: sourceini
  integer                        :: b

  write(*,*)
  write(*,*) ' ATLAS - Initial Conditions Builder'
  write(*,*)

  call command_line_argument()

  ! Phase properties import
  call read_MISCELA(w,cp,dcp,h)
  filename = 'species.data'
  call read_species('species.data',species%n,species%name)

  ! Geometry import
  filename = 'mesh.tec'
  write(*,*)' Reading mesh file: ',trim(filename)
  call read_TECmesh(orion,filename)
  call import_nodes(input=orion,output=block)
  do b = 1, size(block)
    call block(b)%compute_centers(0)
  enddo

  ! INI handling
  call build_INI('BCB',size(block),sourceini)

  !call read_BCB_input(method,gmsh_mode,force_connect,chimeraon)
  !call read_CP_input(CP_present)

  !> write media.bound
  ! do b = 1, nb
  !   call read_and_assign_BC(species,b)
  ! enddo
  ! open(40,FILE='toAFFS/media.bound',STATUS='unknown')
  ! call find_periodic(CP_present)
  ! if (CP_present .and. nb>1) open(unit=1,file='toAFFS/CPMadj.bound')
  ! if (nb>1) then
  !   if (chimeraon) then
  !     call chimera_wrapper()
  !   else
  !     call find_connect(CP_present,force_connect)
  !   endif
  ! endif
  ! do b = 1, nb
  !   call write_mediabound(b)
  ! enddo
  ! close(40)
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
