module ic_rf_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  implicit none

contains

  subroutine build_RF_field(blk,rf_cfg,IC_type,fl,range,dirSize,dir)
    use global_mod,                    only: llen
    use phase_mod,                    only: real_fluid_t
    use ic_block_mod
    use ic_interpolation_old_mod,     only: ensure_old_solution, oldblock, old_mesh_type
    use grid_mod,                     only: MESH_PURE_2D
    use ic_interpolation_general_mod, only: interp_map_t, compute_interp_map, apply_interp_map, &
                                            interpolate_from_file, rotate_2d_to_3d
    use config_mod,                   only: config_rf_t, config_field_source_t, &
                                            config_interpolation, sync_interpolation_config
    implicit none
    type(IC_block),    intent(inout) :: blk
    type(config_rf_t), intent(in)    :: rf_cfg
    character(len=*),  intent(inout) :: IC_type
    real(R8),          intent(in)    :: range(6)
    integer,           intent(in)    :: dirSize
    type(real_fluid_t),intent(inout) :: fl
    integer,           intent(in)    :: dir(:)
    !! Local
    integer                       :: i, j, k, nset
    ! Support fields
    real(R8), allocatable  :: p  (:,:,:)
    real(R8), allocatable  :: T  (:,:,:)
    real(R8), allocatable  :: h  (:,:,:)
    real(R8), allocatable  :: vel(:,:,:)
    ! Velocity direction parameters
    real(R8)                      :: alpha, beta, ux, uy, uz
    ! Turbulence parameters
    real(R8)                      :: mit, kappa, omega, rhoRij
    ! Old-solution / interpolation parameters
    character(len=llen)           :: OFF
    integer                       :: oldid
    real(R8)                      :: here(3)
    logical                       :: is_variable
    ! Interpolation-specific locals
    type(interp_map_t)            :: map
    type(var_block), allocatable  :: src_field(:)
    integer                       :: cnt, bb
    logical                       :: interp_turb, fresh_turb

    allocate(p(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
    allocate(h(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
    allocate(T(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
    allocate(vel(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))

    is_variable = .false.
    call load_zone_field(p, rf_cfg%p, 1.d0)
    call load_zone_field(T, rf_cfg%T, 1.d0)
    call load_zone_field(h, rf_cfg%h, 1.d0)
    call load_zone_field(vel, rf_cfg%vel, 1.d0)

    if (is_variable) IC_type = 'variable'

    alpha = rf_cfg%velocity%alpha
    beta = rf_cfg%velocity%beta
    ! angles absent from the zone section arrive as huge(): 0, set here in serial code (assign_velocity_components runs
    ! inside the parallel region of assign_homogeneous and must not write these shared host variables)
    if (alpha>2026d0) alpha = 0d0
    if (beta>2026d0)  beta = 0d0
    ux = rf_cfg%velocity%u
    uy = rf_cfg%velocity%v
    uz = rf_cfg%velocity%w

    mit = rf_cfg%turbulence%mit
    kappa = rf_cfg%turbulence%kappa
    omega = rf_cfg%turbulence%omega
    rhoRij = rf_cfg%turbulence%rhoRij
    interp_turb = .false.
    ! Turbulence model of the block: a model already set on this block by an
    ! earlier zone (configured, or adopted from an interpolation source)
    ! persists; a later zone may only confirm it.
    fresh_turb = .not.allocated(blk%rf%turbprop)   ! no earlier zone set a turbulence model on this block
    if (allocated(blk%rf%turbprop)) then
      if (rf_cfg%turbulence%nrans > 0 .and. rf_cfg%turbulence%nrans /= blk%nrans) then
        write(*,*) '[ERROR] build_RF_field: zone turbulence model (nrans =', rf_cfg%turbulence%nrans, &
          ') differs from the model already set on this block (nrans =', blk%nrans, ')'
        stop 1
      endif
    else
      blk%nrans = rf_cfg%turbulence%nrans
    endif

    OFF = rf_cfg%interpolation%old_solution
    oldid = rf_cfg%interpolation%old_block_id
    call sync_interpolation_config(rf_cfg%interpolation)
    if (rf_cfg%interpolation%enabled) IC_type = 'interpolation'

    write(*,*) ' -- RF type = ',trim(IC_type)

    if (.not.allocated(blk%rf%pressure)) then
      allocate(blk%rf%velocity   (3,       1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%rf%pressure   (         1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%rf%enthalpy   (         1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%rf%temperature(         1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
    endif
    if (blk%nrans > 0 .and. .not.allocated(blk%rf%turbprop)) then
      allocate(blk%rf%turbprop(blk%nrans,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      blk%rf%turbprop = 0.0_R8   ! never write uninitialised memory
      call new_turbulence_mask()
    endif

    ! The (p,h) -> T table of the phase is needed by every IC type (ph2T): without it the run used to
    ! end in a SIGSEGV on the unallocated table (read_realfluid_properties only warns and returns).
    if (.not.allocated(fl%p) .or. .not.allocated(fl%h) .or. .not.allocated(fl%T)) then
      write(*,*) '[ERROR] build_RF_field: the real-fluid thermo table (thermo.dat of phase '//trim(fl%name)// &
        ') was not loaded (see the [WARNING] above): T(p,h) cannot be computed for IC type '//trim(IC_type)
      stop 1
    endif

    select case (IC_type)

      case ('interpolation')
        call assign_interpolation()

      case ('homogeneous')
        call assign_homogeneous()

      case ('variable')
        call assign_variable()

      case default
        write(*,'(A,I0,A)') "[ERROR] build_RF_field block ", blk%id, ": type = '"//trim(IC_type)// &
          "' is not an initialisation type of a real-fluid zone (allowed: homogeneous, variable, interpolation)"
        stop 1

    end select

    ! Turbulence post-assignment

    ! Turbulence free-stream constants of THIS zone: applied to the cells of the
    ! zone range only (exactly like p, T, u), never block-wide, so a patch zone
    ! cannot overwrite the field interpolated or assigned by another zone.
    if (blk%nrans > 0) then
      nset = 0
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (.not.cell_in_range(i,j,k)) cycle
        nset = nset + 1
        if (blk%nrans==1) then
          if(mit/=0.0) blk%rf%turbprop(1,i,j,k) = mit
          if(mit/=0.0) blk%set_turb_rf(1,i,j,k) = .true.
        elseif (blk%nrans==2) then
          if(kappa/=0.0) blk%rf%turbprop(1,i,j,k) = kappa
          if(omega/=0.0) blk%rf%turbprop(2,i,j,k) = omega
          if(kappa/=0.0) blk%set_turb_rf(1,i,j,k) = .true.
          if(omega/=0.0) blk%set_turb_rf(2,i,j,k) = .true.
        elseif (blk%nrans==7) then
          if(rhoRij/=0.0) blk%rf%turbprop(1:3,i,j,k) = rhoRij
          if(.not.interp_turb .and. rhoRij/=0.0) blk%rf%turbprop(4:6,i,j,k) = 1d-8   ! shear default only with an explicit rhoRij
          if(omega/=0.0) blk%rf%turbprop(7,i,j,k) = omega
          if(rhoRij/=0.0) blk%set_turb_rf(1:6,i,j,k) = .true.
          if(omega/=0.0) blk%set_turb_rf(7,i,j,k) = .true.
        endif
      enddo; enddo; enddo
      if (nset < product(blk%dim) .and. (mit /= 0.0_R8 .or. kappa /= 0.0_R8 .or. omega /= 0.0_R8 .or. rhoRij /= 0.0_R8)) &
        write(*,*) ' - build_RF_field: turbulence constants of this zone applied to ', nset, ' of ', product(blk%dim), &
          ' cells (zone range); the other cells keep their current turbulence field'
    endif
    ! A configured model with neither an interpolated source field nor a
    ! free-stream key keeps the zero initialisation: say so.
    ! a zero omega / k / stress band under an omega model is refused (see build_IG_field)
    if (blk%nrans > 0 .and. .not.interp_turb .and. fresh_turb) then
      if (blk%nrans == 1 .and. mit    == 0.0_R8) call warn_unset("mi_t (key mit)")
      if (blk%nrans == 2 .and. kappa  == 0.0_R8) call refuse_unset("kappa (key kappa)", "k-omega (nrans = 2)", "kappa and omega")
      if (blk%nrans == 2 .and. omega  == 0.0_R8) call refuse_unset("omega (key omega)", "k-omega (nrans = 2)", "kappa and omega")
      if (blk%nrans == 7 .and. rhoRij == 0.0_R8) call refuse_unset("ru'u' rv'v' rw'w' (key rhoRij)", "Reynolds-stress (nrans = 7)", "rhoRij and omega")
      if (blk%nrans == 7 .and. omega  == 0.0_R8) call refuse_unset("omega (key omega)", "Reynolds-stress (nrans = 7)", "rhoRij and omega")
    endif
    ! L5 (state-range check): the state this zone wrote must be physical (p > 0, T > 0)
    do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
      if (.not. cell_in_range(i,j,k)) cycle
      if (.not. (blk%rf%pressure(i,j,k) > 0.0_R8 .and. blk%rf%temperature(i,j,k) > 0.0_R8)) then
        write(*,'(A,I0,A,I0,A,I0,A,I0,A,ES12.5,A,ES12.5,A)') '[ERROR] build_RF_field block ', blk%id, &
          ': the initial field is not physical at cell (', i, ',', j, ',', k, '): p = ', blk%rf%pressure(i,j,k), &
          ' Pa, T = ', blk%rf%temperature(i,j,k), ' K (check p, T, h, or the source)'
        stop 1
      endif
    enddo; enddo; enddo


  contains

    ! -----------------------------------------------------------------------
    subroutine warn_unset(what)
      implicit none
      character(len=*), intent(in) :: what
      write(*,*) '[WARNING] build_RF_field: turbulence band '//what// &
        ' has no value for this zone (no turbulent source, no key): it keeps its current content (0 unless set by another zone)'
    end subroutine warn_unset

    subroutine refuse_unset(what, model, keys)
      implicit none
      character(len=*), intent(in) :: what, model, keys
      write(*,'(A)') '[ERROR] build_RF_field: turbulence band '//what//' would be written as 0 under the '//model// &
        ' model: the solver kernels divide by it. Give the zone keys '//keys//' (a laminar source onto a'// &
        ' RANS target needs free-stream values), or nrans = 0 for a laminar field'
      stop 1
    end subroutine refuse_unset

    ! -----------------------------------------------------------------------
    subroutine assign_interpolation()
      implicit none
      real(R8), allocatable :: sv_h(:,:,:), sv_vel(:,:,:,:), sv_p(:,:,:), sv_T(:,:,:), sv_turb(:,:,:,:)
      logical :: partial

      ! The zone writes the cells of its range only (as build_IG_field): the other cells are kept aside
      partial = .false.
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (.not. cell_in_range(i,j,k)) partial = .true.
      enddo; enddo; enddo
      if (partial) then
        sv_h   = blk%rf%enthalpy
        sv_vel = blk%rf%velocity
        sv_p   = blk%rf%pressure
        sv_T   = blk%rf%temperature
        if (allocated(blk%rf%turbprop)) sv_turb = blk%rf%turbprop
      endif

      call ensure_old_solution(OFF, 'RF')

      ! Turbulence policy (same as IG): adopt the source model when the block
      ! has none; a configured model wins and is interpolated only if it is the
      ! same model as the source's.
      if (oldblock(1)%nrans > 0) then
        if (blk%nrans == 0) then
          blk%nrans = oldblock(1)%nrans
          if (allocated(blk%rf%turbprop)) deallocate(blk%rf%turbprop)
          allocate(blk%rf%turbprop(blk%nrans,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
          blk%rf%turbprop = 0.0_R8
          call new_turbulence_mask()
        elseif (blk%nrans /= oldblock(1)%nrans) then
          write(*,*) '[WARNING] build_RF_field: block turbulence model (nrans =', blk%nrans, &
            ') differs from the source solution (nrans =', oldblock(1)%nrans, &
            '): source turbulence NOT interpolated (slots of different models do not correspond)'
        endif
      endif

      call compute_interp_map(map, oldblock, blk, oldid, config_interpolation%law)

      ! ---- Enthalpy ----
      allocate(src_field(size(oldblock)))
      do bb = 1, size(oldblock)
        allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
        src_field(bb)%var = oldblock(bb)%rf%enthalpy
      enddo
      call apply_interp_map(map, blk%rf%enthalpy, src_field)
      call dealloc_src()

      ! ---- Velocity (3 components) ----
      do cnt = 1, 3
        allocate(src_field(size(oldblock)))
        do bb = 1, size(oldblock)
          allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
          src_field(bb)%var = oldblock(bb)%rf%velocity(cnt,:,:,:)
        enddo
        call apply_interp_map(map, blk%rf%velocity(cnt,:,:,:), src_field)
        call dealloc_src()
      enddo

      ! ---- Pressure ----
      allocate(src_field(size(oldblock)))
      do bb = 1, size(oldblock)
        allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
        src_field(bb)%var = oldblock(bb)%rf%pressure
      enddo
      call apply_interp_map(map, blk%rf%pressure, src_field)
      call dealloc_src()

      ! ---- Turbulent properties ----
      ! Interpolate the turbulence field only when source and block use the
      ! same model (same band count): slots of different models never
      ! correspond positionally.
      if (blk%nrans > 0 .and. oldblock(1)%nrans == blk%nrans) then
        do cnt = 1, blk%nrans
          allocate(src_field(size(oldblock)))
          do bb = 1, size(oldblock)
            allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), &
                                       oldblock(bb)%dim(3)))
            src_field(bb)%var = oldblock(bb)%rf%turbprop(cnt,:,:,:)
          enddo
          call apply_interp_map(map, blk%rf%turbprop(cnt,:,:,:), src_field)
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
                             blk%rf%velocity, blk%rf%turbprop)
      else
        call rotate_2d_to_3d(map, oldblock, blk, old_mesh_type == MESH_PURE_2D, config_interpolation%law == 'index', &
                             blk%rf%velocity)
      endif

      call map%destroy()

      ! Temperature from EOS table (needed for multi-phase coupling)
      !$omp parallel do collapse(3) private(i,j,k)
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        blk%rf%temperature(i,j,k) = ph2T(fl, blk%rf%pressure(i,j,k), blk%rf%enthalpy(i,j,k))
      enddo; enddo; enddo
      !$omp end parallel do

      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (cell_in_range(i,j,k)) then
          blk%set_rf(i,j,k) = .true.
          if (interp_turb) blk%set_turb_rf(:,i,j,k) = .true.
        elseif (partial) then
          blk%rf%enthalpy(i,j,k)    = sv_h(i,j,k)
          blk%rf%velocity(:,i,j,k)  = sv_vel(:,i,j,k)
          blk%rf%pressure(i,j,k)    = sv_p(i,j,k)
          blk%rf%temperature(i,j,k) = sv_T(i,j,k)
          if (allocated(sv_turb)) then
            if (size(sv_turb,1) == size(blk%rf%turbprop,1)) blk%rf%turbprop(:,i,j,k) = sv_turb(:,i,j,k)
          endif
        endif
      enddo; enddo; enddo

    end subroutine assign_interpolation

    subroutine new_turbulence_mask()
      implicit none
      if (allocated(blk%set_turb_rf)) deallocate(blk%set_turb_rf)
      allocate(blk%set_turb_rf(blk%nrans,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)), source=.false.)
    end subroutine new_turbulence_mask

    ! -----------------------------------------------------------------------
    subroutine assign_homogeneous()
      implicit none
      real(R8) :: pc, Tc, hc, vel_c

      pc    = p(1,1,1)
      vel_c = vel(1,1,1)
      if (h(1,1,1) /= 0.0_R8) then
        hc = h(1,1,1)
        Tc = ph2T(fl, pc, hc)
      else
        Tc = T(1,1,1)
        hc = pT2h(fl, pc, Tc)
      endif

      !$omp parallel do collapse(3) private(i,j,k,here)
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (cell_in_range(i,j,k)) then
          blk%rf%pressure   (i,j,k) = pc
          blk%rf%enthalpy   (i,j,k) = hc
          blk%rf%temperature(i,j,k) = Tc
          call assign_velocity_components(i, j, k, vel_c)
          blk%set_rf(i,j,k) = .true.
        endif
      enddo; enddo; enddo
      !$omp end parallel do

    end subroutine assign_homogeneous

    ! -----------------------------------------------------------------------
    subroutine assign_variable()
      implicit none
      real(R8) :: pv, Tv, hv

      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        pv = p(i,j,k)
        if (h(i,j,k) /= 0.0_R8) then
          hv = h(i,j,k)
          Tv = ph2T(fl, pv, hv)
        else
          Tv = T(i,j,k)
          hv = pT2h(fl, pv, Tv)
        endif
        if (cell_in_range(i,j,k)) then
          blk%rf%pressure   (i,j,k) = pv
          blk%rf%enthalpy   (i,j,k) = hv
          blk%rf%temperature(i,j,k) = Tv
          call assign_velocity_components(i, j, k, vel(i,j,k))
          blk%set_rf(i,j,k) = .true.
        endif
      enddo; enddo; enddo

    end subroutine assign_variable

    ! -----------------------------------------------------------------------
    ! Load a field for RF assignment. The field can be either a constant value
    ! or read from a file (Tecplot/1D-profile). scale is a unit-conversion factor
    ! applied when a scalar or file-based value is found.
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

      field = 0.0_R8
      if (.not. field_cfg%has_file) return

      is_variable = .true.
      if (field_cfg%has_direction) then
        call assign_from_1D_table(blk, field_cfg%file, field_cfg%direction, field)
      else
        call interpolate_from_file(field, blk, field_cfg%file)
      endif
      if (scale/=1.d0) field = field*scale

    end subroutine load_zone_field

    ! -----------------------------------------------------------------------
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

    ! -----------------------------------------------------------------------
    subroutine assign_velocity_components(i, j, k, vel_mag)
      implicit none
      integer,  intent(in) :: i, j, k
      real(R8), intent(in) :: vel_mag
      integer :: l

      if (ux == 0.0_R8) then
        blk%rf%velocity(1,i,j,k) = vel_mag*cos(alpha)*cos(beta)
      else
        blk%rf%velocity(1,i,j,k) = ux
      endif

      if (uy == 0.0_R8) then
        blk%rf%velocity(2,i,j,k) = vel_mag*cos(alpha)*sin(beta)
      else
        blk%rf%velocity(2,i,j,k) = uy
      endif

      if (uz == 0.0_R8) then
        blk%rf%velocity(3,i,j,k) = vel_mag*sin(beta)
      else
        blk%rf%velocity(3,i,j,k) = uz
      endif

      do l = 1, 3
        if (isnan(blk%rf%velocity(l,i,j,k))) &
          write(*,*) '[ERROR] NaN in RF velocity assignment'
      enddo

    end subroutine assign_velocity_components

    ! -----------------------------------------------------------------------
    subroutine dealloc_src()
      integer :: bb_tmp
      do bb_tmp = 1, size(src_field)
        if (allocated(src_field(bb_tmp)%var)) deallocate(src_field(bb_tmp)%var)
      enddo
      deallocate(src_field)
    end subroutine dealloc_src

  end subroutine build_RF_field


  !> Bilinear interpolation in the real-fluid table to obtain temperature from (p, h).
  !> Table axes: fl%p(0:Ni) [pressure], fl%h(0:Nj) [enthalpy], fl%T(0:Ni,0:Nj) [temperature].
  !> Assumes uniform spacing on both axes; clamps to table bounds.
  pure function ph2T(fl, p_val, h_val) result(T_val)
    use phase_mod, only: real_fluid_t
    implicit none
    type(real_fluid_t), intent(in) :: fl
    real(R8),           intent(in) :: p_val, h_val
    real(R8)                       :: T_val
    integer  :: Ni, Nj, ip, ih
    real(R8) :: dp, dh, wp, wh

    Ni = ubound(fl%p, 1)
    Nj = ubound(fl%h, 1)
    dp = fl%p(1) - fl%p(0)
    dh = fl%h(1) - fl%h(0)

    ip = max(0, min(Ni-1, floor((p_val - fl%p(0)) / dp)))
    ih = max(0, min(Nj-1, floor((h_val - fl%h(0)) / dh)))

    wp = max(0.0_R8, min(1.0_R8, (p_val - fl%p(ip)) / dp))
    wh = max(0.0_R8, min(1.0_R8, (h_val - fl%h(ih)) / dh))

    T_val = (1.0_R8-wp)*(1.0_R8-wh)*fl%T(ip,   ih  ) &
          +          wp *(1.0_R8-wh)*fl%T(ip+1, ih  ) &
          + (1.0_R8-wp)*         wh *fl%T(ip,   ih+1) &
          +          wp *         wh *fl%T(ip+1, ih+1)

  end function ph2T


  !> Invert the real-fluid table to obtain specific enthalpy from (p, T).
  !> Mirrors ph2T: clamps to pressure bracket [ip, ip+1], performs a 1D linear search
  !> along the enthalpy axis at BOTH pressure brackets, then interpolates in pressure.
  !> This is consistent with the bilinear forward map ph2T.
  pure function pT2h(fl, p_val, T_val) result(h_val)
    use phase_mod, only: real_fluid_t
    implicit none
    type(real_fluid_t), intent(in) :: fl
    real(R8),           intent(in) :: p_val, T_val
    real(R8)                       :: h_val
    integer  :: Ni, Nj, ip, ihL, ihR
    real(R8) :: dp, dT, wp, whL, whR, hL, hR

    Ni = ubound(fl%p, 1)
    Nj = ubound(fl%h, 1)
    dp = fl%p(1) - fl%p(0)

    ip = max(0, min(Ni-1, floor((p_val - fl%p(0)) / dp)))
    wp = max(0.0_R8, min(1.0_R8, (p_val - fl%p(ip)) / dp))

    ! Invert T(ip, h) -> h at lower pressure bracket
    ihL = 0
    do while (ihL < Nj-1 .and. fl%T(ip, ihL+1) < T_val)
      ihL = ihL + 1
    enddo
    dT = fl%T(ip, ihL+1) - fl%T(ip, ihL)
    if (dT /= 0.0_R8) then
      whL = max(0.0_R8, min(1.0_R8, (T_val - fl%T(ip, ihL)) / dT))
    else
      whL = 0.0_R8
    endif
    hL = fl%h(ihL) + whL*(fl%h(ihL+1) - fl%h(ihL))

    ! Invert T(ip+1, h) -> h at upper pressure bracket
    ihR = 0
    do while (ihR < Nj-1 .and. fl%T(ip+1, ihR+1) < T_val)
      ihR = ihR + 1
    enddo
    dT = fl%T(ip+1, ihR+1) - fl%T(ip+1, ihR)
    if (dT /= 0.0_R8) then
      whR = max(0.0_R8, min(1.0_R8, (T_val - fl%T(ip+1, ihR)) / dT))
    else
      whR = 0.0_R8
    endif
    hR = fl%h(ihR) + whR*(fl%h(ihR+1) - fl%h(ihR))

    ! Interpolate in pressure
    h_val = hL + wp*(hR - hL)

  end function pT2h


  subroutine assign_from_1D_table(blk, varfile, vardirection, var)
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
      write(*,*) '[ERROR] Unsupported direction in assign_from_1D_table: ', trim(vardirection)
      stop 1
    end select

    call read_ascii_table(varfile, file_dir, file_var, ios)
    if (ios/=0) then
      write(*,*) '[ERROR] Could not read file: ', trim(varfile)
      stop 1
    endif

    file_length = size(file_dir)
    if (dir == 5) file_dir(:) = file_dir(:) * acos(-1.0d0) / 180.0d0

    !$omp parallel private(i,j,k,found)
    !$omp do collapse(3)
    do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
      found = interp_1d(blk%center(i,j,k)%c(dir), file_dir, file_var, file_length, var(i,j,k))
      if (.not.found) then
        write(*,*) '[ERROR] interpolated point ', blk%center(i,j,k)%c(dir), &
                   ' is outside the file data range.'
        write(*,*) '        File: ', trim(varfile)
        write(*,*) '        File data range: ', file_dir(1), ' to ', file_dir(file_length)
        stop 1
      endif
    enddo; enddo; enddo
    !$omp end parallel

  end subroutine assign_from_1D_table

end module ic_rf_mod