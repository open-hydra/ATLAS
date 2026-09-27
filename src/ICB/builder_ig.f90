module ic_ig_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use area_law, only: Runi, legge_aree
  implicit none

contains

  subroutine build_IG_field(blk,zoneini,ig_cfg,IC_type,sp,range,dirSize,dir)
    use global_mod,                   only: verbose, llen
    use finer,                        only: file_ini
    use phase_mod,                    only: species_t, define_composition, T02T, tab_T
    use ic_block_mod
    use ic_interpolation_old_mod,     only: ensure_old_solution, oldblock, old_mesh_type
    use grid_mod,                     only: MESH_PURE_2D, mesh_cfg
    use ic_interpolation_general_mod, only: interp_map_t, compute_interp_map, apply_interp_map, interpolate_from_file, &
                                            rotate_2d_to_3d
    use config_mod,                   only: config_ig_t, config_field_source_t, &
                                            config_interpolation, sync_interpolation_config
    use io_phase_mod,                 only: read_idealgas_properties
  use composition_check_mod,        only: check_composition, COMPOSITION_TOL
    implicit none
    type(IC_block),   intent(inout)  :: blk
    type(file_ini),   intent(in)     :: zoneini
    type(config_ig_t), intent(in)    :: ig_cfg
    character(len=*), intent(inout)  :: IC_type
    real(R8),         intent(in)     :: range(6)
    integer,          intent(in)     :: dirSize
    type(species_t),  intent(inout)  :: sp
    integer,          intent(in)     :: dir(:)
    !! Local
    ! Unsepcified
    integer                       :: i, ip, j, s, k, nset
    ! Support fields for assignment and interpolation
    real(R8)                      :: M  (1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    real(R8)                      :: p0 (1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    real(R8)                      :: T0 (1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    real(R8)                      :: p  (1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    real(R8)                      :: T  (1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    real(R8)                      :: rho(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    real(R8)                      :: Rgas, gamma, vel, del, a, cp_
    real(R8)                      :: massf(1:sp%n)
    real(R8)                      :: M0, mach
    real(R8)                      :: alpha, beta, ux, uy, uz, mit, kappa, omega, rhoRij
    real(R8)                      :: throat_area, dx, dy, dz, zeta, phi
    character(len=llen)           :: OFF, OSF
    integer                       :: oldid
    real(R8)                      :: here(3)
    character(len=2)              :: nozzle_dir
    real(R8)                      :: L_threshold
    logical                       :: is_variable
    logical                       :: interp_turb, fresh_turb
    ! Interpolation-specific locals
    type(interp_map_t)            :: map
    type(var_block), allocatable  :: src_field(:)
    integer, allocatable          :: species_map_old(:)
    type(species_t)               :: old_sp
    real(R8), allocatable         :: tmp_rho(:,:,:)
    integer                       :: sold, cnt, bb
    ! Species mass-fraction profiles of this zone (y<species>-file [+ y<species>-direction]), read
    ! with the scalar-profile machinery (load_zone_field) and applied per cell (assemble_composition)
    real(R8), allocatable         :: yprof(:,:,:,:)   ! (i,j,k,s): profile of species s
    logical, allocatable          :: has_yprof(:)
    real(R8), parameter           :: YSUM_TOL = 1.0e-3_R8   ! |1 - sum y| accepted: renormalised with a WARNING
    real(R8), parameter           :: YSUM_EPS = 1.0e-12_R8  ! rounding: renormalised in silence
    integer                       :: nrenorm, nclip
    real(R8)                      :: ydev, ydev_max, yneg_min
    character(len=64)             :: xsect          ! the deck section of the zone (x-section), for messages
    character(len=:), allocatable :: zsuffix        ! ' (section [<deck section>])'
    integer                       :: ierr_xs
    ! plenum rows of a nozzle zone outside its range (assign_nozzle): recorded in blk%plenum_ig after the zone
    logical, allocatable          :: plenum_new(:,:,:)

    is_variable = .false.
    interp_turb = .false.
    zsuffix = ''
    call zoneini%get(section_name='zone', option_name='x-section', val=xsect, error=ierr_xs)
    if (ierr_xs == 0) zsuffix = ' (section ['//trim(xsect)//'])'
    call load_zone_field(M, ig_cfg%mach, 1.d0)
    call load_zone_field(p0, ig_cfg%p0, 1.d0)
    call load_zone_field(T0, ig_cfg%T0, 1.d0)
    call load_zone_field(p, ig_cfg%p, 1.d0)
    call load_zone_field(T, ig_cfg%T, 1.d0)
    call load_zone_field(rho, ig_cfg%rho, 1.d0)
    call load_species_profiles()

    if (is_variable .and. IC_type == 'nozzle') write(*,'(A,I0,A)') '[WARNING] build_IG_field: block ', blk%id, &
      ': a *-file profile of this nozzle zone makes it variable (the nozzle law is not applied)'
    if (is_variable) IC_type = 'variable'

    alpha = ig_cfg%velocity%alpha
    beta = ig_cfg%velocity%beta
    ! angles absent from the zone section arrive as huge(): 0, set here in serial code (assign_velocity_components runs
    ! inside the parallel region of assign_homogeneous and must not write these shared host variables)
    if (alpha>2026d0) alpha = 0d0
    if (beta>2026d0)  beta = 0d0
    ux = ig_cfg%velocity%u
    uy = ig_cfg%velocity%v
    uz = ig_cfg%velocity%w

    mit = ig_cfg%turbulence%mit
    kappa = ig_cfg%turbulence%kappa
    omega = ig_cfg%turbulence%omega
    rhoRij = ig_cfg%turbulence%rhoRij
    ! Turbulence model of the block: a model already set on this block by an
    ! earlier zone (configured, or adopted from an interpolation source)
    ! persists; a later zone may only confirm it.
    fresh_turb = .not.allocated(blk%ig%turbprop)   ! no earlier zone set a turbulence model on this block
    if (allocated(blk%ig%turbprop)) then
      if (ig_cfg%turbulence%nrans > 0 .and. ig_cfg%turbulence%nrans /= blk%nrans) then
        write(*,*) '[ERROR] build_IG_field: zone turbulence model (nrans =', ig_cfg%turbulence%nrans, &
          ') differs from the model already set on this block (nrans =', blk%nrans, ')'
        stop 1
      endif
    else
      blk%nrans = ig_cfg%turbulence%nrans
    endif

    nozzle_dir = ig_cfg%nozzle_direction
    L_threshold = ig_cfg%nozzle_threshold

    OSF = ig_cfg%interpolation%old_species
    OFF = ig_cfg%interpolation%old_solution
    oldid = ig_cfg%interpolation%old_block_id
    call sync_interpolation_config(ig_cfg%interpolation)
    if (ig_cfg%interpolation%enabled) IC_type = 'interpolation'
    if (allocated(yprof) .and. IC_type == 'interpolation') then
      write(*,'(A)') '[ERROR] build_IG_field: y<species>-file profiles in an interpolation zone: the composition'// &
        ' of an interpolation zone comes from the old solution (use a variable or homogeneous zone)'
      stop 1
    endif
    nrenorm = 0
    ydev_max = 0.0_R8
    nclip = 0
    yneg_min = 0.0_R8

    write(*,*) ' -- IG type = ',trim(IC_type)

    if (.not.allocated(blk%ig%density)) then
      allocate(blk%ig%density(sp%n,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%ig%velocity(3,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%ig%pressure(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%ig%temperature(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
    endif
    if (blk%nrans > 0 .and. .not.allocated(blk%ig%turbprop)) then
      allocate(blk%ig%turbprop(blk%nrans,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      blk%ig%turbprop = 0.0_R8   ! never write uninitialised memory
      call new_turbulence_mask()
    endif


    ! The species thermo table (thermo.dat of the phase) is needed by every IC type except
    ! 'interpolation' (T0 <-> T and cp(T) lookups): without it the run used to end in a SIGSEGV on the
    ! unallocated table (read_idealgas_properties only warns and returns).
    if (IC_type /= 'interpolation' .and. .not.allocated(sp%cp)) then
      write(*,*) '[ERROR] build_IG_field: the ideal-gas thermo table (thermo.dat of this phase) was not loaded'// &
        ' (see the [WARNING] above): cp(T) lookups are impossible for IC type '//trim(IC_type)
      stop 1
    endif

    select case (IC_type)

      case ('interpolation')
        call assign_interpolation()

      case ('homogeneous')
        call assign_homogeneous()

      case ('variable')
        call assign_variable()

      case ('nozzle')
        call assign_nozzle()

      case default
        write(*,'(A)') "[ERROR] build_IG_field block "//trim(blk_id_txt())//": type = '"//trim(IC_type)//"'"//zsuffix// &
          " is not an initialisation type of an ideal-gas zone (allowed: homogeneous, variable, interpolation, nozzle)"
        stop 1

    end select
    call report_plenum_overwritten()

    ! Turbulence free-stream constants of THIS zone: applied to the cells of the
    ! zone range only (exactly like p, T, u), never block-wide, so a patch zone
    ! cannot overwrite the field interpolated or assigned by another zone.
    if (blk%nrans > 0) then
      nset = 0
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (.not.cell_in_range(i,j,k)) cycle
        nset = nset + 1
        if (blk%nrans==1) then
          if(mit/=0.0) blk%ig%turbprop(1,i,j,k) = mit
          if(mit/=0.0) blk%set_turb_ig(1,i,j,k) = .true.
        elseif (blk%nrans==2) then
          if(kappa/=0.0) blk%ig%turbprop(1,i,j,k) = kappa
          if(omega/=0.0) blk%ig%turbprop(2,i,j,k) = omega
          if(kappa/=0.0) blk%set_turb_ig(1,i,j,k) = .true.
          if(omega/=0.0) blk%set_turb_ig(2,i,j,k) = .true.
        elseif (blk%nrans==7) then
          if(rhoRij/=0.0) blk%ig%turbprop(1:3,i,j,k) = rhoRij
          if(.not.interp_turb .and. rhoRij/=0.0) blk%ig%turbprop(4:6,i,j,k) = 1d-8   ! shear default only with an explicit rhoRij
          if(omega/=0.0) blk%ig%turbprop(7,i,j,k) = omega
          if(rhoRij/=0.0) blk%set_turb_ig(1:6,i,j,k) = .true.
          if(omega/=0.0) blk%set_turb_ig(7,i,j,k) = .true.
        endif
      enddo; enddo; enddo
      if (nset < product(blk%dim) .and. (mit /= 0.0_R8 .or. kappa /= 0.0_R8 .or. omega /= 0.0_R8 .or. rhoRij /= 0.0_R8)) &
        write(*,*) ' - build_IG_field: turbulence constants of this zone applied to ', nset, ' of ', product(blk%dim), &
          ' cells (zone range); the other cells keep their current turbulence field'
    endif
    ! A configured model with neither an interpolated source field nor a
    ! free-stream key keeps the zero initialisation: say so.
    ! under an omega model (k-omega, Wilcox 2006, SSG/LRR-omega: nrans 2 or 7) a
    ! zero omega, k or stress band divides in the solver kernels (Q2D, MOSE, ARES): the field is
    ! known to be wrong and is refused, naming the zone keys that fill a laminar source. Under
    ! SA (nrans 1) nu_tilde = 0 is a fixed point: WARNING only.
    if (blk%nrans > 0 .and. .not.interp_turb .and. fresh_turb) then
      if (blk%nrans == 1 .and. mit    == 0.0_R8) call warn_unset("mi_t (key mit)")
      if (blk%nrans == 2 .and. kappa  == 0.0_R8) call refuse_unset("kappa (key kappa)", "k-omega (nrans = 2)", "kappa and omega")
      if (blk%nrans == 2 .and. omega  == 0.0_R8) call refuse_unset("omega (key omega)", "k-omega (nrans = 2)", "kappa and omega")
      if (blk%nrans == 7 .and. rhoRij == 0.0_R8) call refuse_unset("ru'u' rv'v' rw'w' (key rhoRij)", "Reynolds-stress (nrans = 7)", "rhoRij and omega")
      if (blk%nrans == 7 .and. omega  == 0.0_R8) call refuse_unset("omega (key omega)", "Reynolds-stress (nrans = 7)", "rhoRij and omega")
    endif
    ! L5 (state-range check): the state this zone wrote must be physical
    call check_written_state()

  
  contains

  
    ! cells whose turbulence bands a zone has set (constants of the zone range or source bands): the
    ! bands of the other cells keep 0 and are refused under an omega model after the last zone (build_IC)
    subroutine new_turbulence_mask()
      implicit none
      if (allocated(blk%set_turb_ig)) deallocate(blk%set_turb_ig)
      allocate(blk%set_turb_ig(blk%nrans,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)), source=.false.)
    end subroutine new_turbulence_mask

    ! The plenum rows of a nozzle zone cover the whole cross-section upstream of nozzle-threshold, also
    ! outside the range of the zone, so in a multizone block the zone order decides the state of those
    ! cells. The behaviour is kept and reported: this zone overwrites cells that the plenum of an earlier
    ! nozzle zone wrote outside that zone's range (the cells of this zone's range); then the plenum cells
    ! of this zone, if it is a nozzle zone, are recorded for the zones after it.
    subroutine report_plenum_overwritten()
      implicit none
      integer :: nover, ic, jc, kc
      if (.not. allocated(blk%plenum_ig)) return
      nover = 0
      do kc = 1, blk%dim(3); do jc = 1, blk%dim(2); do ic = 1, blk%dim(1)
        if (.not. blk%plenum_ig(ic,jc,kc)) cycle
        if (.not. cell_in_range(ic,jc,kc)) cycle
        nover = nover + 1
        blk%plenum_ig(ic,jc,kc) = .false.
      enddo; enddo; enddo
      if (nover > 0) write(*,'(A,I0,A)') '[WARNING] build_IG_field block '//trim(blk_id_txt())//zsuffix//': this zone '// &
        'overwrites ', nover, ' cells that the plenum rows of an earlier nozzle zone wrote outside the range of that zone'// &
        ' (the plenum covers the whole cross-section upstream of nozzle-threshold): the zone order decides their state'
      if (allocated(plenum_new)) blk%plenum_ig = blk%plenum_ig .or. plenum_new
    end subroutine report_plenum_overwritten

    subroutine warn_unset(what)
      implicit none
      character(len=*), intent(in) :: what
      write(*,*) '[WARNING] build_IG_field: turbulence band '//what// &
        ' has no value for this zone (no turbulent source, no key): it keeps its current content (0 unless set by another zone)'
    end subroutine warn_unset

    subroutine refuse_unset(what, model, keys)
      implicit none
      character(len=*), intent(in) :: what, model, keys
      write(*,'(A)') '[ERROR] build_IG_field: turbulence band '//what//' would be written as 0 under the '//model// &
        ' model: the solver kernels divide by it. Give the zone keys '//keys//' (a laminar source onto a'// &
        ' RANS target needs free-stream values), or nrans = 0 for a laminar field'
      stop 1
    end subroutine refuse_unset

    ! state-range check: T inside the thermo table (the cp/h lookups of the solvers read it), p > 0,
    ! no negative partial density, on the cells of this zone; written IC files with T = 1.5e22 K,
    ! 0.9 K or p <= 0 used to leave ICB with exit 0.
    subroutine check_written_state()
      implicit none
      integer  :: i, j, k, s, tlo, thi, nout
      real(R8) :: tt, pp, tmin, tmax
      logical  :: bad

      tlo = 0; thi = huge(1)
      if (allocated(sp%cp)) then
        tlo = lbound(sp%cp, dim=2) + 1
        thi = ubound(sp%cp, dim=2) - 1
      endif
      nout = 0; tmin = huge(1.0_R8); tmax = 0.0_R8
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (.not. cell_in_range(i,j,k)) cycle
        tt = blk%ig%temperature(i,j,k); pp = blk%ig%pressure(i,j,k)
        bad = .not. (tt > 0.0_R8) .or. .not. (pp > 0.0_R8) .or. tt /= tt .or. pp /= pp .or. tt > 1.0e5_R8
        do s = 1, sp%n
          if (.not. (blk%ig%density(s,i,j,k) >= 0.0_R8)) bad = .true.
        enddo
        if (bad) then
          write(*,'(A,I0,A,I0,A,I0,A,I0,A,ES12.5,A,ES12.5,A,ES12.5)') '[ERROR] build_IG_field block ', blk%id, &
            ': the initial field is not physical at cell (', i, ',', j, ',', k, '): T = ', tt, ' K, p = ', pp, &
            ' Pa, rho = ', sum(blk%ig%density(:,i,j,k))
          write(*,'(A)') '        (T and p must be positive and finite, T below 1e5 K, no partial density negative:'// &
            ' check p, T, rho, T0/p0, the composition or the source)'
          stop 1
        endif
        if (tt < real(tlo, R8) .or. tt > real(thi, R8)) then
          nout = nout + 1; tmin = min(tmin, tt); tmax = max(tmax, tt)
        endif
      enddo; enddo; enddo
      ! outside the loaded table the solvers clamp their cp/h lookups to its ends: reported, not refused
      if (nout > 0) write(*,'(A,I0,A,I0,A,I0,A,I0,A,ES12.5,A,ES12.5,A)') '[WARNING] build_IG_field block ', blk%id, &
        ': the temperature of ', nout, ' cells lies outside the thermo table [', tlo, ', ', thi, '] K (T = ', &
        tmin, ' .. ', tmax, '): the solver clamps its cp/h lookups there'
    end subroutine check_written_state

    subroutine assign_interpolation()
      implicit none
      integer :: n_old_sp
      real(R8) :: wmax   ! largest third velocity component discarded on a pure-2D target
      real(R8), allocatable :: sv_rho(:,:,:,:), sv_vel(:,:,:,:), sv_p(:,:,:), sv_T(:,:,:), sv_turb(:,:,:,:)
      logical :: partial

      associate( T0c => T0(1,1,1), p0c => p0(1,1,1) )

      ! The zone writes the cells of its range only, like every other zone type: the state of the
      ! cells outside it (set by other zones) is kept aside here and put back after the interpolation
      partial = .false.
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (.not. cell_in_range(i,j,k)) partial = .true.
      enddo; enddo; enddo
      if (partial) then
        sv_rho = blk%ig%density
        sv_vel = blk%ig%velocity
        sv_p   = blk%ig%pressure
        sv_T   = blk%ig%temperature
        if (allocated(blk%ig%turbprop)) sv_turb = blk%ig%turbprop
      endif

      ! Load old species (local, not cached in module)
      if (trim(OSF) /= '') then
        call read_idealgas_properties(OSF, old_sp)
      else
        old_sp = sp
      endif

      ! Lazy-load old solution. Pass the known old-species count so the reader
      ! locates velocity/pressure by the authoritative species number rather
      ! than guessing it from the file column count. This makes interpolation
      ! robust to source files that carry extra trailing variables (e.g. a
      ! solver's derived T, gamma, R, or turbulence fields).
      call ensure_old_solution(OFF, 'IG', old_sp%n)

      ! Turbulence policy: if the block has no turbulence configured but the
      ! source solution carries turbulence variables, adopt the source model so
      ! those fields are interpolated too. When turbulence IS configured, the
      ! configured value/model wins (constant assignment happens post-select).
      if (oldblock(1)%nrans > 0) then
        if (blk%nrans == 0) then
          blk%nrans = oldblock(1)%nrans
          if (allocated(blk%ig%turbprop)) deallocate(blk%ig%turbprop)
          allocate(blk%ig%turbprop(blk%nrans,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
          blk%ig%turbprop = 0.0_R8
          call new_turbulence_mask()
        elseif (blk%nrans /= oldblock(1)%nrans) then
          write(*,*) '[WARNING] build_IG_field: block turbulence model (nrans =', blk%nrans, &
            ') differs from the source solution (nrans =', oldblock(1)%nrans, &
            '): source turbulence NOT interpolated (slots of different models do not correspond)'
        endif
      endif
      ! a partial zone that adopted the source model above had no turbulence state to keep aside: the
      ! cells outside its range keep 0 (no zone set them), and the interpolated band stays in the range
      if (partial .and. allocated(blk%ig%turbprop)) then
        if (allocated(sv_turb)) then
          if (size(sv_turb,1) /= size(blk%ig%turbprop,1)) deallocate(sv_turb)
        endif
        if (.not. allocated(sv_turb)) then
          allocate(sv_turb, mold=blk%ig%turbprop)
          sv_turb = 0.0_R8
        endif
      endif

      ! Species count in old block
      n_old_sp = size(oldblock(1)%ig%density, 1)

      ! Build species name map: new species s -> old species index, or 0 if absent
      allocate(species_map_old(sp%n))
      species_map_old = 0
      do s = 1, sp%n
        do sold = 1, old_sp%n
          if (sp%name(s) == old_sp%name(sold)) then
            species_map_old(s) = sold
            exit
          endif
        enddo
      enddo

      ! Equilibrium mass-fraction decomposition (pre-seed densities before map multiply)
      call define_composition(zoneini, sp, T0c, p0c)
      call check_composition(zoneini, 'zone', sp, 'block '//trim(blk_id_txt())//' zone')
      if (any(sp%massf>0.d0)) then
        if (verbose) write(*,*) "[LOG] Species mass fractions decomposition in interpolation"
        do s = 1, sp%n
          blk%ig%density(s,:,:,:) = max(sp%massf(s),1d-20)
        enddo
      endif

      ! Build interpolation map (once for all fields)
      call compute_interp_map(map, oldblock, blk, oldid, config_interpolation % law)

      ! ---- Density ----
      ! 'index'-law mass-fraction decomposition shortcut (old has 1 species, new densities pre-set)
      if (config_interpolation % law == 'index' .and. &
          any(blk%ig%density(:,1,1,1) /= 0.0_R8) .and. old_sp%n == 1) then
        allocate(src_field(size(oldblock)))
        do bb = 1, size(oldblock)
          allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
          src_field(bb)%var = oldblock(bb)%ig%density(1,:,:,:)
        enddo
        allocate(tmp_rho(blk%dim(1), blk%dim(2), blk%dim(3)))
        call apply_interp_map(map, tmp_rho, src_field)
        !$omp parallel do collapse(3) private(i,j,k)
        do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
          blk%ig%density(:,i,j,k) = blk%ig%density(:,i,j,k) * tmp_rho(i,j,k)
        enddo; enddo; enddo
        !$omp end parallel do
        deallocate(tmp_rho)
        call dealloc_src()
      else
        ! Normal per-species interpolation
        do s = 1, sp%n
          sold = species_map_old(s)
          if (sold > 0) then
            allocate(src_field(size(oldblock)))
            do bb = 1, size(oldblock)
              allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
              src_field(bb)%var = oldblock(bb)%ig%density(sold,:,:,:)
            enddo
            call apply_interp_map(map, blk%ig%density(s,:,:,:), src_field)
            call dealloc_src()
          else
            blk%ig%density(s,:,:,:) = 1.0e-20_R8
          endif
        enddo
        ! dropped-species rule (composition sum): species of the source that the target set does not declare are dropped
        ! above; their mass must not vanish silently (a restart 23 % lighter and hotter was observed)
        call reconcile_dropped_species()
      endif

      ! ---- Velocity (3 components) ----
      do cnt = 1, 3
        allocate(src_field(size(oldblock)))
        do bb = 1, size(oldblock)
          allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
          src_field(bb)%var = oldblock(bb)%ig%velocity(cnt,:,:,:)
        enddo
        call apply_interp_map(map, blk%ig%velocity(cnt,:,:,:), src_field)
        call dealloc_src()
      enddo
      ! A pure-2D (x,y) target holds u, v only (write_vtk_tec): the third component of a wedge / one-cell
      ! 3-D source (the swirl w = v_theta) is interpolated above and then dropped by the writer: reported
      ! (it was discarded in silence)
      if (mesh_cfg%meshType == MESH_PURE_2D) then
        wmax = maxval(abs(blk%ig%velocity(3,:,:,:)))
        if (wmax > 0.0_R8) write(*,'(A,ES12.5,A)') '[WARNING] build_IG_field block '//trim(blk_id_txt())// &
          ': the source carries a third velocity component (swirl w / v_theta, max |w| = ', wmax, &
          ') that the 2D (x,y) target cannot hold: discarded (the product carries u, v only)'
      endif

      ! ---- Pressure ----
      allocate(src_field(size(oldblock)))
      do bb = 1, size(oldblock)
        allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
        src_field(bb)%var = oldblock(bb)%ig%pressure
      enddo
      call apply_interp_map(map, blk%ig%pressure, src_field)
      call dealloc_src()

      ! ---- Turbulent properties ----
      ! Interpolate the turbulence field only when source and block use the
      ! same model (same band count): slots of different models never
      ! correspond positionally.
      if (blk%nrans > 0 .and. oldblock(1)%nrans == blk%nrans) then
        do cnt = 1, blk%nrans
          allocate(src_field(size(oldblock)))
          do bb = 1, size(oldblock)
            allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
            src_field(bb)%var = oldblock(bb)%ig%turbprop(cnt,:,:,:)
          enddo
          call apply_interp_map(map, blk%ig%turbprop(cnt,:,:,:), src_field)
          call dealloc_src()
        enddo
        interp_turb = .true.
      endif

      ! ---- 2D -> 3D rotation of the interpolated velocity / Reynolds stresses (index law) ----
      ! One-cell source (pure-2D x-r plane or one-cell wedge) revolved onto a target whose k-lines
      ! are circles about x; nothing is rotated for a z-extruded (planar) target; with another law a
      ! revolved target is refused with an ERROR. See rotate_2d_to_3d.
      if (config_interpolation%law == 'extrude') then
        continue   ! the extruded source already carries the velocity (and stresses) of each azimuth
      elseif (interp_turb .and. blk%nrans == 7) then
        call rotate_2d_to_3d(map, oldblock, blk, old_mesh_type == MESH_PURE_2D, config_interpolation%law == 'index', &
                             blk%ig%velocity, blk%ig%turbprop)
      else
        call rotate_2d_to_3d(map, oldblock, blk, old_mesh_type == MESH_PURE_2D, config_interpolation%law == 'index', &
                             blk%ig%velocity)
      endif

      call map%destroy()
      deallocate(species_map_old)

      ! Temperature evaluation (not performed during interpolation but needed for multi-phase coupling)
      !$omp parallel private(i,j,k,massf,Rgas)
      !$omp do collapse(3)
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
            massf = blk%ig%density(:,i,j,k)/sum(blk%ig%density(:,i,j,k))
            Rgas = sum(Runi*massf/sp%w)
            blk%ig%temperature(i,j,k) = blk%ig%pressure(i,j,k)/(Rgas*sum(blk%ig%density(:,i,j,k)))
      enddo; enddo; enddo
      !$omp end parallel

      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (cell_in_range(i,j,k)) then
          blk%set_ig(i,j,k) = .true.
          if (interp_turb) blk%set_turb_ig(:,i,j,k) = .true.
        elseif (partial) then
          blk%ig%density(:,i,j,k)   = sv_rho(:,i,j,k)
          blk%ig%velocity(:,i,j,k)  = sv_vel(:,i,j,k)
          blk%ig%pressure(i,j,k)    = sv_p(i,j,k)
          blk%ig%temperature(i,j,k) = sv_T(i,j,k)
          if (allocated(sv_turb)) then
            if (size(sv_turb,1) == size(blk%ig%turbprop,1)) blk%ig%turbprop(:,i,j,k) = sv_turb(:,i,j,k)
          endif
        endif
      enddo; enddo; enddo

      endassociate
    end subroutine assign_interpolation

    ! Total density of the source interpolated once more; the target partial densities are
    ! scaled cell by cell to it when the lost fraction is <= 1e-3 (WARNING naming the dropped
    ! species and the largest lost fraction), the block is refused beyond that.
    subroutine reconcile_dropped_species()
      implicit none
      character(len=:), allocatable :: dropped
      real(R8), allocatable :: tot_old(:,:,:)
      real(R8) :: tgt, lost, maxlost
      integer  :: so, s2
      logical  :: absent

      dropped = ''
      do so = 1, old_sp%n
        absent = .true.
        do s2 = 1, sp%n
          if (species_map_old(s2) == so) absent = .false.
        enddo
        if (absent) dropped = dropped//' '//trim(old_sp%name(so))
      enddo
      if (dropped == '') return
      allocate(src_field(size(oldblock)))
      do bb = 1, size(oldblock)
        allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
        src_field(bb)%var = sum(oldblock(bb)%ig%density, dim=1)
      enddo
      allocate(tot_old(blk%dim(1), blk%dim(2), blk%dim(3)))
      call apply_interp_map(map, tot_old, src_field)
      call dealloc_src()
      maxlost = 0.0_R8
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (tot_old(i,j,k) <= 0.0_R8) cycle
        lost = 1.0_R8 - sum(blk%ig%density(:,i,j,k)) / tot_old(i,j,k)
        maxlost = max(maxlost, lost)
      enddo; enddo; enddo
      if (maxlost > COMPOSITION_TOL) then
        write(*,'(A,ES12.5,A)') '[ERROR] build_IG_field block '//trim(blk_id_txt())//': the source species'//dropped// &
          ' are not species of the run: up to ', maxlost, ' of the source mass would be dropped (more than 1e-3);'// &
          ' declare them in the phase or take a source with the species of the run'
        stop 1
      endif
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        tgt = sum(blk%ig%density(:,i,j,k))
        if (tgt > 0.0_R8 .and. tot_old(i,j,k) > 0.0_R8) blk%ig%density(:,i,j,k) = blk%ig%density(:,i,j,k) * tot_old(i,j,k) / tgt
      enddo; enddo; enddo
      write(*,'(A,ES12.5,A)') '[WARNING] build_IG_field block '//trim(blk_id_txt())//': the source species'//dropped// &
        ' are not species of the run: dropped, the partial densities are rescaled to the source density (largest'// &
        ' lost fraction ', maxlost, ')'
      deallocate(tot_old)
    end subroutine reconcile_dropped_species

    function blk_id_txt() result(txt)
      implicit none
      character(len=12) :: txt
      write(txt, '(I0)') blk%id
    end function blk_id_txt

    subroutine refuse_state(what, val)
      implicit none
      character(len=*), intent(in) :: what
      real(R8), intent(in)         :: val
      write(*,'(A,ES12.5,A)') '[ERROR] build_IG_field block '//trim(blk_id_txt())//': the initial field is not physical: '// &
        what//' = ', val, ' (T and p must be positive and finite, T inside the thermo table: check p, T, rho, T0/p0)'
      stop 1
    end subroutine refuse_state

    ! (family rule, as the BCB 420 and 405 kernels): a stagnation T0 outside the loaded thermo
    ! table is refused on every path that expands from it (the enthalpy balance of T02T and the nozzle
    ! kernel read the cp/h tables between T0 and the static state); an expanded or given static T
    ! outside the table is reported by check_written_state, not refused (the IG-nozzle3D case).
    subroutine refuse_T0_outside_table(T0v)
      implicit none
      real(R8), intent(in) :: T0v
      integer :: lo, hi
      lo = lbound(sp%cp, dim=2) + 1; hi = ubound(sp%cp, dim=2) - 1
      if (T0v < real(lo, R8) .or. T0v > real(hi, R8)) then
        write(*,'(A,ES12.5,A,I0,A,I0,A)') '[ERROR] build_IG_field block '//trim(blk_id_txt())//': T0 = ', T0v, &
          ' K lies outside the temperature range of thermo.dat [', lo, ', ', hi, '] K (the expansion from T0 reads'// &
          ' the cp/h tables there: extend the table, or give T)'
        stop 1
      endif
    end subroutine refuse_T0_outside_table

    subroutine assign_homogeneous()
      implicit none
      associate( T0c => T0(1,1,1), p0c => p0(1,1,1), Tc => T(1,1,1), &
                 pc => p(1,1,1), rhoc => rho(1,1,1), Mc => M(1,1,1) )
      sp%massf = 1d-20
      call define_composition(zoneini, sp, T0c, p0c)
      ! composition-sum check of the zone constants when no y<species>-file profile is given; with profiles
      ! assemble_composition checks the sum cell by cell
      if (.not.allocated(yprof)) then
        call check_composition(zoneini, 'zone', sp, 'block '//trim(blk_id_txt())//' zone', required = .true.)
      endif
      call assemble_composition(1, 1, 1)
      call report_renormalisation()

      ! R
      Rgas = sum(Runi*sp%massf/sp%w)
      ! Temperature
      if (T0c < 0.0_R8 .or. T0c /= T0c) call refuse_state('T0', T0c)
      if (T0c==0 .and. Tc==0) Tc = pc/(Rgas*rhoc)
      if (T0c/=0 .and. Tc==0) then
        call refuse_T0_outside_table(T0c)   !
        Tc = T02T(T0c,Mc,sp)
      endif
      ! L5 (state-range check): a non-positive or non-finite T (T = -300 given, or p / rho of the wrong sign) is
      ! refused here, before the lookup; a T outside the thermo table reads its end row (tab_T, as
      ! the solvers clamp) and is reported by check_written_state, not refused
      if (.not. (Tc > 0.0_R8) .or. Tc /= Tc) call refuse_state('T', Tc)   ! compared as reals: nint(1.5e22) overflows
      ! Mach
      cp_ = sum(sp%massf*sp%cp(:,nint(tab_T(Tc, sp))))
      gamma = cp_/(cp_-Rgas)
      del = 0.5*(gamma-1)
      a = sqrt(gamma*Rgas*Tc)
      if (Mc==0) Mc = sqrt(ux*ux+uy*uy+uz*uz)/a
      ! Pressure
      if (p0c==0 .and. pc==0) pc = Tc * (Rgas*rhoc)
      if (p0c/=0 .and. pc==0) pc = p0c/((1+del*Mc*Mc)**(gamma/(gamma-1)))
      ! Density
      if (rhoc==0) rhoc = pc/(Rgas*Tc)
      ! Velocity
      vel = Mc*a

      !$omp parallel private(i,j,k,s,here)
      !$omp do collapse(3)
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)

          if (cell_in_range(i,j,k)) then
              do s = 1, sp%n
              blk%ig%density(s,i,j,k) = rhoc*sp%massf(s)
              if (isnan(blk%ig%density(s,i,j,k))) then
                write(*,*) '[ERROR] NaN in density assignment'
                stop 1
              endif
              enddo
              blk%ig%temperature(i,j,k) = Tc
              call assign_velocity_components(i, j, k, vel)
              blk%ig%pressure(i,j,k) = pc
              blk%set_ig(i,j,k) = .true.
              if (isnan(blk%ig%pressure(i,j,k))) then
                write(*,*) '[ERROR] NaN in pressure assignment'
                stop 1
              endif
          endif

      enddo; enddo; enddo
      !$omp end parallel
      endassociate
    end subroutine assign_homogeneous

    subroutine assign_variable()
      implicit none

      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)

          ! the cells outside the zone range are neither assigned nor checked (a profile value
          ! outside the zone is meaningless there)
          if (.not.cell_in_range(i,j,k)) cycle
          sp%massf = 1d-20
          call define_composition(zoneini, sp, T0(i,j,k), p0(i,j,k))
          ! composition-sum check on this path too: the keys are those of the zone, the WARNING is printed once;
          ! with y<species>-file profiles assemble_composition checks the sum cell by cell
          if (.not.allocated(yprof)) then
            call check_composition(zoneini, 'zone', sp, 'block '//trim(blk_id_txt())//' zone', &
                                   report = (i == 1 .and. j == 1 .and. k == 1), required = .true.)
          endif
          call assemble_composition(i, j, k)

          ! R
          Rgas = sum(Runi*sp%massf/sp%w)

          ! Temperature
          if (T0(i,j,k)==0 .and. T(i,j,k)==0) T(i,j,k) = p(i,j,k)/(Rgas*rho(i,j,k))
          if (T0(i,j,k)/=0 .and. T(i,j,k)==0) then
            call refuse_T0_outside_table(T0(i,j,k))   !
            T(i,j,k) = T02T(T0(i,j,k),M(i,j,k),sp)
          endif
          ! state-range check: non-positive / non-finite T refused before the lookup, T outside the
          ! table reads its end row and is reported by check_written_state
          if (.not. (T(i,j,k) > 0.0_R8) .or. T(i,j,k) /= T(i,j,k)) call refuse_state('T', T(i,j,k))
          cp_ = sum(sp%massf*sp%cp(:,nint(tab_T(T(i,j,k), sp))))
          gamma = cp_/(cp_-Rgas)
          del = 0.5*(gamma-1)
          ! Mach
          if (M(i,j,k)==0) M(i,j,k) = sqrt((ux*ux+uy*uy+uz*uz)/(gamma*Rgas*T(i,j,k)))
          ! Pressure
          if (p0(i,j,k)==0 .and. p(i,j,k)==0) p(i,j,k) = T(i,j,k) * (Rgas*rho(i,j,k))
          if (p0(i,j,k)/=0 .and. p(i,j,k)==0) p(i,j,k) = p0(i,j,k)/((1+del*M(i,j,k)*M(i,j,k))**(gamma/(gamma-1)))
          ! Density
          if (rho(i,j,k)==0) rho(i,j,k) = p(i,j,k)/(Rgas*T(i,j,k))

            if (cell_in_range(i,j,k)) then
              do s = 1, sp%n
                blk%ig%density(s,i,j,k) = rho(i,j,k)*sp%massf(s)
                if (isnan(blk%ig%density(s,i,j,k))) then
                  write(*,*) '[ERROR] NaN in density assignment'
                  stop 1
                endif
              enddo
              a = sqrt(gamma*Rgas*T(i,j,k))
              vel = M(i,j,k)*a
              blk%ig%temperature(i,j,k) = T(i,j,k)
              call assign_velocity_components(i, j, k, vel)
              blk%ig%pressure(i,j,k) = p(i,j,k)
              blk%set_ig(i,j,k) = .true.
              if (isnan(blk%ig%pressure(i,j,k))) then
                write(*,*) '[ERROR] NaN in pressure assignment'
                stop 1
              endif
          endif

      enddo; enddo; enddo
      call report_renormalisation()
    end subroutine assign_variable

    subroutine assign_nozzle()
      implicit none
      real(R8), allocatable :: radius_ext(:), radius_int(:), area(:)
      integer :: ib1, ib2, ib3, throat_cell, L_threshold_cell, nplenum_over

      associate( T0c => T0(1,1,1), p0c => p0(1,1,1) )
      ! Assign species mass fractions (if equilibrium also pressure and temperature may be assigned)
      sp%massf = 1d-20
      call define_composition(zoneini, sp, T0c, p0c)
      ! composition-sum check of the zone constants when no y<species>-file profile is given; with profiles
      ! assemble_composition checks the sum cell by cell
      if (.not.allocated(yprof)) then
        call check_composition(zoneini, 'zone', sp, 'block '//trim(blk_id_txt())//' zone', required = .true.)
      endif
      call assemble_composition(1, 1, 1)
      call report_renormalisation()

      allocate(radius_ext(1:blk%dim(1)))
      allocate(radius_int(1:blk%dim(1)))
      allocate(area(1:blk%dim(1)))

      Rgas = sum(Runi*sp%massf/sp%w)
      ! state-range check: a non-positive / non-finite T0 is refused before the lookup; a T0 outside
      ! the table is refused too; the expanded field outside it is reported by check_written_state
      if (.not. (T0c > 0.0_R8) .or. T0c /= T0c) call refuse_state('T0', T0c)
      call refuse_T0_outside_table(T0c)
      cp_ = sum(sp%massf*sp%cp(:,nint(tab_T(T0c, sp))))
      gamma = cp_/(cp_-Rgas)
      del = 0.5*(gamma-1)

      do i = 1, blk%dim(1)
        radius_ext(i) = sqrt( 0.25*(blk%node(i-1,blk%dim(2),0)%c(2)+blk%node(i,blk%dim(2),0)%c(2))**2 + &
                              0.25*(blk%node(i-1,blk%dim(2),0)%c(3)+blk%node(i,blk%dim(2),0)%c(3))**2 )
        radius_int(i) = sqrt( 0.25*(blk%node(i-1,0,0)%c(2)+blk%node(i,0,0)%c(2))**2 + &
                              0.25*(blk%node(i-1,0,0)%c(3)+blk%node(i,0,0)%c(3))**2 )
      enddo
      area = acos(-1d0)*abs(radius_ext*radius_ext-radius_int*radius_int)
      throat_cell = minloc(area,1)
      throat_area = area(throat_cell)

      L_threshold_cell = 0
      do i = 1, blk%dim(1)
        if (blk%center(i,1,1)%c(1)>L_threshold) then
          L_threshold_cell = i
          exit
        endif
      enddo

      if (nozzle_dir=='dx') then
        ip = 1
        ib1 = 1
        ib2 = L_threshold_cell+1
        ib3 = blk%dim(1)
      elseif (nozzle_dir=='sx') then
        ip = -1
        ib1 = blk%dim(1)
        ib2 = L_threshold_cell+1
        ib3 = 1
      endif

      ! plenum rows outside the range of this zone: the cells an earlier zone wrote there are overwritten
      ! (reported), and the zones after this one are checked against them (report_plenum_overwritten)
      allocate(plenum_new(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)), source=.false.)
      nplenum_over = 0
      do i = ib1, ib2, ip
        do k = 1, blk%dim(3)
          do j = 1, blk%dim(2)
            if (cell_in_range(i,j,k)) cycle
            plenum_new(i,j,k) = .true.
            if (blk%set_ig(i,j,k)) nplenum_over = nplenum_over + 1
          enddo
        enddo
      enddo
      if (nplenum_over > 0) write(*,'(A,I0,A)') '[WARNING] build_IG_field block '//trim(blk_id_txt())//zsuffix// &
        ': the plenum rows of this nozzle zone (the whole cross-section upstream of nozzle-threshold, also outside'// &
        ' the range of the zone) overwrite ', nplenum_over, ' cells that an earlier zone wrote: the zone order decides'// &
        ' their state'

      do i = ib1, ib2, ip
        do s = 1, sp%n
          blk%ig%density(s,i,:,:) = sp%massf(s)*p0c/(Rgas*T0c)
        enddo
        blk%ig%pressure(i,:,:) = p0c
        blk%ig%velocity(:,i,:,:) = 0.0
        blk%ig%temperature(i,:,:) = T0c
        blk%set_ig(i,:,:) = .true.   ! plenum rows: every j, k of the row, whatever the range
      enddo

      do i = ib2, ib3, ip
        M0 = 0.001
        if (ip*i > ip*throat_cell) M0 = 1.30
        call legge_aree(area(i),M0,Mach,throat_area,gamma)
        Mach = Mach * ip
        !$omp parallel private(j,k,s,here,dx,dy,dz,zeta,phi)
        !$omp do collapse(2)
        do k = 1, blk%dim(3)
          do j = 1, blk%dim(2)
            if (cell_in_range(i,j,k)) then
              dx = blk%center(i,j,k)%c(1)-blk%center(i-1,j,k)%c(1)
              dy = blk%center(i,j,k)%c(2)-blk%center(i-1,j,k)%c(2)
              dz = blk%center(i,j,k)%c(3)-blk%center(i-1,j,k)%c(3)
              zeta = atan(dy/sqrt(dx*dx+dz*dz))
              phi = atan(dz/dx)
              do s = 1, sp%n
                blk%ig%density(s,i,j,k) = sp%massf(s)*p0c/(Rgas*T0c)/((1+del*(Mach**2))**(0.5/del))
              enddo
              blk%ig%pressure(i,j,k) = p0c/((1+del*(Mach**2))**(gamma/(2*del)))
              blk%ig%velocity(1,i,j,k) = Mach*sqrt(gamma*Rgas*T0c/(1+del*(Mach**2)))*cos(zeta)*cos(phi)
              blk%ig%velocity(2,i,j,k) = Mach*sqrt(gamma*Rgas*T0c/(1+del*(Mach**2)))*sin(zeta)
              blk%ig%velocity(3,i,j,k) = Mach*sqrt(gamma*Rgas*T0c/(1+del*(Mach**2)))*cos(zeta)*sin(phi)
              blk%ig%temperature(i,j,k) = T0c/(1+del*(Mach**2))
              blk%set_ig(i,j,k) = .true.
            endif
          end do
        end do
        !$omp end parallel
      end do

      endassociate
    end subroutine assign_nozzle


    ! Load a field for IG assignment. The field can be either a constant value
    ! or read from a file. File-based inputs support Tecplot data on the same
    ! grid or a 1D profile when an additional direction is provided.
    subroutine load_zone_field(field, field_cfg, scale)
      implicit none
      real(R8),         intent(inout) :: field(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
      type(config_field_source_t), intent(in) :: field_cfg
      real(R8),         intent(in)    :: scale

      if (field_cfg%has_value) then
        field = field_cfg%value
        if (scale/=1.d0) field = field*scale
        return
      endif

      field = 0.d0
      if (.not. field_cfg%has_file) return

      is_variable = .true.
      if (field_cfg%has_direction) then
        call assign_from_1D_table(blk, field_cfg%file, field_cfg%direction, field)
      else
        call interpolate_from_file(field, blk, field_cfg%file)
      endif
      if (scale/=1.d0) field = field*scale

    end subroutine load_zone_field

    ! Check if the cell center is within the specified range for IG assignment
    logical function cell_in_range(i, j, k)
      implicit none
      integer, intent(in) :: i, j, k
      real(R8)            :: here(3)   ! local: the host array is shared by the OpenMP threads (a private clause does not reach a host-associated reference)

      integer             :: n

      ! a coordinate letter compares the cell centre, an index letter (i, j, k) the cell index
      here = 1.0_R8
      do n = 1, min(dirSize, 3)
        select case (dir(n))
        case (6); here(n) = real(i, R8)
        case (7); here(n) = real(j, R8)
        case (8); here(n) = real(k, R8)
        case default; here(n) = blk%center(i,j,k)%c(dir(n))
        end select
      enddo
      cell_in_range = here(1)>=range(1) .and. here(1)<=range(2) .and. &
                      here(2)>=range(3) .and. here(2)<=range(4) .and. &
                      here(3)>=range(5) .and. here(3)<=range(6)

    end function cell_in_range

    ! Assign velocity components based on specified angles and magnitude, or user-defined values. 
    subroutine assign_velocity_components(i, j, k, vel_mag)
      implicit none
      integer,  intent(in) :: i, j, k
      real(R8), intent(in) :: vel_mag
      integer :: l

      if (ux==0.d0 .and. uy==0.d0 .and. uz==0.d0) then
        blk%ig%velocity(1,i,j,k) = vel_mag*cos(alpha)*cos(beta)
        blk%ig%velocity(2,i,j,k) = vel_mag*cos(alpha)*sin(beta)
        blk%ig%velocity(3,i,j,k) = vel_mag*sin(beta)
      else
        blk%ig%velocity(1,i,j,k) = ux
        blk%ig%velocity(2,i,j,k) = uy
        blk%ig%velocity(3,i,j,k) = uz
      endif

      do l = 1, 3
        if (isnan(blk%ig%velocity(l,i,j,k))) then
          write(*,*) '[ERROR] NaN in velocity assignment'
        endif
      enddo

    end subroutine assign_velocity_components

    ! y<species>-file [+ y<species>-direction] of this zone: the loader, file formats and direction
    ! interpolation of the scalar profiles (load_zone_field). A profile key of a species the
    ! phase does not declare is an ERROR; so are a profile next to the constant y<species> of the
    ! same species and a direction without a file (nothing is ignored in silence).
    subroutine load_species_profiles()
      implicit none
      type(config_field_source_t)   :: y_cfg
      character(len=:), allocatable :: items(:,:), key
      character(len=64)             :: base_name, file_option, dir_option
      integer                       :: q, n, err_value, err_file, err_dir

      allocate(has_yprof(sp%n))
      has_yprof = .false.
      call zoneini%get_items(items)
      if (allocated(items)) then
        do q = 1, size(items, dim=1)
          key = trim(adjustl(items(q,1)))
          n = len(key)
          if (n < 7 .or. key(1:1) /= 'y') cycle
          if (key(n-4:n) == '-file') then
            n = n - 5
          elseif (n >= 12 .and. key(n-9:n) == '-direction') then
            n = n - 10
          else
            cycle
          endif
          if (.not. any(sp%name == key(2:n))) then
            write(*,'(A,I0,A)') '[ERROR] key '//key//' in the zone of block ', blk%id, &
              ': no species '//key(2:n)//' in the ideal-gas phase of the run'
            stop 1
          endif
        enddo
      endif
      do q = 1, sp%n
        base_name   = 'y'//trim(sp%name(q))
        file_option = trim(base_name)//'-file'
        dir_option  = trim(base_name)//'-direction'
        y_cfg%value = 0.0_R8
        y_cfg%file = ''
        y_cfg%direction = ''
        call zoneini%get(section_name='zone', option_name=trim(base_name),   val=y_cfg%value,     error=err_value)
        call zoneini%get(section_name='zone', option_name=trim(file_option), val=y_cfg%file,      error=err_file)
        call zoneini%get(section_name='zone', option_name=trim(dir_option),  val=y_cfg%direction, error=err_dir)
        if (err_file /= 0) then
          if (err_dir == 0) then
            write(*,'(A,I0,A)') '[ERROR] key '//trim(dir_option)//' in the zone of block ', blk%id, &
              ': a direction without the profile file '//trim(file_option)
            stop 1
          endif
          cycle
        endif
        if (err_value == 0) then
          write(*,'(A,I0,A)') '[ERROR] key '//trim(file_option)//' in the zone of block ', blk%id, &
            ': the constant '//trim(base_name)//' is given too; give one of the two'
          stop 1
        endif
        y_cfg%has_value = .false.
        y_cfg%has_file = .true.
        y_cfg%has_direction = err_dir == 0
        if (.not.allocated(yprof)) then
          allocate(yprof(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3),1:sp%n))
          yprof = 0.0_R8
        endif
        has_yprof(q) = .true.
        call load_zone_field(yprof(:,:,:,q), y_cfg, 1.d0)
      enddo
    end subroutine load_species_profiles

    ! composition-sum check per cell: the composition of one cell = the constants of the zone (define_composition) with the
    ! y<species>-file values in place of the constants of the profiled species. |1 - sum y| up to
    ! YSUM_TOL is renormalised (one WARNING per zone), more is an ERROR; a negative value is an
    ! ERROR below -YSUM_TOL and clipped to 0 above it (its mass is part of the deviation).
    subroutine assemble_composition(i, j, k)
      implicit none
      integer, intent(in) :: i, j, k
      integer  :: q
      real(R8) :: ysum, ymin

      if (allocated(yprof)) then
        do q = 1, sp%n
          if (has_yprof(q)) sp%massf(q) = yprof(i,j,k,q)
        enddo
      endif
      ymin = minval(sp%massf)
      ! both limits carry YSUM_EPS of slack: 0.249 + 0.75 (|1 - sum y| = 1e-3 in decimal) is
      ! 1 - 1.0000000000000009e-3 in binary and lies inside the tolerance
      if (ymin < -(YSUM_TOL + YSUM_EPS)) call composition_error(i, j, k, 'a mass fraction is', ymin)
      if (ymin < 0.0_R8) then
        sp%massf = max(sp%massf, 0.0_R8)
        nclip = nclip + 1
        yneg_min = min(yneg_min, ymin)
      endif
      ysum = sum(sp%massf)
      ydev = abs(1.0_R8 - ysum)
      if (ydev > YSUM_TOL + YSUM_EPS) call composition_error(i, j, k, 'the mass fractions sum to', ysum)
      if (ydev > YSUM_EPS) then
        sp%massf = sp%massf / ysum
        nrenorm = nrenorm + 1
        ydev_max = max(ydev_max, ydev)
      endif
    end subroutine assemble_composition

    subroutine composition_error(i, j, k, what, value)
      implicit none
      integer,          intent(in) :: i, j, k
      character(len=*), intent(in) :: what
      real(R8),         intent(in) :: value

      write(*,'(A,I0,A,I0,A,I0,A,I0,A,ES12.4,A)') '[ERROR] build_IG_field: block ', blk%id, ' cell (', i, ',', j, ',', k, &
        '): '//trim(what)//' ', value, ' (tolerance 1e-3 on |1 - sum y|): check the y<species> keys and profiles of this zone'//zsuffix
      stop 1
    end subroutine composition_error

    subroutine report_renormalisation()
      implicit none

      if (nclip > 0) write(*,'(A,I0,A,I0,A,ES10.2,A)') '[WARNING] build_IG_field: block ', blk%id, &
        ': the negative mass fractions of ', nclip, ' cell(s) of this zone were set to 0 (min = ', yneg_min, ' >= -1e-3)'//zsuffix
      nclip = 0
      yneg_min = 0.0_R8
      if (nrenorm == 0) return
      write(*,'(A,I0,A,I0,A,ES9.2,A)') '[WARNING] build_IG_field: block ', blk%id, ': the mass fractions of ', nrenorm, &
        ' cell(s) of this zone were renormalised to sum 1 (max |1 - sum y| = ', ydev_max, ' <= 1e-3)'//zsuffix
      nrenorm = 0
      ydev_max = 0.0_R8
    end subroutine report_renormalisation

    subroutine dealloc_src()
      integer :: bb_tmp
      do bb_tmp = 1, size(src_field)
        if (allocated(src_field(bb_tmp)%var)) deallocate(src_field(bb_tmp)%var)
      enddo
      deallocate(src_field)
    end subroutine dealloc_src

  end subroutine build_IG_field


  subroutine assign_from_1D_table (blk, varfile, vardirection, var)
    use io_ascii_table_mod
    use ic_block_mod
    use math_utils_mod, only: interp_1d
    implicit none
    type(IC_block),   intent(in)  :: blk
    character(len=*), intent(in)  :: varfile
    character(len=*), intent(in)  :: vardirection
    real(R8),         intent(out) :: var(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    ! Local
    integer :: dir, ios, file_length, i, j, k
    real(R8), dimension(:), allocatable :: file_dir, file_var
    logical :: found

    select case (trim(vardirection))
    case ('x'); dir = 1
    case ('y'); dir = 2
    case ('z'); dir = 3
    case ('r'); dir = 4
    case ('t'); dir = 5
    case default
      write(*,*) '[ERROR] Unsupported direction in read_file_direction: ', trim(vardirection)
      stop 1
    end select

    call read_ascii_table(varfile, file_dir, file_var, ios)
    if (ios/=0) then
      write(*,*) '[ERROR] Could not read file: ', trim(varfile)
      stop 1
    endif

    file_length = size(file_dir)
    if (dir == 5) file_dir(:) = file_dir(:) * acos(-1d0) / 180d0

    !$omp parallel private(i,j,k,found)
    !$omp do collapse(3)
    do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
      found = interp_1d(blk%center(i,j,k)%c(dir), file_dir, file_var, file_length, var(i,j,k))
      if (.not.found) then
        write(*,*) '[ERROR] interpolated point ', blk%center(i,j,k)%c(dir), ' is outside the file data range.'
        write(*,*) '        File: ', trim(varfile)
        write(*,*) '        File data range: ', file_dir(1), ' to ', file_dir(file_length)
        stop 1
      endif
    enddo; enddo; enddo
    !$omp end parallel

  end subroutine assign_from_1D_table  

end module ic_ig_mod