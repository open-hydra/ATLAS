module bcb_config_mod
  use iso_fortran_env, only: R8 => real64
  use registry_mod,    only: registry_t
  use finer,           only: file_ini
  use global_mod,      only: llen
  use phase_mod,       only: phase_t
  use bc_names_mod
  use config_shared_mod

  implicit none
  private

  integer, parameter         :: max_faces = 6
  integer, parameter, public :: n_variable_file_keys = 18

  character(len=10), parameter, public :: variable_file_keys(n_variable_file_keys) = [ &
    'ks        ', 'q         ', 'T         ', 'Tref      ', 'hconv     ', &
    'qrad      ', 'eps       ', 'alpha     ', 'beta      ', 'g         ', &
    'krho      ', 'a         ', 'n         ', 'pRef      ', 'rhoGrain  ', &
    'Taf       ', 'SFgeo     ', 'SF        ' ]

  type, public :: bcb_block_config_t
    logical             :: has_phase = .false.
    character(len=llen) :: phase = ''
    character(len=50)   :: face_names(max_faces) = ''
  end type bcb_block_config_t

  type, public :: bcb_face_patch_t
    character(len=50) :: name = ''
    real(R8)          :: range(4) = 0.0_R8
  end type bcb_face_patch_t

  type, public :: bcb_face_setup_t
    character(len=50) :: name = ''
    character(len=20) :: definition = ''
    logical           :: multipatch = .false.
    logical           :: has_direction = .false.
    character(len=7)  :: direction = ''
    integer           :: patch_count = 0
    type(bcb_face_patch_t), allocatable :: patches(:)
  end type bcb_face_setup_t

  type, public :: bcb_periodic_config_t
    integer :: blocks(2) = 0
    integer :: faces(2) = 0
    logical :: has_connection = .false.
  end type bcb_periodic_config_t

  type, public :: bcb_manifold_config_t
    integer :: block = 0
    integer :: face = 0
  end type bcb_manifold_config_t

  type, public :: bcb_wall_fluid_config_t
    real(R8) :: q = 0.0_R8
    real(R8) :: T = 0.0_R8
    real(R8) :: ks = 0.0_R8
    real(R8) :: qrad = 0.0_R8
    real(R8) :: eps = 0.0_R8
    logical  :: has_q = .false.
    logical  :: has_T = .false.
    logical  :: has_ks = .false.
    logical  :: has_qrad = .false.
    logical  :: has_eps = .false.
  end type bcb_wall_fluid_config_t

  type, public :: bcb_wall_solid_config_t
    real(R8) :: q = 0.0_R8
    real(R8) :: T = 0.0_R8
    real(R8) :: qrad = 0.0_R8
    real(R8) :: hconv = 0.0_R8
    real(R8) :: Tref = 0.0_R8
    real(R8) :: eps = 0.0_R8
    logical  :: has_q = .false.
    logical  :: has_T = .false.
    logical  :: has_qrad = .false.
    logical  :: has_hconv = .false.
    logical  :: has_Tref = .false.
    logical  :: has_eps = .false.
  end type bcb_wall_solid_config_t

  type, public :: bcb_ig_boundary_config_t
    real(R8) :: p0 = 0.0_R8
    real(R8) :: T0 = 0.0_R8
    real(R8) :: h0 = 0.0_R8
    real(R8) :: mach = 0.0_R8
    real(R8) :: T = 0.0_R8
    real(R8) :: g = 0.0_R8
    real(R8) :: p = 0.0_R8
    real(R8) :: rel_fac = 1.0_R8
    real(R8) :: Ae_At = 0.0_R8
    real(R8) :: rt = 0.0_R8
    real(R8) :: psup = 0.0_R8
    real(R8) :: psub = 0.0_R8
    character(len=32) :: p0_time_file = 'none'
    character(len=32) :: p_time_file = 'none'
    character(len=32) :: time_file = 'none'
    logical           :: periodic = .false.
    type(config_velocity_t)   :: velocity
    type(config_turbulence_t) :: turbulence
  end type bcb_ig_boundary_config_t

  type, public :: bcb_srm_config_t
    real(R8) :: a = 0.0_R8
    real(R8) :: n = 0.0_R8
    real(R8) :: pRef = 1.0_R8
    real(R8) :: rhoGrain = 0.0_R8
    real(R8) :: SF = 1.0_R8
    type(config_turbulence_t) :: turbulence
  end type bcb_srm_config_t

  type, public :: bcb_dp_material_config_t
    integer :: npcp = 0
    logical :: has_gp = .false.
    real(R8), allocatable :: krho(:)
    real(R8), allocatable :: kV(:)
    real(R8), allocatable :: kT(:)
    real(R8), allocatable :: gp(:)
    real(R8), allocatable :: up(:)
    real(R8), allocatable :: vp(:)
    real(R8), allocatable :: wp(:)
    real(R8), allocatable :: velocity_magnitude(:)
    real(R8), allocatable :: Tp(:)
    real(R8), allocatable :: rp(:)
    real(R8), allocatable :: sigmap(:)
    real(R8), allocatable :: alphap(:)
    real(R8), allocatable :: betap(:)
    real(R8), allocatable :: rRes(:)
    real(R8), allocatable :: Tsat(:)
  end type bcb_dp_material_config_t

  type, public :: bcb_dp_boundary_config_t
    type(bcb_dp_material_config_t), allocatable :: materials(:)
  end type bcb_dp_boundary_config_t

  public :: load_bcb_block_config
  public :: load_bcb_face_setup
  public :: load_bcb_periodic_config
  public :: load_bcb_manifold_config
  public :: load_bcb_wall_fluid_config
  public :: load_bcb_wall_solid_config
  public :: load_bcb_ig_boundary_config
  public :: load_bcb_srm_config
  public :: load_bcb_dp_boundary_config
  public :: write_bcb_registry_markdown

