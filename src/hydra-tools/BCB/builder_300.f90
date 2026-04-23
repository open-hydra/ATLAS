submodule (bc_mod) bc_wall_mod
  use bcb_config_mod, only: bcb_wall_fluid_config_t, bcb_wall_solid_config_t, &
                            load_bcb_wall_fluid_config, load_bcb_wall_solid_config

  implicit none

contains

  module procedure build_wall_fluid
    implicit none
    type(bcb_wall_fluid_config_t) :: cfg

    self % ig_species % n = 0

    call load_bcb_wall_fluid_config(sourceini, section, cfg)

    ! Heat flux, roughness (if 0, smooth wall), and emissivity
    if (cfg%has_q .and. .not. cfg%has_T .and. .not. cfg%has_qrad) then
      self % ig_n = 3
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_id = 301
      self % ig_properties(1:3) = [cfg%q, cfg%ks, cfg%eps]
    
    ! Temperature, roughness (if 0, smooth wall), and emissivity
    elseif (cfg%has_T .and. .not. cfg%has_q .and. .not. cfg%has_qrad) then
      self % ig_n = 3
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_id = 302
      self % ig_properties(1:3) = [cfg%T, cfg%ks, cfg%eps]

    ! Temperature, radiative heat flux, and roughness (if 0, smooth wall)
    elseif (cfg%has_T .and. cfg%has_qrad .and. .not. cfg%has_q) then
      self % ig_n = 3
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_id = 303
      self % ig_properties(1:3) = [cfg%T, cfg%qrad, cfg%ks]

    ! Radiative heat flux, and roughness (if 0, smooth wall)
    elseif (cfg%has_qrad .and. .not. cfg%has_T .and. .not. cfg%has_q) then
      self % ig_n = 2
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_id = 304
      self % ig_properties(1:2) = [cfg%qrad, cfg%ks]

    ! Eulerian symmetry
    else
      self % ig_n = 0
      self % ig_id = 300

    endif

  end procedure build_wall_fluid


  module procedure build_wall_solid
    implicit none
    type(bcb_wall_solid_config_t) :: cfg

    call load_bcb_wall_solid_config(sourceini, section, cfg)

    ! Heat flux
    if (cfg%has_q .and. .not. cfg%has_T .and. .not. cfg%has_qrad) then
      self % sp_n = 1
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 301
      self % sp_properties(1) = cfg%q
    
    ! Temperature
    elseif (cfg%has_T .and. .not. cfg%has_q .and. .not. cfg%has_qrad) then
      self % sp_n = 1
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 302
      self % sp_properties(1) = cfg%T

    ! Convection coefficient, reference temperature, and radiative heat flux
    elseif (cfg%has_hconv .and. cfg%has_qrad .and. cfg%has_Tref) then
      self % sp_n = 3
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 303
      self % sp_properties(1:3) = [cfg%hconv, cfg%qrad, cfg%Tref]

    ! Radiative heat flux
    elseif (cfg%has_eps .and. cfg%has_Tref) then
      self % sp_n = 2
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 304
      self % sp_properties(1:2) = [cfg%eps, cfg%Tref]

    ! Convective and radiative heat flux
    elseif (cfg%has_hconv .and. cfg%has_eps .and. cfg%has_Tref .and. .not. cfg%has_qrad) then
      self % sp_n = 3
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 305
      self % sp_properties(1:3) = [cfg%hconv, cfg%eps, cfg%Tref]
    endif

  end procedure build_wall_solid

end submodule bc_wall_mod
