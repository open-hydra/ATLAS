module species
  use CEA_module
  implicit none

  type, extends(obj_CEA_species) :: obj_species
    real(8), dimension(:), allocatable   :: w
    real(8), dimension(:,:), allocatable :: dcp, h, s, cp
  end type obj_species
  
contains

  subroutine define_composition(sini,species,T0,p0,h0)
    use finer, only: file_ini
    use strings, only: parse
    implicit none
    type(file_ini),    intent(in)            :: sini
    type(obj_species), intent(inout)         :: species
    real(8),           intent(inout)         :: T0, p0
    real(8),           intent(out), optional :: h0
    type(obj_CEA)                    :: CEA
    character(len=500)               :: CEAfile
    character(len=20)                :: name, str(2)
    character(len=:), allocatable    :: item(:), section_name(:)
    integer :: i, j, error
    real(8) :: ytot

    species%massf = 0.0d0

    ! Initialize h0, if CEA is used, its value will be overwritten
    if (present(h0)) h0 = 0.d0

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
      ! Look for mixture presence
      do j = 1, species%n
        if (species%name(j)=='CEA-mixture') then
          species%massf(j) = 1.0-ytot
        endif
      enddo
    endif
    ! Direct address of mass fractions
    do while(sini%loop(section_name=section_name(1), option_pairs=item))
      if (index(item(1),'y')/=0 .and. item(1)/='type') then
        name = item(1); name = name(2:20)
        do j = 1, species%n
          if (trim(name)==trim(species%name(j))) then
            read(item(2),'(D12.5)') species%massf(j)
            exit
          end if
        end do
      endif
    enddo

    if (species%n==1) species%massf(1) = 1.0
    if (present(h0)) h0 = CEA%SE%h0*1000

  end subroutine define_composition

end module species
