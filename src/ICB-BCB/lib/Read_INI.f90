module input_ini
  use finer, only: file_ini
  implicit none
  private

  !public:: read_BCB_input
  public:: read_ATLAS_general
  public:: read_ICB_input
  !public:: read_CP_input

  type(file_ini)  :: fini       !< INI File.
  integer         :: error      !< Error code.


contains

  subroutine read_ATLAS_general(inifile,ICformat)
    implicit none
    character(len=*), intent(inout)           :: inifile
    character(len=*), intent(inout), optional :: ICformat

    call fini%load(filename='input.ini')

    call fini%get(section_name='ATLAS-General', option_name='ICB-file', val=inifile, error=error)
    if (error/=0) inifile = 'input.ini'

    call fini%get(section_name='ATLAS-General', option_name='BCB-file', val=inifile, error=error)
    if (error/=0) inifile = 'input.ini'
    
    if (present(ICformat)) then
      call fini%get(section_name='ATLAS-General', option_name='IC-format', val=ICformat, error=error)
      if (error/=0) ICformat = 'tec'
    endif

  end subroutine read_ATLAS_general

  ! subroutine read_CP_input(CP_present)
  !   use bc, only: npCP
  !   implicit none
  !   logical, intent(out) :: CP_present

  !   npCP = 0; CP_present = .false.
  !   call fini%load(filename='input.ini')
  !   call fini%get(section_name='CPM-General', option_name='np', val=npCP, error=error)
  !   if (error/=0) call fini%get(section_name='ICE-General', option_name='np', val=npCP, error=error)
  !   if (error==0) then
  !     CP_present = .true.
  !     write(*,*)
  !     write(*,*)' Multi-phase section found'
  !   endif

  ! end subroutine read_CP_input


  ! subroutine read_BCB_input(method,force_connect,chimeraon)
  !   implicit none
  !   character(len=2), intent(out)  :: method
  !   logical, intent(out)           :: force_connect, chimeraon
  !   character(len=:), allocatable  :: list(:)
  !   character(len=:), allocatable  :: items(:,:)
  !   logical                        :: timeBC
  !   integer                        :: i

  !   call fini%load(filename=adjustl(trim(folder_path))//'/input.ini')
  !   call fini%get_sections_list(list=list)
  !   nb = 0
  !   do i = 1, size(list,1)
  !     if (index(list(i),'BCB-Block')>0) nb = nb+1
  !   enddo

  !   ! Look for turbulent flow entry and time-dependent boundary conditions
  !   call fini%get_items(items=items)
  !   nrans = 0; timeBC = .false.
  !   do i = 1, size(items, dim=1)
  !     if (items(i,1)=='mit') nrans = 1
  !     if (items(i,1)=='kappa') nrans = 2
  !     if (items(i,1)=='rhoRij') nrans = 7
  !     if (index(items(i,1),'-time-file')>0) timeBC = .true.
  !   enddo

  !   ! Write file list for time-dependent boundary conditions
  !   if (timeBC) then
  !     open(newunit=unitFile,file='toAFFS/timeBC.bound')
  !     do i = 1, size(items, dim=1)
  !       if (index(items(i,1),'-time-file')>0) write(unitFile,*) items(i,2)
  !     enddo
  !     close(unitFile)
  !   endif

  !   method = 'CB'
  !   write(*,*)' Method: ', method
  !   write(*,*)
  !   if (nrans==0) write(*,*)' No turbulent model properties found'
  !   if (nrans==1) write(*,*)' One-equation turbulent model properties found'
  !   if (nrans==2) write(*,*)' Two-equation turbulent model properties found'
  !   if (nrans==7) write(*,*)' Full Reynolds Stress Model properties found'
  !   write(*,*)

  !   call fini%get(section_name='BCB-General', option_name='force-connect', val=force_connect, error=error)
  !   if (error/=0) force_connect = .true.

  !   call fini%get(section_name='BCB-General', option_name='chimera', val=chimeraon, error=error)
  !   if (error/=0) chimeraon = .false.

  ! end subroutine read_BCB_input


  subroutine read_ICB_input(inifile)
    use lib_ic
    use variables
    implicit none
    character(len=*), intent(in)    :: inifile
    character(len=:), allocatable   :: list(:)
    character(len=:), allocatable   :: items(:,:)
    integer :: i

    call fini%load(filename=inifile)
    call fini%get_sections_list(list=list)

    ! Look for turbulent flow entry
    call fini%get_items(items=items)
    nrans = 0
    do i = 1, size(items, dim=1)
      if (items(i,1)=='mit') nrans = 1
      if (items(i,1)=='kappa') nrans = 2
      if (items(i,1)=='rhoRij') nrans = 7
    enddo

    write(*,*)
    if (nrans==0) write(*,*)' No turbulent model properties found'
    if (nrans==1) write(*,*)' One-equation turbulent model properties found'
    if (nrans==2) write(*,*)' Two-equation turbulent model properties found'
    if (nrans==7) write(*,*)' Full Reynolds Stress Model properties found'
    write(*,*)

  end subroutine read_ICB_input

end module input_ini
