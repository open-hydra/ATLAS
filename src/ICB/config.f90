module config_mod
  use iso_fortran_env, only: R8 => real64
  use finer,           only: file_ini
  use global_mod,      only: llen
  use registry_mod,    only: registry_t
  use config_shared_mod

  implicit none
  private

  type, public :: config_field_source_t
    logical             :: has_value = .false.
    logical             :: has_file = .false.
    logical             :: has_direction = .false.
    real(R8)            :: value = 0.0_R8
    character(len=llen) :: file = ''
    character(len=16)   :: direction = ''
  end type config_field_source_t

  type, public :: config_zone_runtime_t
    character(len=llen) :: ic_type = 'homogeneous'
    logical             :: has_direction = .false.
    logical             :: has_range = .false.
    character(len=16)   :: direction = ''
    real(R8)            :: range(6) = 0.0_R8
  end type config_zone_runtime_t

  type, public :: config_interpolation_t
    character(len=llen) :: warning_message = ''
    character(len=llen) :: error_message = ''
    character(len=llen) :: description = ''
    logical             :: enabled = .false.
    real(R8)            :: theta = 90.0_R8
    integer             :: nz = 4
    integer             :: old_block_id = 0
    character(len=llen) :: file = ''
    character(len=llen) :: law = 'outlaw'
    character(len=llen) :: old_solution = ''
    character(len=llen) :: old_species = ''
  end type config_interpolation_t

  type, public :: config_ig_t
    type(config_field_source_t) :: mach
    type(config_field_source_t) :: p0
    type(config_field_source_t) :: T0
    type(config_field_source_t) :: p
    type(config_field_source_t) :: T
    type(config_field_source_t) :: rho
    type(config_velocity_t)     :: velocity
    type(config_turbulence_t)   :: turbulence
    type(config_interpolation_t):: interpolation
    character(len=2)            :: nozzle_direction = 'dx'
    real(R8)                    :: nozzle_threshold = huge(1.0_R8)
  end type config_ig_t

  type, public :: config_rf_t
    type(config_field_source_t) :: p
    type(config_field_source_t) :: T
    type(config_field_source_t) :: h
    type(config_field_source_t) :: vel
    type(config_velocity_t)     :: velocity
    type(config_turbulence_t)   :: turbulence
    type(config_interpolation_t):: interpolation
  end type config_rf_t

  type, public :: config_sp_t
    type(config_field_source_t) :: T
    type(config_field_source_t) :: qvol
    type(config_interpolation_t):: interpolation
    character(len=16)           :: material = ''
  end type config_sp_t

  type, public :: config_dp_t
    type(config_interpolation_t) :: interpolation
    integer                      :: neuler = 0
    logical                      :: has_rp = .false.
    real(R8), allocatable        :: krho(:)
    real(R8), allocatable        :: kT(:)
    real(R8), allocatable        :: Pp(:)
    real(R8), allocatable        :: rp(:)
  end type config_dp_t

  public :: load_zone_runtime_config
  public :: load_ig_config
  public :: load_rf_config
  public :: load_sp_config
  public :: load_dp_config
  public :: sync_interpolation_config
  public :: write_icb_registry_markdown

  type(config_interpolation_t), public :: config_interpolation

