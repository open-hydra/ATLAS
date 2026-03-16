module ATLAS_IO_INI
  use finer, only: file_ini
  implicit none
  private

  public:: build_INI

  integer :: error

contains

  subroutine build_INI(prog,nb,inisource,ICformat,MG_levels,chimeraon,poweron,powerfile,force_connect)
    implicit none
    character(len=3), intent(in)                :: prog
    integer, intent(in)                         :: nb
    type(file_ini), intent(out)                 :: inisource
    integer, intent(inout), optional            :: MG_levels
    character(len=*), intent(inout), optional   :: ICformat
    logical, intent(inout), optional            :: chimeraon, poweron, force_connect
    character(len=200), intent(inout), optional :: powerfile
    character(len=30)                           :: inifile
    type(file_ini)                              :: fini

    call fini%load(filename='input.ini')

    call fini%get(section_name='ATLAS-General', option_name='ICB-file', val=inifile, error=error)
    if (error/=0) inifile = 'input.ini'

    call fini%get(section_name='ATLAS-General', option_name='BCB-file', val=inifile, error=error)
    if (error/=0) inifile = 'input.ini'

    if (present(MG_levels)) then
      call fini%get(section_name='ATLAS-General', option_name='MG-levels', val=MG_levels, error=error)
      if (error/=0) MG_levels = 1
    endif

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

    if (present(poweron)) then
      call fini%get(section_name='ATLAS-General', option_name='IC-power', val=poweron, error=error)
      if (error/=0) poweron = .false.
      if (poweron) then
        call fini%get(section_name='ATLAS-General', option_name='IC-powerfile', val=powerfile, error=error)
        if (error/=0) powerfile = 'power.tec'
      endif
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
    integer                       :: b, s
    logical                       :: is_there
    character(len=:), allocatable :: section_list(:)

    call sini%free

    do b = 1, nb
      write(indb,'(I4)') b
      ! Define and add a *-Block# section
      new_section = prog//'-Block'//adjustl(indb)
      call sini%add(section_name=new_section)

      ! Look for section name in inifile
      actual_section = new_section
      is_there = fini%has_section(actual_section)
      if (.not.is_there) then
        actual_section = prog//'-Block*'
        is_there = fini%has_section(actual_section)
      endif

      ! Copy the options from the inifile to the inisource
      do while (fini%loop(section_name=actual_section, option_pairs=option_pairs))
        call sini%add(section_name=new_section, option_name=option_pairs(1), val=option_pairs(2))
      enddo
    enddo

    ! Add further sections
    call fini%get_sections_list(section_list)
    do s = 1, size(section_list)
      ! Bypass sections named after a block
      if (index(section_list(s),'Block')>0) cycle
      ! Copy all the remaining sections
      call sini%add(section_name=section_list(s))
      do while (fini%loop(section_name=section_list(s), option_pairs=option_pairs))
        call sini%add(section_name=section_list(s), option_name=option_pairs(1), val=option_pairs(2))
      enddo
    enddo

  end function generate_sections_input


  subroutine scan_turbo_input(fini)
    use variables
    implicit none
    type(file_ini), intent(in)    :: fini       !< INI File.
    character(len=:), allocatable :: items(:,:)
    integer :: i

    call fini%get_items(items=items)
    cfg%nrans = 0
    do i = 1, size(items, dim=1)
      if (items(i,1)=='mit') cfg%nrans = 1
      if (items(i,1)=='kappa') cfg%nrans = 2
      if (items(i,1)=='rhoRij') cfg%nrans = 7
    enddo

    write(*,*)
    if (cfg%nrans==0) write(*,*)' No turbulent model properties found'
    if (cfg%nrans==1) write(*,*)' One-equation turbulent model properties found'
    if (cfg%nrans==2) write(*,*)' Two-equation turbulent model properties found'
    if (cfg%nrans==7) write(*,*)' Full Reynolds Stress Model properties found'
    write(*,*)

  end subroutine scan_turbo_input

end module ATLAS_IO_INI
