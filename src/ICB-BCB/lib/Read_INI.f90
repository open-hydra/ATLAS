module input_ini
  use finer, only: file_ini
  implicit none
  private

  !public:: read_BCB_input
  public:: build_INI
  !public:: read_CP_input

  integer :: error

contains

  subroutine build_INI(prog,nb,inisource,ICformat)
    implicit none
    character(len=3), intent(in)              :: prog
    integer, intent(in)                       :: nb
    type(file_ini), intent(out)               :: inisource
    character(len=*), intent(inout), optional :: ICformat
    character(len=30)                         :: inifile
    type(file_ini)                            :: fini

    call fini%load(filename='input.ini')

    call fini%get(section_name='ATLAS-General', option_name='ICB-file', val=inifile, error=error)
    if (error/=0) inifile = 'input.ini'

    call fini%get(section_name='ATLAS-General', option_name='BCB-file', val=inifile, error=error)
    if (error/=0) inifile = 'input.ini'

    if (present(ICformat)) then
      call fini%get(section_name='ATLAS-General', option_name='IC-format', val=ICformat, error=error)
      if (error/=0) ICformat = 'tec'
    endif

    ! Read specific INI file
    call fini%load(filename=inifile)
    inisource = generate_sections_input(prog,fini,nb)

    call scan_turbo_input(fini)

  end subroutine build_INI


  function generate_sections_input(prog,fini,nb) result(sini)
    implicit none
    character(len=3), intent(in)  :: prog
    type(file_ini), intent(in)    :: fini
    integer, intent(in)           :: nb
    type(file_ini)                :: sini
    character(len=:), allocatable :: option_pairs(:)
    character(len=30)             :: actual_section, new_section
    character(len=4)              :: indb
    integer                       :: b
    logical                       :: is_there

    call sini%free

    do b = 1, nb
      write(indb,'(I4)') b
      new_section = prog//'-Block'//adjustl(indb)
      call sini%add(section_name=new_section)

      ! Look for section name in inifile
      actual_section = new_section
      is_there = fini%has_section(actual_section)
      if (.not.is_there) then
        actual_section = prog//'-Block*'
        is_there = fini%has_section(actual_section)
      endif

      do while (fini%loop(section_name=actual_section, option_pairs=option_pairs))
        call sini%add(section_name=new_section, option_name=option_pairs(1), val=option_pairs(2))
      enddo
    enddo

  end function generate_sections_input

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


  subroutine scan_turbo_input(fini)
    use variables
    implicit none
    type(file_ini), intent(in)    :: fini       !< INI File.
    character(len=:), allocatable :: items(:,:)
    integer :: i

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

  end subroutine scan_turbo_input

end module input_ini
