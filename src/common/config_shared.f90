module config_shared_mod
  use iso_fortran_env, only: R8 => real64
  use registry_mod,    only: registry_t
  use finer,           only: file_ini
  use global_mod,      only: llen

  implicit none
  private

  type, public :: atlas_parameters_t
    character(len=llen) :: input_file = 'input.ini'
    character(len=32)   :: ic_format = 'tec'
    integer             :: mg_levels = 1
    logical             :: bc_force_connect = .true.
    logical             :: bc_chimera = .false.
    logical             :: bc_force_chimera = .false.
    logical             :: strict_keys = .true.     ! unknown key: error (T) or WARNING (F)
  end type atlas_parameters_t

  type, public :: config_velocity_t
    real(R8) :: alpha = 0.0_R8
    real(R8) :: beta = 0.0_R8
    real(R8) :: un = 0.0_R8
    real(R8) :: u = 0.0_R8
    real(R8) :: v = 0.0_R8
    real(R8) :: w = 0.0_R8
  end type config_velocity_t

  !> Free-stream turbulence keys. Each quantity has a specific key and a density-weighted one:
  !>   Spalart-Allmaras working variable   nuTilde [m2/s]    rhoNuTilde = rho*nuTilde [kg/(m s)]
  !>   turbulent kinetic energy            k       [m2/s2]   rhoK       = rho*k       [kg/(m s2)]
  !>   specific dissipation rate           omega   [1/s]     rhoOmega   = rho*omega   [kg/(m3 s)]
  !>   normal Reynolds stresses            Rij     [m2/s2]   rhoRij     = rho*Rij     [kg/(m s2)]
  !> (the names of the NASA Turbulence Modeling Resource; nuTilde is the variable the model
  !> transports, not the eddy viscosity, which TMR and the solvers call mut).
  type, public :: config_turbulence_t
    real(R8) :: nuTilde = 0.0_R8
    real(R8) :: k = 0.0_R8
    real(R8) :: omega = 0.0_R8
    real(R8) :: Rij = 0.0_R8
    real(R8) :: rhoNuTilde = 0.0_R8
    real(R8) :: rhoK = 0.0_R8
    real(R8) :: rhoOmega = 0.0_R8
    real(R8) :: rhoRij = 0.0_R8
    integer  :: nrans = 0
    logical  :: has_nrans = .false.
  end type config_turbulence_t

  type, public :: config_composition_doc_t
    logical             :: eq_og = .false.
    character(len=llen) :: eq_cea_file = ''
    integer             :: eq_cea_section = 1
    real(R8)            :: y_species = 0.0_R8
  end type config_composition_doc_t

  public :: load_atlas_parameters
  public :: load_ini_file
  public :: load_shared_velocity_config
  public :: load_shared_turbulence_config
  public :: turbulence_weighted, turbulence_specific_keys
  public :: add_atlas_registry_entries
  public :: add_velocity_registry_entries
  public :: add_turbulence_registry_entries
  public :: add_composition_registry_entries
  ! keys of [ATLAS-Parameters] read below for every tool (input_keys_mod)
  character(len=16), parameter, public :: atlas_shared_keys(10) = [character(len=16) :: &
    'BCB-file', 'ICB-file', 'STB-file', 'MDB-file', 'MG-levels', 'IC-format', &
    'BC-force-connect', 'BC-chimera', 'BC-force-chimera', 'strict-keys']

