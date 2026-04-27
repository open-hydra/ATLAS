module phase_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use CEA_module
  implicit none

  real(8), parameter :: Runi = 8314.51d0  !< Universal gas constant [J/(kmol·K)]

  type, extends(obj_CEA_species) :: species_t
    real(R8), dimension(:), allocatable   :: w
    real(R8), dimension(:,:), allocatable :: dcp, h, s, cp
  end type species_t

  type :: real_fluid_t
    integer                               :: n = 0
    character(len=16)                     :: name = ''
    real(R8), dimension(:),   allocatable :: p
    real(R8), dimension(:),   allocatable :: h
    real(R8), dimension(:,:), allocatable :: T
  end type real_fluid_t

  type :: material_t
    integer :: n
    character(len=16), allocatable        :: name(:)
    integer, allocatable                  :: npCP(:)
    real(R8), dimension(:,:), allocatable :: h
    real(R8), dimension(:,:), allocatable :: rho
    real(R8), dimension(:,:), allocatable :: cp
  end type material_t

  type, public :: phase_t
    character(len=2)        :: type
    character(len=128)      :: name
    type(material_t)        :: material
    type(species_t)         :: species
    type(real_fluid_t)      :: fluid
  end type phase_t

contains

  subroutine define_composition(sini,species,T0,p0,h0)
    use finer, only: file_ini
    use strings, only: parse
    implicit none
    type(file_ini),  intent(in)            :: sini
    type(species_t), intent(inout)         :: species
    real(R8),        intent(inout)         :: T0, p0
    real(R8),        intent(inout), optional :: h0
    type(obj_CEA)                    :: CEA
    character(len=500)               :: CEAfile
    character(len=20)                :: name, str(2)
    character(len=:), allocatable    :: item(:), section_name(:)
    integer :: i, j, error
    real(R8) :: ytot

    species%massf = 0.0d0

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
      T0 = CEA%SE%temperature
      p0 = CEA%SE%pressure*1e+5
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


  !> Newton-Raphson procedure for T0
  pure function T02T(T0,M,sp) result(T)
    implicit none
    real(R8), intent(in)        :: T0, M
    type(species_t), intent(in) :: sp
    ! Local
    real(R8)             :: T
    real(R8)             :: TT,Tnew,H0,h_tot,cp_tot,dcp_tot,FT,DFT,Rgas
    real(R8), parameter  :: toll=1.d-8
    integer              :: s

    Rgas = sum(Runi*sp%massf/sp%w)

    Tnew = T0*0.95
    H0 = 0.0
    do s = 1, size(sp%massf)
      H0 = H0+sp%massf(s)*(sp%h(s,idint(T0))+(sp%h(s,idint(T0)+1)-sp%h(s,idint(T0)))*(T0-idint(T0)))
    enddo

    FT  = 1.0
    DFT = 1.0
    TT  = 1.0
    do while (abs(FT/(DFT*TT))>toll)
      TT = Tnew
      cp_tot = 0.0
      dcp_tot = 0.0
      h_tot = 0.0
      do s = 1, size(sp%massf)
        cp_tot  = cp_tot  + sp%massf(s) * (sp%cp(s,idint(TT))  + (sp%cp(s,idint(TT)+1)  - sp%cp(s,idint(TT)))*(TT-idint(TT)))
        dcp_tot = dcp_tot + sp%massf(s) * (sp%dcp(s,idint(TT)) + (sp%dcp(s,idint(TT)+1) - sp%dcp(s,idint(TT)))*(TT-idint(TT)))
        h_tot   = h_tot   + sp%massf(s) * (sp%h(s,idint(TT))   + (sp%h(s,idint(TT)+1)   - sp%h(s,idint(TT)))*(TT-idint(TT)))
      enddo
      FT = H0-h_tot-0.5d0*M*M*cp_tot/(cp_tot-Rgas)*Rgas*TT
      DFT = -cp_tot-0.5d0*M*M*Rgas*(cp_tot*(cp_tot-Rgas)-TT*dcp_tot*Rgas)/(cp_tot-Rgas)**2d0
      Tnew = TT-FT/DFT
    enddo

    T = TT

  end function T02T


  pure function p02p(p0,M,T,sp) result(p)
    implicit none
    real(R8), intent(in)        :: p0, M, T
    type(species_t), intent(in) :: sp
    ! Local
    real(R8) :: p
    real(R8) :: cp_, Rgas, gamma, del

    Rgas = sum(Runi*sp%massf/sp%w)
    cp_ = sum(sp%massf*sp%cp(:,nint(T)))
    gamma = cp_/(cp_-Rgas)
    del = 0.5d0*(gamma-1d0)
    p = p0/((1d0+del*M*M)**(gamma/(gamma-1d0)))

  end function p02p

end module phase_mod