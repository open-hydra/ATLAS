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
  end type atlas_parameters_t

  type, public :: config_velocity_t
    real(R8) :: alpha = 0.0_R8
    real(R8) :: beta = 0.0_R8
    real(R8) :: u = 0.0_R8
    real(R8) :: v = 0.0_R8
    real(R8) :: w = 0.0_R8
  end type config_velocity_t

  type, public :: config_turbulence_t
    real(R8) :: mit = 0.0_R8
    real(R8) :: kappa = 0.0_R8
    real(R8) :: omega = 0.0_R8
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
  public :: load_shared_velocity_config
  public :: load_shared_turbulence_config
  public :: add_atlas_registry_entries
  public :: add_velocity_registry_entries
  public :: add_turbulence_registry_entries
  public :: add_composition_registry_entries

contains

  subroutine load_atlas_parameters(prog, cfg)
    implicit none
    character(*), intent(in)         :: prog
    type(atlas_parameters_t), intent(out) :: cfg

    type(file_ini) :: fini
    character(len=32) :: file_option
    integer :: error

    cfg%input_file = 'input.ini'
    cfg%ic_format = 'tec'
    cfg%mg_levels = 1
    cfg%bc_force_connect = .true.
    cfg%bc_chimera = .false.

    call fini%load(filename='input.ini')

    file_option = atlas_input_option_name(prog)
    if (len_trim(file_option) > 0) then
      call fini%get(section_name='ATLAS-Parameters', option_name=trim(file_option), &
                    val=cfg%input_file, error=error)
      if (error /= 0) cfg%input_file = 'input.ini'
    endif

    call fini%get(section_name='ATLAS-Parameters', option_name='MG-levels', &
                  val=cfg%mg_levels, error=error)
    if (error /= 0) cfg%mg_levels = 1

    call fini%get(section_name='ATLAS-Parameters', option_name='IC-format', &
                  val=cfg%ic_format, error=error)
    if (error /= 0) cfg%ic_format = 'tec'

    call fini%get(section_name='ATLAS-Parameters', option_name='BC-force-connect', &
                  val=cfg%bc_force_connect, error=error)
    if (error /= 0) cfg%bc_force_connect = .true.

    call fini%get(section_name='ATLAS-Parameters', option_name='BC-chimera', &
                  val=cfg%bc_chimera, error=error)
    if (error /= 0) cfg%bc_chimera = .false.
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

    call zoneini%get(section_name=section_id, option_name='alpha', val=cfg%alpha, error=error)
    if (error /= 0) cfg%alpha = huge(0.0_R8)
    call zoneini%get(section_name=section_id, option_name='beta', val=cfg%beta, error=error)
    if (error /= 0) cfg%beta = huge(0.0_R8)
    call zoneini%get(section_name=section_id, option_name='u', val=cfg%u, error=error)
    if (error /= 0) cfg%u = 0.0_R8
    call zoneini%get(section_name=section_id, option_name='v', val=cfg%v, error=error)
    if (error /= 0) cfg%v = 0.0_R8
    call zoneini%get(section_name=section_id, option_name='w', val=cfg%w, error=error)
    if (error /= 0) cfg%w = 0.0_R8
  end subroutine load_shared_velocity_config

  subroutine load_shared_turbulence_config(zoneini, cfg, section_name)
    implicit none
    type(file_ini), intent(in)             :: zoneini
    type(config_turbulence_t), intent(out) :: cfg
    character(*), intent(in), optional     :: section_name

    character(len=32) :: section_id
    integer :: error

    section_id = 'zone'
    if (present(section_name)) section_id = section_name

    cfg%mit = 0.0_R8
    cfg%kappa = 0.0_R8
    cfg%omega = 0.0_R8
    cfg%rhoRij = 0.0_R8
    cfg%nrans = 0
    cfg%has_nrans = .false.

    call zoneini%get(section_name=section_id, option_name='mit', val=cfg%mit, error=error)
    if (error /= 0) cfg%mit = 0.0_R8
    call zoneini%get(section_name=section_id, option_name='kappa', val=cfg%kappa, error=error)
    if (error /= 0) cfg%kappa = 0.0_R8
    call zoneini%get(section_name=section_id, option_name='omega', val=cfg%omega, error=error)
    if (error /= 0) cfg%omega = 0.0_R8
    call zoneini%get(section_name=section_id, option_name='rhoRij', val=cfg%rhoRij, &
                     error=error)
    if (error /= 0) cfg%rhoRij = 0.0_R8

    call zoneini%get(section_name=section_id, option_name='nrans', val=cfg%nrans, error=error)
    cfg%has_nrans = error == 0
    if (cfg%has_nrans) return

    if (cfg%rhoRij /= 0.0_R8) then
      cfg%nrans = 7
    elseif (cfg%kappa /= 0.0_R8 .or. cfg%omega /= 0.0_R8) then
      cfg%nrans = 2
    elseif (cfg%mit /= 0.0_R8) then
      cfg%nrans = 1
    endif
  end subroutine load_shared_turbulence_config

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
                        'Output format used when writing initial conditions.', &
                        '', .false.)
    case ('BCB')
      call registry%add('ATLAS-Parameters', 'BCB-file', cfg%input_file, 'input.ini', &
                        'INI file containing BCB block and boundary definitions.', &
                        '', .false.)
      call registry%add('ATLAS-Parameters', 'BC-force-connect', cfg%bc_force_connect, &
                        'T', 'Force standard connection matching when chimera is off.', &
                        '', .false.)
      call registry%add('ATLAS-Parameters', 'BC-chimera', cfg%bc_chimera, 'F', &
                        'Enable chimera connectivity instead of standard matching.', &
                        '', .false.)
    end select
  end subroutine add_atlas_registry_entries

  subroutine add_velocity_registry_entries(registry, section, velocity_cfg)
    implicit none
    class(registry_t), intent(inout)     :: registry
    character(*), intent(in)             :: section
    type(config_velocity_t), target, intent(inout) :: velocity_cfg

    call registry%add(section, 'alpha', velocity_cfg%alpha, '0.0', &
                      'Velocity angle alpha.', '', .false.)
    call registry%add(section, 'beta', velocity_cfg%beta, '0.0', &
                      'Velocity angle beta.', '', .false.)
    call registry%add(section, 'u', velocity_cfg%u, '0.0', &
                      'Prescribed x-velocity component.', '', .false.)
    call registry%add(section, 'v', velocity_cfg%v, '0.0', &
                      'Prescribed y-velocity component.', '', .false.)
    call registry%add(section, 'w', velocity_cfg%w, '0.0', &
                      'Prescribed z-velocity component.', '', .false.)
  end subroutine add_velocity_registry_entries

  subroutine add_turbulence_registry_entries(registry, section, turbulence_cfg)
    implicit none
    class(registry_t), intent(inout)       :: registry
    character(*), intent(in)               :: section
    type(config_turbulence_t), target, intent(inout) :: turbulence_cfg

    call registry%add(section, 'mit', turbulence_cfg%mit, '0.0', &
                      'Turbulence intensity for 1-equation models.', '', .false.)
    call registry%add(section, 'kappa', turbulence_cfg%kappa, '0.0', &
                      'Turbulent kinetic energy.', '', .false.)
    call registry%add(section, 'omega', turbulence_cfg%omega, '0.0', &
                      'Specific dissipation rate.', '', .false.)
    call registry%add(section, 'rhoRij', turbulence_cfg%rhoRij, '0.0', &
                      'Reynolds-stress tensor magnitude.', '', .false.)
    call registry%add(section, 'nrans', turbulence_cfg%nrans, '0', &
                      'Explicit turbulence model size override.', '>=0', .false.)
  end subroutine add_turbulence_registry_entries

  subroutine add_composition_registry_entries(registry, section, composition_cfg)
    implicit none
    class(registry_t), intent(inout)       :: registry
    character(*), intent(in)               :: section
    type(config_composition_doc_t), target, intent(inout) :: composition_cfg

    call registry%add(section, 'eq-OG', composition_cfg%eq_og, 'F', &
                      'Enable CEA oxidizer-fuel equilibrium mode.', '', .false.)
    call registry%add(section, 'eq-CEA-file', composition_cfg%eq_cea_file, '', &
                      'CEA input file used to derive equilibrium composition.', &
                      '', .false.)
    call registry%add(section, 'eq-CEA-section', composition_cfg%eq_cea_section, '1', &
                      'CEA section index used when eq-CEA-file is provided.', &
                      '>=1', .false.)
    call registry%add(section, 'y<species>', composition_cfg%y_species, '0.0', &
                      'Mass fraction assigned to a species name suffix.', &
                      '>=0', .false.)
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

end module config_shared_mod