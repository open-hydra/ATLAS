!! TODO: dispersed-phase bc for srm + adapt ideal gas bc to handle multiphase cases (e.g., mass fractions of condensed species, etc.)

submodule (bc_mod) special_bc_mod
  use bcb_config_mod, only: bcb_gsi_fluid_config_t, load_bcb_gsi_fluid_config, &
                            bcb_manifold_config_t, load_bcb_manifold_config
  use phase_mod, only: phase_t, species_t, define_composition
  implicit none

contains

  module procedure build_manifold
    implicit none
    type(bcb_manifold_config_t) :: cfg

    self%gp_id = 501
    call load_bcb_manifold_config(sourceini, section, cfg)

    self % ig_n = 2
    allocate(self % ig_properties(1:self % ig_n))
    allocate(self % ig_time(1:self % ig_n))
    self % ig_properties = 0.0_R8
    self % IG_time = .false.
    self%ig_properties = [cfg%block, cfg%face]

  end procedure build_manifold


  module procedure build_gsi_ig
    implicit none
    type(bcb_gsi_fluid_config_t) :: cfg
    real(R8) :: CEAT0, CEAp0

    call load_bcb_gsi_fluid_config(sourceini, section, cfg)

    ! GSI - Melting | cp, Tm, Ti, dh, qrad, epsilon, and species mass fractions
    if (cfg%has_cp .and. cfg%has_dh .and. cfg%has_T .and. cfg%has_qrad) then
      self % ig_id = 503
      self % ig_species = phase % species
      if (.not.allocated(self % ig_species % massf)) allocate(self % ig_species % massf(1:self % ig_species % n))
      self % ig_species % massf = 1d-20
      self % ig_n = 6 + self % ig_species % n
      allocate(self % ig_properties(1:self % ig_n))
      CEAT0 = 0.0_R8; CEAp0 = 0.0_R8
      call define_composition(sourceini, self%ig_species, CEAT0, CEAp0)
      self % ig_properties(1:6) = [cfg%cp, cfg%T, cfg%Ti, cfg%dh, cfg%qrad, cfg%eps]
      self % ig_properties(7:self % ig_n) = self % ig_species % massf

    ! GSI - Pyrolysis | pyrolysis model, qrad, ks, epsilon, and species mass fractions
    elseif (cfg%pyrolysis_model /= 'none' .and. cfg%has_qrad .and. cfg%surface_reactions_model == 'none') then
      self % ig_id = 504
      self % ig_species = phase % species
      if (.not.allocated(self % ig_species % massf)) allocate(self % ig_species % massf(1:self % ig_species % n))
      self % ig_species % massf = 1d-20
      self % ig_n = 3 + self % ig_species % n
      allocate(self % ig_properties(1:self % ig_n))
      CEAT0 = 0.0_R8; CEAp0 = 0.0_R8
      call define_composition(sourceini, self%ig_species, CEAT0, CEAp0)
      self % ig_properties(1:3) = [pyrolysis_model_name2value(cfg%pyrolysis_model), cfg%qrad, cfg%eps]
      self % ig_properties(4:self % ig_n) = self % ig_species % massf

    ! GSI - Surface reactions | reactions name, qrad, epsilon
    elseif (cfg%surface_reactions_model /= 'none' .and. cfg%has_qrad .and. cfg%pyrolysis_model == 'none') then
      self % ig_id = 505
      self % ig_n = 3
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_properties(1:3) = [surface_model_name2value(cfg%surface_reactions_model), cfg%qrad, cfg%eps]

    ! GSI - Pyrolysis + Surface reactions | pyrolysis model, reactions name, qrad, epsilon, and species mass fractions
    elseif (cfg%pyrolysis_model /= 'none' .and. cfg%surface_reactions_model /= 'none' .and. cfg%has_qrad) then
      self % ig_id = 506
      self % ig_species = phase % species
      if (.not.allocated(self % ig_species % massf)) allocate(self % ig_species % massf(1:self % ig_species % n))
      self % ig_species % massf = 1d-20
      self % ig_n = 4 + self % ig_species % n
      allocate(self % ig_properties(1:self % ig_n))
      CEAT0 = 0.0_R8; CEAp0 = 0.0_R8
      call define_composition(sourceini, self%ig_species, CEAT0, CEAp0)
      self % ig_properties(1:4) = [pyrolysis_model_name2value(cfg%pyrolysis_model), surface_model_name2value(cfg%surface_reactions_model), cfg%qrad, cfg%eps]
      self % ig_properties(5:self % ig_n) = self % ig_species % massf

    else
      ! GSI - Solid propellant (deferred subroutine to build ig_properties)
      call build_srm_ig()

    endif

  
  contains


    subroutine build_srm_ig
      implicit none
      real(R8) :: mit, kappa, omega, rhoRij
      real(R8) :: T0, a_srm, n_srm, pRef_srm, rhoGrain_srm, SFgeo_srm
      integer  :: dim, start, nrans

      self%ig_id = 502

      dim = 6

      self % ig_species = phase % species
      if (.not.allocated(self % ig_species % massf)) allocate(self % ig_species % massf(1:self % ig_species % n))
      self % ig_species % massf = 1d-20

      mit = cfg%turbulence%mit
      kappa = cfg%turbulence%kappa
      omega = cfg%turbulence%omega
      rhoRij = cfg%turbulence%rhoRij
      nrans = cfg%turbulence%nrans

      a_srm = cfg%a
      n_srm = cfg%n
      pRef_srm = cfg%pRef
      rhoGrain_srm = cfg%rhoGrain
      SFgeo_srm = cfg%SF

      self % ig_n = dim + self % ig_species % n + nrans
      allocate(self % ig_properties(1:self % ig_n))
      allocate(self % ig_time(1:self % ig_n))
      self % ig_properties = 0.0_R8
      self % IG_time = .false.

      ! Assign species mass fractions
      call define_composition(sourceini, self%ig_species, CEAT0, CEAp0)
      T0 = CEAT0

      ! Property layout:
      !   [1]      Taf        - adiabatic flame temperature [K]
      !   [2]      a          - burn rate pre-exponential coefficient
      !   [3]      n          - burn rate pressure exponent
      !   [4]      pRef       - reference pressure [Pa]
      !   [5]      rhoGrain   - grain density [kg/m3]
      !   [6]      SF         - scale factor (default 1)
      !   [7..6+ns]           - species mass fractions
      !   following           - turbulence variables

      if (n_srm == 0._R8) then
        write(*,*) '[ERROR] Burn rate exponent n required for SRM grain BC.'
        stop
      endif
      if (rhoGrain_srm == 0._R8) then
        write(*,*) '[ERROR] Grain density rhoGrain required for SRM grain BC.'
        stop
      endif

      self%ig_properties(1) = T0            ! Taf: adiabatic flame temperature
      self%ig_properties(2) = a_srm         ! burn rate coefficient
      self%ig_properties(3) = n_srm         ! burn rate pressure exponent
      self%ig_properties(4) = pRef_srm      ! reference pressure [Pa]
      self%ig_properties(5) = rhoGrain_srm  ! grain density [kg/m3]
      self%ig_properties(6) = SFgeo_srm     ! geometric safety factor

      ! Mass fractions
      self % ig_properties(dim+1:dim+self % ig_species % n) = self % ig_species % massf

      ! Turbulence
      start = dim + self%ig_species%n
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

    end subroutine build_srm_ig

  end procedure build_gsi_ig



  function surface_model_name2value (name) result(value)
    implicit none
    character(len=*), intent(in) :: name
    real(R8) :: value

    select case (trim(adjustl(name)))
      case ('bradley')     ; value = 1_R8
      case default
        write(*,*) '[ERROR] Unknown surface reaction model name: ', trim(adjustl(name))
        write(*,*) '        Available options: bradley'
        stop
    end select

  end function surface_model_name2value

  function pyrolysis_model_name2value (name) result(value)
    implicit none
    character(len=*), intent(in) :: name
    real(R8) :: value

    select case (trim(adjustl(name)))
      case ('HTPB')     ; value = 1_R8
      case ('HDPB')     ; value = 2_R8
      case ('PP')       ; value = 3_R8
      case default
        write(*,*) '[ERROR] Unknown pyrolysis model name: ', trim(adjustl(name))
        write(*,*) '        Available options: HTPB'
        write(*,*) '                           HDPB'
        write(*,*) '                           PP'
        stop
    end select

  end function pyrolysis_model_name2value

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

end submodule special_bc_mod
