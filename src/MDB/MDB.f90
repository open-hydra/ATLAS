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
  use bc_scan_mod
  use search_mod
  use cost_mod, only: cost_evaluate
  use finer, only: file_ini
  implicit none

  !> The rank of every piece, kept per phase for the interface count.
  type :: owner_t
    integer, allocatable :: r(:)
  end type owner_t

  type(mdb_config_t)    :: cfg
  type(decomposition_t), allocatable :: dec(:)
  type(bc_scan_t),       allocatable :: scan(:)
  type(owner_t),         allocatable :: own(:)
  integer               :: lev, gran, ierr
  integer               :: ip, jp, ndonor
  logical               :: write_config_doc, coupled, anysplit, has_level
  character(len=llen)   :: input_file, fin, fout, sweep_list

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
  allocate(dec(cfg%nphase), scan(cfg%nphase), own(cfg%nphase))
  anysplit = .false.

  if (coupled) then
    write(*,'(A,I0,A)') ' Coupled mode: ', cfg%nphase, ' phases'
    if (cfg%same_cut) write(*,'(A)') ' same-cut: the decomposition of phase 1 is applied to every phase'
    write(*,*)
  elseif (cfg%same_cut) then
    write(*,'(A)') ' [WARNING] same-cut needs [MDB-Phase1] and [MDB-Phase2]: ignored for a single phase'
  endif

  ! ── Sweep: the best cut per rank count, nothing written ─────────────────────
  if (len_trim(sweep_list) > 0) then
    do ip = 1, cfg%nphase
      call sweep_phase(ip)
    enddo
    stop
  endif

  ! ════ Stage 1: decompose every phase and write its grid ═══════════════════
  ! Each phase is decomposed independently -- ATLAS numbers blocks per phase --
  ! but all decompositions must exist before any BC file is rewritten, because
  ! a type-103/104 record has to be remapped against the *other* phase.
  do ip = 1, cfg%nphase
    if (coupled) then
      write(*,'(A,I0,A)') ' ── Phase ', ip, ' ─────────────────────────────────────────────'
    endif
    call decompose_phase(ip)
  enddo

  if (coupled) call report_interface()

  if (coupled .and. .not. anysplit) then
    write(*,'(A)') ' Nothing to split: every phase already meets the target.'
    stop
  endif

  ! ════ Stage 2: boundary conditions ════════════════════════════════════════
  ! One file per phase per multigrid level. `ndonor` is the other phase of the
  ! coupling, whose decomposition resolves the type-103/104 donors.
  write(*,*)
  write(*,'(A)') ' Boundary conditions'

  if (cfg%nphase > 2) then
    write(*,'(A)') ' [ERROR] a type-103/104 record names only (block,i,j,k) in "the other phase",'
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

      ! A coarse level is optional: a solver that builds its coarse grids
      ! without boundary conditions has none, and ATLAS writes none at all for a
      ! dispersed phase. The fine level is not optional.
      if (lev > 1) then
        inquire(file=trim(fin), exist=has_level)
        if (.not. has_level) then
          write(*,'(A,I0,A)') '   level ', lev, ': '//trim(fin)//' not found, nothing to split'
          cycle
        endif
      endif
      if (ndonor > 0) then
        call split_bc_level(dec(ip), lev, trim(fin), trim(fout), ierr, donor_dec=dec(ndonor), &
                            dispersed=cfg%phase(ip)%dispersed)
      else
        call split_bc_level(dec(ip), lev, trim(fin), trim(fout), ierr, &
                            dispersed=cfg%phase(ip)%dispersed)
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
    logical              :: same
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

    ! ── same-cut: this phase takes phase 1's decomposition ───────────────────
    ! Only meaningful when the phases share the mesh block for block and are
    ! balanced for the same ranks: then the same pieces get the same LPT owners
    ! and every cell of one phase sits on the rank of its twin in the other.
    same = cfg%same_cut .and. coupled .and. ip > 1
    if (same) then
      if (nb /= dec(1)%nparent) then
        write(*,'(A,I0,A,I0,A)') ' [ERROR] same-cut needs the phases to share the mesh: phase ', ip, &
          ' has ', nb, ' blocks, phase 1 has ', dec(1)%nparent
        stop 1
      endif
      do b = 1, nb
        if (any(pdim(:,b) /= dec(1)%pdim(:,b))) then
          write(*,'(A,I0,A,I0,A,3(X,I0),A,3(X,I0))') ' [ERROR] same-cut needs the phases to share the mesh: block ', &
            b, ' of phase ', ip, ' is', pdim(:,b), ' cells, of phase 1', dec(1)%pdim(:,b)
          write(*,'(A)') '         decompose the phases on their own (same-cut = false)'
          stop 1
        endif
      enddo
      if (cfg%phase(ip)%ranks /= cfg%phase(1)%ranks) then
        write(*,'(A,I0,A,I0,A,I0)') ' [ERROR] same-cut needs the phases balanced for the same ranks: phase ', &
          ip, ' has ', cfg%phase(ip)%ranks, ', phase 1 has ', cfg%phase(1)%ranks
        stop 1
      endif
    endif

    ! ── Per-block split directions ───────────────────────────────────────────
    if (len_trim(input_file) > 0) then
      call build_INI(prog='MDB', nb=nb, inisource=sourceini, input_file=trim(input_file))
    else
      call build_INI(prog='MDB', nb=nb, inisource=sourceini)
    endif
    allocate(allow(3,nb))
    call load_block_directions(sourceini, nb, cfg%directions, allow)

    ! ── Fine-level boundary conditions ───────────────────────────────────────
    ! Read once before anything is cut: a manifold (BC 501) ties two whole
    ! faces together and MOSE refuses the pair on two ranks, so the
    ! decomposition is checked against those records before it is written.
    call bc_scan_fine(bc_name(trim(cfg%phase(ip)%bc_in), 1, trim(cfg%phase(ip)%prefix)), nb, pdim, &
                      cfg%phase(ip)%dispersed, scan(ip), err)
    if (err /= 0) stop 1

    ! ── Decomposition ────────────────────────────────────────────────────────
    write(*,*)
    write(*,'(A,I0,A)') ' Decomposing for ', cfg%phase(ip)%ranks, ' MPI ranks ...'
    call dec_init(dec(ip), nb, pdim)
    if (same) then
      write(*,'(A)') '   same-cut: decomposition of phase 1 applied'
      deallocate(dec(ip)%piece)
      allocate(dec(ip)%piece(dec(1)%npieces))
      dec(ip)%piece   = dec(1)%piece(1:dec(1)%npieces)
      dec(ip)%npieces = dec(1)%npieces
    elseif (trim(cfg%objective) == 'balance') then
      call build_decomposition(dec(ip), cfg%phase(ip)%ranks, cfg%target_bal, cfg%halo_weight, &
                               cfg%max_blocks, cfg%min_cells, gran, allow, verbose)
    else
      if (trim(cfg%objective) == 'cost' .and. .not. scan(ip)%ok) then
        write(*,'(A)') ' [ERROR] objective = cost prices the faces by their boundary conditions, so it needs'
        write(*,'(A)') '         the fine-level BC file before the decomposition: '// &
          trim(bc_name(trim(cfg%phase(ip)%bc_in), 1, trim(cfg%phase(ip)%prefix)))//' not found'
        stop 1
      endif
      call search_decomposition(dec(ip), cfg%phase(ip)%ranks, trim(cfg%objective), cfg%target_bal, &
                                cfg%halo_weight, cfg%max_blocks, cfg%min_cells, gran, allow, &
                                cfg%blocks_per_rank, cfg%balance_tol, verbose, scan(ip), cfg%cost)
    endif
    call dec_finalize(dec(ip))
    call lpt_assign(dec(ip), cfg%phase(ip)%ranks, owner, bal)
    own(ip)%r = owner
    call report_decomposition(dec(ip), cfg%phase(ip)%ranks, owner, orig_cells, trim(cfg%objective), &
                              cfg%halo_weight, scan(ip), cfg%cost)

    call check_manifold_pairs(scan(ip), dec(ip), owner, err)
    if (err /= 0) stop 1

    call dec_write_map(dec(ip), trim(cfg%phase(ip)%map_file), owner)
    call append_face_map(trim(cfg%phase(ip)%map_file), dec(ip))
    write(*,*)
    write(*,'(A)') ' Wrote '//trim(cfg%phase(ip)%map_file)

    if (dec(ip)%npieces == dec(ip)%nparent) then
      write(*,'(A)') ' Nothing to split: the mesh already meets the target.'
      ! In coupled mode this phase's BC file still has to be rewritten: its
      ! type-103/104 donors point into the other phase, which may well be split.
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


  !> `--sweep R1,R2,...`: decompose one phase for every rank count of the list
  !> under the greedy walk and, when it differs, the configured objective, and
  !> tabulate what each gives. Nothing is written. This is the sweep the ICE
  !> campaign did by hand over min-cells to find a good cut per rank count; the
  !> search makes that lever moot and the table shows the cut it settles on.
  subroutine sweep_phase(ip)
    integer, intent(in) :: ip
    type(orion_data)     :: gin
    type(file_ini)       :: sourceini
    type(decomposition_t) :: d
    type(bc_scan_t)      :: sc
    logical, allocatable :: allow(:,:)
    integer, allocatable :: owner(:), pdim(:,:), ranks(:)
    integer              :: b, nb, r, err, pass, npass
    real(8)              :: bal, halo, tmax, tmean
    character(len=llen)  :: gridfile
    character(len=16)    :: obj

    call parse_list(sweep_list, ranks, err)
    if (err /= 0) then
      write(*,'(A)') ' [ERROR] --sweep takes a comma-separated list of rank counts, e.g. --sweep 8,12,16'
      stop 1
    endif

    gridfile = cfg%phase(ip)%grid
    if (len_trim(gridfile) == 0) call autodetect_grid(gridfile)
    if (len_trim(gridfile) == 0) then
      write(*,'(A)') ' [ERROR] no grid file found; set [MDB-Parameters] grid'
      stop 1
    endif
    write(*,'(A)') ' Reading '//trim(gridfile)//' ...'
    call read_mesh(gin, trim(gridfile))
    nb = size(gin%block)
    allocate(pdim(3,nb))
    do b = 1, nb
      pdim(1,b) = gin%block(b)%Ni
      pdim(2,b) = max(gin%block(b)%Nj, 1)
      pdim(3,b) = max(gin%block(b)%Nk, 1)
    enddo
    if (len_trim(input_file) > 0) then
      call build_INI(prog='MDB', nb=nb, inisource=sourceini, input_file=trim(input_file))
    else
      call build_INI(prog='MDB', nb=nb, inisource=sourceini)
    endif
    allocate(allow(3,nb))
    call load_block_directions(sourceini, nb, cfg%directions, allow)
    call bc_scan_fine(bc_name(trim(cfg%phase(ip)%bc_in), 1, trim(cfg%phase(ip)%prefix)), nb, pdim, &
                      cfg%phase(ip)%dispersed, sc, err)
    if (err /= 0) stop 1
    if (trim(cfg%objective) == 'cost' .and. .not. sc%ok) then
      write(*,'(A)') ' [ERROR] objective = cost needs the fine-level BC file: '// &
        trim(bc_name(trim(cfg%phase(ip)%bc_in), 1, trim(cfg%phase(ip)%prefix)))//' not found'
      stop 1
    endif

    npass = 1
    if (trim(cfg%objective) /= 'balance') npass = 2

    write(*,*)
    if (coupled) then
      write(*,'(A,I0,A)') ' Sweep of rank counts (phase ', ip, ')'
    else
      write(*,'(A)') ' Sweep of rank counts'
    endif
    if (sc%ok) then
      write(*,'(A)') '   ranks  objective  blocks  balance   ghost   score  pred.time  spread'
    else
      write(*,'(A)') '   ranks  objective  blocks  balance   ghost   score'
    endif

    do r = 1, size(ranks)
      do pass = 1, npass
        obj = 'balance'
        if (pass == 2) obj = cfg%objective
        call dec_init(d, nb, pdim)
        if (trim(obj) == 'balance') then
          call build_decomposition(d, ranks(r), cfg%target_bal, cfg%halo_weight, max(8*ranks(r), 1), &
                                   cfg%min_cells, gran, allow, .false.)
        else
          call search_decomposition(d, ranks(r), trim(obj), cfg%target_bal, cfg%halo_weight, &
                                    max(8*ranks(r), 1), cfg%min_cells, gran, allow, cfg%blocks_per_rank, &
                                    cfg%balance_tol, .false., sc, cfg%cost, quiet=.true.)
        endif
        call dec_finalize(d)
        call lpt_assign(d, ranks(r), owner, bal)
        halo = halo_overhead(d)
        if (sc%ok) then
          call cost_evaluate(d, owner, ranks(r), sc, cfg%cost, tmax, tmean)
          write(*,'(I8,2X,A9,I8,F8.1,A,F7.1,A,F8.1,F11.1,F7.1,A)') ranks(r), obj, d%npieces, bal, '%', halo, '%', &
            bal / (1.0d0 + cfg%halo_weight * halo / 100.0d0), tmax, 100.0d0 * (tmax / max(tmean, tiny(1.0d0)) - 1.0d0), '%'
        else
          write(*,'(I8,2X,A9,I8,F8.1,A,F7.1,A,F8.1)') ranks(r), obj, d%npieces, bal, '%', halo, '%', &
            bal / (1.0d0 + cfg%halo_weight * halo / 100.0d0)
        endif
      enddo
    enddo
    write(*,*)
    write(*,'(A)') '   max-blocks is 8 x ranks for every row; score is balance / (1 + halo-weight x ghost);'
    write(*,'(A)') '   pred.time and spread are the [MDB-Cost] model over the ranks the solvers'' LPT forms.'

  end subroutine sweep_phase


  !> "8,12,16" -> [8, 12, 16]
  subroutine parse_list(s, v, err)
    character(len=*),     intent(in)  :: s
    integer, allocatable, intent(out) :: v(:)
    integer,              intent(out) :: err
    integer :: n, i, ios
    character(len=len(s)) :: t

    err = 0
    t = s
    n = 1
    do i = 1, len_trim(t)
      if (t(i:i) == ',') then
        t(i:i) = ' '
        n = n + 1
      endif
    enddo
    allocate(v(n))
    read(t,*,iostat=ios) v
    if (ios /= 0 .or. any(v < 1)) err = 1

  end subroutine parse_list


  !> How many type-103/104 cells of each phase face a partner the solvers' LPT
  !> puts on another rank: the exchange the coupling will pay for over MPI.
  !> A volumetric coupling has no such records and, under same-cut, sits on
  !> one rank cell for cell by construction.
  subroutine report_interface()
    integer :: ip, jp, o, p, q, ntot, nmpi

    if (cfg%nphase /= 2) return
    do ip = 1, 2
      jp = 3 - ip
      if (.not. scan(ip)%ok) cycle
      ntot = 0; nmpi = 0
      do o = 1, scan(ip)%ntot
        if (scan(ip)%ctype(o) /= 103 .and. scan(ip)%ctype(o) /= 104) cycle
        ntot = ntot + 1
        p = dec_locate(dec(ip), scan(ip)%cell(1,o), scan(ip)%cell(2,o), scan(ip)%cell(3,o), scan(ip)%cell(4,o))
        q = dec_locate(dec(jp), scan(ip)%donor(1,o), scan(ip)%donor(2,o), scan(ip)%donor(3,o), scan(ip)%donor(4,o))
        if (p == 0 .or. q == 0) cycle
        if (own(ip)%r(p) /= own(jp)%r(q)) nmpi = nmpi + 1
      enddo
      if (ntot > 0) write(*,'(A,I0,A,I0,A,I0,A,I0,A)') ' Interface over MPI (phase ', ip, ' -> ', jp, '): ', &
        nmpi, ' of ', ntot, ' type-103/104 cells face a partner on another rank'
    enddo

  end subroutine report_interface


  subroutine command_line_argument()
    character(len=llen) :: arg
    integer :: n, i

    verbose = .false.
    write_config_doc = .false.
    input_file = ''
    sweep_list = ''

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
      case('--sweep')
        if (i < n) call get_command_argument(i+1, sweep_list)
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
