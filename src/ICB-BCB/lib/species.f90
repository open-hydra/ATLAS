module species
  use CEA_module
  implicit none

  type, extends(obj_CEA_species) :: obj_species
    real(8), dimension(:), allocatable   :: w
    real(8), dimension(:,:), allocatable :: dcp, h, s, cp
  end type obj_species
  
contains

  subroutine define_composition(sini,species,ytot,T0,p0)
    use finer, only: file_ini
    use strings, only: parse
    implicit none
    type(file_ini), intent(in)       :: sini
    type(obj_species), intent(inout) :: species
    real(8), intent(inout)           :: T0, p0, ytot
    type(obj_CEA)                    :: CEA
    type(obj_species)                :: ct_species
    character(len=500)               :: CEAfile
    character(len=20)                :: name, str(2)
    character(len=:), allocatable    :: item(:), section_name(:)
    integer :: i, j, error

    CEA%OG = .false.
    call sini%get_sections_list(section_name)
    call sini%get(section_name=section_name(1), option_name='eq-OG',val=CEA%OG,error=error)
    call sini%get(section_name=section_name(1), option_name='eq-CEA-file',val=CEAfile,error=error)
    if (error==0) then
    ! Use CEA
      CEA%indx = 1
      call sini%get(section_name=section_name(1), option_name='eq-CEA-section',val=CEA%indx,error=error)
      CEAfile = trim(CEAfile(:(len_trim(CEAfile)-4)))
      call CEA%solve(CEAfile)
      if (T0==0) T0 = CEA%SE%temperature
      if (p0==0) p0 = CEA%SE%pressure*1e+5
      ytot = 0.0
      do j = 1, species%n; do i = 1, CEA%SE%species%n
          if (index(species%name(j),'-')/=0) then
            call parse(species%name(j),'-',str)
            name = str(1)
          else
            name = species%name(j)
          endif
          if (trim(CEA%SE%species%name(i))==trim(name)) then
            species%massf(j) = CEA%SE%species%massf(i)
            ytot = ytot+species%massf(j)
            exit
          end if
      end do; end do
    elseif (sini%has_option(option_name='eq-pressure')) then
    ! Use Cantera
      call write_KAnT_INI(sini)
      call read_KAnT_out(T0,ct_species)
      if (p0==0) then 
        call sini%get(section_name=section_name(1), option_name='eq-pressure',val=p0,error=error)
        p0 = p0*1e+5
      endif
      ytot = 0.0
      do j = 1, species%n; do i = 1, ct_species%n
          if (trim(ct_species%name(i))==trim(species%name(j))) then
            species%massf(j) = ct_species%massf(i)
            ytot = ytot+species%massf(j)
            exit
          end if
      end do; end do
    else
    ! Direct address of mass fractions
      do while(sini%loop(section_name=section_name(1), option_pairs=item))
        if (index(item(1),'y')/=0) then
          name = item(1); name = name(2:20)
          do j = 1, species%n
            if (trim(name)==trim(species%name(j))) then
              read(item(2),'(D12.5)') species%massf(j)
              ytot = ytot+species%massf(j)
              exit
            end if
          end do
        endif
      enddo
    endif

    if (species%n==1) species%massf(1) = 1.0

  end subroutine define_composition

  subroutine write_KAnT_INI(sini)
    use finer, only: file_ini
    implicit none
    type(file_ini), intent(in)    :: sini
    type(file_ini)                :: nini
    character(len=20)             :: name
    character(len=:), allocatable :: item(:), section_name(:)

      call nini%free
      call nini%add(section_name='KAnT-Equilibrium')
      call sini%get_sections_list(section_name)
      do while(sini%loop(section_name=section_name(1), option_pairs=item))
        if (index(item(1),'eq-')/=0) then
          name = item(1)
          call nini%add(section_name='KAnT-Equilibrium', option_name=trim(name(4:)), val=item(2))
        endif
      enddo
      call nini%save(filename='kant.ini')

  end subroutine write_KAnT_INI

  subroutine run_KAnT()
    implicit none
    character(len=500) :: master_path
    call get_environment_variable('ATLASDIR',master_path)
    call execute_command_line(trim(master_path)//'/ATLAS.sh KAnT > kant-out')
  end subroutine

  subroutine read_KAnT_out(temp,sp)
    use strings, only: parse
    implicit none
    real(8), intent(out)  :: temp
    type(obj_species), intent(out) :: sp
    integer :: u, ios, n, nskip, s
    character(len=200) :: wholestring, stringa(2)

    call run_KAnT

    ios = 10; nskip = 0; n = -1
    open(unit=u, file='kant-out')
    do while (ios/=0)
      read(u,'(A)',iostat=ios) wholestring
      read(wholestring,*,iostat=ios) temp
      nskip = nskip + 1
    enddo
    do while ( ios==0 )
      read(u,*,iostat = ios)
      n = n+1
    enddo
    rewind(u)
    do s = 1, nskip; read(u,*); enddo
    sp%n = n
    allocate(sp%name(1:n))
    allocate(sp%massf(1:n))
    do s = 1, n
      read(u,'(A)') wholestring
      call parse(wholestring,' ',stringa)
      sp%name(s) = trim(stringa(1))
      read( stringa(2), * ) sp%massf(s)
    enddo
    close(u)
    call execute_command_line('rm kant*')

  end subroutine read_KAnT_out

end module species