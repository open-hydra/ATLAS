submodule (bc_mod) ig_inflow_outflow_mod
  use bcb_config_mod, only: bcb_ig_boundary_config_t, load_bcb_ig_boundary_config
  use phase_mod, only: phase_t, species_t, define_composition, T02T, p02p
  implicit none

contains

  module procedure build_inflow_outflow_ig
    implicit none
    type(bcb_ig_boundary_config_t) :: cfg
    real(R8) :: p0, T0, h0, mach, T, g, alpha, beta, p, rel_fac, Ae_At, rt, psup, psub
    real(R8) :: mit, kappa, omega, rhoRij
    integer  :: dim, start, nrans
    real(R8) :: ceah0, ceaT0, ceap0
    character(len=32) :: p0_time_file, p_time_file, time_file
    logical :: periodic

    self % ig_species = phase % species
    if (.not.allocated(self % ig_species % massf)) allocate(self % ig_species % massf(1:self % ig_species % n))
    self % ig_species % massf = 1d-20

    call load_bcb_ig_boundary_config(sourceini, section, cfg)

    mach         = cfg%mach
    p0           = cfg%p0
    T0           = cfg%T0
    h0           = cfg%h0
    T            = cfg%T
    g            = cfg%g
    alpha        = cfg%velocity%alpha
    beta         = cfg%velocity%beta
    p            = cfg%p
    rel_fac      = cfg%rel_fac
    Ae_At        = cfg%Ae_At
    rt           = cfg%rt
    psub         = cfg%psub
    psup         = cfg%psup
    p0_time_file = cfg%p0_time_file
    p_time_file  = cfg%p_time_file
    time_file    = cfg%time_file
    periodic     = cfg%periodic
    mit          = cfg%turbulence%mit
    kappa        = cfg%turbulence%kappa
    omega        = cfg%turbulence%omega
    rhoRij       = cfg%turbulence%rhoRij
    nrans        = cfg%turbulence%nrans

    ! Assign species mass fractions; pre-init so intent(inout) args are never sNaN
    CEAT0 = 0.0_R8; CEAp0 = 0.0_R8; CEAh0 = 0.0_R8
    call define_composition(sourceini, self%ig_species, CEAT0, CEAp0, CEAh0)

    if (p0==0_R8 .and. g==0_R8) p0 = CEAp0
    if (T0==0_R8 .and. T==0_R8) T0 = CEAT0

    if (h0/=0_R8 .and. self%ig_species%n==1) then
      T0 = h02T0(h0, self%ig_species%h, lbound(self%ig_species%h, dim=2))
    else
      h0 = CEAh0
    endif

    ! Dispatch
    if ( Ae_At + rt /= 0_R8) then
      call nozzle
    else
      call standard
    endif

    if (self % definition=='inlet') then

      ! Mass fractions
      self % ig_properties(dim+2+1:dim+2+self % ig_species % n) = self % ig_species % massf

      ! Turbulence
      start = dim + 2 + self%ig_species%n
      if     (nrans==1) then
        self%ig_properties(start+1) = mit

      elseif (nrans==2) then
        self%ig_properties(start+1) = kappa
        self%ig_properties(start+2) = omega

      elseif (nrans==7) then
        self%ig_properties(start+1:start+3) = rhoRij
        self%ig_properties(start+4:start+6) = 1d-8
        self%ig_properties(start+7) = omega

      endif

    endif

  contains

    subroutine standard()
      implicit none

      ! Inflow | p0, T0
      if     (p0/=0_R8     .and. T0/=0_R8 .and. p==0._R8 .and. self%definition=='inlet') then
        self % ig_id = 401
        dim = 3
        call setup_bc_inlet(ip0=2)
        self % ig_properties(1:2) = [T0, p0]

      ! Inflow | p0(t), T0
      elseif (p0_time_file/='none' .and. self%definition=='inlet') then
        self % ig_id = 402
        self % time_varying = .true.
        dim = 3
        call setup_bc_inlet(ip0=1)
        self % ig_properties(2) = T0

      ! Subsonic inflow | g, T0
      elseif ( g/=0_R8     .and. T0/=0_R8 .and. self%definition=='inlet') then
        self % ig_id = 403
        dim = 3
        call setup_bc_inlet(ip0=0)
        self % ig_properties(1:2) = [T0, g]

      ! Subsonic inflow | g, T
      elseif ( g/=0_R8     .and.  T/=0_R8 .and. self%definition=='inlet') then
        self % ig_id = 404
        dim = 3
        call setup_bc_inlet(ip0=0)
        self % ig_properties(1:2) = [T, g]

      ! Supersonic inflow | M, p0, T0
      elseif ( mach/=0._R8 .and. p0/=0_R8 .and. T0/=0._R8 .and. self%definition=='inlet') then
        self % ig_id = 405
        dim = 4
        call setup_bc_inlet(ip0=0)
        T = T02T(T0,mach,self%ig_species)
        p = p02p(p0,mach,T,self%ig_species)
        self % ig_properties(1:3) = [mach, T, p]

      ! Supersonic inflow | M, p, T
      elseif ( mach/=0._R8 .and.  p/=0_R8 .and. T/=0._R8 .and. self%definition=='inlet') then
        self % ig_id = 405
        dim = 4
        call setup_bc_inlet(ip0=0)
        self % ig_properties(1:3) = [mach, T, p]

      ! Pressure outflow | p
      elseif (self%definition=='outlet') then
        self % ig_id = 406
        dim = 1
        call setup_bc_outlet(ip=1)
        self % ig_properties(1) = p
        return

      ! Inflow/outflow | p0, T0, p
      elseif (p0/=0_R8     .and. T0/=0_R8 .and. p/=0._R8 .and. self%definition=='inlet') then
        self % ig_id = 407
        dim = 4
        call setup_bc_inlet(ip0=2)
        self % ig_properties(1:3) = [T0, p0, p]

      ! Full state specification with time-varying properties
      elseif ( time_file/='none') then
        self % ig_id = 410
        self % ig_n = 2
        self % time_varying = .true.
        allocate(self % ig_properties(1:self % ig_n))
        allocate(self % ig_time(1:self % ig_n))
        allocate(self % ig_time_file(1:self % ig_n))
        self % ig_properties = 0.0_R8
        self % IG_time = .true.
        self % IG_time_file(1) = time_file
        self % IG_time_file(2) = 'one-shot'
        if (periodic) self % IG_time_file(2) = 'periodic'
      
      else
        write(*,*) '[ERROR] insufficient or inconsistent inflow properties specified.'
        write(*,*) '        Please check input file and documentation.'
        stop

      endif

      
      if (self%definition=='inlet') then
        ! Inflow direction
        self%ig_properties(dim) = alpha
        self%ig_properties(dim+1) = beta
        ! Relaxation factor
        self%ig_properties(dim+2) = rel_fac
      else
        ! Relaxation factor
        self%ig_properties(dim+1) = rel_fac
      endif

    end subroutine standard

    
    subroutine setup_bc_inlet(ip0)
      implicit none
      integer, intent(in) :: ip0
      
      self % ig_n = dim + 2 + self % ig_species % n + nrans
      allocate(self % ig_properties(1:self % ig_n))
      allocate(self % ig_time(1:self % ig_n))
      allocate(self % ig_time_file(1:self % ig_n))
      self % ig_properties = 0.0_R8
      self % IG_time = .false.
      self % IG_time_file = 'none'
      if (self % time_varying) then
        self % IG_time(ip0) = .true.
        self % IG_time_file(ip0) = p0_time_file
      endif

    end subroutine setup_bc_inlet


    subroutine setup_bc_outlet(ip)
      implicit none
      integer, intent(in) :: ip
      
      self % ig_n = 2
      allocate(self % ig_properties(1:self % ig_n))
      allocate(self % ig_time(1:self % ig_n))
      allocate(self % ig_time_file(1:self % ig_n))
      self % ig_properties = 0.0_R8
      self % IG_time = .false.
      self % IG_time_file = 'none'
      if (self % time_varying) then
        self % IG_time(ip) = .true.
        self % IG_time_file(ip) = p_time_file
      endif

    end subroutine setup_bc_outlet


    subroutine nozzle
      use area_law,     only: legge_aree, Runi
      implicit none
      real(R8) :: Gamma_V, M_sup, M_sub
      real(R8) :: cp, gam, Rgas
      

      if (Ae_At/=0._R8) then

        if (Ae_At < 1.0d0) then
          write(*,*) '[ERROR] Ae_At must be >= 1.0'
          stop
        endif

        ! Compute gas properties from species composition
        Rgas = sum(Runi * self%ig_species%massf / self%ig_species%w)
        cp = sum(self%ig_species%massf * self%ig_species%cp(:, nint(T0)))
        gam = cp / (cp - Rgas)

        if (Ae_At > 1.0d0) then
          call legge_aree(Ae_At, 0.5d0, M_sub, 1.0d0, gam)
          call legge_aree(Ae_At, 2.0d0, M_sup, 1.0d0, gam)
        else
          M_sub = 1.0d0
          M_sup = 1.0d0
        endif

        psub = p0 * (1.0d0 + 0.5d0*(gam-1.0d0)*M_sub**2)**(-gam/(gam-1.0d0)) / 1.0d5
        psup = p0 * (1.0d0 + 0.5d0*(gam-1.0d0)*M_sup**2)**(-gam/(gam-1.0d0)) / 1.0d5

        Gamma_v = sqrt(gam) * (2.0d0/(gam+1.0d0))**((gam+1.0d0)/(2.0d0*(gam-1.0d0)))
        rt = p0 * Gamma_v / sqrt(Rgas * T0) / Ae_At

      else

        if (psub==0._R8) then
          write(*,*) '[ERROR] psub is necessary when rt assigned'
          stop
        endif
        if (psup==0._R8) then
          write(*,*) '[ERROR] psup is necessary when rt assigned'
          stop
        endif

      endif

      self%ig_id = 420
      dim = 5
      self % ig_n = dim + 2 + self % ig_species % n + nrans
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_properties(2:6) = [T0, p0, psub, psup, rt]

    end subroutine nozzle

  end procedure build_inflow_outflow_ig


  ! Compute T starting from h
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


      ! if (present(SRMswitch)) then
      !   m = size(self_properties)
      !   self_properties(m-2) = (csAl*sum(self_cp_properties(m,1:npCP,2)*(volRatio*T0-Tsat))+ sum((1d0-self_cp_properties(m,1:npCP,2)*volRatio))*self_properties(m-2)- sum(self_cp_properties(m,1:npCP,2)*(1d0-volRatio))*Qal)/(1d0-sum(self_cp_properties(m,1:npCP,2)))
      !   if (all(self_cp_properties(:,:,1)==0.d0)) then
      !     krho = sum( self_cp_properties(:,:,2) )
      !   else
      !     write(*,*) 'ERROR: you should not fix the condensed-phase mass flux when using the SRM grain BC (14)'
      !     stop
      !   endif
      !   self_properties(m-6) = self_properties(m-6)*(1.d0-krho)
      ! endif

end submodule ig_inflow_outflow_mod
