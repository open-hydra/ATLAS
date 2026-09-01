module config_mdb_mod
  use iso_fortran_env, only: R8 => real64
  use finer,           only: file_ini
  use global_mod,      only: llen
  use registry_mod,    only: registry_t
  use config_shared_mod

  implicit none
  private

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
  end type mdb_config_t

  public :: load_mdb_config
  public :: load_block_directions
  public :: write_mdb_registry_markdown

  character(len=*), parameter :: SEC = 'MDB-Parameters'

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

  end subroutine load_mdb_config


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
    call reg%add(SEC, 'prefix', c%prefix, '', &
      'MOSE phase prefix of the BC files (<prefix>bc.txt).', '', .false.)
    call reg%add(SEC, 'map-file', c%map_file, 'decomposition.map', &
      'File recording the new-block to parent-block mapping.', '', .false.)

    if (present(filename)) then
      fileout = filename
    else
      fileout = 'mdb-input.md'
    endif

    call reg%generate_markdown(trim(fileout), 'ATLAS MDB Input Parameters')

  end subroutine write_mdb_registry_markdown

end module config_mdb_mod
