module phase_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use cea_param,       only : dp, empty_dp, get_data_search_dirs, &
                              gas_constant
  use cea_thermo,      only : ThermoDB, read_thermo
  use cea_input,       only : ProblemDB, read_input
  use cea_mixture,     only : Mixture
  use cea_equilibrium, only : EqSolver, EqSolution, EqPartials
  use cea_rocket,      only : RocketSolver, RocketSolution
  use cea_units,       only : convert_units_to_si
  implicit none

  real(8), parameter :: Runi = 8314.46261815324d0  !< Universal gas constant [J/(kmol·K)], exact SI 2019 (N_A k_B)

  type :: base_species_t
    integer :: n = 0
    real(R8), dimension(:), allocatable :: massf, molem
    character(len=20), dimension(:), allocatable :: name
  end type base_species_t

  type, extends(base_species_t) :: species_t
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

  type(ThermoDB), save :: atlas_cea_thermo
  logical, save        :: atlas_cea_thermo_loaded = .false.

contains

  subroutine define_composition(sini,species,T0,p0,h0)
    use finer, only: file_ini
    use strings, only: parse
    implicit none
    type(file_ini),  intent(in)            :: sini
    type(species_t), intent(inout)         :: species
    real(R8),        intent(inout)         :: T0, p0
    real(R8),        intent(inout), optional :: h0
    character(len=500)               :: CEAfile
    character(len=20)                :: name, str(2)
    character(len=:), allocatable    :: items(:,:), section_name(:), key
    integer :: i, j, error
    integer :: section_idx
    real(R8) :: ytot
    logical  :: eq_og

    species%massf = 1.d-20

    call sini%get_sections_list(section_name)
    eq_og = .false.
    section_idx = 1
    call sini%get(section_name=section_name(1), option_name='eq-OG', val=eq_og, error=error)
    call sini%get(section_name=section_name(1), option_name='eq-CEA-file',val=CEAfile,error=error)
    if (error==0) then
      call sini%get(section_name=section_name(1), option_name='eq-CEA-section', val=section_idx, error=error)
      call solve_cea_input(trim(CEAfile), section_idx, eq_og, T0, p0, h0, name_list=species%name, massf=species%massf)
      ytot = 0.0
      do j = 1, species%n
          if (index(species%name(j),'-')/=0) then
            call parse(species%name(j),'-',str)
            name = str(1)
          else
            name = species%name(j)
          endif
          if (trim(name) /= 'CEA-mixture') then
            ytot = ytot + species%massf(j)
          end if
      end do
      ! Look for mixture presence
      do j = 1, species%n
        if (species%name(j)=='CEA-mixture') then
          species%massf(j) = 1.0-ytot
        endif
      enddo
    endif
    ! Direct address of mass fractions: the key y<species> of a declared species, matched exactly
    ! (input_keys_mod, the single key validator, reports the y-keys of undeclared species; no
    ! substring stripping: 'yN2-file' is a profile key of the ICB builder, not the species 'N2-file').
    ! The value is read as one list-directed number: the former fixed-format read (D12.5) turned
    ! 'yN2 = 1' into 1e-5 and truncated values longer than 12 characters.
    call sini%get_items(items)
    if (allocated(items)) then
      do i = 1, size(items, dim=1)
        key = trim(adjustl(items(i,1)))
        if (len(key) < 2) cycle
        if (key(1:1) /= 'y') cycle
        do j = 1, species%n
          if (key(2:) == trim(adjustl(species%name(j)))) then
            species%massf(j) = read_massf(key, items(i,2))
            exit
          end if
        end do
      enddo
    endif

    if (species%n==1) species%massf(1) = 1.0

  contains

    !> The value of a y<species> key: one number in [0, 1]; anything else is an ERROR. This is the
    !> only check of the range (the key validator reads the value as a number and leaves the range here).
    !> A value outside [0, 1] by rounding only, at most YROUND (1.0000000000000002 left by a sum,
    !> -1e-20), is set exactly to the bound it passes.
    function read_massf(key, value) result(y)
      implicit none
      character(len=*), intent(in)  :: key, value
      real(R8)                      :: y
      character(len=:), allocatable :: token
      integer                       :: ios
      real(R8), parameter           :: YROUND = 1.0e-12_R8

      token = trim(adjustl(value))
      ios = 1
      y = 0.0_R8
      if (len(token) > 0) then
        if (scan(token, ' ,;/*') == 0) read(token, *, iostat=ios) y
      endif
      if (ios /= 0 .or. y /= y) then
        write(*,'(A)') '[ERROR] key '//key//' = '//token//': the mass fraction must be one number'
        stop 1
      endif
      if (y < 0.0_R8 .and. y >= -YROUND) y = 0.0_R8
      if (y > 1.0_R8 .and. y <= 1.0_R8 + YROUND) y = 1.0_R8
      if (y < 0.0_R8 .or. y > 1.0_R8) then
        write(*,'(A)') '[ERROR] key '//key//' = '//token//': the mass fraction must lie in [0, 1]'
        stop 1
      endif
    end function read_massf

  end subroutine define_composition


  subroutine ensure_cea_thermo_loaded()
    implicit none
    character(len=:), allocatable :: thermo_file
    character(len=:), allocatable :: search_dirs(:)
    character(len=:), allocatable :: candidate
    character(len=1024)           :: env_dir, exe_path, bin_dir, root_dir
    logical :: exists
    integer :: i, status, p

    if (atlas_cea_thermo_loaded) return

    exists = .false.
    call get_data_search_dirs(search_dirs)
    do i = 1, size(search_dirs)
      if (len_trim(search_dirs(i)) == 0 .or. trim(search_dirs(i)) == '.') then
        candidate = 'thermo.lib'
      else
        candidate = trim(search_dirs(i))//'/'//'thermo.lib'
      end if
      inquire(file=candidate, exist=exists)
      if (exists) then
        thermo_file = candidate
        exit
      end if
    end do

    if (.not. exists) then
      env_dir = ''
      call get_environment_variable('CEA_DATA_DIR', env_dir, status=status)
      if (status == 0 .and. len_trim(env_dir) > 0) then
        candidate = trim(env_dir)//'/thermo.lib'
        inquire(file=candidate, exist=exists)
        if (exists) thermo_file = candidate
      end if
    end if

    if (.not. exists) then
      env_dir = ''
      call get_environment_variable('ATLASDIR', env_dir, status=status)
      if (status == 0 .and. len_trim(env_dir) > 0) then
        candidate = trim(env_dir)//'/build/thermo.lib'
        inquire(file=candidate, exist=exists)
        if (exists) then
          thermo_file = candidate
        else
          candidate = trim(env_dir)//'/lib/cea/data/thermo.lib'
          inquire(file=candidate, exist=exists)
          if (exists) thermo_file = candidate
        end if
      end if
    end if

    if (.not. exists) then
      exe_path = ''
      call get_command_argument(0, exe_path)
      p = scan(trim(exe_path), '/', back=.true.)
      if (p > 1) then
        bin_dir = trim(exe_path(:p-1))
        p = scan(trim(bin_dir), '/', back=.true.)
        if (p > 1) then
          root_dir = trim(bin_dir(:p-1))
          candidate = trim(root_dir)//'/build/thermo.lib'
          inquire(file=candidate, exist=exists)
          if (exists) then
            thermo_file = candidate
          else
            candidate = trim(root_dir)//'/build-dev/thermo.lib'
            inquire(file=candidate, exist=exists)
            if (exists) then
              thermo_file = candidate
            else
              candidate = trim(root_dir)//'/lib/cea/data/thermo.lib'
              inquire(file=candidate, exist=exists)
              if (exists) thermo_file = candidate
            end if
          end if
        end if
      end if
    end if

    if (.not. exists) then
      write(*,*) '[ERROR] unable to locate thermo.lib for cea'
      stop 1
    end if

    atlas_cea_thermo = read_thermo(thermo_file)
    atlas_cea_thermo_loaded = .true.
  end subroutine ensure_cea_thermo_loaded


  subroutine solve_cea_input(filename, section_idx, gas_only, T0, p0, h0, name_list, massf)
    implicit none
    character(*), intent(in)        :: filename
    integer,      intent(in)        :: section_idx
    logical,      intent(in)        :: gas_only
    real(R8),     intent(out)       :: T0, p0
    real(R8),     intent(out), optional :: h0
    character(len=*), intent(in)    :: name_list(:)
    real(R8), intent(out)           :: massf(:)

    type(ProblemDB), allocatable :: problems(:)
    type(ProblemDB)              :: problem
    type(Mixture)                :: reactants, products
    type(EqSolver)               :: eq_solver
    type(EqSolution)             :: eq_solution
    type(EqPartials)             :: eq_partials
    type(RocketSolver)           :: rocket_solver
    type(RocketSolution)         :: rocket_solution
    real(dp), allocatable        :: weights(:)
    character(len=15), allocatable :: product_names(:)
    real(dp), allocatable        :: result_massf(:)
    character(len=15), allocatable :: result_names(:)
    real(dp), allocatable        :: pi_p(:), subar(:), supar(:)
    real(dp) :: state1, state2, hc, tc, tc_est, mdot, ac_at
    integer  :: n_frz
    logical  :: fac

    call ensure_cea_thermo_loaded()

    problems = read_input(filename)
    if (section_idx < 1 .or. section_idx > size(problems)) then
      write(*,*) '[ERROR] eq-CEA-section is out of range'
      stop 1
    end if
    problem = problems(section_idx)

    reactants = Mixture(atlas_cea_thermo, input_reactants=problem%reactants,ions=problem%problem%include_ions)
    call apply_reactant_thermo_overrides(problem, reactants)
    product_names = get_problem_products(problem, reactants)
    products = Mixture(atlas_cea_thermo, product_names, ions=problem%problem%include_ions)
    weights = get_problem_weights(problem, reactants, 1)

    select case (trim(problem%problem%type))
    case ('tp', 'hp', 'sp', 'tv', 'uv', 'sv')
      eq_solver = build_eq_solver(problem, products, reactants)
      eq_solution = EqSolution(eq_solver)
      state1 = get_state1(problem, reactants, weights, 1)
      state2 = get_state2(problem, 1)
      call eq_solver%solve(eq_solution, problem%problem%type, state1, state2, weights, eq_partials)
      T0 = real(eq_solution%T, R8)
      p0 = real(eq_solution%pressure * 1.0d5, R8)
      if (present(h0)) h0 = real(eq_solution%enthalpy * 1.0d3, R8)
      call extract_solution_products(products, eq_solution%mass_fractions, gas_only, result_names, result_massf)

    case ('rkt')
      rocket_solver = build_rocket_solver(problem, products, reactants)
      fac = problem%problem%rkt_finite_area
      n_frz = problem%problem%rkt_nfrozen
      tc_est = empty_dp
      mdot = empty_dp
      ac_at = empty_dp
      hc = empty_dp
      tc = empty_dp
      if (allocated(problem%problem%pcp_schedule)) pi_p = problem%problem%pcp_schedule%values
      if (allocated(problem%problem%subar_schedule)) subar = problem%problem%subar_schedule%values
      if (allocated(problem%problem%supar_schedule)) supar = problem%problem%supar_schedule%values
      if (allocated(problem%problem%mdot)) mdot = problem%problem%mdot
      if (allocated(problem%problem%ac_at)) ac_at = problem%problem%ac_at
      if (allocated(problem%problem%tc_est)) tc_est = problem%problem%tc_est
      if (allocated(problem%problem%h_schedule)) then
        hc = problem%problem%h_schedule%values(1)
      else if (allocated(problem%problem%t_schedule)) then
        tc = convert_units_to_si(problem%problem%t_schedule%values(1), problem%problem%t_schedule%units)
      else
        hc = compute_reactant_enthalpy(problem, reactants, weights)
      end if
      state2 = get_state2(problem, 1)
      rocket_solution = rocket_solver%solve(weights, state2, pi_p=pi_p, fac=fac, &
                                            subar=subar, supar=supar, mdot=mdot, &
                                            ac_at=ac_at, n_frz=n_frz, tc_est=tc_est, &
                                            hc=hc, tc=tc)
      T0 = real(rocket_solution%eq_soln(1)%T, R8)
      p0 = real(rocket_solution%pressure(1) * 1.0d5, R8)
      if (present(h0)) h0 = real(rocket_solution%eq_soln(1)%enthalpy * 1.0d3, R8)
      call extract_solution_products(products, rocket_solution%eq_soln(1)%mass_fractions, gas_only, result_names, result_massf)

    case default
      write(*,*) '[ERROR] Unsupported cea problem type in eq-CEA-file'
      stop 1
    end select

    call assign_species_massf(name_list, massf, result_names, result_massf)
  end subroutine solve_cea_input


  function build_eq_solver(problem, products, reactants) result(solver)
    implicit none
    type(ProblemDB), intent(in) :: problem
    type(Mixture), intent(in)   :: products, reactants
    type(EqSolver)              :: solver

    if (allocated(problem%output%trace)) then
      solver = EqSolver(products, reactants, trace=problem%output%trace, ions=problem%problem%include_ions, insert=problem%insert)
    else
      solver = EqSolver(products, reactants, ions=problem%problem%include_ions, insert=problem%insert)
    end if
  end function build_eq_solver


  function build_rocket_solver(problem, products, reactants) result(solver)
    implicit none
    type(ProblemDB), intent(in) :: problem
    type(Mixture), intent(in)   :: products, reactants
    type(RocketSolver)          :: solver

    if (allocated(problem%output%trace)) then
      solver = RocketSolver(products, reactants, trace=problem%output%trace, ions=problem%problem%include_ions, insert=problem%insert)
    else
      solver = RocketSolver(products, reactants, ions=problem%problem%include_ions, insert=problem%insert)
    end if
  end function build_rocket_solver


  function get_problem_products(problem, reactants) result(product_names)
    implicit none
    type(ProblemDB), intent(in) :: problem
    type(Mixture), intent(in)   :: reactants
    character(len=15), allocatable :: product_names(:)

    if (allocated(problem%only)) then
      allocate(product_names(size(problem%only)))
      product_names = problem%only
    else if (allocated(problem%omit)) then
      product_names = reactants%get_products(atlas_cea_thermo, problem%omit)
    else
      product_names = reactants%get_products(atlas_cea_thermo)
    end if
  end function get_problem_products


  subroutine extract_solution_products(products, source_massf, gas_only, names, massf)
    implicit none
    type(Mixture), intent(in)   :: products
    real(dp), intent(in)        :: source_massf(:)
    logical, intent(in)         :: gas_only
    character(len=15), allocatable, intent(out) :: names(:)
    real(dp), allocatable, intent(out) :: massf(:)
    real(dp) :: total

    if (gas_only) then
      names = pack(products%species_names, .not. products%is_condensed)
      massf = pack(source_massf, .not. products%is_condensed)
      total = sum(massf)
      if (total > 0.0_dp) massf = massf / total
    else
      names = products%species_names
      massf = source_massf
    end if
  end subroutine extract_solution_products


  subroutine assign_species_massf(target_names, target_massf, source_names, source_massf)
    use strings, only: parse
    implicit none
    character(len=*), intent(in) :: target_names(:)
    real(R8), intent(out)        :: target_massf(:)
    character(len=*), intent(in) :: source_names(:)
    real(dp), intent(in)         :: source_massf(:)
    character(len=20)            :: name, str(2)
    integer :: i, j

    target_massf = 0.0_R8
    do j = 1, size(target_names)
      if (index(target_names(j), '-') /= 0) then
        call parse(target_names(j), '-', str)
        name = str(1)
      else
        name = target_names(j)
      end if
      do i = 1, size(source_names)
        if (trim(source_names(i)) == trim(name)) then
          target_massf(j) = real(source_massf(i), R8)
          exit
        end if
      end do
    end do
  end subroutine assign_species_massf


  subroutine apply_reactant_thermo_overrides(problem, reactants)
    implicit none
    type(ProblemDB), intent(in)    :: problem
    type(Mixture), intent(inout)   :: reactants
    integer :: i
    real(dp) :: h_val

    do i = 1, min(size(problem%reactants), reactants%num_species)
      if (.not. allocated(problem%reactants(i)%enthalpy)) cycle
      h_val = convert_units_to_si(problem%reactants(i)%enthalpy%values(1), problem%reactants(i)%enthalpy%units)
      reactants%species(i)%enthalpy_ref = h_val
      reactants%species(i)%num_intervals = 0
      if (allocated(reactants%species(i)%T_fit)) deallocate(reactants%species(i)%T_fit)
      if (allocated(reactants%species(i)%fits)) deallocate(reactants%species(i)%fits)
    end do
  end subroutine apply_reactant_thermo_overrides


  function get_state1(problem, reactants, weights, idx) result(state1)
    implicit none
    type(ProblemDB), intent(in) :: problem
    type(Mixture), intent(in)   :: reactants
    real(dp), intent(in)        :: weights(:)
    integer, intent(in), optional :: idx
    real(dp) :: state1
    integer  :: idx_

    idx_ = 1
    if (present(idx)) idx_ = idx

    select case (trim(problem%problem%type))
    case ('tp', 'tv', 'det')
      state1 = convert_units_to_si(problem%problem%t_schedule%values(idx_), problem%problem%t_schedule%units)
    case ('hp')
      state1 = compute_reactant_enthalpy(problem, reactants, weights, idx_)
    case ('sp', 'sv')
      if (allocated(problem%problem%s_schedule)) then
        state1 = problem%problem%s_schedule%values(idx_)
      else
        write(*,*) '[ERROR] Entropy from reactants is not supported'
        stop 1
      end if
    case ('uv')
      if (allocated(problem%problem%u_schedule)) then
        state1 = problem%problem%u_schedule%values(idx_)
      else
        write(*,*) '[ERROR] Internal energy from reactants is not supported'
        stop 1
      end if
    case default
      state1 = 0.0_dp
    end select
  end function get_state1


  function get_state2(problem, idx) result(state2)
    implicit none
    type(ProblemDB), intent(in) :: problem
    integer, intent(in), optional :: idx
    real(dp) :: state2
    real(dp) :: val
    integer  :: idx_

    idx_ = 1
    if (present(idx)) idx_ = idx

    select case (trim(problem%problem%type))
    case ('tp', 'hp', 'sp', 'rkt')
      state2 = convert_units_to_si(problem%problem%p_schedule%values(idx_), problem%problem%p_schedule%units)
    case ('tv', 'uv', 'sv')
      select case (trim(problem%problem%v_schedule%units))
      case ('m**3/kg', 'cm**3/g', 'cc/g')
        state2 = convert_units_to_si(problem%problem%v_schedule%values(idx_), problem%problem%v_schedule%units)
      case ('kg/m**3', 'g/cm**3', 'g/cc')
        val = convert_units_to_si(problem%problem%v_schedule%values(idx_), problem%problem%v_schedule%units)
        state2 = 1.0_dp / val
      case default
        write(*,*) '[ERROR] Volume units not recognized in cea input'
        stop 1
      end select
    case default
      state2 = convert_units_to_si(problem%problem%p_schedule%values(idx_), problem%problem%p_schedule%units)
    end select
  end function get_state2


  function compute_reactant_enthalpy(problem, reactants, weights, idx) result(h0)
    implicit none
    type(ProblemDB), intent(in) :: problem
    type(Mixture), intent(in)   :: reactants
    real(dp), intent(in)        :: weights(:)
    integer, intent(in), optional :: idx
    real(dp) :: h0
    real(dp), allocatable :: reac_temps(:)
    integer :: i, idx_

    idx_ = 1
    if (present(idx)) idx_ = idx

    allocate(reac_temps(reactants%num_species))

    if (allocated(problem%problem%h_schedule)) then
      h0 = problem%problem%h_schedule%values(idx_)
      return
    end if

    h0 = 0.0_dp
    do i = 1, reactants%num_species
      reac_temps(i) = 0.0_dp
      if (allocated(problem%reactants(i)%temperature)) then
        reac_temps(i) = convert_units_to_si(problem%reactants(i)%temperature%values(1), problem%reactants(i)%temperature%units)
      end if
    end do
    h0 = reactants%calc_enthalpy(weights, reac_temps) / gas_constant
  end function compute_reactant_enthalpy


  function get_problem_weights(problem, reactants, idx) result(weights)
    implicit none
    type(ProblemDB), intent(in) :: problem
    type(Mixture), intent(in)   :: reactants
    integer, intent(in), optional :: idx
    real(dp), allocatable :: weights(:)
    real(dp), allocatable :: moles(:), fuel_moles(:), oxidant_moles(:)
    real(dp), allocatable :: fuel_weights(:), oxidant_weights(:)
    character(:), allocatable :: amount_basis
    real(dp) :: of_ratio, ratio_val
    integer  :: i, idx_

    allocate(moles(reactants%num_species), weights(reactants%num_species))
    allocate(fuel_moles(reactants%num_species), oxidant_moles(reactants%num_species))
    allocate(fuel_weights(reactants%num_species), oxidant_weights(reactants%num_species))

    idx_ = 1
    if (present(idx)) idx_ = idx

    fuel_weights = 0.0_dp
    oxidant_weights = 0.0_dp
    fuel_moles = 0.0_dp
    oxidant_moles = 0.0_dp
    weights = 0.0_dp

    if (problem%reactants(1)%type == 'na') then
      amount_basis = ''
      do i = 1, size(problem%reactants)
        if (allocated(problem%reactants(i)%amount)) then
          amount_basis = problem%reactants(i)%amount%name
          exit
        end if
      end do

      if (.not. allocated(amount_basis) .or. len_trim(amount_basis) == 0) then
        weights = 1.0_dp
      else if (amount_basis == 'weight_frac') then
        do i = 1, size(problem%reactants)
          if (allocated(problem%reactants(i)%amount)) then
            weights(i) = problem%reactants(i)%amount%values(1)
          else
            weights(i) = 1.0_dp
          end if
        end do
      else if (amount_basis == 'mole_frac') then
        do i = 1, size(problem%reactants)
          if (allocated(problem%reactants(i)%amount)) then
            moles(i) = problem%reactants(i)%amount%values(1)
          else
            moles(i) = 1.0_dp
          end if
        end do
        weights = reactants%weights_from_moles(moles)
      else
        write(*,*) '[ERROR] Unsupported reactant amount type in cea input'
        stop 1
      end if
      return
    end if

    if (.not. allocated(problem%reactants(1)%amount)) then
      do i = 1, size(problem%reactants)
        if (problem%reactants(i)%type == 'fu') then
          fuel_weights(i) = 1.0_dp
        else if (problem%reactants(i)%type == 'ox') then
          oxidant_weights(i) = 1.0_dp
        end if
      end do
    else if (problem%reactants(1)%amount%name == 'weight_frac') then
      do i = 1, size(problem%reactants)
        if (problem%reactants(i)%type == 'fu') then
          fuel_weights(i) = problem%reactants(i)%amount%values(1)
        else if (problem%reactants(i)%type == 'ox') then
          oxidant_weights(i) = problem%reactants(i)%amount%values(1)
        end if
      end do
    else
      do i = 1, size(problem%reactants)
        if (problem%reactants(i)%type == 'fu') then
          fuel_moles(i) = problem%reactants(i)%amount%values(1)
        else if (problem%reactants(i)%type == 'ox') then
          oxidant_moles(i) = problem%reactants(i)%amount%values(1)
        end if
      end do
      fuel_weights = reactants%weights_from_moles(fuel_moles)
      oxidant_weights = reactants%weights_from_moles(oxidant_moles)
    end if

    if (allocated(problem%problem%of_schedule)) then
      ratio_val = problem%problem%of_schedule%values(idx_)
      select case (trim(problem%problem%of_schedule%name))
      case ('f/o', 'f/a')
        of_ratio = 1.0_dp / ratio_val
      case ('%f', '%fuel')
        of_ratio = (100.0_dp - ratio_val) / ratio_val
      case ('phi')
        of_ratio = reactants%of_from_phi(oxidant_weights, fuel_weights, ratio_val)
      case ('r')
        of_ratio = reactants%of_from_equivalence(oxidant_weights, fuel_weights, ratio_val)
      case default
        of_ratio = ratio_val
      end select
      weights = reactants%weights_from_of(oxidant_weights, fuel_weights, of_ratio)
    else
      weights = fuel_weights + oxidant_weights
    end if
  end function get_problem_weights


  !> Newton-Raphson procedure for T0
  pure function T02T(T0,M,sp) result(T)
    implicit none
    real(R8), intent(in)        :: T0, M
    type(species_t), intent(in) :: sp
    ! Local
    real(R8)             :: T
    real(R8)             :: TT,Tnew,H0,h_tot,cp_tot,dcp_tot,FT,DFT,Rgas,T0t,TTt
    real(R8), parameter  :: toll=1.d-8
    integer              :: s

    Rgas = sum(Runi*sp%massf/sp%w)

    Tnew = T0*0.95
    H0 = 0.0
    ! Table lookups at T clamped to the loaded range: outside it cp and h are
    ! frozen at the end row as in the solvers; the callers decide (ICB reports, BCB refuses before)
    T0t = tab_T(T0, sp)
    do s = 1, size(sp%massf)
      H0 = H0+sp%massf(s)*(sp%h(s,idint(T0t))+(sp%h(s,idint(T0t)+1)-sp%h(s,idint(T0t)))*(T0t-idint(T0t)))
    enddo

    FT  = 1.0
    DFT = 1.0
    TT  = 1.0
    do while (abs(FT/(DFT*TT))>toll)
      TT = Tnew
      TTt = tab_T(TT, sp)
      cp_tot = 0.0
      dcp_tot = 0.0
      h_tot = 0.0
      do s = 1, size(sp%massf)
        cp_tot  = cp_tot  + sp%massf(s) * (sp%cp(s,idint(TTt))  + (sp%cp(s,idint(TTt)+1)  - sp%cp(s,idint(TTt)))*(TTt-idint(TTt)))
        dcp_tot = dcp_tot + sp%massf(s) * (sp%dcp(s,idint(TTt)) + (sp%dcp(s,idint(TTt)+1) - sp%dcp(s,idint(TTt)))*(TTt-idint(TTt)))
        h_tot   = h_tot   + sp%massf(s) * (sp%h(s,idint(TTt))   + (sp%h(s,idint(TTt)+1)   - sp%h(s,idint(TTt)))*(TTt-idint(TTt)))
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


  !> T clamped to the interpolation range [lbound, ubound - 1] of the loaded
  !> tables: every lookup outside it reads the end row (cp and h frozen), as the
  !> solvers' table lookup (FLINT) does. State-range check: ICB reports
  !> the cells outside the table (check_written_state) and does not refuse them;
  !> every path that expands from a stagnation T0 (BCB 420, 405 by p0 and T0; ICB
  !> nozzle, homogeneous and variable zones given by T0) refuses a T0 outside the
  !> table before calling here.
  pure function tab_T(T, sp) result(Tt)
    implicit none
    real(R8), intent(in)        :: T
    type(species_t), intent(in) :: sp
    real(R8) :: Tt
    Tt = min(max(T, real(lbound(sp%cp, dim=2), R8)), real(ubound(sp%cp, dim=2) - 1, R8))
  end function tab_T


  !> Mixture specific heat [J/(kg K)] at T from the species tables by linear
  !> interpolation on the 1 K grid, species by species: the arithmetic of the
  !> solvers' table lookup (FLINT, in MOSE and Q2D), so that the same thermo.dat
  !> gives the same value here and inside their nozzle kernels. T is clamped to
  !> the table range by tab_T (cp frozen outside it, as that lookup does).
  pure function mix_cp(T, sp) result(cp)
    implicit none
    real(R8), intent(in)        :: T
    type(species_t), intent(in) :: sp
    real(R8) :: cp, Tt
    integer  :: s, i

    Tt = tab_T(T, sp)
    i  = idint(Tt)
    cp = 0.0_R8
    do s = 1, size(sp%massf)
      cp = cp + sp%massf(s) * (sp%cp(s,i) + (sp%cp(s,i+1) - sp%cp(s,i)) * (Tt - i))
    enddo

  end function mix_cp


  !> Mixture enthalpy [J/kg] at T, same interpolation as mix_cp.
  pure function mix_h(T, sp) result(h)
    implicit none
    real(R8), intent(in)        :: T
    type(species_t), intent(in) :: sp
    real(R8) :: h, Tt
    integer  :: s, i

    Tt = tab_T(T, sp)
    i  = idint(Tt)
    h  = 0.0_R8
    do s = 1, size(sp%massf)
      h = h + sp%massf(s) * (sp%h(s,i) + (sp%h(s,i+1) - sp%h(s,i)) * (Tt - i))
    enddo

  end function mix_h


  !> Isentrope integral int_T^T0 cp(T')/(Rgas T') dT', T <= T0: composite
  !> trapezoidal rule on the integer-K nodes plus the two fractional end points,
  !> accumulated from T up to T0 node by node exactly as the solvers'
  !> Trapezoidal (MOSE/Q2D Lib_BC_Fluxes*), so that p0/exp(integral) is the
  !> static pressure their nozzle kernels associate with T.
  pure function isentrope_integral(T, T0, Rgas, sp) result(integral)
    implicit none
    real(R8), intent(in)        :: T, T0, Rgas
    type(species_t), intent(in) :: sp
    real(R8) :: integral
    real(R8) :: Tprev, Tnext, f_prev, f_next
    integer  :: k, n

    n        = floor(T0) - ceiling(T) + 3    ! nodes: T, ceiling(T), ..., floor(T0), T0
    integral = 0.0_R8
    Tprev    = T
    f_prev   = mix_cp(T, sp) / Rgas / T
    do k = 2, n
      if (k < n) then
        Tnext = real(ceiling(T) + (k - 2), R8)
      else
        Tnext = T0
      endif
      f_next   = mix_cp(Tnext, sp) / Rgas / Tnext
      integral = integral + 0.5_R8 * (Tnext - Tprev) * (f_prev + f_next)
      Tprev    = Tnext
      f_prev   = f_next
    enddo

  end function isentrope_integral


  !> Mass flux per unit area G = rho*u [kg/(m2 s)] of the isentropic expansion
  !> from (T0, p0), h0 = mix_h(T0, sp), down to the static temperature T:
  !> p = p0/exp(integral), rho = p/(Rgas T), u = sqrt(2 (h0 - h(T))).
  pure function isentrope_massflux(T, T0, p0, h0, Rgas, sp) result(G)
    implicit none
    real(R8), intent(in)        :: T, T0, p0, h0, Rgas
    type(species_t), intent(in) :: sp
    real(R8) :: G
    real(R8) :: p, rho, u2

    p   = p0 / exp(isentrope_integral(T, T0, Rgas, sp))
    rho = p / (Rgas * T)
    u2  = 2.0_R8 * (h0 - mix_h(T, sp))
    G   = rho * sqrt(max(u2, 0.0_R8))

  end function isentrope_massflux


  !> Regime thresholds of the choked injector (BC 420) from the exit/throat
  !> area ratio Ae_At >= 1, on the tabulated-cp isentrope from (T0, p0) with
  !> the discrete arithmetic of the solver kernels (mix_cp, mix_h,
  !> isentrope_integral). Along the expansion G(T) = rho*u vanishes at T0 and
  !> at T -> 0 and has one maximum, the sonic throat: G* = max G, located by a
  !> coarse scan and a golden-section refinement. g = G*/Ae_At is the choked
  !> mass flux per unit exit area. The exit states are the roots of G(T) = g
  !> on the subsonic branch (T* < T < T0, G decreasing) and on the supersonic
  !> branch (T < T*, G increasing): both bracketed, both found by bisection.
  !> psub, psup = the static pressures of the two exit states.
  !> ierr = 0 ok; 1 = the maximum is not interior to the table range;
  !> 2 = the supersonic exit state lies below the table range.
  pure subroutine nozzle_thresholds(T0, p0, Ae_At, sp, psub, psup, g, ierr)
    implicit none
    real(R8), intent(in)        :: T0, p0, Ae_At
    type(species_t), intent(in) :: sp
    real(R8), intent(out)       :: psub, psup, g
    integer,  intent(out)       :: ierr
    ! Local
    real(R8), parameter :: gr = 0.6180339887498949_R8     ! golden ratio conjugate
    integer,  parameter :: nscan = 64
    real(R8) :: Rgas, h0, Tlo, Ta, Tb, Tc, Td, Gc, Gd, Gmax, Tstar, Tsub, Tsup
    integer  :: k, kmax

    ierr = 0
    psub = 0.0_R8; psup = 0.0_R8; g = 0.0_R8
    Rgas = sum(Runi * sp%massf / sp%w)
    h0   = mix_h(T0, sp)
    Tlo  = real(max(lbound(sp%cp, dim=2), 1), R8)   ! coldest static state of the tables

    ! Throat: coarse scan of [Tlo, T0] for the bracket of the maximum ...
    kmax = 0
    Gmax = -1.0_R8
    do k = 0, nscan
      Tc = Tlo + (T0 - Tlo) * real(k, R8) / real(nscan, R8)
      Gc = isentrope_massflux(Tc, T0, p0, h0, Rgas, sp)
      if (Gc > Gmax) then
        Gmax = Gc
        kmax = k
      endif
    enddo
    if (kmax == 0 .or. kmax == nscan) then
      ierr = 1
      return
    endif
    ! ... then golden-section search of the maximum inside the bracket
    Ta = Tlo + (T0 - Tlo) * real(kmax - 1, R8) / real(nscan, R8)
    Tb = Tlo + (T0 - Tlo) * real(kmax + 1, R8) / real(nscan, R8)
    Tc = Tb - gr * (Tb - Ta)
    Td = Ta + gr * (Tb - Ta)
    Gc = isentrope_massflux(Tc, T0, p0, h0, Rgas, sp)
    Gd = isentrope_massflux(Td, T0, p0, h0, Rgas, sp)
    do while (Tb - Ta > 1.0e-10_R8 * T0)
      if (Gc > Gd) then
        Tb = Td; Td = Tc; Gd = Gc
        Tc = Tb - gr * (Tb - Ta)
        Gc = isentrope_massflux(Tc, T0, p0, h0, Rgas, sp)
      else
        Ta = Tc; Tc = Td; Gc = Gd
        Td = Ta + gr * (Tb - Ta)
        Gd = isentrope_massflux(Td, T0, p0, h0, Rgas, sp)
      endif
    enddo
    Tstar = 0.5_R8 * (Ta + Tb)
    g     = isentrope_massflux(Tstar, T0, p0, h0, Rgas, sp) / Ae_At

    if (Ae_At == 1.0_R8) then
      Tsub = Tstar
      Tsup = Tstar
    else
      ! subsonic exit: G(Tstar) = G* > g > 0 = G(T0)
      Tsub = bisect(Tstar, T0)
      ! supersonic exit: G(Tlo) < g < G* = G(Tstar)
      if (isentrope_massflux(Tlo, T0, p0, h0, Rgas, sp) >= g) then
        ierr = 2
        return
      endif
      Tsup = bisect(Tstar, Tlo)
    endif
    psub = p0 / exp(isentrope_integral(Tsub, T0, Rgas, sp))
    psup = p0 / exp(isentrope_integral(Tsup, T0, Rgas, sp))

  contains

    !> Root of G(T) - g between Tpos (G > g) and Tneg (G < g) by bisection.
    pure function bisect(Tpos, Tneg) result(T)
      implicit none
      real(R8), intent(in) :: Tpos, Tneg
      real(R8) :: T
      real(R8) :: a, b, m
      integer  :: it

      a = Tpos
      b = Tneg
      do it = 1, 200
        if (abs(b - a) <= 2.0_R8 * epsilon(T0) * T0) exit   ! bracket at the rounding limit
        m = 0.5_R8 * (a + b)
        if (isentrope_massflux(m, T0, p0, h0, Rgas, sp) > g) then
          a = m
        else
          b = m
        endif
      enddo
      T = 0.5_R8 * (a + b)

    end function bisect

  end subroutine nozzle_thresholds

end module phase_mod