contains

  subroutine load_bcb_block_config(sini, section_name, nfaces, cfg)
    implicit none
    type(file_ini), intent(in)            :: sini
    character(*), intent(in)              :: section_name
    integer, intent(in)                   :: nfaces
    type(bcb_block_config_t), intent(out) :: cfg

    character(len=4) :: ind
    integer :: error, ff

    cfg%has_phase = .false.
    cfg%phase = ''
    cfg%face_names = ''

    call sini%get(section_name=section_name, option_name='phase', val=cfg%phase, error=error)
    cfg%has_phase = error == 0

    do ff = 1, min(nfaces, max_faces)
      write(ind, '(I4)') ff
      call sini%get(section_name=section_name, option_name='face'//trim(adjustl(ind)), &
                    val=cfg%face_names(ff), error=error)
      if (error /= 0) cfg%face_names(ff) = ''
    enddo
  end subroutine load_bcb_block_config

  subroutine load_bcb_face_setup(sini, bc_name, cfg)
    implicit none
    type(file_ini), intent(in)           :: sini
    character(*), intent(in)             :: bc_name
    type(bcb_face_setup_t), intent(out)  :: cfg

    character(len=:), allocatable :: option_pairs(:)
    character(len=4) :: ind
    integer :: error, patch_error, patch_count, p

    cfg%name = bc_name
    cfg%definition = ''
    cfg%multipatch = .false.
    cfg%has_direction = .false.
    cfg%direction = ''
    cfg%patch_count = 0
    if (allocated(cfg%patches)) deallocate(cfg%patches)

    do while (sini%loop(section_name=trim(bc_name), option_pairs=option_pairs))
      if (index(option_pairs(1), 'patch') == 1) cfg%multipatch = .true.
    enddo

    call sini%get(section_name=trim(bc_name), option_name='type', val=cfg%definition, &
                  error=error)
    if (error == 0) then
      call check_assignment_with_input(trim(cfg%definition), cfg%definition)
    elseif (.not. cfg%multipatch) then
      call check_assignment_no_input(trim(cfg%name), cfg%definition)
    endif

    call sini%get(section_name=trim(bc_name), option_name='direction', val=cfg%direction, &
                  error=error)
    cfg%has_direction = error == 0

    if (.not. cfg%multipatch) return
    if (.not. cfg%has_direction) return

    patch_count = 0
    do
      patch_count = patch_count + 1
      write(ind, '(I4)') patch_count
      call sini%get(section_name=trim(bc_name), option_name='patch'//trim(adjustl(ind)), &
                    val=cfg%name, error=patch_error)
      if (patch_error /= 0) exit
    enddo

    cfg%patch_count = patch_count - 1
    if (cfg%patch_count <= 0) return

    allocate(cfg%patches(1:cfg%patch_count))
    do p = 1, cfg%patch_count
      write(ind, '(I4)') p
      call sini%get(section_name=trim(bc_name), option_name='patch'//trim(adjustl(ind)), &
                    val=cfg%patches(p)%name, error=error)
      call sini%get(section_name=trim(bc_name), option_name='range'//trim(adjustl(ind)), &
                    val=cfg%patches(p)%range, error=error)
      if (error /= 0) cfg%patches(p)%range = 0.0_R8
    enddo

    cfg%name = bc_name
  end subroutine load_bcb_face_setup

  subroutine load_bcb_periodic_config(sourceini, section, cfg)
    implicit none
    type(file_ini), intent(in)               :: sourceini
    character(*), intent(in)                 :: section
    type(bcb_periodic_config_t), intent(out) :: cfg

    integer :: error

    cfg%blocks = 0
    cfg%faces = 0
    cfg%has_connection = .false.

    call sourceini%get(section_name=section, option_name='blocks', val=cfg%blocks, error=error)
    cfg%has_connection = error == 0
    call sourceini%get(section_name=section, option_name='faces', val=cfg%faces, error=error)
    cfg%has_connection = cfg%has_connection .and. error == 0
  end subroutine load_bcb_periodic_config

  subroutine load_bcb_manifold_config(sourceini, section, cfg)
    implicit none
    type(file_ini), intent(in)               :: sourceini
    character(*), intent(in)                 :: section
    type(bcb_manifold_config_t), intent(out) :: cfg

    integer :: error

    cfg%block = 0
    cfg%face = 0

    call sourceini%get(section_name=section, option_name='block', val=cfg%block, error=error)
    if (error /= 0) cfg%block = 0
    call sourceini%get(section_name=section, option_name='face', val=cfg%face, error=error)
    if (error /= 0) cfg%face = 0
  end subroutine load_bcb_manifold_config

  subroutine load_bcb_wall_fluid_config(sourceini, section, cfg)
    implicit none
    type(file_ini), intent(in)                 :: sourceini
    character(*), intent(in)                   :: section
    type(bcb_wall_fluid_config_t), intent(out) :: cfg

    integer :: error

    call sourceini%get(section_name=section, option_name='q', val=cfg%q, error=error)
    cfg%has_q = error == 0
    if (.not. cfg%has_q) cfg%q = 0.0_R8

    call sourceini%get(section_name=section, option_name='T', val=cfg%T, error=error)
    cfg%has_T = error == 0
    if (.not. cfg%has_T) cfg%T = 0.0_R8

    call sourceini%get(section_name=section, option_name='ks', val=cfg%ks, error=error)
    cfg%has_ks = error == 0
    if (.not. cfg%has_ks) cfg%ks = 0.0_R8

    call sourceini%get(section_name=section, option_name='qrad', val=cfg%qrad, error=error)
    cfg%has_qrad = error == 0
    if (.not. cfg%has_qrad) cfg%qrad = 0.0_R8

    call sourceini%get(section_name=section, option_name='eps', val=cfg%eps, error=error)
    cfg%has_eps = error == 0
    if (.not. cfg%has_eps) cfg%eps = 0.0_R8
  end subroutine load_bcb_wall_fluid_config

  subroutine load_bcb_wall_solid_config(sourceini, section, cfg)
    implicit none
    type(file_ini), intent(in)                 :: sourceini
    character(*), intent(in)                   :: section
    type(bcb_wall_solid_config_t), intent(out) :: cfg

    integer :: error

    call sourceini%get(section_name=section, option_name='q', val=cfg%q, error=error)
    cfg%has_q = error == 0
    if (.not. cfg%has_q) cfg%q = 0.0_R8

    call sourceini%get(section_name=section, option_name='T', val=cfg%T, error=error)
    cfg%has_T = error == 0
    if (.not. cfg%has_T) cfg%T = 0.0_R8

    call sourceini%get(section_name=section, option_name='qrad', val=cfg%qrad, error=error)
    cfg%has_qrad = error == 0
    if (.not. cfg%has_qrad) cfg%qrad = 0.0_R8

    call sourceini%get(section_name=section, option_name='hconv', val=cfg%hconv, error=error)
    cfg%has_hconv = error == 0
    if (.not. cfg%has_hconv) cfg%hconv = 0.0_R8

    call sourceini%get(section_name=section, option_name='Tref', val=cfg%Tref, error=error)
    cfg%has_Tref = error == 0
    if (.not. cfg%has_Tref) cfg%Tref = 0.0_R8

    call sourceini%get(section_name=section, option_name='eps', val=cfg%eps, error=error)
    cfg%has_eps = error == 0
    if (.not. cfg%has_eps) cfg%eps = 0.0_R8
  end subroutine load_bcb_wall_solid_config

  subroutine load_bcb_ig_boundary_config(sourceini, section, cfg)
    implicit none
    type(file_ini), intent(in)                  :: sourceini
    character(*), intent(in)                    :: section
    type(bcb_ig_boundary_config_t), intent(out) :: cfg

    integer :: error

    call sourceini%get(section_name=section, option_name='mach', val=cfg%mach, error=error)
    if (error /= 0) cfg%mach = 0.0_R8
    call sourceini%get(section_name=section, option_name='p0', val=cfg%p0, error=error)
    if (error /= 0) cfg%p0 = 0.0_R8
    call sourceini%get(section_name=section, option_name='T0', val=cfg%T0, error=error)
    if (error /= 0) cfg%T0 = 0.0_R8
    call sourceini%get(section_name=section, option_name='h0', val=cfg%h0, error=error)
    if (error /= 0) cfg%h0 = 0.0_R8
    call sourceini%get(section_name=section, option_name='T', val=cfg%T, error=error)
    if (error /= 0) cfg%T = 0.0_R8
    call sourceini%get(section_name=section, option_name='g', val=cfg%g, error=error)
    if (error /= 0) cfg%g = 0.0_R8
    call sourceini%get(section_name=section, option_name='p', val=cfg%p, error=error)
    if (error /= 0) cfg%p = 0.0_R8

    call sourceini%get(section_name=section, option_name='p0-time-file', val=cfg%p0_time_file, error=error)
    if (error /= 0) cfg%p0_time_file = 'none'
    call sourceini%get(section_name=section, option_name='p-time-file', val=cfg%p_time_file, error=error)
    if (error /= 0) cfg%p_time_file = 'none'
    call sourceini%get(section_name=section, option_name='time-file', val=cfg%time_file, error=error)
    if (error /= 0) cfg%time_file = 'none'
    call sourceini%get(section_name=section, option_name='periodic', val=cfg%periodic, error=error)
    if (error /= 0) cfg%periodic = .false.

    call sourceini%get(section_name=section, option_name='rf', val=cfg%rel_fac, error=error)
    if (error /= 0) cfg%rel_fac = 1.0_R8

    call sourceini%get(section_name=section, option_name='Ae_At', val=cfg%Ae_At, error=error)
    if (error /= 0) cfg%Ae_At = 0.0_R8
    call sourceini%get(section_name=section, option_name='rt', val=cfg%rt, error=error)
    if (error /= 0) cfg%rt = 0.0_R8
    call sourceini%get(section_name=section, option_name='psub', val=cfg%psub, error=error)
    if (error /= 0) cfg%psub = 0.0_R8
    call sourceini%get(section_name=section, option_name='psup', val=cfg%psup, error=error)
    if (error /= 0) cfg%psup = 0.0_R8

    call load_shared_velocity_config(sourceini, cfg%velocity, section)
    call load_shared_turbulence_config(sourceini, cfg%turbulence, section)
  end subroutine load_bcb_ig_boundary_config

  subroutine load_bcb_srm_config(sourceini, section, cfg)
    implicit none
    type(file_ini), intent(in)            :: sourceini
    character(*), intent(in)              :: section
    type(bcb_srm_config_t), intent(out)   :: cfg

    integer :: error

    call load_shared_turbulence_config(sourceini, cfg%turbulence, section)

    call sourceini%get(section_name=section, option_name='a', val=cfg%a, error=error)
    if (error /= 0) cfg%a = 0.0_R8
    call sourceini%get(section_name=section, option_name='n', val=cfg%n, error=error)
    if (error /= 0) cfg%n = 0.0_R8
    call sourceini%get(section_name=section, option_name='pRef', val=cfg%pRef, error=error)
    if (error /= 0) cfg%pRef = 1.0_R8
    call sourceini%get(section_name=section, option_name='rhoGrain', val=cfg%rhoGrain, error=error)
    if (error /= 0) cfg%rhoGrain = 0.0_R8
    call sourceini%get(section_name=section, option_name='SF', val=cfg%SF, error=error)
    if (error /= 0) cfg%SF = 1.0_R8
  end subroutine load_bcb_srm_config

  subroutine load_bcb_dp_boundary_config(sourceini, section, phase, cfg)
    implicit none
    type(file_ini), intent(in)                   :: sourceini
    character(*), intent(in)                     :: section
    type(phase_t), intent(in)                    :: phase
    type(bcb_dp_boundary_config_t), intent(out)  :: cfg

    integer :: error, m, npcp

    allocate(cfg%materials(1:phase%material%n))
    do m = 1, phase%material%n
      npcp = phase%material%npCP(m)
      cfg%materials(m)%npcp = npcp

      allocate(cfg%materials(m)%krho(1:npcp))
      allocate(cfg%materials(m)%kV(1:npcp))
      allocate(cfg%materials(m)%kT(1:npcp))
      allocate(cfg%materials(m)%gp(1:npcp))
      allocate(cfg%materials(m)%up(1:npcp))
      allocate(cfg%materials(m)%vp(1:npcp))
      allocate(cfg%materials(m)%wp(1:npcp))
      allocate(cfg%materials(m)%velocity_magnitude(1:npcp))
      allocate(cfg%materials(m)%Tp(1:npcp))
      allocate(cfg%materials(m)%rp(1:npcp))
      allocate(cfg%materials(m)%sigmap(1:npcp))
      allocate(cfg%materials(m)%alphap(1:npcp))
      allocate(cfg%materials(m)%betap(1:npcp))
      allocate(cfg%materials(m)%rRes(1:npcp))
      allocate(cfg%materials(m)%Tsat(1:npcp))

      cfg%materials(m)%krho = 0.0_R8
      cfg%materials(m)%kV = 1.0_R8
      cfg%materials(m)%kT = 1.0_R8
      cfg%materials(m)%gp = 0.0_R8
      cfg%materials(m)%up = 0.0_R8
      cfg%materials(m)%vp = 0.0_R8
      cfg%materials(m)%wp = 0.0_R8
      cfg%materials(m)%velocity_magnitude = 0.0_R8
      cfg%materials(m)%Tp = 0.0_R8
      cfg%materials(m)%rp = 0.0_R8
      cfg%materials(m)%sigmap = 0.0_R8
      cfg%materials(m)%alphap = huge(1.0_R8)
      cfg%materials(m)%betap = huge(1.0_R8)
      cfg%materials(m)%rRes = 0.0_R8
      cfg%materials(m)%Tsat = 0.0_R8
      cfg%materials(m)%has_gp = .false.

      call sourceini%get(section_name=section, option_name='krho', val=cfg%materials(m)%krho, error=error)
      call sourceini%get(section_name=section, option_name='kV',   val=cfg%materials(m)%kV, error=error)
      call sourceini%get(section_name=section, option_name='kT',   val=cfg%materials(m)%kT, error=error)
      call sourceini%get(section_name=section, option_name='gp',   val=cfg%materials(m)%gp, error=error)
      cfg%materials(m)%has_gp = error == 0
      call sourceini%get(section_name=section, option_name='up',   val=cfg%materials(m)%up, error=error)
      call sourceini%get(section_name=section, option_name='vp',   val=cfg%materials(m)%vp, error=error)
      call sourceini%get(section_name=section, option_name='wp',   val=cfg%materials(m)%wp, error=error)
      call sourceini%get(section_name=section, option_name='Vp',   val=cfg%materials(m)%velocity_magnitude, error=error)
      if (error /= 0) then
        cfg%materials(m)%velocity_magnitude = sqrt(cfg%materials(m)%up**2 + &
                                                   cfg%materials(m)%vp**2 + &
                                                   cfg%materials(m)%wp**2)
      endif
      call sourceini%get(section_name=section, option_name='Tp',   val=cfg%materials(m)%Tp, error=error)
      call sourceini%get(section_name=section, option_name='rp',   val=cfg%materials(m)%rp, error=error)
      call sourceini%get(section_name=section, option_name='dp',   val=cfg%materials(m)%rp, error=error)
      if (error == 0) cfg%materials(m)%rp = 0.5_R8 * cfg%materials(m)%rp
      call sourceini%get(section_name=section, option_name='sigmap', val=cfg%materials(m)%sigmap, error=error)
      call sourceini%get(section_name=section, option_name='alphap', val=cfg%materials(m)%alphap, error=error)
      call sourceini%get(section_name=section, option_name='betap',  val=cfg%materials(m)%betap, error=error)
      call sourceini%get(section_name=section, option_name='rRes',   val=cfg%materials(m)%rRes, error=error)
      call sourceini%get(section_name=section, option_name='Tsat',   val=cfg%materials(m)%Tsat, error=error)

      if (all(cfg%materials(m)%rRes == 0.0_R8)) cfg%materials(m)%rRes = cfg%materials(m)%rp
    enddo
  end subroutine load_bcb_dp_boundary_config

  subroutine write_bcb_registry_markdown(filename)
    implicit none
    character(*), intent(in), optional :: filename

    type(registry_t) :: bcb_registry
    type(atlas_parameters_t), target :: atlas_cfg
    type(config_composition_doc_t), target :: composition_cfg
    type(config_velocity_t), target :: velocity_cfg
    type(config_turbulence_t), target :: turbulence_cfg
    character(len=llen), target :: phase_name
    character(len=50), target :: face_name
    character(len=20), target :: bc_type
    character(len=7), target :: direction
    character(len=50), target :: patch_name
    real(R8), target :: patch_range(4)
    integer, target :: periodic_blocks(2)
    integer, target :: periodic_faces(2)
    integer, target :: manifold_block
    integer, target :: manifold_face
    character(len=7), target :: file_direction
    type(bcb_wall_fluid_config_t), target :: wall_fluid_cfg
    type(bcb_wall_solid_config_t), target :: wall_solid_cfg
    type(bcb_ig_boundary_config_t), target :: ig_cfg
    type(bcb_srm_config_t), target :: srm_cfg
    real(R8), target :: dp_scalar(3)
    character(len=32), target :: time_file
    logical, target :: periodic
    real(R8), target :: relaxation_factor
    real(R8), target :: nozzle_scalar
    character(len=llen) :: fileout
    integer :: ff

    atlas_cfg%input_file = 'input.ini'
    atlas_cfg%bc_force_connect = .true.
    atlas_cfg%bc_chimera = .false.
    composition_cfg%eq_og = .false.
    composition_cfg%eq_cea_file = ''
    composition_cfg%eq_cea_section = 1
    composition_cfg%y_species = 0.0_R8
    phase_name = ''
    face_name = ''
    bc_type = MARKER_NULL
    direction = ''
    patch_name = ''
    patch_range = 0.0_R8
    periodic_blocks = 0
    periodic_faces = 0
    manifold_block = 0
    manifold_face = 0
    file_direction = ''
    wall_fluid_cfg = bcb_wall_fluid_config_t()
    wall_solid_cfg = bcb_wall_solid_config_t()
    ig_cfg = bcb_ig_boundary_config_t()
    srm_cfg = bcb_srm_config_t()
    dp_scalar = 0.0_R8
    time_file = 'none'
    periodic = .false.
    relaxation_factor = 1.0_R8
    nozzle_scalar = 0.0_R8

    call add_atlas_registry_entries(bcb_registry, 'BCB', atlas_cfg)

    call bcb_registry%add('BCB-Block*', 'phase', phase_name, '', &
                          'Space-separated phase names. Blank means all phases.', &
                          '', .false.)
    do ff = 1, max_faces
      call bcb_registry%add('BCB-Block*', 'face'//trim(adjustl(face_index(ff))), &
                            face_name, '', 'Boundary section name assigned to face '// &
                            trim(adjustl(face_index(ff)))//'.', '', .false.)
    enddo

    call bcb_registry%add('BCB-Boundary*', 'type', bc_type, MARKER_NULL, &
                          'Boundary-condition type for the named section.', &
                          boundary_type_list(), .false.)
    call bcb_registry%add('BCB-Boundary*', 'direction', direction, '', &
                          'Patch directions using x,y,z,r,t,i,j,k.', '', .false.)
    call bcb_registry%add('BCB-Boundary*', 'patch<n>', patch_name, '', &
                          'Named sub-patch section used by multipatch boundaries.', &
                          '', .false.)
    call bcb_registry%add('BCB-Boundary*', 'range<n>', patch_range, '0.0', &
                          'Sub-patch limits associated with patch<n>.', '', .false.)
    call bcb_registry%add('BCB-Boundary*', 'blocks', periodic_blocks, '0', &
                          'Periodic source and destination block indices.', '', .false.)
    call bcb_registry%add('BCB-Boundary*', 'faces', periodic_faces, '0', &
                          'Periodic source and destination face indices.', '', .false.)
    call bcb_registry%add('BCB-Boundary*', 'block', manifold_block, '0', &
                          'Connected block index for manifold boundaries.', '', .false.)
    call bcb_registry%add('BCB-Boundary*', 'face', manifold_face, '0', &
                          'Connected face index for manifold boundaries.', '', .false.)
    call bcb_registry%add('BCB-Boundary*', 'file-direction', file_direction, '', &
                          'Coordinate or index directions used by varying BC files.', &
                          '', .false.)

    call add_composition_registry_entries(bcb_registry, 'BCB-Composition', composition_cfg)

    call add_velocity_registry_entries(bcb_registry, 'BCB-IG', velocity_cfg)
    call add_turbulence_registry_entries(bcb_registry, 'BCB-IG', turbulence_cfg)
    call add_ig_entries()
    call add_wall_entries()
    call add_dp_entries()
    call add_srm_entries()
    call add_variable_file_entries()

    if (present(filename)) then
      fileout = filename
    else
      fileout = 'bcb-input.md'
    endif

    call bcb_registry%generate_markdown(trim(fileout), 'ATLAS BCB Input Parameters')

  contains

    subroutine add_ig_entries()
      call bcb_registry%add('BCB-IG', 'mach', ig_cfg%mach, '0.0', &
                            'Ideal-gas Mach number.', '', .false.)
      call bcb_registry%add('BCB-IG', 'p0', ig_cfg%p0, '0.0', &
                            'Ideal-gas stagnation pressure.', '', .false.)
      call bcb_registry%add('BCB-IG', 'T0', ig_cfg%T0, '0.0', &
                            'Ideal-gas stagnation temperature.', '', .false.)
      call bcb_registry%add('BCB-IG', 'h0', ig_cfg%h0, '0.0', &
                            'Ideal-gas stagnation enthalpy.', '', .false.)
      call bcb_registry%add('BCB-IG', 'T', ig_cfg%T, '0.0', &
                            'Ideal-gas static temperature.', '', .false.)
      call bcb_registry%add('BCB-IG', 'g', ig_cfg%g, '0.0', &
                            'Mass flux for inlet boundaries.', '', .false.)
      call bcb_registry%add('BCB-IG', 'p', ig_cfg%p, '0.0', &
                            'Static pressure for outlet or mixed inflow boundaries.', &
                            '', .false.)
      call bcb_registry%add('BCB-IG', 'p0-time-file', ig_cfg%p0_time_file, 'none', &
                            'Time-series file for total pressure.', '', .false.)
      call bcb_registry%add('BCB-IG', 'p-time-file', ig_cfg%p_time_file, 'none', &
                            'Time-series file for static pressure.', '', .false.)
      call bcb_registry%add('BCB-IG', 'time-file', time_file, 'none', &
                            'Full time-varying boundary data file.', '', .false.)
      call bcb_registry%add('BCB-IG', 'periodic', periodic, 'F', &
                            'Treat a time-file series as periodic.', '', .false.)
      call bcb_registry%add('BCB-IG', 'rf', relaxation_factor, '1.0', &
                            'Boundary relaxation factor.', '', .false.)
      call bcb_registry%add('BCB-IG', 'Ae_At', nozzle_scalar, '0.0', &
                            'Nozzle exit-to-throat area ratio.', '>=1', .false.)
      call bcb_registry%add('BCB-IG', 'rt', nozzle_scalar, '0.0', &
                            'Nozzle throat loading parameter.', '', .false.)
      call bcb_registry%add('BCB-IG', 'psub', nozzle_scalar, '0.0', &
                            'Subsonic exit pressure used with rt.', '', .false.)
      call bcb_registry%add('BCB-IG', 'psup', nozzle_scalar, '0.0', &
                            'Supersonic exit pressure used with rt.', '', .false.)
    end subroutine add_ig_entries

    subroutine add_wall_entries()
      call bcb_registry%add('BCB-Wall-Fluid', 'q', wall_fluid_cfg%q, '0.0', &
                            'Prescribed wall heat flux.', '', .false.)
      call bcb_registry%add('BCB-Wall-Fluid', 'T', wall_fluid_cfg%T, '0.0', &
                            'Prescribed wall temperature.', '', .false.)
      call bcb_registry%add('BCB-Wall-Fluid', 'ks', wall_fluid_cfg%ks, '0.0', &
                            'Wall roughness height.', '', .false.)
      call bcb_registry%add('BCB-Wall-Fluid', 'qrad', wall_fluid_cfg%qrad, '0.0', &
                            'Radiative heat flux.', '', .false.)
      call bcb_registry%add('BCB-Wall-Fluid', 'eps', wall_fluid_cfg%eps, '0.0', &
                            'Wall emissivity.', '', .false.)

      call bcb_registry%add('BCB-Wall-Solid', 'q', wall_solid_cfg%q, '0.0', &
                            'Prescribed wall heat flux.', '', .false.)
      call bcb_registry%add('BCB-Wall-Solid', 'T', wall_solid_cfg%T, '0.0', &
                            'Prescribed wall temperature.', '', .false.)
      call bcb_registry%add('BCB-Wall-Solid', 'qrad', wall_solid_cfg%qrad, '0.0', &
                            'Radiative heat flux.', '', .false.)
      call bcb_registry%add('BCB-Wall-Solid', 'hconv', wall_solid_cfg%hconv, '0.0', &
                            'Convective heat-transfer coefficient.', '', .false.)
      call bcb_registry%add('BCB-Wall-Solid', 'Tref', wall_solid_cfg%Tref, '0.0', &
                            'Reference temperature for convection.', '', .false.)
      call bcb_registry%add('BCB-Wall-Solid', 'eps', wall_solid_cfg%eps, '0.0', &
                            'Wall emissivity.', '', .false.)
    end subroutine add_wall_entries

    subroutine add_dp_entries()
      call bcb_registry%add('BCB-DP', 'krho', dp_scalar, '0.0', &
                            'Density ratios for dispersed populations.', '', .false.)
      call bcb_registry%add('BCB-DP', 'kV', dp_scalar, '1.0', &
                            'Velocity scaling factors for dispersed populations.', &
                            '', .false.)
      call bcb_registry%add('BCB-DP', 'kT', dp_scalar, '1.0', &
                            'Temperature scaling factors for dispersed populations.', &
                            '', .false.)
      call bcb_registry%add('BCB-DP', 'gp', dp_scalar, '0.0', &
                            'Mass flux per dispersed population.', '', .false.)
      call bcb_registry%add('BCB-DP', 'up', dp_scalar, '0.0', &
                            'x-velocity component per dispersed population.', '', .false.)
      call bcb_registry%add('BCB-DP', 'vp', dp_scalar, '0.0', &
                            'y-velocity component per dispersed population.', '', .false.)
      call bcb_registry%add('BCB-DP', 'wp', dp_scalar, '0.0', &
                            'z-velocity component per dispersed population.', '', .false.)
      call bcb_registry%add('BCB-DP', 'Vp', dp_scalar, '0.0', &
                            'Velocity magnitude per dispersed population.', '', .false.)
      call bcb_registry%add('BCB-DP', 'Tp', dp_scalar, '0.0', &
                            'Temperature per dispersed population.', '', .false.)
      call bcb_registry%add('BCB-DP', 'rp', dp_scalar, '0.0', &
                            'Particle radii per dispersed population.', '', .false.)
      call bcb_registry%add('BCB-DP', 'dp', dp_scalar, '0.0', &
                            'Particle diameters per dispersed population.', '', .false.)
      call bcb_registry%add('BCB-DP', 'sigmap', dp_scalar, '0.0', &
                            'Particle dispersion widths.', '', .false.)
      call bcb_registry%add('BCB-DP', 'alphap', dp_scalar, '0.0', &
                            'Primary injection angle per dispersed population.', '', .false.)
      call bcb_registry%add('BCB-DP', 'betap', dp_scalar, '0.0', &
                            'Secondary injection angle per dispersed population.', '', .false.)
      call bcb_registry%add('BCB-DP', 'rRes', dp_scalar, '0.0', &
                            'Residual radius per dispersed population.', '', .false.)
      call bcb_registry%add('BCB-DP', 'Tsat', dp_scalar, '0.0', &
                            'Saturation temperature per dispersed population.', '', .false.)
    end subroutine add_dp_entries

    subroutine add_srm_entries()
      call add_turbulence_registry_entries(bcb_registry, 'BCB-SRM', srm_cfg%turbulence)
      call bcb_registry%add('BCB-SRM', 'a', srm_cfg%a, '0.0', &
                            'Burn-rate pre-exponential coefficient.', '', .false.)
      call bcb_registry%add('BCB-SRM', 'n', srm_cfg%n, '0.0', &
                            'Burn-rate pressure exponent.', '', .false.)
      call bcb_registry%add('BCB-SRM', 'pRef', srm_cfg%pRef, '1.0', &
                            'Reference pressure for the burn law.', '', .false.)
      call bcb_registry%add('BCB-SRM', 'rhoGrain', srm_cfg%rhoGrain, '0.0', &
                            'Solid propellant density.', '', .false.)
      call bcb_registry%add('BCB-SRM', 'SF', srm_cfg%SF, '1.0', &
                            'Geometric scaling factor for the grain surface.', '', .false.)
    end subroutine add_srm_entries

    subroutine add_variable_file_entries()
      integer :: i

      do i = 1, n_variable_file_keys
        call bcb_registry%add('BCB-Variable-BC', trim(variable_file_keys(i))//'-file', &
                              patch_name, '', 'ASCII file providing varying values for '// &
                              trim(variable_file_keys(i))//'.', '', .false.)
      enddo
    end subroutine add_variable_file_entries

    function face_index(ff) result(index_string)
      integer, intent(in) :: ff
      character(len=4)    :: index_string

      write(index_string, '(I4)') ff
    end function face_index

    function boundary_type_list() result(allowed)
      character(len=160) :: allowed

      allowed = trim(MARKER_NULL)//','//trim(MARKER_AXIS)//','//trim(MARKER_EXTRA)//','// &
                trim(MARKER_CONN)//','//trim(MARKER_Chim)//','//trim(MARKER_SYM)//','// &
                trim(MARKER_PER)//','//trim(MARKER_WALL)//','//trim(MARKER_INLET)//','// &
                trim(MARKER_OUTLET)//','//trim(MARKER_MANIFOLD)//','//trim(MARKER_SRM)
    end function boundary_type_list

  end subroutine write_bcb_registry_markdown

end module bcb_config_mod