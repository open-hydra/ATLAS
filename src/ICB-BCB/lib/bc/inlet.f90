!> Inlet boundary condition builder (extracted from bc_types.f90).
!> Handles ideal-gas and condensed-phase inlet physics: Mach/mass-flux
!> modes, Ae/At area-ratio injection, turbulence properties, species
!> composition, and SRM grain coupling.
module bc_inlet
  use bc_constants, only: nIG_bc, Qal, csAl
  use phase_module,  only: phase_type
  use species,       only: obj_species, define_composition
  use area_law,      only: legge_aree, Runi
  use finer,         only: file_ini
  implicit none
  private

  public :: build_inlet, h02T0, T02h0

contains

  !> Build inlet BC properties for ideal-gas and/or condensed-phase streams.
  !> When SRMswitch is present, the SRM grain coupling path is followed.
  subroutine build_inlet(self_properties, self_species, self_IG_time_BC, &
                         self_IG_time_properties, self_cp_properties, &
                         self_cp_nproperties, nrans, sourceini, section, &
                         phase, SRMswitch)
    implicit none
    real(8), intent(inout)               :: self_properties(:)
    type(obj_species), intent(inout)     :: self_species
    logical, intent(inout)               :: self_IG_time_BC(:)
    character(32), intent(inout)         :: self_IG_time_properties(:)
    real(8), allocatable, intent(inout)  :: self_cp_properties(:,:,:)
    integer, intent(in)                  :: self_cp_nproperties
    integer, intent(in)                  :: nrans
    type(file_ini), intent(in)           :: sourceini
    character(len=4), intent(in)         :: section
    type(phase_type), intent(in)         :: phase
    logical, intent(in), optional        :: SRMswitch

    logical                        :: found_CEA, force_inflow
    integer                        :: error, m, npCP, i
    ! Ideal gas
    real(8) :: mach, massflux, p0, T0, h0, CEAh0, T, pstatic, rel_fac
    real(8) :: alpha, beta, nmach, mit, kappa, omega, rhoRij, psub, psup, rt
    real(8) :: krho
    real(8) :: Ae_At, Rgas, cp_, gam, M_sub, M_sup, Gamma_v
    ! Condensed-phase
    integer :: cp_scaling, error_gp
    real(8), allocatable :: kr(:), ku(:), kt(:), rp(:), dp(:), sigmap(:)
    real(8), allocatable :: rRes(:), Tsat(:), volRatio(:)
    real(8), allocatable :: gp(:), up(:), vp(:), wp(:), mvp(:)
    real(8), allocatable :: alphap(:), betap(:), Tp(:)

    ! Ideal gas bc
    if (phase%type=='IG'.or.present(SRMswitch)) then
      self_IG_time_BC = .false.
      self_IG_time_properties = 'None'
      found_cea = .false.
      nmach = 0.0; p0 = 0.0; force_inflow = .false.
      call sourceini%get(section_name=section, option_name='force-inflow', &
                         val=force_inflow, error=error)
      call sourceini%get(section_name=section, option_name='mach', &
                         val=mach, error=error)
      if (error==0) nmach = mach
      call sourceini%get(section_name=section, option_name='p0', &
                         val=p0, error=error)
      if (error==0) p0 = p0*1d+5
      call sourceini%get(section_name=section, option_name='T0', &
                         val=T0, error=error)
      if (error/=0) T0 = 0.0
      call sourceini%get(section_name=section, option_name='h0', &
                         val=h0, error=error)
      if (error/=0) h0 = 0.0
      call sourceini%get(section_name=section, option_name='T', &
                         val=T, error=error)
      if (error/=0) T = 0.0
      call sourceini%get(section_name=section, option_name='g', &
                         val=massflux, error=error)
      if (error==0 .and. nmach==0.0) nmach = -10.0
      call sourceini%get(section_name=section, option_name='alpha', &
                         val=alpha, error=error)
      if (error/=0) alpha = 0.0
      call sourceini%get(section_name=section, option_name='beta', &
                         val=beta, error=error)
      if (error/=0) beta = 0.0
      call sourceini%get(section_name=section, option_name='p', &
                         val=pstatic, error=error)
      if (error/=0) pstatic = 0.0

      ! Relaxation factor
      call sourceini%get(section_name=section, option_name='rf', &
                         val=rel_fac, error=error)
      if (error/=0) rel_fac = 1.0

      ! Turbulence properties
      call sourceini%get(section_name=section, option_name='mit', &
                         val=mit, error=error)
      if (error/=0) mit = 0.0
      call sourceini%get(section_name=section, option_name='kappa', &
                         val=kappa, error=error)
      if (error/=0) kappa = 0.0
      call sourceini%get(section_name=section, option_name='omega', &
                         val=omega, error=error)
      if (error/=0) omega = 0.0
      call sourceini%get(section_name=section, option_name='rhoRij', &
                         val=rhoRij, error=error)
      if (error/=0) rhoRij = 0.0

      ! Assign species mass fractions
      call define_composition(sourceini, self_species, T0, p0, CEAh0)

      if (h0/=0 .and. self_species%n==1) then
        T0 = h02T0(h0, self_species%h, lbound(self_species%h, dim=2))
      else
        h0 = CEAh0
      endif

      ! Injector - Area ratio mode or legacy mode
      Ae_At = 0.0d0
      rt = 0.0d0
      call sourceini%get(section_name=section, option_name='Ae_At', &
                         val=Ae_At, error=error)

      if (error==0) then
        ! Ae_At provided: new mode
        if (Ae_At < 1.0d0) error stop 'Ae_At must be >= 1.0'
        if (T0 <= 0.0d0 .or. p0 <= 0.0d0) &
          error stop 'Ae_At mode requires T0 > 0'
        if (sum(self_species%massf) < 1.0d-10) &
          error stop 'Ae_At mode requires species composition'

        ! Compute gas properties from species composition
        Rgas = sum(Runi * self_species%massf / self_species%w)
        cp_ = sum(self_species%massf * self_species%cp(:, nint(T0)))
        gam = cp_ / (cp_ - Rgas)

        if (Ae_At > 1.0d0) then
          call legge_aree(Ae_At, 0.5d0, M_sub, 1.0d0, gam)
          call legge_aree(Ae_At, 2.0d0, M_sup, 1.0d0, gam)
        else
          M_sub = 1.0d0
          M_sup = 1.0d0
        endif

        psub = p0 * (1.0d0 + 0.5d0*(gam-1.0d0)*M_sub**2) &
               **(-gam/(gam-1.0d0)) / 1.0d5
        psup = p0 * (1.0d0 + 0.5d0*(gam-1.0d0)*M_sup**2) &
               **(-gam/(gam-1.0d0)) / 1.0d5

        Gamma_v = sqrt(gam) * (2.0d0/(gam+1.0d0)) &
                  **((gam+1.0d0)/(2.0d0*(gam-1.0d0)))
        rt = p0 * Gamma_v / sqrt(Rgas * T0)

        alpha = psub
        beta = psup
        pstatic = rt

      else
        ! Legacy mode: read directly
        call sourceini%get(section_name=section, option_name='psub', &
                           val=psub, error=error)
        if (error==0) alpha = psub
        call sourceini%get(section_name=section, option_name='psup', &
                           val=psup, error=error)
        if (error==0) beta = psup
        call sourceini%get(section_name=section, option_name='rt', &
                           val=rt, error=error)
        if (error==0) pstatic = rt
      endif

      ! Time bc - only total pressure currently allowed
      call sourceini%get(section_name=section, &
                         option_name='p0-time-file', &
                         val=self_IG_time_properties(3), error=error)
      if (error==0) self_IG_time_BC(3) = .true.

      ! Force inflow
      if (force_inflow) pstatic = -3.14d-5

      ! Choose between total temperature and static one
      if (nmach<0.0 .and. T>0) nmach = -5.0

      if (.not.present(SRMswitch)) then
        self_properties(1) = nmach
        self_properties(2) = T0
        if (T>0) self_properties(2) = T
        if (nmach>=0) self_properties(3) = p0
        if (nmach<0) self_properties(3) = massflux
        self_properties(4) = alpha
        self_properties(5) = beta
        if (rt/=0.0) then
          self_properties(6) = rt
        else
          self_properties(6) = pstatic*1e+5
        endif
        self_properties(7) = rel_fac
        if (nrans==1) then
          self_properties(nIG_bc+1) = mit
        elseif (nrans==2) then
          self_properties(nIG_bc+1) = kappa
          self_properties(nIG_bc+2) = omega
        elseif (nrans==7) then
          self_properties(nIG_bc+1:nIG_bc+3) = rhoRij
          self_properties(nIG_bc+4:nIG_bc+6) = 1d-8
          self_properties(nIG_bc+7) = omega
        endif
      else
        m = size(self_properties)
        if (self_properties(m-3)>0.5d0) then
          T0 = self_properties(m-3)
          write(*,*) ' Override CEA mixture temperature given' &
                     //' adiabatic flame temperature Taf'
          do i = 1, self_species%n
            self_properties(m-2) = self_properties(m-2) &
              + self_species%massf(i) &
              * T02h0(T0, self_species%h, i)
          enddo
        else
          self_properties(m-3) = T0
          self_properties(m-2) = h0
        endif
        self_properties(m-6) = self_properties(1) &
          * self_properties(m) * self_properties(m-1) &
          * self_properties(m-6)
      endif

    endif

    if (phase%type/='IG') then

      ! Condensed-phase bc
      do m = 1, phase%material%n
        npCP = phase%material%npCP(m)
        allocate(kr(1:npCP));  kr  = 0d0
        call sourceini%get(section_name=section, option_name='krho', &
                           val=kr, error=error)
        allocate(ku(1:npCP));  ku  = 1d0
        call sourceini%get(section_name=section, option_name='kV', &
                           val=ku, error=error)
        allocate(kt(1:npCP));  kt  = 1d0
        call sourceini%get(section_name=section, option_name='kT', &
                           val=kt, error=error)

        allocate(gp(1:npCP));  gp  = 0d0
        call sourceini%get(section_name=section, option_name='gp', &
                           val=gp, error=error_gp)
        allocate(up(1:npCP));  up  = 0d0
        call sourceini%get(section_name=section, option_name='up', &
                           val=up, error=error)
        allocate(vp(1:npCP));  vp  = 0d0
        call sourceini%get(section_name=section, option_name='vp', &
                           val=vp, error=error)
        allocate(wp(1:npCP));  wp  = 0d0
        call sourceini%get(section_name=section, option_name='wp', &
                           val=wp, error=error)
        allocate(mvp(1:npCP)); mvp = 0d0
        call sourceini%get(section_name=section, option_name='|up|', &
                           val=mvp, error=error)
        if (error/=0) mvp = sqrt(up**2+vp**2+wp**2)
        allocate(Tp(1:npCP));  Tp = 0d0
        call sourceini%get(section_name=section, option_name='Tp', &
                           val=Tp, error=error)

        allocate(rp(1:npCP))
        call sourceini%get(section_name=section, option_name='rp', &
                           val=rp, error=error)
        allocate(dp(1:npCP))
        call sourceini%get(section_name=section, option_name='dp', &
                           val=dp, error=error)
        if (error==0) rp = 0.5*dp
        allocate(sigmap(1:npCP)); sigmap = 0d0
        call sourceini%get(section_name=section, option_name='sigmap', &
                           val=sigmap, error=error)

        allocate(alphap(1:npCP)); alphap = 0d0
        call sourceini%get(section_name=section, option_name='alphap', &
                           val=alphap, error=error)
        allocate(betap(1:npCP)); betap = 0d0
        call sourceini%get(section_name=section, option_name='betap', &
                           val=betap, error=error)
        allocate(rRes(1:npCP)); rRes = rp
        call sourceini%get(section_name=section, option_name='rRes', &
                           val=rRes, error=error)
        allocate(volRatio(1:npCP)); volRatio = (rRes/rp)**3.d0

        allocate(Tsat(1:npCP)); Tsat = T0
        call sourceini%get(section_name=section, option_name='Tsat', &
                           val=Tsat, error=error)

        if (error_gp/=0) cp_scaling = 0
        if (error_gp==0 .and. all(mvp/=0.d0)) cp_scaling = 1
        if (error_gp==0 .and. all(mvp==0.d0)) cp_scaling = 2

        self_cp_properties(m,1:npCP,1) = dble(cp_scaling)
        if (cp_scaling==0) then
          self_cp_properties(m,1:npCP,2) = kr
          self_cp_properties(m,1:npCP,3) = ku
          self_cp_properties(m,1:npCP,6) = kt
        elseif (cp_scaling==1) then
          self_cp_properties(m,1:npCP,2) = gp
          self_cp_properties(m,1:npCP,3) = mvp
          self_cp_properties(m,1:npCP,6) = Tp
        elseif (cp_scaling==2) then
          self_cp_properties(m,1:npCP,2) = gp
          self_cp_properties(m,1:npCP,3) = ku
          self_cp_properties(m,1:npCP,6) = Tp
        endif
        self_cp_properties(m,1:npCP,4) = alphap
        self_cp_properties(m,1:npCP,5) = betap
        self_cp_properties(m,1:npCP,7) = rp
        self_cp_properties(m,1:npCP,8) = sigmap
      enddo

      if (present(SRMswitch)) then
        m = size(self_properties)
        self_properties(m-2) = &
          (csAl*sum(self_cp_properties(m,1:npCP,2) &
                    *(volRatio*T0-Tsat)) &
           + sum((1d0-self_cp_properties(m,1:npCP,2) &
                      *volRatio))*self_properties(m-2) &
           - sum(self_cp_properties(m,1:npCP,2) &
                 *(1d0-volRatio))*Qal) &
          /(1d0-sum(self_cp_properties(m,1:npCP,2)))
        if (all(self_cp_properties(:,:,1)==0.d0)) then
          krho = sum( self_cp_properties(:,:,2) )
        else
          write(*,*) 'ERROR: you should not fix the condensed-phase' &
                     //' mass flux when using the SRM grain BC (14)'
          stop
        endif
        self_properties(m-6) = self_properties(m-6)*(1.d0-krho)
      endif
    endif

  end subroutine build_inlet


  !> Compute T starting from h using tabellams
  function h02T0(h0, h, start) result(T0)
    implicit none
    real(8), intent(in) :: h0
    integer, intent(in) :: start
    real(8), intent(in) :: h(:,start:)
    real(8) :: T0
    integer :: i

    do i = lbound(h, dim=2), ubound(h, dim=2)
      if (h0<=h(1,i) .and. h0>h(1,i-1)) then
        T0 = 1d0/(h(1,i)-(h(1,i-1))*(h0-(h(1,i-1))))+dble(i-1)
        exit
      endif
    enddo
  end function h02T0


  function T02h0(T0, h, s) result(h0)
    implicit none
    real(8), intent(in) :: T0
    real(8), intent(in) :: h(:,:)
    integer, intent(in) :: s
    real(8) :: h0
    integer :: i

    do i = lbound(h, dim=2), ubound(h, dim=2)
      if (T0<=i .and. T0>i-1) then
        h0 = (T0-dble(i-1))*(h(s,i)-(h(s,i-1))) + (h(s,i-1))
        exit
      endif
    enddo
  end function T02h0

end module bc_inlet
