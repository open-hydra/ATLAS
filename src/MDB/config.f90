module config_mdb_mod
  use iso_fortran_env, only: R8 => real64
  use finer,           only: file_ini
  use global_mod,      only: llen
  use registry_mod,    only: registry_t
  use config_shared_mod

  implicit none
  private

  !> One phase of a (possibly coupled) case. ATLAS numbers blocks per phase and
  !> writes one BC file set per phase, so each phase is decomposed on its own;
  !> the phases are tied together only by the type-103 records that cross the
  !> fluid-solid interface.
  type, public :: mdb_phase_t
    character(len=llen) :: grid     = ''
    character(len=llen) :: grid_out = ''                 !< '' -> <grid>-split.<ext>
    character(len=llen) :: bc_in    = 'INPUT'
    character(len=llen) :: bc_out   = 'INPUT-split'
    character(len=llen) :: prefix   = ''
    character(len=llen) :: map_file = ''                 !< '' -> <prefix>decomposition.map
    integer             :: ranks    = 0                  !< 0 -> inherit [MDB-Parameters] ranks
    !> A dispersed phase writes a different BC file: ATLAS_BCB::write_dp_bc puts
    !> no property line under a wall or a symmetry, where the gas and solid
    !> writers do, and repeats the whole boundary table once per (material,
    !> population) pair. Detected from <prefix>phase.txt; `phase-type` overrides.
    logical             :: dispersed = .false.
  end type mdb_phase_t

  type, public :: mdb_config_t
    character(len=llen) :: input_file = 'input.ini'
    integer             :: mg_levels  = 1
    integer             :: ranks      = 0
    real(R8)            :: target_bal = 95.0_R8
    real(R8)            :: halo_weight = 1.0_R8              !< cost of a ghost cell vs a real one
    integer             :: max_blocks = 0                    !< 0 -> 8*ranks
    integer             :: min_cells  = 0                    !< 0 -> 4*2**(mg_levels-1)
    character(len=llen) :: grid       = ''                   !< '' -> autodetect
    character(len=llen) :: grid_out   = ''                   !< '' -> <grid>-split.<ext>
    character(len=llen) :: bc_in      = 'INPUT'
    character(len=llen) :: bc_out     = 'INPUT-split'
    character(len=llen) :: prefix     = ''                   !< MOSE phase prefix of the BC files
    character(len=llen) :: map_file   = 'decomposition.map'
    character(len=8)    :: directions = 'ijk'
    integer                        :: nphase = 0        !< number of [MDB-Phase#] sections
    type(mdb_phase_t), allocatable :: phase(:)
  end type mdb_config_t

  public :: load_mdb_config
  public :: load_block_directions
  public :: write_mdb_registry_markdown

  character(len=*), parameter :: SEC  = 'MDB-Parameters'
  character(len=*), parameter :: PSEC = 'MDB-Phase*'

  !> Upper bound on [MDB-Phase#] sections scanned. A type-103 record names only
  !> (block,i,j,k) in "the other phase", so a coupled mesh is meaningful for two
  !> phases; the extra slots exist so a miscounted input fails loudly.
  integer, parameter, public :: MAXPHASE = 8

contains

  subroutine load_mdb_config(cfg, input_file)
    type(mdb_config_t), intent(out)          :: cfg
    character(*),       intent(in), optional :: input_file
    type(atlas_parameters_t) :: atlas_cfg
    type(file_ini) :: fini
    integer :: error

    if (present(input_file)) then
      call load_atlas_parameters('MDB', atlas_cfg, input_file)
    else
      call load_atlas_parameters('MDB', atlas_cfg)
    endif

    cfg%input_file = atlas_cfg%input_file
    cfg%mg_levels  = max(1, atlas_cfg%mg_levels)

    call fini%load(filename=trim(cfg%input_file))

    call fini%get(section_name=SEC, option_name='ranks',            val=cfg%ranks,      error=error)
    call fini%get(section_name=SEC, option_name='target-balance',   val=cfg%target_bal, error=error)
    call fini%get(section_name=SEC, option_name='halo-weight',      val=cfg%halo_weight,error=error)
    call fini%get(section_name=SEC, option_name='max-blocks',       val=cfg%max_blocks, error=error)
    call fini%get(section_name=SEC, option_name='min-cells',        val=cfg%min_cells,  error=error)
    call fini%get(section_name=SEC, option_name='grid',             val=cfg%grid,       error=error)
    call fini%get(section_name=SEC, option_name='grid-out',         val=cfg%grid_out,   error=error)
    call fini%get(section_name=SEC, option_name='bc-path',          val=cfg%bc_in,      error=error)
    call fini%get(section_name=SEC, option_name='bc-out-path',      val=cfg%bc_out,     error=error)
    call fini%get(section_name=SEC, option_name='prefix',           val=cfg%prefix,     error=error)
    call fini%get(section_name=SEC, option_name='map-file',         val=cfg%map_file,   error=error)
    call fini%get(section_name=SEC, option_name='split-directions', val=cfg%directions, error=error)

    if (cfg%min_cells  <= 0) cfg%min_cells  = 4 * 2**(cfg%mg_levels-1)
    if (cfg%max_blocks <= 0) cfg%max_blocks = max(8*cfg%ranks, 1)

    call load_phases(fini, cfg)

  end subroutine load_mdb_config


  !> Collect the [MDB-Phase1] .. [MDB-Phase#] sections, numbered consecutively
  !> from 1. With none declared the flat [MDB-Parameters] keys describe a single
  !> phase, which is what every pre-existing single-phase input does.
  subroutine load_phases(fini, cfg)
    type(file_ini),     intent(in)    :: fini
    type(mdb_config_t), intent(inout) :: cfg
    type(mdb_phase_t) :: ph(MAXPHASE)
    character(len=32) :: section
    character(len=16) :: sn
    integer :: n, np, error
    logical :: found

    np = 0
    do n = 1, MAXPHASE
      write(sn,'(I0)') n
      section = 'MDB-Phase'//trim(sn)

      ph(n)%grid = ''
      call fini%get(section_name=trim(section), option_name='grid', val=ph(n)%grid, error=error)
      found = (error == 0 .and. len_trim(ph(n)%grid) > 0)
      if (.not. found) exit

      ph(n)%grid_out = ''
      ph(n)%bc_in    = cfg%bc_in
      ph(n)%bc_out   = cfg%bc_out
      ph(n)%prefix   = ''
      ph(n)%map_file = ''
      ph(n)%ranks    = 0
      call fini%get(section_name=trim(section), option_name='grid-out',    val=ph(n)%grid_out, error=error)
      call fini%get(section_name=trim(section), option_name='bc-path',     val=ph(n)%bc_in,    error=error)
      call fini%get(section_name=trim(section), option_name='bc-out-path', val=ph(n)%bc_out,   error=error)
      call fini%get(section_name=trim(section), option_name='prefix',      val=ph(n)%prefix,   error=error)
      call fini%get(section_name=trim(section), option_name='map-file',    val=ph(n)%map_file, error=error)
      call fini%get(section_name=trim(section), option_name='ranks',       val=ph(n)%ranks,    error=error)
      call read_phase_type(fini, trim(section), ph(n))
      np = n
    enddo

    if (np == 0) then
      ! Legacy single-phase input: the flat keys are the one and only phase.
      allocate(cfg%phase(1))
      cfg%nphase           = 1
      cfg%phase(1)%grid     = cfg%grid
      cfg%phase(1)%grid_out = cfg%grid_out
      cfg%phase(1)%bc_in    = cfg%bc_in
      cfg%phase(1)%bc_out   = cfg%bc_out
      cfg%phase(1)%prefix   = cfg%prefix
      cfg%phase(1)%map_file = cfg%map_file
      cfg%phase(1)%ranks    = cfg%ranks
      call read_phase_type(fini, SEC, cfg%phase(1))
      return
    endif

    allocate(cfg%phase(np))
    cfg%nphase = np
    do n = 1, np
      cfg%phase(n) = ph(n)
      if (cfg%phase(n)%ranks < 1) cfg%phase(n)%ranks = cfg%ranks
      if (len_trim(cfg%phase(n)%map_file) == 0) &
        cfg%phase(n)%map_file = trim(cfg%phase(n)%prefix)//'decomposition.map'
    enddo

  end subroutine load_phases


  !> Is this phase a dispersed one? `phase-type = gas|dispersed` decides when it
  !> is given; otherwise the phase file settles it, the same first line BCB used
  !> to choose its writer. Looked for beside the input file and in the BC
  !> directory, which is where a solver case keeps it. Unknown means gas, which
  !> is what every pre-existing input is.
  subroutine read_phase_type(fini, section, ph)
    type(file_ini),    intent(in)    :: fini
    character(len=*),  intent(in)    :: section
    type(mdb_phase_t), intent(inout) :: ph
    character(len=llen) :: kind, line
    integer :: error, u, ios
    logical :: ex

    kind = ''
    call fini%get(section_name=section, option_name='phase-type', val=kind, error=error)
    if (error == 0 .and. len_trim(kind) > 0) then
      ph%dispersed = (index(kind, 'disp') > 0)
      return
    endif

    ph%dispersed = .false.
    line = trim(ph%prefix)//'phase.txt'
    inquire(file=trim(line), exist=ex)
    if (.not. ex) then
      line = trim(ph%bc_in)//'/'//trim(ph%prefix)//'phase.txt'
      inquire(file=trim(line), exist=ex)
    endif
    if (.not. ex) return

    open(newunit=u, file=trim(line), status='old', action='read', iostat=ios)
    if (ios /= 0) return
    read(u,'(A)',iostat=ios) line
    close(u)
    if (ios /= 0) return

    ph%dispersed = index(line, 'dispersed') > 0

  end subroutine read_phase_type


  !> Per-block override of the directions that may be cut, e.g.
  !>   [MDB-Block7]
  !>   split-directions = ik
  !> Useful to protect the wall-normal direction of boundary-layer blocks.
  subroutine load_block_directions(sini, nb, default_dirs, allow)
    type(file_ini),   intent(in)  :: sini
    integer,          intent(in)  :: nb
    character(len=*), intent(in)  :: default_dirs
    logical,          intent(out) :: allow(3,nb)
    character(len=32) :: dirs
    character(len=32) :: section
    character(len=8)  :: sb
    integer :: b, error

    do b = 1, nb
      write(sb,'(I0)') b
      section = 'MDB-Block'//trim(sb)
      dirs = default_dirs
      call sini%get(section_name=trim(section), option_name='split-directions', val=dirs, error=error)
      if (error /= 0 .or. len_trim(dirs) == 0) dirs = default_dirs
      allow(1,b) = index(dirs,'i') > 0
      allow(2,b) = index(dirs,'j') > 0
      allow(3,b) = index(dirs,'k') > 0
    enddo

  end subroutine load_block_directions


  subroutine write_mdb_registry_markdown(filename)
    character(*), intent(in), optional :: filename
    type(registry_t)                 :: reg
    type(atlas_parameters_t), target :: atlas_cfg
    type(mdb_config_t),       target :: c
    character(len=llen)              :: fileout
    character(len=32), target        :: dirs

    atlas_cfg%input_file = 'input.ini'
    dirs = 'ijk'

    call add_atlas_registry_entries(reg, 'MDB', atlas_cfg)

    call reg%add(SEC, 'ranks', c%ranks, '0', &
      'Number of MPI ranks the mesh must be balanced for.', '', .true.)
    call reg%add(SEC, 'target-balance', c%target_bal, '95.0', &
      'Stop splitting once the predicted MOSE balance reaches this percentage of ideal.', '', .false.)
    call reg%add(SEC, 'halo-weight', c%halo_weight, '1.0', &
      'Cost of a ghost cell relative to a real one when scoring a decomposition; &
      &0 restores the old balance-only behaviour.', '>= 0', .false.)
    call reg%add(SEC, 'max-blocks', c%max_blocks, '0', &
      'Hard cap on the number of blocks produced (0 = 8 x ranks).', '', .false.)
    call reg%add(SEC, 'min-cells', c%min_cells, '0', &
      'Smallest admissible sub-block extent along a cut direction (0 = 4 x 2^(MG-levels-1)).', '', .false.)
    call reg%add(SEC, 'split-directions', dirs, 'ijk', &
      'Directions that may be cut; can be overridden per block in [MDB-Block#].', 'any subset of ijk', .false.)
    call reg%add(SEC, 'grid', c%grid, '', &
      'Grid or grid+solution file to split (empty = autodetect INPUT/ic.* then mesh.*).', '', .false.)
    call reg%add(SEC, 'grid-out', c%grid_out, '', &
      'Output grid file (empty = <grid>-split.<ext>).', '', .false.)
    call reg%add(SEC, 'bc-path', c%bc_in, 'INPUT', &
      'Directory holding the boundary condition files to split.', '', .false.)
    call reg%add(SEC, 'bc-out-path', c%bc_out, 'INPUT-split', &
      'Directory the decomposed boundary condition files are written to.', '', .false.)
    call reg%add(SEC, 'phase-type', dirs, '', &
      'Phase kind of the BC files: gas or dispersed, which use different property-line &
      &conventions. Empty = read it from <prefix>phase.txt.', 'gas | dispersed', .false.)
    call reg%add(SEC, 'prefix', c%prefix, '', &
      'MOSE phase prefix of the BC files (<prefix>bc.txt).', '', .false.)
    call reg%add(SEC, 'map-file', c%map_file, 'decomposition.map', &
      'File recording the new-block to parent-block mapping.', '', .false.)

    call reg%add(PSEC, 'grid', c%grid, '', &
      'Grid or grid+solution file of this phase. Declaring [MDB-Phase1] and &
      &[MDB-Phase2] puts MDB in coupled mode, which is required whenever the BC &
      &files contain type-103 (fluid-solid interface) records.', '', .false.)
    call reg%add(PSEC, 'grid-out', c%grid_out, '', &
      'Output grid file for this phase (empty = <grid>-split.<ext>).', '', .false.)
    call reg%add(PSEC, 'bc-path', c%bc_in, 'INPUT', &
      'Directory holding this phase''s boundary condition files.', '', .false.)
    call reg%add(PSEC, 'bc-out-path', c%bc_out, 'INPUT-split', &
      'Directory this phase''s decomposed boundary condition files go to.', '', .false.)
    call reg%add(PSEC, 'prefix', c%prefix, '', &
      'Phase prefix of this phase''s BC files (<prefix>bc.txt).', '', .false.)
    call reg%add(PSEC, 'map-file', c%map_file, '', &
      'Decomposition record for this phase (empty = <prefix>decomposition.map).', '', .false.)
    call reg%add(PSEC, 'ranks', c%ranks, '0', &
      'Ranks to balance this phase for (0 = the [MDB-Parameters] value). Both &
      &phases run on every rank, so leaving this at 0 is almost always right.', '', .false.)

    if (present(filename)) then
      fileout = filename
    else
      fileout = 'mdb-input.md'
    endif

    call reg%generate_markdown(trim(fileout), 'ATLAS MDB Input Parameters')

  end subroutine write_mdb_registry_markdown

end module config_mdb_mod