contains

  subroutine load_zone_runtime_config(zoneini, cfg)
    implicit none
    type(file_ini), intent(in)          :: zoneini
    type(config_zone_runtime_t), intent(out) :: cfg
    integer :: error

    cfg%ic_type = 'homogeneous'
    cfg%has_direction = .false.
    cfg%has_range = .false.
    cfg%direction = ''
    cfg%range = 0.0_R8

    call zoneini%get(section_name='zone', option_name='type', val=cfg%ic_type, error=error)
    if (error /= 0) cfg%ic_type = 'homogeneous'

    call zoneini%get(section_name='zone', option_name='direction', val=cfg%direction, error=error)
    cfg%has_direction = error == 0

    call zoneini%get(section_name='zone', option_name='range', val=cfg%range, error=error)
    cfg%has_range = error == 0
  end subroutine load_zone_runtime_config

  subroutine load_ig_config(zoneini, cfg)
    implicit none
    type(file_ini), intent(in)      :: zoneini
    type(config_ig_t), intent(out)  :: cfg
    integer :: error

    call load_field_source(zoneini, 'mach', cfg%mach)
    call load_field_source(zoneini, 'p0', cfg%p0)
    call load_field_source(zoneini, 'T0', cfg%T0)
    call load_field_source(zoneini, 'p', cfg%p)
    call load_field_source(zoneini, 'T', cfg%T)
    call load_field_source(zoneini, 'rho', cfg%rho)
    call load_shared_velocity_config(zoneini, cfg%velocity)
    call load_shared_turbulence_config(zoneini, cfg%turbulence)
    call load_interpolation_config(zoneini, cfg%interpolation)

    cfg%nozzle_direction = 'dx'
    call zoneini%get(section_name='zone', option_name='nozzle-direction', &
                     val=cfg%nozzle_direction, error=error)
    if (error /= 0) cfg%nozzle_direction = 'dx'

    cfg%nozzle_threshold = huge(1.0_R8)
    call zoneini%get(section_name='zone', option_name='nozzle-threshold', &
                     val=cfg%nozzle_threshold, error=error)
    if (error /= 0) cfg%nozzle_threshold = huge(1.0_R8)
  end subroutine load_ig_config

  subroutine load_rf_config(zoneini, cfg)
    implicit none
    type(file_ini), intent(in)      :: zoneini
    type(config_rf_t), intent(out)  :: cfg

    call load_field_source(zoneini, 'p', cfg%p)
    call load_field_source(zoneini, 'T', cfg%T)
    call load_field_source(zoneini, 'h', cfg%h)
    call load_field_source(zoneini, 'vel', cfg%vel)
    call load_shared_velocity_config(zoneini, cfg%velocity)
    call load_shared_turbulence_config(zoneini, cfg%turbulence)
    call load_interpolation_config(zoneini, cfg%interpolation)
  end subroutine load_rf_config

  subroutine load_sp_config(zoneini, cfg)
    implicit none
    type(file_ini), intent(in)      :: zoneini
    type(config_sp_t), intent(out)  :: cfg
    integer :: error

    call load_field_source(zoneini, 'T', cfg%T)
    call load_field_source(zoneini, 'qvol', cfg%qvol)
    call load_interpolation_config(zoneini, cfg%interpolation)

    cfg%material = ''
    call zoneini%get(section_name='zone', option_name='material', val=cfg%material, &
                     error=error)
  end subroutine load_sp_config

  subroutine load_dp_config(zoneini, nnn, cfg)
    implicit none
    type(file_ini), intent(in)      :: zoneini
    integer, intent(in)             :: nnn
    type(config_dp_t), intent(out)  :: cfg
    integer :: error

    allocate(cfg%krho(1:nnn))
    allocate(cfg%kT(1:nnn))
    allocate(cfg%Pp(1:nnn))
    allocate(cfg%rp(1:nnn))
    cfg%krho = 0.0_R8
    cfg%kT = 1.0_R8
    cfg%Pp = 0.0_R8
    cfg%rp = 0.0_R8
    cfg%neuler = 0
    cfg%has_rp = .false.

    call load_interpolation_config(zoneini, cfg%interpolation)

    call zoneini%get(section_name='zone', option_name='krho', val=cfg%krho, error=error)
    call zoneini%get(section_name='zone', option_name='kT', val=cfg%kT, error=error)
    call zoneini%get(section_name='zone', option_name='Pp', val=cfg%Pp, error=error)
    if (error == 0) cfg%neuler = 1

    call zoneini%get(section_name='zone', option_name='neuler', val=cfg%neuler, error=error)

    call zoneini%get(section_name='zone', option_name='dp', val=cfg%rp, error=error)
    if (error == 0) then
      cfg%rp = 0.5_R8 * cfg%rp
      cfg%has_rp = .true.
      return
    endif

    call zoneini%get(section_name='zone', option_name='rp', val=cfg%rp, error=error)
    cfg%has_rp = error == 0
  end subroutine load_dp_config

  subroutine sync_interpolation_config(cfg)
    implicit none
    type(config_interpolation_t), intent(in) :: cfg

    config_interpolation = cfg
  end subroutine sync_interpolation_config

  subroutine load_field_source(zoneini, base_name, cfg)
    implicit none
    type(file_ini), intent(in)              :: zoneini
    character(len=*), intent(in)            :: base_name
    type(config_field_source_t), intent(out):: cfg
    character(len=64) :: file_option, dir_option
    integer :: error

    cfg%has_value = .false.
    cfg%has_file = .false.
    cfg%has_direction = .false.
    cfg%value = 0.0_R8
    cfg%file = ''
    cfg%direction = ''

    call zoneini%get(section_name='zone', option_name=trim(base_name), val=cfg%value, &
                     error=error)
    if (error == 0) then
      cfg%has_value = .true.
      return
    endif

    file_option = trim(base_name) // '-file'
    call zoneini%get(section_name='zone', option_name=trim(file_option), val=cfg%file, &
                     error=error)
    if (error /= 0) return

    cfg%has_file = .true.
    dir_option = trim(base_name) // '-direction'
    call zoneini%get(section_name='zone', option_name=trim(dir_option), val=cfg%direction, &
                     error=error)
    cfg%has_direction = error == 0
  end subroutine load_field_source

  subroutine load_interpolation_config(zoneini, cfg)
    implicit none
    type(file_ini), intent(in)               :: zoneini
    type(config_interpolation_t), intent(out):: cfg
    integer :: error

    cfg%warning_message = ''
    cfg%error_message = ''
    cfg%description = ''
    cfg%enabled = .false.
    cfg%theta = 90.0_R8
    cfg%nz = 4
    cfg%old_block_id = 0
    cfg%file = ''
    cfg%law = 'outlaw'
    cfg%old_solution = ''
    cfg%old_species = ''

    call zoneini%get(section_name='zone', option_name='old-species', val=cfg%old_species, &
                     error=error)
    if (error /= 0) cfg%old_species = ''

    call zoneini%get(section_name='zone', option_name='old-solution', &
                     val=cfg%old_solution, error=error)
    cfg%enabled = error == 0
    if (.not. cfg%enabled) cfg%old_solution = ''

    call zoneini%get(section_name='zone', option_name='old-block-id', &
                     val=cfg%old_block_id, error=error)
    if (error /= 0) cfg%old_block_id = 0

    call zoneini%get(section_name='zone', option_name='interpolation-law', val=cfg%law, &
                     error=error)
    if (error /= 0) cfg%law = 'outlaw'

    if (cfg%law == 'extrude') then
      call zoneini%get(section_name='zone', option_name='theta', val=cfg%theta, error=error)
      if (error /= 0) cfg%theta = 90.0_R8
      call zoneini%get(section_name='zone', option_name='nz', val=cfg%nz, error=error)
      if (error /= 0) cfg%nz = 4
    endif
  end subroutine load_interpolation_config

  subroutine write_icb_registry_markdown(filename)
    implicit none
    character(*), intent(in), optional :: filename

    type(registry_t) :: icb_registry
    type(atlas_parameters_t), target :: atlas_cfg
    type(config_composition_doc_t), target :: composition_cfg
    type(config_ig_t), target :: ig_cfg
    type(config_rf_t), target :: rf_cfg
    type(config_sp_t), target :: sp_cfg
    type(config_interpolation_t), target :: dp_interp_cfg
    character(len=128), target :: phase_name
    character(len=32), target :: block_type
    character(len=32), target :: direction
    character(len=32), target :: zone_name
    real(R8), target :: block_range(6)
    real(R8), target :: zone_range(6)
    real(R8), target :: dp_krho(3)
    real(R8), target :: dp_kT(3)
    real(R8), target :: dp_Pp(3)
    real(R8), target :: dp_rp(3)
    integer, target :: dp_neuler
    character(len=llen) :: fileout

    atlas_cfg%input_file = 'input.ini'
    atlas_cfg%ic_format = 'tec'
    phase_name = ''
    block_type = 'homogeneous'
    direction = ''
    zone_name = ''
    block_range = 0.0_R8
    zone_range = 0.0_R8
    composition_cfg%eq_og = .false.
    composition_cfg%eq_cea_file = ''
    composition_cfg%eq_cea_section = 1
    composition_cfg%y_species = 0.0_R8
    dp_krho = 0.0_R8
    dp_kT = 1.0_R8
    dp_Pp = 0.0_R8
    dp_rp = 0.0_R8
    dp_neuler = 0

    call add_atlas_registry_entries(icb_registry, 'ICB', atlas_cfg)
    call add_block_entries()
    call add_composition_registry_entries(icb_registry, 'ICB-Composition', composition_cfg)

    call add_field_source_entries('ICB-IG', 'mach', ig_cfg%mach, 'Ideal-gas Mach number.')
    call add_field_source_entries('ICB-IG', 'p0', ig_cfg%p0, 'Ideal-gas stagnation pressure.')
    call add_field_source_entries('ICB-IG', 'T0', ig_cfg%T0, 'Ideal-gas stagnation temperature.')
    call add_field_source_entries('ICB-IG', 'p', ig_cfg%p, 'Ideal-gas static pressure.')
    call add_field_source_entries('ICB-IG', 'T', ig_cfg%T, 'Ideal-gas static temperature.')
    call add_field_source_entries('ICB-IG', 'rho', ig_cfg%rho, 'Ideal-gas density.')
    call add_velocity_registry_entries(icb_registry, 'ICB-IG', ig_cfg%velocity)
    call add_turbulence_registry_entries(icb_registry, 'ICB-IG', ig_cfg%turbulence)
    call add_interpolation_entries('ICB-IG', ig_cfg%interpolation, .true.)
    call icb_registry%add('ICB-IG', 'nozzle-direction', ig_cfg%nozzle_direction, 'dx', &
                          'Nozzle marching direction.', 'dx,sx', .false.)
    call icb_registry%add('ICB-IG', 'nozzle-threshold', ig_cfg%nozzle_threshold, &
                          '0.0', 'Coordinate threshold separating plenum and nozzle.', &
                          '', .false.)

    call add_field_source_entries('ICB-RF', 'p', rf_cfg%p, 'Real-fluid pressure.')
    call add_field_source_entries('ICB-RF', 'T', rf_cfg%T, 'Real-fluid temperature.')
    call add_field_source_entries('ICB-RF', 'h', rf_cfg%h, 'Real-fluid enthalpy.')
    call add_field_source_entries('ICB-RF', 'vel', rf_cfg%vel, 'Real-fluid speed magnitude.')
    call add_velocity_registry_entries(icb_registry, 'ICB-RF', rf_cfg%velocity)
    call add_turbulence_registry_entries(icb_registry, 'ICB-RF', rf_cfg%turbulence)
    call add_interpolation_entries('ICB-RF', rf_cfg%interpolation, .false.)

    call add_field_source_entries('ICB-SP', 'T', sp_cfg%T, 'Solid temperature.')
    call add_field_source_entries('ICB-SP', 'qvol', sp_cfg%qvol, 'Volumetric heat source.')
    call icb_registry%add('ICB-SP', 'material', sp_cfg%material, '', &
                          'Solid material name from the phase database.', '', .false.)
    call add_interpolation_entries('ICB-SP', sp_cfg%interpolation, .false.)

    call icb_registry%add('ICB-DP', 'krho', dp_krho, '0.0', &
                          'Per-population density ratios relative to IG density.', '', .false.)
    call icb_registry%add('ICB-DP', 'kT', dp_kT, '1.0', &
                          'Per-population temperature ratios.', '', .false.)
    call icb_registry%add('ICB-DP', 'Pp', dp_Pp, '0.0', &
                          'Per-population pseudo-pressure values.', '', .false.)
    call icb_registry%add('ICB-DP', 'dp', dp_rp, '0.0', &
                          'Per-population particle diameters.', '', .false.)
    call icb_registry%add('ICB-DP', 'rp', dp_rp, '0.0', &
                          'Per-population particle radii. Use as an alternative to dp.', &
                          '', .false.)
    call icb_registry%add('ICB-DP', 'neuler', dp_neuler, '0', &
                          'Eulerian model selector for dispersed phase support fields.', &
                          '', .false.)
    call add_interpolation_entries('ICB-DP', dp_interp_cfg, .false.)

    if (present(filename)) then
      fileout = filename
    else
      fileout = 'icb-input.md'
    endif

    call icb_registry%generate_markdown(trim(fileout), 'ATLAS ICB Input Parameters')

  contains

    subroutine add_block_entries()
      call icb_registry%add('ICB-Block*', 'phase', phase_name, '', &
                            'Space-separated phase names. Blank means all phases.', &
                            '', .false.)
      call icb_registry%add('ICB-Block*', 'type', block_type, 'homogeneous', &
                            'Block initialization type.', '', .false.)
      call icb_registry%add('ICB-Block*', 'direction', direction, '', &
                            'Range directions using x,y,z,r,t,i,j,k.', '', .false.)
      call icb_registry%add('ICB-Block*', 'range', block_range, '0.0', &
                            'Range limits for the selected directions.', '', .false.)
      call icb_registry%add('ICB-Block*', 'zone<n>', zone_name, '', &
                            'Referenced auxiliary zone section for multizone setup.', &
                            '', .false.)
      call icb_registry%add('ICB-Block*', 'range<n>', zone_range, '0.0', &
                            'Range associated with zone<n>.', '', .false.)
    end subroutine add_block_entries

    subroutine add_field_source_entries(section, base_name, field_cfg, description)
      character(*), intent(in) :: section, base_name, description
      type(config_field_source_t), target, intent(inout) :: field_cfg
      character(len=64) :: file_key, dir_key

      file_key = trim(base_name)//'-file'
      dir_key = trim(base_name)//'-direction'

      call icb_registry%add(section, trim(base_name), field_cfg%value, '0.0', &
                            trim(description), '', .false.)
      call icb_registry%add(section, trim(file_key), field_cfg%file, '', &
                            'File-backed input for '//trim(base_name)//'.', &
                            '', .false.)
      call icb_registry%add(section, trim(dir_key), field_cfg%direction, '', &
                            'Direction for 1D '//trim(base_name)//' profiles.', &
                            'x,y,z,r,t', .false.)
    end subroutine add_field_source_entries

    subroutine add_interpolation_entries(section, interp_cfg, include_old_species)
      character(*), intent(in) :: section
      type(config_interpolation_t), target, intent(inout) :: interp_cfg
      logical, intent(in) :: include_old_species

      call icb_registry%add(section, 'old-solution', interp_cfg%old_solution, '', &
                            'Previous solution file used for interpolation.', &
                            '', .false.)
      call icb_registry%add(section, 'old-block-id', interp_cfg%old_block_id, '0', &
                            'Source block index for interpolation. Zero means auto.', &
                            '>=0', .false.)
      call icb_registry%add(section, 'interpolation-law', interp_cfg%law, 'outlaw', &
                            'Interpolation mapping law.', '', .false.)
      call icb_registry%add(section, 'theta', interp_cfg%theta, '90.0', &
                            'Extrusion angle used by the extrude law.', '', .false.)
      call icb_registry%add(section, 'nz', interp_cfg%nz, '4', &
                            'Number of extrusion layers used by the extrude law.', &
                            '>=1', .false.)

      if (include_old_species) then
        call icb_registry%add(section, 'old-species', interp_cfg%old_species, '', &
                              'Legacy species file prefix used during IG interpolation.', &
                              '', .false.)
      endif
    end subroutine add_interpolation_entries

  end subroutine write_icb_registry_markdown

end module config_mod