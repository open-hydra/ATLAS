!! TODO: dispersed-phase bc for srm + adapt ideal gas bc to handle multiphase cases (e.g., mass fractions of condensed species, etc.)

submodule (bc_mod) special_bc_mod
  use bcb_config_mod, only: bcb_gsi_fluid_config_t, load_bcb_gsi_fluid_config, &
                            bcb_manifold_config_t, load_bcb_manifold_config, gsi_variant, dp_inlet_key_given, &
                            check_gsi_keys
  use input_keys_mod, only: input_keys_strict
  use phase_mod, only: phase_t, species_t, define_composition
  use composition_check_mod, only: check_composition
  implicit none
  character(len=20), allocatable, save :: warned_502(:)   ! sections already given the Taf WARNING
  ! inlet keys of a dispersed phase on a manifold or a non-grain gsi face, under strict-keys = false: one
  ! WARNING per (section, key), the builder runs once per face cell
  character(len=200), allocatable, save :: warned_dp_keys(:)
  ! BC 506: the <phase>-pyrolysis.dat last read and its table names in file order (pyrolysis_table_id; the builder
  ! runs once per face cell)
  character(len=:), allocatable, save :: pyro_file
  character(len=64), allocatable, save :: pyro_tables(:)

contains

  module procedure build_manifold
    implicit none
    type(bcb_manifold_config_t) :: cfg

    self%gp_id = 501
    call load_bcb_manifold_config(sourceini, section, cfg)
    ! Q2D (the only reader of the x,y deck format) refuses BC 501 at its pre-scan: refused here (same meshType gate as 408/410/421)
    call refuse_on_2d_mesh(self, 501, 'manifold', 'use 101 or 401-407')

    self % ig_n = 2
    allocate(self % ig_properties(1:self % ig_n))
    allocate(self % ig_time(1:self % ig_n))
    allocate(self % ig_time_file(1:self % ig_n))   ! copied by broadcast_uniform_bc whenever ig_time is
    self % ig_properties = 0.0_R8
    self % IG_time = .false.
    self % IG_time_file = 'none'
    self%ig_properties = [cfg%block, cfg%face]

  end procedure build_manifold


  module procedure build_gsi_ig
    implicit none
    type(bcb_gsi_fluid_config_t) :: cfg
    real(R8) :: CEAT0, CEAp0

    call load_bcb_gsi_fluid_config(sourceini, section, cfg)
    call check_gsi_keys(cfg, self%name)

    select case (gsi_variant(cfg))

    ! GSI - Melting | cp, Tm, Ti, dh, qrad, epsilon, and species mass fractions
    case (503)
      self % ig_id = 503
      self % ig_species = phase % species
      if (.not.allocated(self % ig_species % massf)) allocate(self % ig_species % massf(1:self % ig_species % n))
      self % ig_species % massf = 1d-20
      self % ig_n = 6 + self % ig_species % n
      allocate(self % ig_properties(1:self % ig_n))
      CEAT0 = 0.0_R8; CEAp0 = 0.0_R8
      call define_composition(sourceini, self%ig_species, CEAT0, CEAp0)
      call check_composition(sourceini, section, self%ig_species, 'section ['//trim(self%name)//']')   ! composition-sum check on every gsi record
      self % ig_properties(1:6) = [cfg%cp, cfg%T, cfg%Ti, cfg%dh, cfg%qrad, cfg%eps]
      self % ig_properties(7:self % ig_n) = self % ig_species % massf

    ! GSI - Pyrolysis | pyrolysis model, qrad, ks, epsilon, and species mass fractions
    case (504)
      self % ig_id = 504
      self % ig_species = phase % species
      if (.not.allocated(self % ig_species % massf)) allocate(self % ig_species % massf(1:self % ig_species % n))
      self % ig_species % massf = 1d-20
      self % ig_n = 3 + self % ig_species % n
      allocate(self % ig_properties(1:self % ig_n))
      CEAT0 = 0.0_R8; CEAp0 = 0.0_R8
      call define_composition(sourceini, self%ig_species, CEAT0, CEAp0)
      call check_composition(sourceini, section, self%ig_species, 'section ['//trim(self%name)//']')   ! composition-sum check on every gsi record
      self % ig_properties(1:3) = [pyrolysis_model_name2value(cfg%pyrolysis_model), cfg%qrad, cfg%eps]
      self % ig_properties(4:self % ig_n) = self % ig_species % massf

    ! GSI - Surface reactions | reactions name, qrad, epsilon
    case (505)
      self % ig_id = 505
      self % ig_n = 3
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_properties(1:3) = [surface_model_name2value(cfg%surface_reactions_model), cfg%qrad, cfg%eps]

    ! GSI - Pyrolysing ablator | pyrolysis-gas table id, surface-reactions model, phi, hv0, qrad, epsilon; no mass
    ! fractions: the solver takes the char products from the surface model and the pyrolysis gas from the table
    case (506)
      self % ig_id = 506
      if (.not. cfg % has_phi) call missing_506_key('phi')
      if (.not. cfg % has_hv0) call missing_506_key('hv0')
      self % ig_n = 6
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_properties(1:6) = [real(pyrolysis_table_id(phase, cfg % pyrolysis_gas, self % name), R8), &
                                   surface_model_name2value(cfg % surface_reactions_model), cfg % phi, cfg % hv0, &
                                   cfg % qrad, cfg % eps]

    case default
      ! GSI - Solid propellant (deferred subroutine to build ig_properties)
      call build_srm_ig()

    end select

  
  contains

    !> phi and hv0 of a 506 cell: the constant of the section or the value a phi-file/hv0-file gives the cell. A cell
    !> that the file's range does not reach, before any cell it reaches, has neither (build_face adds the key only
    !> inside the range).
    subroutine missing_506_key(key)
      implicit none
      character(*), intent(in) :: key
      write(*,'(A)') '[ERROR] section ['//trim(self % name)//'] (gsi, BC 506): no '//key//' for a cell: give '//key// &
        ' or a '//key//'-file whose range covers the face'
      stop 1
    end subroutine missing_506_key


    subroutine build_srm_ig
      use grid_mod, only: mesh_cfg, MESH_PURE_2D
      implicit none
      real(R8) :: nuTilde, k, omega, Rij
      real(R8) :: T0, a_srm, n_srm, pRef_srm, rhoGrain_srm, SFgeo_srm, mode
      integer  :: dim, start, nrans

      self%ig_id = 502

      dim = 5

      self % ig_species = phase % species
      if (.not.allocated(self % ig_species % massf)) allocate(self % ig_species % massf(1:self % ig_species % n))
      self % ig_species % massf = 1d-20

      nuTilde = cfg%turbulence%nuTilde
      k = cfg%turbulence%k
      omega = cfg%turbulence%omega
      Rij = cfg%turbulence%Rij
      nrans = cfg%turbulence%nrans

      a_srm = cfg%a
      n_srm = cfg%n
      pRef_srm = cfg%pRef
      rhoGrain_srm = cfg%rhoGrain
      SFgeo_srm = cfg%SF

      ! a: required, the key a or an a-file (builder_face gives the cell the value of the file as the key a). A grain
      ! without it was written with a = 0, a surface that does not burn, in silence; a = 0 given stays that surface
      if (.not. cfg%has_a) then
        write(*,'(A)') '[ERROR] section ['//trim(self%name)//'] (gsi, BC 502): no burn rate coefficient a (the key a '// &
          'or an a-file); a = 0 is a surface that does not burn (grain-wall = T)'
        stop 1
      endif

      ! grain-wall: how the solver applies the grain, the mode of the record. F, the default: an inlet of the solver
      ! (mode 2), with the turbulence variables of the section as the inlets 401-404; T: a wall that blows the products
      ! in (mode 1), none (the solver sets the wall values)
      if (cfg%grain_wall) then
        mode = 1.0_R8
        nrans = 0
      else
        mode = 2.0_R8
        ! the 5 bands of an inflow of Q2D, the reader of the 2D meshes (x,y file), as BC 401-404 (build_400ig):
        ! R11 R22 R33 R12 omega
        if (nrans == 7 .and. mesh_cfg%meshType == MESH_PURE_2D) nrans = 5
        if (.not. (a_srm > 0.0_R8)) then
          write(*,'(A)') '[ERROR] section ['//trim(self%name)//'] (gsi, BC 502): an inlet grain (grain-wall = F, the '// &
            'default) needs a burn rate a > 0 (an inflow with no mass flux; a surface that does not burn is grain-wall = T '// &
            'with a = 0)'
          stop 1
        endif
      endif

      self % ig_n = dim + self % ig_species % n + nrans
      allocate(self % ig_properties(1:self % ig_n))
      allocate(self % ig_time(1:self % ig_n))
      allocate(self % ig_time_file(1:self % ig_n))   ! copied by broadcast_uniform_bc whenever ig_time is
      self % ig_properties = 0.0_R8
      self % IG_time = .false.
      self % IG_time_file = 'none'

      ! Assign species mass fractions; pre-init so that a deck without eq-CEA-file writes a
      ! defined Taf
      CEAT0 = 0.0_R8; CEAp0 = 0.0_R8
      call define_composition(sourceini, self%ig_species, CEAT0, CEAp0)
      call check_composition(sourceini, section, self%ig_species, 'section ['//trim(self%name)//']')
      T0 = CEAT0
      if (T0 <= 0.0_R8 .and. first_warning(trim(self%name))) write(*,'(A)') '[WARNING] '//trim(self%name)// &
        ' (gsi, BC 502): no eq-CEA-file, the adiabatic flame temperature Taf is written as 0, which MOSE refuses'// &
        ' (the total temperature of the grain gas): give the section its eq-CEA-file'

      ! Property layout (MOSE: IO_BC, record 502):
      !   [1]      a*rhoGrain*SF - the propellant mass flux at pRef [kg/(m2 s)]: a the linear burn rate
      !                           coefficient [m/s] of r = a (p/pRef)^n; the solver takes the mass flux as it is
      !                           (MOSE: mdot = [1] (p/pRef)^n), times 1 - krho_tot with dispersed phases
      !                           (correct_grain_flux)
      !   [2]      n          - burn rate pressure exponent
      !   [3]      pRef       - reference pressure [Pa]
      !   [4]      Taf        - adiabatic flame temperature [K], of the eq-CEA-file: the solver takes it as the total
      !                           temperature of the products (MOSE: they enter with the total enthalpy h(Taf))
      !   [5]      mode       - 1 (grain-wall = T): a wall that blows the products in; 2 (F, the default): an inlet
      !   [6..5+ns]           - species mass fractions
      !   following           - with mode 2 only, the turbulence variables of the section

      if (n_srm == 0._R8) then
        write(*,*) '[ERROR] Burn rate exponent n required for SRM grain BC.'
        stop 1
      endif
      if (rhoGrain_srm == 0._R8) then
        write(*,*) '[ERROR] Grain density rhoGrain required for SRM grain BC.'
        stop 1
      endif

      self%ig_properties(1) = a_srm*rhoGrain_srm*SFgeo_srm   ! the propellant mass flux at pRef [kg/(m2 s)]
      self%ig_properties(2) = n_srm         ! burn rate pressure exponent
      self%ig_properties(3) = pRef_srm      ! reference pressure [Pa]
      self%ig_properties(4) = T0            ! Taf: adiabatic flame temperature
      self%ig_properties(5) = mode          ! 1 a wall that blows the products in, 2 an inlet

      ! Mass fractions
      self % ig_properties(dim+1:dim+self % ig_species % n) = self % ig_species % massf

      ! Turbulence (mode 2 only, nrans = 0 in mode 1): a zero band under a model is reported, as on the inlets 401-404
      start = dim + self%ig_species%n
      if     (nrans==1) then
        self%ig_properties(start+1) = nuTilde
        if (nuTilde <= 0._R8) &
          call warn_turbulence_zero(self, 'gsi, BC 502, inlet', 'nuTilde', 'Spalart-Allmaras (nrans = 1)', &
                                    'nuTilde')
      elseif (nrans==2) then
        self%ig_properties(start+1) = k
        self%ig_properties(start+2) = omega
        if (k <= 0._R8 .or. omega <= 0._R8) &
          call warn_turbulence_zero(self, 'gsi, BC 502, inlet', 'k or omega', 'k-omega (nrans = 2)', &
                                    'k and omega')
      elseif (nrans==7 .or. nrans==5) then
        ! 7 bands: R11 R22 R33 R12 R13 R23 omega; 5 bands (pure-2D mesh, mode 2): R11 R22 R33 R12 omega
        self%ig_properties(start+1:start+3) = Rij
        self%ig_properties(start+4:start+nrans-1) = 1d-8
        self%ig_properties(start+nrans) = omega
        if (Rij <= 0._R8 .or. omega <= 0._R8) &
          call warn_turbulence_zero(self, 'gsi, BC 502, inlet', 'Rij or omega', &
                                    'Reynolds-stress (nrans = 7)', 'Rij and omega')
      endif

    end subroutine build_srm_ig

  end procedure build_gsi_ig



  !> A face of the 500 family seen by the dispersed phase `phase`, in its slot k: a symmetry (300, no payload),
  !> since the phase neither follows a manifold nor takes part in a gas-surface interaction, except the
  !> solid-propellant grain (gsi, BC 502) of a section that gives the phase's inlet keys: that face injects the
  !> phase as an inlet does, from the same keys and defaults (build_inflow_outflow_dp), as a 401 record -- a fraction
  !> krho of the grain's flow, the gas keeping the rest (correct_grain_flux); a mass flux (402/403) is refused. The phase's inlet
  !> keys on any other face of the family are refused, or reported once with strict-keys = false (the face then
  !> a symmetry). A manifold keeps its 501 in the fluid's file; write_dp_bc prints the slot's 300 for the phase.
  module procedure build_special_dp
    implicit none
    type(bcb_gsi_fluid_config_t) :: cfg
    character(len=160) :: key
    character(len=12)  :: id_txt
    character(len=:), allocatable :: msg
    integer :: id

    if (trim(self % definition) == trim(MARKER_GSI)) then
      call load_bcb_gsi_fluid_config(sourceini, section, cfg)
      call check_gsi_keys(cfg, self % name)
      id = gsi_variant(cfg)
    else
      id = 501
    endif

    if (dp_inlet_key_given(sourceini, section, phase, key)) then
      if (id == 502) then
        call self % build_inflow_outflow_dp(k, sourceini, section, phase)
        ! The grain gives the phase a fraction of its flow, krho, and the gas the rest (correct_grain_flux): a
        ! mass flux (gp, BC 402/403) cannot be taken out of the burn-rate law, which the solver evaluates
        if (self % dp(k) % id /= 401) then
          write(id_txt,'(I0)') self % dp(k) % id
          write(*,'(A)') '[ERROR] key '//trim(prefix(phase))//'gp of section ['//trim(self % name)//']: not honoured by '// &
            'BC 502 (gsi): a solid-propellant grain injects the dispersed phase '//trim(phase % name)//' with '// &
            trim(prefix(phase))//'krho, a fraction of its flow (the gas takes the rest), not with a '// &
            'mass flux (BC '//trim(id_txt)//')'
          stop 1
        endif
        return
      endif
      write(id_txt,'(I0)') id
      msg = 'key '//trim(key)//' of section ['//trim(self % name)//']: not honoured by BC '//trim(id_txt)// &
            ' ('//trim(self % definition)//'): only the solid-propellant grain (gsi, BC 502) injects the dispersed'// &
            ' phase '//trim(phase % name)//', this face is a symmetry (300) for it'
      if (input_keys_strict()) then
        write(*,'(A)') '[ERROR] '//msg
        stop 1
      endif
      call warn_dp_key_once(trim(self % name)//'/'//trim(key), msg)
    endif

    ! A grain applied as an inlet (grain-wall = F, the default) is an inlet also for a phase it does not inject, as the other
    ! inlets are: a 401 record with krho 0, through which the solvers inject nothing of the phase (its particles leave
    ! the domain there, as at any inlet). A grain applied as a wall stays a symmetry (300) for that phase
    if (id == 502) then
      if (.not. cfg % grain_wall) then
        call self % build_inflow_outflow_dp(k, sourceini, section, phase)
        return
      endif
    endif

    self % dp(k) % id = 300
    self % dp(k) % n  = 0

  contains

    !> The prefix of the phase's keys: '<name>-', or none for an unnamed phase.
    function prefix(ph) result(pn)
      implicit none
      type(phase_t), intent(in) :: ph
      character(len=:), allocatable :: pn
      pn = ''
      if (len_trim(ph % name) > 0) pn = trim(adjustl(ph % name))//'-'
    end function prefix

    !> One [WARNING] per (section, key) tag.
    subroutine warn_dp_key_once(tag, text)
      implicit none
      character(len=*), intent(in) :: tag, text
      integer :: i
      if (.not. allocated(warned_dp_keys)) allocate(warned_dp_keys(0))
      do i = 1, size(warned_dp_keys)
        if (trim(warned_dp_keys(i)) == tag) return
      enddo
      warned_dp_keys = [character(len=200) :: warned_dp_keys, tag]
      write(*,'(A)') '[WARNING] '//text
    end subroutine warn_dp_key_once

  end procedure build_special_dp


  !> The gas flow of a solid-propellant grain (gsi, BC 502) that also injects dispersed phases: the propellant's
  !> flow is shared, the phases take krho_tot of it -- the sum of krho over every (material, population) pair of
  !> every dispersed phase entering through the cell (their 401 slots) -- and the gas the rest. The record's
  !> first field, a*rhoGrain*SF, the propellant mass flux at pRef and the only factor of the gas flow (MOSE:
  !> mdot = [1] (p/pRef)^n), is multiplied by 1 - krho_tot. Called once per face cell, after every phase of the
  !> block has been built on it.
  module procedure correct_grain_flux
    implicit none
    real(R8) :: krho_tot
    character(len=24) :: txt
    integer :: k

    if (self % ig_id /= 502 .or. .not. allocated(self % dp)) return
    krho_tot = 0.0_R8
    do k = 1, size(self % dp)
      if (self % dp(k) % id == 401) krho_tot = krho_tot + self % dp(k) % krho_sum
    enddo
    if (krho_tot == 0.0_R8) return
    if (.not. (krho_tot < 1.0_R8)) then
      write(txt,'(ES12.5)') krho_tot
      write(*,'(A)') '[ERROR] section ['//trim(self % name)//'] (gsi, BC 502): the dispersed phases entering the grain take '// &
        'krho = '//trim(adjustl(txt))//' of its flow, 1 or more: no gas is left (the gas takes 1 - krho of it)'
      stop 1
    endif
    self % ig_properties(1) = self % ig_properties(1) * (1.0_R8 - krho_tot)

  end procedure correct_grain_flux



  function surface_model_name2value (name) result(value)
    implicit none
    character(len=*), intent(in) :: name
    real(R8) :: value

    select case (trim(adjustl(name)))
      case ('bradley')     ; value = 1_R8
      case default
        write(*,*) '[ERROR] Unknown surface reaction model name: ', trim(adjustl(name))
        write(*,*) '        Available options: bradley'
        stop 1
    end select

  end function surface_model_name2value

  !> pyro_id of a 506 record: the position of the table *table* among the 'table <name>' lines of <phase>-pyrolysis.dat
  !> (written by GPB, one table per [GPB-Pyrolysis<n>] that names the phase; MOSE reads INPUT/<prefix>pyrolysis.dat
  !> and takes pyro_id as the 1-based index of its table blocks). The file is read from the case directory, else
  !> from fromATLAStoSolver/, once (the names are kept for the next cells). GPB writes full-line comments and one-word names
  !> only (DEC-3); a hand-edited 'table <name> # note' or a tab after 'table' is not read as FLINT reads it.
  integer function pyrolysis_table_id(phase, table, section) result(id)
    implicit none
    type(phase_t), intent(in) :: phase
    character(*),  intent(in) :: table, section
    character(len=:), allocatable :: prefix, path, names
    character(len=512) :: line
    logical :: found
    integer :: u, ios, i

    prefix = ''
    if (len_trim(phase % name) > 0) prefix = trim(adjustl(phase % name))//'-'
    path = prefix//'pyrolysis.dat'
    inquire(file=path, exist=found)
    if (.not. found) path = outpath//prefix//'pyrolysis.dat'
    if (.not. allocated(pyro_file)) pyro_file = ''
    if (pyro_file /= path) then
      open(newunit=u, file=path, status='old', action='read', iostat=ios)
      if (ios /= 0) then
        write(*,'(A)') '[ERROR] key pyrolysis-gas of section ['//trim(section)//']: '//prefix//'pyrolysis.dat is '// &
          'neither in the case directory nor in '//outpath//': run GPB with a [GPB-Pyrolysis<n>] named '//trim(table)
        stop 1
      endif
      if (allocated(pyro_tables)) deallocate(pyro_tables)
      allocate(pyro_tables(0))
      do
        read(u, '(A)', iostat=ios) line
        if (ios /= 0) exit
        line = adjustl(line)
        if (line(1:6) == 'table ') pyro_tables = [character(len=64) :: pyro_tables, adjustl(line(7:))]
      enddo
      close(u)
      pyro_file = path
    endif
    id = 0
    do i = 1, size(pyro_tables)
      if (trim(pyro_tables(i)) == trim(adjustl(table))) then
        id = i
        exit
      endif
    enddo
    if (id == 0) then
      names = ''
      do i = 1, size(pyro_tables)
        names = names//' '//trim(pyro_tables(i))
      enddo
      write(*,'(A)') '[ERROR] key pyrolysis-gas of section ['//trim(section)//']: no table '//trim(adjustl(table))// &
        ' in '//path//' (its tables:'//names//')'
      stop 1
    endif
  end function pyrolysis_table_id

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
        stop 1
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

  !> .true. the first time a section is named: the builder runs once per cell of a varying face.
  logical function first_warning(name)
    implicit none
    character(len=*), intent(in) :: name
    integer :: i
    if (.not. allocated(warned_502)) allocate(warned_502(0))
    first_warning = .false.
    do i = 1, size(warned_502)
      if (trim(warned_502(i)) == name) return
    enddo
    warned_502 = [character(len=20) :: warned_502, name]
    first_warning = .true.
  end function first_warning

end submodule special_bc_mod
