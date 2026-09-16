!>
!> Mesh Decomposition Builder
!>
!> Splits a multi-block structured grid (and, if the file carries one, its
!> solution field) into more, smaller blocks so that MOSE's block-atomic MPI
!> partitioner can balance the load over a given number of ranks, and rewrites
!> the boundary condition files of every multigrid level to match.
!>
program MDB
  use global_mod
  use Lib_ORION_data
  use Lib_Tecplot
  use Lib_PLOT3D
  use read_mesh_mod
  use io_ini_mod
  use config_mdb_mod
  use decomposition_mod
  use partition_mod
  use split_grid_mod
  use split_bc_mod
  use finer, only: file_ini
  implicit none

  type(mdb_config_t)    :: cfg
  type(decomposition_t), allocatable :: dec(:)
  integer               :: lev, gran, ierr
  integer               :: ip, jp, ndonor
  logical               :: write_config_doc, coupled, anysplit
  character(len=llen)   :: input_file, fin, fout

  write(*,*)
  write(*,*) ' ATLAS - Mesh Decomposition Builder'
  write(*,*)

  call command_line_argument()

  if (write_config_doc) then
    call write_mdb_registry_markdown('mdb-input.md')
    write(*,*) ' MDB input documentation written to mdb-input.md'
    stop
  endif

  ! ── Configuration ──────────────────────────────────────────────────────────
  if (len_trim(input_file) > 0) then
    call load_mdb_config(cfg, trim(input_file))
  else
    call load_mdb_config(cfg)
  endif

  if (cfg%ranks < 1) then
    write(*,'(A)') ' [ERROR] [MDB-Parameters] ranks must be set to the number of MPI processes'
    stop 1
  endif

  gran = 2**(cfg%mg_levels - 1)
  if (cfg%min_cells < gran) cfg%min_cells = gran

  coupled = cfg%nphase > 1
  allocate(dec(cfg%nphase))
  anysplit = .false.

  if (coupled) then
    write(*,'(A,I0,A)') ' Coupled mode: ', cfg%nphase, ' phases'
    write(*,*)
  endif

  ! ════ Stage 1: decompose every phase and write its grid ═══════════════════
  ! Each phase is decomposed independently -- ATLAS numbers blocks per phase --
  ! but all decompositions must exist before any BC file is rewritten, because
  ! a type-103 record has to be remapped against the *other* phase.
  do ip = 1, cfg%nphase
    if (coupled) then
      write(*,'(A,I0,A)') ' ── Phase ', ip, ' ─────────────────────────────────────────────'
    endif
    call decompose_phase(ip)
  enddo

  if (coupled .and. .not. anysplit) then
    write(*,'(A)') ' Nothing to split: every phase already meets the target.'
    stop
  endif

  ! ════ Stage 2: boundary conditions ════════════════════════════════════════
  ! One file per phase per multigrid level. `ndonor` is the other phase of the
  ! coupling, whose decomposition resolves the type-103 donors.
  write(*,*)
  write(*,'(A)') ' Boundary conditions'

  if (cfg%nphase > 2) then
    write(*,'(A)') ' [ERROR] a type-103 record names only (block,i,j,k) in "the other phase",'
    write(*,'(A,I0,A)') '         so the interface is ambiguous with ', cfg%nphase, ' phases declared.'
    write(*,'(A)') '         Declare exactly two [MDB-Phase#] sections.'
    stop 1
  endif

  do ip = 1, cfg%nphase
    ndonor = 0
    do jp = 1, cfg%nphase
      if (jp /= ip) ndonor = jp
    enddo

    call execute_command_line('mkdir -p '//trim(cfg%phase(ip)%bc_out))
    do lev = 1, cfg%mg_levels
      fin  = bc_name(trim(cfg%phase(ip)%bc_in),  lev, trim(cfg%phase(ip)%prefix))
      fout = bc_name(trim(cfg%phase(ip)%bc_out), lev, trim(cfg%phase(ip)%prefix))
      if (ndonor > 0) then
        call split_bc_level(dec(ip), lev, trim(fin), trim(fout), ierr, donor_dec=dec(ndonor))
      else
        call split_bc_level(dec(ip), lev, trim(fin), trim(fout), ierr)
      endif
      if (ierr /= 0) then
        write(*,'(A)') ' [ERROR] failed on '//trim(fin)
        stop 1
      endif
    enddo
  enddo

  write(*,*)
  write(*,'(A)') ' Done.'
  write(*,'(A)') ' Point MOSE at the new grid and copy the BC files from '//trim(cfg%phase(1)%bc_out)//'/'
  write(*,*)

contains

  !> Read one phase's grid, decompose it, record the map and write the split
  !> grid. `gin`/`gout` are local so every phase reads into fresh storage:
  !> read_mesh takes an intent(inout) orion_data and does not reset the blocks
  !> of a previous mesh, so reusing one handle across phases corrupts the second
  !> read. The resulting decomposition is kept in dec(ip) for stage 2.
  subroutine decompose_phase(ip)
    integer, intent(in) :: ip
    type(orion_data)     :: gin, gout
    type(file_ini)       :: sourceini
    logical, allocatable :: allow(:,:)
    integer, allocatable :: owner(:), pdim(:,:)
    real(8)              :: bal
    integer              :: b, d, nb, orig_cells, err
    character(len=llen)  :: gridfile, gridout

    ! ── Grid import ──────────────────────────────────────────────────────────
    gridfile = cfg%phase(ip)%grid
    if (len_trim(gridfile) == 0) call autodetect_grid(gridfile)
    if (len_trim(gridfile) == 0) then
      write(*,'(A)') ' [ERROR] no grid file found; set [MDB-Parameters] grid'
      stop 1
    endif

    write(*,'(A)') ' Reading '//trim(gridfile)//' ...'
    call read_mesh(gin, trim(gridfile))
    nb = size(gin%block)
    write(*,'(A,I0,A)') ' Done: ', nb, ' blocks'

    allocate(pdim(3,nb))
    orig_cells = 0
    do b = 1, nb
      pdim(1,b) = gin%block(b)%Ni
      pdim(2,b) = max(gin%block(b)%Nj, 1)
      pdim(3,b) = max(gin%block(b)%Nk, 1)
      orig_cells = orig_cells + pdim(1,b)*pdim(2,b)*pdim(3,b)
    enddo

    ! Multigrid coarsening must stay exact at every level, as MOSE derives the
    ! coarse grids itself (MOSE_Lib_Multigrid).
    err = 0
    do b = 1, nb
      do d = 1, 3
        if (pdim(d,b) == 1) cycle
        if (mod(pdim(d,b), gran) /= 0) then
          write(*,'(A,I0,A,I0,A,I0,A,I0)') ' [ERROR] block ', b, ' dimension ', d, ' = ', &
            pdim(d,b), ' is not a multiple of ', gran
          err = 1
        endif
      enddo
    enddo
    if (err /= 0) then
      write(*,'(A,I0,A)') '         with MG-levels = ', cfg%mg_levels, &
        ' every block dimension must be a multiple of 2^(MG-levels-1)'
      stop 1
    endif

    ! ── Per-block split directions ───────────────────────────────────────────
    if (len_trim(input_file) > 0) then
      call build_INI(prog='MDB', nb=nb, inisource=sourceini, input_file=trim(input_file))
    else
      call build_INI(prog='MDB', nb=nb, inisource=sourceini)
    endif
    allocate(allow(3,nb))
    call load_block_directions(sourceini, nb, cfg%directions, allow)

    ! ── Decomposition ────────────────────────────────────────────────────────
    write(*,*)
    write(*,'(A,I0,A)') ' Decomposing for ', cfg%phase(ip)%ranks, ' MPI ranks ...'
    call dec_init(dec(ip), nb, pdim)
    call build_decomposition(dec(ip), cfg%phase(ip)%ranks, cfg%target_bal, cfg%halo_weight, &
                             cfg%max_blocks, cfg%min_cells, gran, allow, verbose)
    call dec_finalize(dec(ip))
    call lpt_assign(dec(ip), cfg%phase(ip)%ranks, owner, bal)
    call report_decomposition(dec(ip), cfg%phase(ip)%ranks, owner, orig_cells)

    call dec_write_map(dec(ip), trim(cfg%phase(ip)%map_file), owner)
    call append_face_map(trim(cfg%phase(ip)%map_file), dec(ip))
    write(*,*)
    write(*,'(A)') ' Wrote '//trim(cfg%phase(ip)%map_file)

    if (dec(ip)%npieces == dec(ip)%nparent) then
      write(*,'(A)') ' Nothing to split: the mesh already meets the target.'
      ! In coupled mode this phase's BC file still has to be rewritten: its
      ! type-103 donors point into the other phase, which may well be split.
      if (.not. coupled) stop
      write(*,*)
      return
    endif
    anysplit = .true.

    ! ── Grid + solution ──────────────────────────────────────────────────────
    gridout = cfg%phase(ip)%grid_out
    if (len_trim(gridout) == 0) gridout = split_name(gridfile)

    write(*,'(A)') ' Writing '//trim(gridout)//' ...'
    call split_grid(dec(ip), gin, gout)
    call write_grid(gout, trim(gridout), err)
    if (err /= 0) then
      write(*,'(A)') ' [ERROR] writing '//trim(gridout)
      stop 1
    endif
    write(*,*)

  end subroutine decompose_phase


  subroutine command_line_argument()
    character(len=llen) :: arg
    integer :: n, i

    verbose = .false.
    write_config_doc = .false.
    input_file = ''

    n = command_argument_count()
    do i = 1, n
      call get_command_argument(i, arg)
      select case(trim(arg))
      case('-v', '--verbose')
        verbose = .true.
      case('--write-config-doc')
        write_config_doc = .true.
      case('-i', '--input')
        if (i < n) call get_command_argument(i+1, input_file)
      end select
    enddo

  end subroutine command_line_argument


  subroutine autodetect_grid(path)
    character(len=*), intent(out) :: path
    character(len=32), parameter :: candidates(6) = &
      [ character(len=32) :: 'INPUT/ic.tec', 'INPUT/ic.szplt', 'mesh.tec', &
                             'mesh.szplt', 'mesh.p3d', 'MESH/mesh.tec' ]
    integer :: i
    logical :: ex

    path = ''
    do i = 1, size(candidates)
      inquire(file=trim(candidates(i)), exist=ex)
      if (ex) then
        path = trim(candidates(i))
        return
      endif
    enddo

  end subroutine autodetect_grid


  !> <name>.<ext>  ->  <name>-split.<ext>
  function split_name(path) result(res)
    character(len=*), intent(in) :: path
    character(len=llen) :: res
    integer :: p

    p = index(path, '.', back=.true.)
    if (p > 0) then
      res = path(1:p-1)//'-split'//trim(path(p:))
    else
      res = trim(path)//'-split'
    endif

  end function split_name


  function bc_name(dir, level, prefix) result(res)
    character(len=*), intent(in) :: dir
    integer,          intent(in) :: level
    character(len=*), intent(in) :: prefix
    character(len=llen) :: res
    character(len=8) :: sl

    if (level == 1) then
      res = trim(dir)//'/'//trim(prefix)//'bc.txt'
    else
      write(sl,'(I0)') level
      res = trim(dir)//'/'//trim(prefix)//'bc'//trim(sl)//'.txt'
    endif

  end function bc_name


  subroutine write_grid(orion, filename, err)
    type(orion_data), intent(inout) :: orion
    character(len=*), intent(in)    :: filename
    integer,          intent(out)   :: err
    character(len=1024) :: vnames
    integer :: nd, nv

    err = 0
    nd = size(orion%block(1)%mesh, 1)
    nv = 0
    if (allocated(orion%block(1)%vars)) nv = size(orion%block(1)%vars, 1)
    call variable_names(orion, nd, nv, vnames)

    if (index(filename, '.p3d') > 0) then
      orion%p3d%format = 'ascii'
      err = p3d_write_multiblock(orion=orion, filename=filename)
    elseif (index(filename, '.szplt') > 0 .or. index(filename, '.plt') > 0) then
      orion%tec%format = 'binary'
      if (len_trim(vnames) > 0) then
        err = tec_write_structured_multiblock(orion=orion, varnames=trim(vnames), filename=filename)
      else
        err = tec_write_structured_multiblock(orion=orion, filename=filename)
      endif
    else
      orion%tec%format = 'ascii'
      if (len_trim(vnames) > 0) then
        err = tec_write_structured_multiblock(orion=orion, varnames=trim(vnames), filename=filename)
      else
        err = tec_write_structured_multiblock(orion=orion, filename=filename)
      endif
    endif

  end subroutine write_grid


  !> Rebuild the quoted variable list of the source file, dropping the
  !> coordinates if the reader kept them in varnames.
  subroutine variable_names(orion, nd, nv, vnames)
    type(orion_data),  intent(in)  :: orion
    integer,           intent(in)  :: nd, nv
    character(len=*),  intent(out) :: vnames
    integer :: i, i0

    vnames = ''
    if (nv == 0) return
    if (.not. allocated(orion%varnames)) return

    if (size(orion%varnames) == nd + nv) then
      i0 = nd
    elseif (size(orion%varnames) == nv) then
      i0 = 0
    else
      return
    endif

    do i = 1, nv
      if (i == 1) then
        vnames = '"'//trim(orion%varnames(i0+i))//'"'
      else
        vnames = trim(vnames)//' "'//trim(orion%varnames(i0+i))//'"'
      endif
    enddo

  end subroutine variable_names


  !> Append, for every new block, where each of its six faces came from: the
  !> parent face number it inherits, or 'cut' for a face created by the split.
  !> This is what tells you how the [BCB-Block#] face assignments carry over.
  subroutine append_face_map(filename, d)
    character(len=*),      intent(in) :: filename
    type(decomposition_t), intent(in) :: d
    integer :: u, p, f, dir, side, bb
    character(len=8) :: tag(6)

    open(newunit=u, file=filename, action='write', position='append')
    write(u,'(A)') '#'
    write(u,'(A)') '# face origin of every new block (parent face number, or cut)'
    write(u,'(A)') '# new  parent   face1    face2    face3    face4    face5    face6'
    do p = 1, d%npieces
      bb = d%piece(p)%parent
      do f = 1, 6
        dir  = face_dir(f)
        side = face_side(f)
        if (side == 1) then
          if (d%piece(p)%lo(dir) == 1) then
            write(tag(f),'(I0)') f
          else
            tag(f) = 'cut'
          endif
        else
          if (d%piece(p)%hi(dir) == d%pdim(dir,bb)) then
            write(tag(f),'(I0)') f
          else
            tag(f) = 'cut'
          endif
        endif
      enddo
      write(u,'(2I6,6(A9))') p, bb, (adjustr(tag(f)), f=1,6)
    enddo
    close(u)

  end subroutine append_face_map

end program MDB
