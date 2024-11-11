module input_ini
  use finer, only: file_ini
  implicit none
  private

  public:: build_INI
  !public:: read_CP_input

  integer :: error

contains

  subroutine build_INI(prog,nb,inisource,ICformat,chimeraon,force_connect)
    implicit none
    character(len=3), intent(in)              :: prog
    integer, intent(in)                       :: nb
    type(file_ini), intent(out)               :: inisource
    character(len=*), intent(inout), optional :: ICformat
    logical, intent(inout), optional          :: chimeraon, force_connect
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

    if (present(force_connect)) then
      call fini%get(section_name='ATLAS-General', option_name='BC-force-connect', val=force_connect, error=error)
      if (error/=0) force_connect = .true.
    endif

    if (present(chimeraon)) then
      call fini%get(section_name='ATLAS-General', option_name='BC-chimera', val=chimeraon, error=error)
      if (error/=0) chimeraon = .false.
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
