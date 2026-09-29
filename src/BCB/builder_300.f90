submodule (bc_mod) bc_wall_mod
  use bcb_config_mod, only: bcb_wall_fluid_config_t, bcb_wall_solid_config_t, &
                            load_bcb_wall_fluid_config, load_bcb_wall_solid_config

  implicit none

contains

  module procedure build_wall_fluid
    implicit none
    type(bcb_wall_fluid_config_t) :: cfg
    character(len=:), allocatable :: option_pairs(:), key
    integer :: nsel

    self % ig_species % n = 0

    call load_bcb_wall_fluid_config(sourceini, section, cfg)

    ! WARNING only: a wall given more than one of q, T, qrad falls to the Eulerian-symmetry
    ! record below (the thermal condition is lost); a key of another family on a wall section (p0,
    ! T0, g, mach, ...) has no field in a 3xx record and is ignored.
    nsel = count([cfg%has_q, cfg%has_T, cfg%has_qrad])
    if (nsel > 1) then
      write(*,'(A)') '[WARNING] section ['//trim(self%name)//'] (wall): more than one of q, T, qrad is given, the wall is'// &
                     ' written as BC 300 (Eulerian symmetry, no thermal condition): keep one of them'
    endif
    do while (sourceini%loop(section_name=section, option_pairs=option_pairs))
      key = trim(option_pairs(1))
      if (.not. inlet_family_key(key)) cycle
      write(*,'(A)') '[WARNING] key '//key//' of section ['//trim(self%name)//']: not honoured by a wall (BC 300-302),'// &
                     ' the record carries q or T, ks, eps only: the key is ignored'
    enddo

    ! Heat flux, roughness (if 0, smooth wall), and emissivity
    if (cfg%has_q .and. .not. cfg%has_T .and. .not. cfg%has_qrad) then
      self % ig_id = 301
      self % ig_n = 3
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_properties(1:3) = [cfg%q, cfg%ks, cfg%eps]
    
    ! Temperature, roughness (if 0, smooth wall), and emissivity
    elseif (cfg%has_T .and. .not. cfg%has_q .and. .not. cfg%has_qrad) then
      self % ig_id = 302
      self % ig_n = 3
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_properties(1:3) = [cfg%T, cfg%ks, cfg%eps]

    ! Eulerian symmetry
    else
      self % ig_n = 0
      self % ig_id = 300

    endif

  contains
    !> A key of the inlet/outlet family (the 4xx records): state, direction, composition, turbulence
    !> and the time series; the per-face ini also carries internal keys, which are not reported.
    logical function inlet_family_key(key)
      implicit none
      character(len=*), intent(in) :: key
      inlet_family_key = any(key == [character(len=14) :: 'p0', 'T0', 'h0', 'g', 'mach', 'p', 'un', 'alpha', 'beta', 'rf', &
                             'time-file', 'line-file', 'p0-time-file', 'p-time-file', 'periodic', 'Ae_At', 'psub', 'psup', &
                             'a1-a3', 'mit', 'kappa', 'omega', 'rhoRij', 'nrans', 'eq-OG', 'eq-CEA-file', 'eq-CEA-section', &
                             'u', 'v', 'w'])
      if (.not. inlet_family_key .and. len(key) > 1) inlet_family_key = key(1:1) == 'y'
    end function inlet_family_key
  end procedure build_wall_fluid


  module procedure build_wall_solid
    implicit none
    type(bcb_wall_solid_config_t) :: cfg
    character(len=:), allocatable :: given

    call load_bcb_wall_solid_config(sourceini, section, cfg)

    ! Heat flux
    if (cfg%has_q .and. .not. cfg%has_T .and. .not. cfg%has_qrad) then
      self % sp_n = 1
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 301
      self % sp_properties(1) = cfg%q
    
    elseif (cfg%has_q_timefile .and. .not. cfg%has_T .and. .not. cfg%has_qrad) then
      self % sp_n = 1
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))
      self % sp_id = 301
      allocate(self % sp_time(1:self % sp_n))
      allocate(self % sp_time_file(1:self % sp_n))
      self % sp_properties(1) = 0.0_R8
      self % sp_time(1) = .true.
      self % sp_time_file(1) = cfg%q_timefile

    ! Temperature
    elseif (cfg%has_T .and. .not. cfg%has_q .and. .not. cfg%has_qrad) then
      self % sp_n = 1
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 302
      self % sp_properties(1) = cfg%T

    elseif (cfg%has_T_timefile .and. .not. cfg%has_q .and. .not. cfg%has_qrad) then
      self % sp_n = 1
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))
      self % sp_id = 302
      allocate(self % sp_time(1:self % sp_n))
      allocate(self % sp_time_file(1:self % sp_n))
      self % sp_properties(1) = 0.0_R8
      self % sp_time(1) = .true.
      self % sp_time_file(1) = cfg%T_timefile

    ! Convection coefficient, reference temperature, and radiative heat flux
    elseif (cfg%has_hconv .and. cfg%has_qrad .and. cfg%has_Tref) then
      self % sp_n = 3
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 303
      self % sp_properties(1:3) = [cfg%hconv, cfg%qrad, cfg%Tref]

    ! Radiative heat flux
    elseif (cfg%has_eps .and. cfg%has_Tref .and. .not. cfg%has_hconv) then
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

    ! No record matches the keys (q and T together, a key without its partners, none of them): the faces
    ! keep BC id 0, as upstream writes them; WARNING only, like the fluid wall with more than one of q, T, qrad
    else
      given = ''
      if (cfg%has_q)          given = given//', q'
      if (cfg%has_q_timefile) given = given//', q-time-file'
      if (cfg%has_T)          given = given//', T'
      if (cfg%has_T_timefile) given = given//', T-time-file'
      if (cfg%has_qrad)       given = given//', qrad'
      if (cfg%has_hconv)      given = given//', hconv'
      if (cfg%has_eps)        given = given//', eps'
      if (cfg%has_Tref)       given = given//', Tref'
      if (len(given) == 0) given = ', none of them'
      write(*,'(A)') '[WARNING] section ['//trim(self%name)//'] (solid wall): the keys given ('//given(3:)//') select none of'// &
                     ' the records 301 (q), 302 (T), 303 (hconv, qrad, Tref), 304 (eps, Tref), 305 (hconv, eps, Tref):'// &
                     ' its faces are written with BC id 0 (no wall condition)'
    endif

  end procedure build_wall_solid

end submodule bc_wall_mod