contains

  subroutine load_atlas_parameters(prog, cfg, input_file)
    use input_keys_mod, only: input_keys_check_section, input_keys_set_strict, input_keys_check_duplicate_sections, &
                              input_keys_check_logical
    implicit none
    character(len=64) :: strict_value
    character(*), intent(in)              :: prog
    type(atlas_parameters_t), intent(out) :: cfg
    character(*), intent(in), optional    :: input_file

    type(file_ini) :: fini
    character(len=32) :: file_option
    character(len=llen) :: ini_filename
    integer :: error
    logical :: ini_exists

    if (present(input_file)) then
      ini_filename = input_file
    else
      ini_filename = 'input.ini'
    end if

    ! FiNeR's load() silently ignores a missing file, which leaves every option
    ! at its default and makes the tool fail much later (or crash) for reasons
    ! that have nothing to do with the real problem. Catch it here instead.
    inquire(file=trim(ini_filename), exist=ini_exists)
    if (.not. ini_exists) then
      write(*,'(3A)') '[ERROR] ', trim(prog), ' input file not found: '//trim(ini_filename)
      write(*,'(A)')  '        Pass one with -i/--input, or create input.ini in this directory.'
      stop 1
    endif

    cfg%input_file = trim(ini_filename)
    cfg%ic_format = 'tec'
    cfg%mg_levels = 1
    cfg%bc_force_connect = .true.
    cfg%bc_chimera = .false.
    cfg%bc_force_chimera = .false.

    call load_ini_file(fini, trim(ini_filename))

    ! strict-keys and the key check of the section come before the gets below: FiNeR reads an
    ! integer (MG-levels = 1e0) or a logical (strict-keys = maybe) without iostat and would stop
    ! with a runtime error instead of the diagnostic
    strict_value = ''
    call fini%get(section_name='ATLAS-Parameters', option_name='strict-keys', &
                  val=strict_value, error=error)
    cfg%strict_keys = .true.
    if (error == 0) then
      ! the whole value, with the rule of every logical key (T, F, true, false, .true., .false., any
      ! case, a comment after it), also in a tool that checks no key table: a word that only starts
      ! like a logical (Tomato) is refused, not read by its first letter
      call input_keys_check_logical('strict-keys', strict_value, 'ATLAS-Parameters')
      strict_value = adjustl(strict_value)
      if (strict_value(1:1) == '.') strict_value = strict_value(2:)
      cfg%strict_keys = strict_value(1:1) == 'T' .or. strict_value(1:1) == 't'
    endif
    call input_keys_set_strict(cfg%strict_keys)
    call input_keys_check_duplicate_sections(trim(ini_filename), fini)   ! L0: a section header written twice (FiNeR keeps the first in silence)
    call input_keys_check_section(fini, 'ATLAS-Parameters', 'atlas', extra=atlas_shared_keys)

    file_option = atlas_input_option_name(prog)
    if (len_trim(file_option) > 0) then
      call fini%get(section_name='ATLAS-Parameters', option_name=trim(file_option), &
                    val=cfg%input_file, error=error)
      if (error /= 0) cfg%input_file = trim(ini_filename)
    endif

    call fini%get(section_name='ATLAS-Parameters', option_name='MG-levels', &
                  val=cfg%mg_levels, error=error)
    if (error /= 0) cfg%mg_levels = 1
    if (cfg%mg_levels < 1) then
      write(*,'(A,I0,A)') '[ERROR] key MG-levels of section [ATLAS-Parameters]: value ', cfg%mg_levels, ' is not >= 1'
      stop 1
    endif

    call fini%get(section_name='ATLAS-Parameters', option_name='IC-format', &
                  val=cfg%ic_format, error=error)
    if (error /= 0) cfg%ic_format = 'tec'

    call fini%get(section_name='ATLAS-Parameters', option_name='BC-force-connect', &
                  val=cfg%bc_force_connect, error=error)
    if (error /= 0) cfg%bc_force_connect = .true.

    call fini%get(section_name='ATLAS-Parameters', option_name='BC-chimera', &
                  val=cfg%bc_chimera, error=error)
    if (error /= 0) cfg%bc_chimera = .false.

    call fini%get(section_name='ATLAS-Parameters', option_name='BC-force-chimera', &
                  val=cfg%bc_force_chimera, error=error)
    if (error /= 0) cfg%bc_force_chimera = .false.

  end subroutine load_atlas_parameters

  subroutine load_shared_velocity_config(zoneini, cfg, section_name)
    implicit none
    type(file_ini), intent(in)           :: zoneini
    type(config_velocity_t), intent(out) :: cfg
    character(*), intent(in), optional   :: section_name

    character(len=32) :: section_id
    integer :: error

    section_id = 'zone'
    if (present(section_name)) section_id = section_name

    cfg%alpha = 0.0_R8
    cfg%beta = 0.0_R8
    cfg%u = 0.0_R8
    cfg%v = 0.0_R8
    cfg%w = 0.0_R8
    cfg%un = 0.0_R8

    call zoneini%get(section_name=section_id, option_name='alpha', val=cfg%alpha, error=error)
    if (error /= 0) cfg%alpha = huge(0.0_R8)
    call zoneini%get(section_name=section_id, option_name='beta', val=cfg%beta, error=error)
    if (error /= 0) cfg%beta = huge(0.0_R8)
    call zoneini%get(section_name=section_id, option_name='un', val=cfg%un, error=error)
    if (error /= 0) cfg%un = 0.0_R8
    call zoneini%get(section_name=section_id, option_name='u', val=cfg%u, error=error)
    if (error /= 0) cfg%u = 0.0_R8
    call zoneini%get(section_name=section_id, option_name='v', val=cfg%v, error=error)
    if (error /= 0) cfg%v = 0.0_R8
    call zoneini%get(section_name=section_id, option_name='w', val=cfg%w, error=error)
    if (error /= 0) cfg%w = 0.0_R8
  end subroutine load_shared_velocity_config

  !> The turbulence keys of a section. boundary = .true. (BCB): nuTilde, k, omega and Rij only, the
  !> specific keys of a boundary record (input_keys reports the density-weighted ones as unknown, with a hint).
  subroutine load_shared_turbulence_config(zoneini, cfg, section_name, boundary)
    implicit none
    type(file_ini), intent(in)             :: zoneini
    type(config_turbulence_t), intent(out) :: cfg
    character(*), intent(in), optional     :: section_name
    logical, intent(in), optional          :: boundary

    character(len=32)   :: section_id
    character(len=llen) :: deck_section
    integer :: error
    logical :: read_all

    section_id = 'zone'
    if (present(section_name)) section_id = section_name
    read_all = .true.
    if (present(boundary)) read_all = .not. boundary
    ! the deck section, for the messages (an ICB zone is read from a copy named 'zone')
    deck_section = section_id
    call zoneini%get(section_name=section_id, option_name='x-section', val=deck_section, error=error)
    if (error /= 0) deck_section = section_id

    cfg = config_turbulence_t()
    call get_key('nuTilde', cfg%nuTilde)
    call get_key('k', cfg%k)
    call get_key('omega', cfg%omega)
    call get_key('Rij', cfg%Rij)
    if (read_all) then
      call get_key('rhoNuTilde', cfg%rhoNuTilde)
      call get_key('rhoK', cfg%rhoK)
      call get_key('rhoOmega', cfg%rhoOmega)
      call get_key('rhoRij', cfg%rhoRij)
    endif
    call refuse_both('nuTilde', 'rhoNuTilde', cfg%nuTilde, cfg%rhoNuTilde)
    call refuse_both('k', 'rhoK', cfg%k, cfg%rhoK)
    call refuse_both('omega', 'rhoOmega', cfg%omega, cfg%rhoOmega)
    call refuse_both('Rij', 'rhoRij', cfg%Rij, cfg%rhoRij)

    call zoneini%get(section_name=section_id, option_name='nrans', val=cfg%nrans, error=error)
    cfg%has_nrans = error == 0
    if (cfg%has_nrans) return

    if (cfg%Rij /= 0.0_R8 .or. cfg%rhoRij /= 0.0_R8) then
      cfg%nrans = 7
    elseif (cfg%k /= 0.0_R8 .or. cfg%omega /= 0.0_R8 .or. cfg%rhoK /= 0.0_R8 .or. cfg%rhoOmega /= 0.0_R8) then
      cfg%nrans = 2
    elseif (cfg%nuTilde /= 0.0_R8 .or. cfg%rhoNuTilde /= 0.0_R8) then
      cfg%nrans = 1
    endif

  contains

    subroutine get_key(key, val)
      character(*), intent(in) :: key
      real(R8), intent(inout)  :: val
      call zoneini%get(section_name=section_id, option_name=key, val=val, error=error)
      if (error /= 0) val = 0.0_R8
    end subroutine get_key

    subroutine refuse_both(specific_key, weighted_key, specific, weighted)
      character(*), intent(in) :: specific_key, weighted_key
      real(R8), intent(in)     :: specific, weighted
      if (specific /= 0.0_R8 .and. weighted /= 0.0_R8) then
        write(*,'(A)') '[ERROR] keys '//specific_key//' and '//weighted_key//' of section ['//trim(deck_section)// &
          ']: one quantity given twice (give the specific '//specific_key//' or the density-weighted '//weighted_key//')'
        stop 1
      endif
    end subroutine refuse_both
  end subroutine load_shared_turbulence_config

  !> The density-weighted free-stream values (rhoNuTilde, rhoK, rhoOmega, rhoRij) for a cell of density
  !> rho: a specific key times rho, a density-weighted key as given (0 = not given).
  pure function turbulence_weighted(cfg, rho) result(w)
    type(config_turbulence_t), intent(in) :: cfg
    real(R8), intent(in)                  :: rho
    real(R8)                              :: w(4)
    w = [cfg%rhoNuTilde, cfg%rhoK, cfg%rhoOmega, cfg%rhoRij]
    if (cfg%nuTilde /= 0.0_R8)   w(1) = rho*cfg%nuTilde
    if (cfg%k /= 0.0_R8)     w(2) = rho*cfg%k
    if (cfg%omega /= 0.0_R8) w(3) = rho*cfg%omega
    if (cfg%Rij /= 0.0_R8)   w(4) = rho*cfg%Rij
  end function turbulence_weighted

  !> The specific turbulence keys given (blank-separated), '' if none.
  function turbulence_specific_keys(cfg) result(keys)
    type(config_turbulence_t), intent(in) :: cfg
    character(len=:), allocatable         :: keys
    keys = ''
    if (cfg%nuTilde /= 0.0_R8)   keys = keys//' nuTilde'
    if (cfg%k /= 0.0_R8)     keys = keys//' k'
    if (cfg%omega /= 0.0_R8) keys = keys//' omega'
    if (cfg%Rij /= 0.0_R8)   keys = keys//' Rij'
    keys = trim(adjustl(keys))
  end function turbulence_specific_keys

  subroutine add_atlas_registry_entries(registry, prog, cfg)
    implicit none
    class(registry_t), intent(inout)      :: registry
    character(*), intent(in)              :: prog
    type(atlas_parameters_t), target, intent(inout) :: cfg

    select case (trim(prog))
    case ('ICB')
      call registry%add('ATLAS-Parameters', 'ICB-file', cfg%input_file, 'input.ini', &
                        'INI file containing ICB block definitions.', '', .false.)
      call registry%add('ATLAS-Parameters', 'IC-format', cfg%ic_format, 'tec', &
                        'Output format used when writing initial conditions: a family (tec, tecplot, vtk) '// &
                        'with an optional mode (binary, ascii, raw) joined by -, blank or _ (tecplot binary, '// &
                        'vtk binary, tecplot-ascii are accepted); a binary Tecplot file (.szplt) needs a TecIO build.', &
                        'tec<br>tec-binary<br>vtk<br>vtk-binary<br>vtk-ascii<br>vtk-raw', .false.)
    case ('BCB')
      call registry%add('ATLAS-Parameters', 'BCB-file', cfg%input_file, 'input.ini', &
                        'INI file containing BCB block and boundary definitions.', &
                        '', .false.)
      call registry%add('ATLAS-Parameters', 'MG-levels', cfg%mg_levels, '1', &
                        'Number of multigrid levels for which BC files are written.', '>=1', .false.)
      call registry%add('ATLAS-Parameters', 'BC-force-connect', cfg%bc_force_connect, &
                        'T', 'Force standard connection matching when chimera is off.', &
                        '', .false.)
      call registry%add('ATLAS-Parameters', 'BC-chimera', cfg%bc_chimera, 'F', &
                        'Enable the overset search on the faces declared chimera. '// &
                        'Faces declared connection keep the standard matching.', &
                        '', .false.)
      call registry%add('ATLAS-Parameters', 'BC-force-chimera', cfg%bc_force_chimera, 'F', &
                        'Extend the overset search to every unresolved face, whatever '// &
                        'its declared type. Facelets without donors keep their own BC.', &
                        '', .false.)
    case ('MDB')
      call registry%add('ATLAS-Parameters', 'MDB-file', cfg%input_file, 'input.ini', &
                        'INI file containing the MDB parameters.', '', .false.)
      call registry%add('ATLAS-Parameters', 'MG-levels', cfg%mg_levels, '1', &
                        'Number of multigrid levels the solver will run. Every cut is placed at a '// &
                        'multiple of 2^(MG-levels-1) so that each coarse level cuts at an integer index '// &
                        'too, and one BC file per level is rewritten.', '>=1', .false.)
    end select
    call registry%add('ATLAS-Parameters', 'strict-keys', cfg%strict_keys, 'T', &
                      'F turns the error on a key the tool does not read (or not honoured by the '// &
                      'resolved BC type, or y of an undeclared species) into a WARNING; wrong values '// &
                      'are always errors (keys with the prefix ignore- are never read).', '', .false.)
  end subroutine add_atlas_registry_entries

  subroutine add_velocity_registry_entries(registry, section, velocity_cfg)
    implicit none
    class(registry_t), intent(inout)     :: registry
    character(*), intent(in)             :: section
    type(config_velocity_t), target, intent(inout) :: velocity_cfg

    call registry%add(section, 'alpha', velocity_cfg%alpha, '0.0', &
                      'Flow angle [rad] in the x-y plane, from x towards y: the direction is '// &
                      '(cos alpha cos beta, sin alpha cos beta, sin beta).', '', .false.)
    call registry%add(section, 'beta', velocity_cfg%beta, '0.0', &
                      'Flow angle [rad] out of the x-y plane, towards z.', '', .false.)
    call registry%add(section, 'u', velocity_cfg%u, '0.0', &
                      'Prescribed x-velocity component.', '', .false.)
    call registry%add(section, 'v', velocity_cfg%v, '0.0', &
                      'Prescribed y-velocity component.', '', .false.)
    call registry%add(section, 'w', velocity_cfg%w, '0.0', &
                      'Prescribed z-velocity component.', '', .false.)
    call registry%add(section, 'un', velocity_cfg%un, '0.0', &
                      'Prescribed normal velocity component.', '', .false.)
  end subroutine add_velocity_registry_entries

  !> The turbulence keys. boundary = .true. (BCB): the keys of a boundary record, nuTilde, k, omega
  !> and Rij, all specific.
  subroutine add_turbulence_registry_entries(registry, section, turbulence_cfg, boundary)
    implicit none
    class(registry_t), intent(inout)       :: registry
    character(*), intent(in)               :: section
    type(config_turbulence_t), target, intent(inout) :: turbulence_cfg
    logical, intent(in), optional          :: boundary
    character(len=*), parameter :: ICB_SPECIFIC = ' ICB multiplies it by the cell density (ideal-gas zone; refused in a'// &
      ' real-fluid zone, whose table carries no density). Give it or the density-weighted '
    character(len=*), parameter :: ICB_WEIGHTED = ' ICB writes it as given (the band of the IC file). Give it or the specific '
    character(len=*), parameter :: BCB_SPECIFIC = ' BCB writes it as given; the solver multiplies it by the density of the'// &
      ' boundary state.'
    logical :: bc

    bc = .false.
    if (present(boundary)) bc = boundary

    call registry%add(section, 'nuTilde', turbulence_cfg%nuTilde, '0.0', &
      'Spalart-Allmaras working variable nu_tilde [m2/s] (not the eddy viscosity), specific.'// &
      use_specific('rhoNuTilde'), '', .false.)
    call registry%add(section, 'k', turbulence_cfg%k, '0.0', &
      'Turbulent kinetic energy k [m2/s2], specific.'//use_specific('rhoK'), '', .false.)
    call registry%add(section, 'omega', turbulence_cfg%omega, '0.0', &
      'Specific dissipation rate omega [1/s], specific.'//use_specific('rhoOmega'), '', .false.)
    call registry%add(section, 'Rij', turbulence_cfg%Rij, '0.0', &
      'Normal Reynolds stresses R11 = R22 = R33 [m2/s2], specific, one value for the three (the shear'// &
      ' stresses are set to 1e-8).'//use_specific('rhoRij'), '', .false.)
    if (.not. bc) then
      call registry%add(section, 'rhoNuTilde', turbulence_cfg%rhoNuTilde, '0.0', &
        'Density-weighted Spalart-Allmaras working variable rho*nu_tilde [kg/(m s)].'//ICB_WEIGHTED//'nuTilde.', '', .false.)
      call registry%add(section, 'rhoK', turbulence_cfg%rhoK, '0.0', &
        'Density-weighted turbulent kinetic energy rho*k [kg/(m s2)].'//ICB_WEIGHTED//'k.', '', .false.)
      call registry%add(section, 'rhoOmega', turbulence_cfg%rhoOmega, '0.0', &
        'Density-weighted specific dissipation rate rho*omega [kg/(m3 s)].'//ICB_WEIGHTED//'omega.', '', .false.)
      call registry%add(section, 'rhoRij', turbulence_cfg%rhoRij, '0.0', &
        'Density-weighted normal Reynolds stresses rho*Rij [kg/(m s2)], one value for the three (the shear stresses'// &
        ' are set to 1e-8).'//ICB_WEIGHTED//'Rij.', '', .false.)
    endif
    call registry%add(section, 'nrans', turbulence_cfg%nrans, '0', &
                      'Explicit turbulence model size override.', '>=0', .false.)

  contains

    function use_specific(weighted_key) result(t)
      character(*), intent(in)      :: weighted_key
      character(len=:), allocatable :: t
      if (bc) then
        t = BCB_SPECIFIC
      else
        t = ICB_SPECIFIC//weighted_key//'.'
      endif
    end function use_specific
  end subroutine add_turbulence_registry_entries

  subroutine add_composition_registry_entries(registry, section, composition_cfg)
    implicit none
    class(registry_t), intent(inout)       :: registry
    character(*), intent(in)               :: section
    type(config_composition_doc_t), target, intent(inout) :: composition_cfg

    call registry%add(section, 'eq-OG', composition_cfg%eq_og, 'F', &
                      'Keep only the gaseous products of the CEA equilibrium of `eq-CEA-file`: the condensed '// &
                      'products are dropped and the mass fractions of the gaseous ones are renormalised to 1.', &
                      '', .false.)
    call registry%add(section, 'eq-CEA-file', composition_cfg%eq_cea_file, '', &
                      'CEA input file used to derive equilibrium composition.', &
                      '', .false.)
    call registry%add(section, 'eq-CEA-section', composition_cfg%eq_cea_section, '1', &
                      'CEA section index used when eq-CEA-file is provided.', &
                      '>=1', .false.)
    call registry%add(section, 'yspecies', composition_cfg%y_species, '0.0', &
                      'Mass fraction assigned to a species name suffix: one number in [0, 1].', &
                      '', .false.)
  end subroutine add_composition_registry_entries

  function atlas_input_option_name(prog) result(option_name)
    implicit none
    character(*), intent(in) :: prog
    character(len=32)        :: option_name

    option_name = ''
    select case (trim(prog))
    case ('ICB')
      option_name = 'ICB-file'
    case ('BCB')
      option_name = 'BCB-file'
    end select
  end function atlas_input_option_name

  !> Load an ini file into fini without its full-line comments (a line whose first non-blank character is
  !> '#', ';' or '!'). FiNeR counts the options of a section by their '=' signs, comment lines included, and
  !> stops with a segmentation fault on a comment that holds one ('# p0 = 10 bar'): the file is read here,
  !> the comment lines are left out and the rest goes to FiNeR unchanged. Inline comments stay FiNeR's.
  subroutine load_ini_file(fini, filename)
    type(file_ini),   intent(inout) :: fini
    character(len=*), intent(in)    :: filename
    character(len=:), allocatable :: src, line
    character(len=1024) :: buf
    integer :: u, ios, sz, c
    open(newunit=u, file=trim(filename), status='old', action='read', form='formatted', iostat=ios)
    if (ios /= 0) then
      call fini%load(filename=trim(filename))   ! FiNeR's own handling of a file it cannot read
      return
    endif
    src = ''
    do
      line = ''
      do
        read(u, '(A)', advance='no', iostat=ios, size=sz) buf
        line = line//buf(1:sz)
        if (ios /= 0) exit
      enddo
      if (.not. (is_iostat_eor(ios) .or. (is_iostat_end(ios) .and. len(line) > 0))) exit
      c = verify(line, ' '//char(9))
      if (c > 0) then
        if (index('#;!', line(c:c)) > 0) line = ''
      endif
      src = src//line//new_line('a')
      if (is_iostat_end(ios)) exit
    enddo
    close(u)
    call fini%load(source=src)
  end subroutine load_ini_file

end module config_shared_mod