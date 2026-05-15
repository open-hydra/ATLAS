module config_stb_mod
  use iso_fortran_env, only: R8 => real64
  use finer,           only: file_ini
  use global_mod,      only: llen
  use registry_mod,    only: registry_t
  use config_shared_mod

  implicit none
  private

  type, public :: config_source_t
    logical             :: has_value = .false.
    logical             :: has_file = .false.
    logical             :: has_direction = .false.
    real(R8)            :: value = 0.0_R8
    character(len=llen) :: file = ''
    character(len=20)   :: direction = ''
  end type config_source_t

  type, public :: config_t
    character(len=16)     :: var_type = ''
    type(config_source_t) :: var
  end type config_t

  type, public :: config_area_variation_t
    logical             :: has_profile = .false.
    character(len=llen) :: file = ''
    character(len=20)   :: direction = ''
  end type config_area_variation_t

  public :: load_var_config
  public :: load_area_variation_config
  public :: write_stb_registry_markdown

contains

  ! Load variable configuration for a single STB block from INI file
  subroutine load_var_config(section_name, sini, name, cfg)
    implicit none
    character(*),   intent(in)  :: section_name
    type(file_ini), intent(in)  :: sini
    character(*),   intent(in)  :: name
    type(config_t), intent(out) :: cfg
    integer :: error

    ! Default initialization
    cfg%var_type = ''
    cfg%var%has_value = .false.
    cfg%var%has_file = .false.
    cfg%var%has_direction = .false.
    cfg%var%value = 0.0_R8
    cfg%var%file = ''
    cfg%var%direction = ''

    call sini%get(section_name=section_name, option_name='direction', val=cfg%var%direction, error=error)
    cfg%var%has_direction = (error == 0 .and. len_trim(cfg%var%direction) > 0)

    call sini%get(section_name=section_name, option_name=trim(name)//'-file', val=cfg%var%file, error=error)
    cfg%var%has_file = (error == 0)

    call sini%get(section_name=section_name, option_name=trim(name), val=cfg%var%value, error=error)
    cfg%var%has_value = (error == 0)

  end subroutine load_var_config

  ! Load area variation configuration for a single STB block from INI file
  subroutine load_area_variation_config(section_name, sini, cfg)
    implicit none
    character(*), intent(in) :: section_name
    type(file_ini), intent(in) :: sini
    type(config_area_variation_t), intent(out) :: cfg

    integer :: error

    cfg%has_profile = .false.
    cfg%file = ''
    cfg%direction = ''

    call sini%get(section_name=section_name, option_name='x-areavariation', &
                  val=cfg%file, error=error)
    if (error == 0 .and. len_trim(cfg%file) > 0) then
      cfg%has_profile = .true.
      cfg%direction = 'x'
      return
    endif

    call sini%get(section_name=section_name, option_name='y-areavariation', &
                  val=cfg%file, error=error)
    if (error == 0 .and. len_trim(cfg%file) > 0) then
      cfg%has_profile = .true.
      cfg%direction = 'y'
      return
    endif

    call sini%get(section_name=section_name, option_name='r-areavariation', &
                  val=cfg%file, error=error)
    if (error == 0 .and. len_trim(cfg%file) > 0) then
      cfg%has_profile = .true.
      cfg%direction = 'r'
      return
    endif

    call sini%get(section_name=section_name, option_name='theta-areavariation', &
                  val=cfg%file, error=error)
    if (error == 0 .and. len_trim(cfg%file) > 0) then
      cfg%has_profile = .true.
      cfg%direction = 't'
      return
    endif
  end subroutine load_area_variation_config

  ! Generate STB registry documentation (Markdown format, registry-based like ICB)
  subroutine write_stb_registry_markdown(filename)
    implicit none
    character(*), intent(in), optional :: filename

    type(registry_t) :: stb_registry
    type(atlas_parameters_t), target :: atlas_cfg
    type(config_source_t), target :: qvol_cfg
    character(len=llen) :: fileout
    character(len=32), target :: var_name
    character(len=32), target :: direction

    ! Initialize registry and defaults
    atlas_cfg%input_file = 'input.ini'
    atlas_cfg%ic_format = 'tec'
    var_name = 'qvol'
    direction = ''
    qvol_cfg%value = 0.0_R8
    qvol_cfg%file = ''
    qvol_cfg%direction = ''

    ! Add common/global registry entries
    call add_atlas_registry_entries(stb_registry, 'STB', atlas_cfg)

    ! Add STB-specific block entries
    call add_stb_block_entries()

    ! Add qvol source entries
    call add_source_entries('STB-Block*', 'qvol', qvol_cfg, 'Volumetric heat source')

    ! Write markdown output
    if (present(filename)) then
      fileout = filename
    else
      fileout = 'stb-input.md'
    endif

    call stb_registry%generate_markdown(trim(fileout), 'ATLAS STB Input Parameters')

  contains

    subroutine add_stb_block_entries()
      call stb_registry%add('STB-Block*', 'direction', direction, '', &
                           'Direction for 1D profiles: x,y,z,r,t or combinations.', &
                           'x,y,z,r,t', .false.)
      call stb_registry%add('STB-Block*', 'x-areavariation', qvol_cfg%file, '', &
                           'Area profile file for x-directed variation.', '', .false.)
      call stb_registry%add('STB-Block*', 'y-areavariation', qvol_cfg%file, '', &
                           'Area profile file for y-directed variation.', '', .false.)
      call stb_registry%add('STB-Block*', 'r-areavariation', qvol_cfg%file, '', &
                           'Area profile file for radial variation.', '', .false.)
      call stb_registry%add('STB-Block*', 'theta-areavariation', qvol_cfg%file, '', &
                           'Area profile file for azimuthal variation (degrees in file).', '', .false.)
    end subroutine add_stb_block_entries

    subroutine add_source_entries(section, base_name, source_cfg, description)
      character(*), intent(in) :: section, base_name, description
      type(config_source_t), target, intent(inout) :: source_cfg
      character(len=64) :: file_key

      file_key = trim(base_name)//'-file'

      call stb_registry%add(section, trim(base_name), source_cfg%value, '0.0', &
                           'Uniform '//trim(description)//' value.', '', .false.)
      call stb_registry%add(section, trim(file_key), source_cfg%file, '', &
                           'File path for 1D profile or 3D field input.', '', .false.)
    end subroutine add_source_entries

  end subroutine write_stb_registry_markdown

end module config_stb_mod
