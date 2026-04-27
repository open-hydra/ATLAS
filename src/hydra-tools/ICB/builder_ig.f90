module ic_ig_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use area_law, only: Runi, legge_aree
  implicit none

contains

  subroutine build_IG_field(blk,zoneini,ig_cfg,IC_type,sp,range,dirSize,dir)
    use global_mod,                   only: verbose, llen
    use finer,                        only: file_ini
    use phase_mod,                    only: species_t, define_composition, T02T
    use ic_block_mod
    use ic_interpolation_old_mod,     only: ensure_old_solution, oldblock
    use ic_interpolation_general_mod, only: interp_map_t, compute_interp_map, apply_interp_map, interpolate_from_file
    use config_mod,                   only: config_ig_t, config_field_source_t, &
                                            config_interpolation, sync_interpolation_config
    use io_phase_mod,                 only: read_idealgas_properties
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
    integer                       :: i, ip, j, s, k
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
    ! Interpolation-specific locals
    type(interp_map_t)            :: map
    type(var_block), allocatable  :: src_field(:)
    integer, allocatable          :: species_map_old(:)
    type(species_t)               :: old_sp
    real(R8), allocatable         :: tmp_rho(:,:,:)
    integer                       :: sold, cnt, bb

    is_variable = .false.
    call load_zone_field(M, ig_cfg%mach, 1.d0)
    call load_zone_field(p0, ig_cfg%p0, 1.d0)
    call load_zone_field(T0, ig_cfg%T0, 1.d0)
    call load_zone_field(p, ig_cfg%p, 1.d0)
    call load_zone_field(T, ig_cfg%T, 1.d0)
    call load_zone_field(rho, ig_cfg%rho, 1.d0)

    if (is_variable) IC_type = 'variable'

    alpha = ig_cfg%velocity%alpha
    beta = ig_cfg%velocity%beta
    ux = ig_cfg%velocity%u
    uy = ig_cfg%velocity%v
    uz = ig_cfg%velocity%w

    mit = ig_cfg%turbulence%mit
    kappa = ig_cfg%turbulence%kappa
    omega = ig_cfg%turbulence%omega
    rhoRij = ig_cfg%turbulence%rhoRij
    blk%nrans = ig_cfg%turbulence%nrans

    nozzle_dir = ig_cfg%nozzle_direction
    L_threshold = ig_cfg%nozzle_threshold

    OSF = ig_cfg%interpolation%old_species
    OFF = ig_cfg%interpolation%old_solution
    oldid = ig_cfg%interpolation%old_block_id
    call sync_interpolation_config(ig_cfg%interpolation)
    if (ig_cfg%interpolation%enabled) IC_type = 'interpolation'

    write(*,*) ' -- IG type = ',trim(IC_type)

    if (.not.allocated(blk%ig%density)) then
      allocate(blk%ig%density(sp%n,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%ig%velocity(3,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%ig%pressure(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%ig%temperature(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      if (blk%nrans>0) allocate(blk%ig%turbprop(blk%nrans,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
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

    end select

    ! Turbulence specific parameters
    if (blk%nrans==1) then

        if(mit/=0.0) blk%ig%turbprop(1,:,:,:) = mit

    elseif (blk%nrans==2) then

        if(kappa/=0.0) blk%ig%turbprop(1,:,:,:) = kappa
        if(omega/=0.0) blk%ig%turbprop(2,:,:,:) = omega

    elseif (blk%nrans==7) then

        if(rhoRij/=0.0) blk%ig%turbprop(1:3,:,:,:) = rhoRij
        blk%ig%turbprop(4:6,:,:,:) = 1d-8
        if(omega/=0.0) blk%ig%turbprop(7,:,:,:) = omega

    endif

  
  contains

  
    subroutine assign_interpolation()
      implicit none
      integer :: n_old_sp

      associate( T0c => T0(1,1,1), p0c => p0(1,1,1) )

      ! Load old species (local, not cached in module)
      if (trim(OSF) /= '') then
        call read_idealgas_properties(OSF, old_sp)
      else
        old_sp = sp
      endif

      ! Lazy-load old solution
      call ensure_old_solution(OFF, 'IG')

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

      ! 2D -> 3D azimuthal velocity rotation (index law only)
      if (config_interpolation % law == 'index') then
        if (oldblock(max(oldid,1))%dim(3) == 1 .and. blk%dim(3) /= 1) then
          !$omp parallel do collapse(3) private(i,j,k)
          do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
            blk%ig%velocity(2,i,j,k) = blk%ig%velocity(2,i,j,k) * cos(atan2(blk%center(i,j,k)%c(3), blk%center(i,j,k)%c(2)))
            blk%ig%velocity(3,i,j,k) = blk%ig%velocity(3,i,j,k) * sin(atan2(blk%center(i,j,k)%c(3), blk%center(i,j,k)%c(2)))
          enddo; enddo; enddo
          !$omp end parallel do
        endif
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
      if (blk%nrans > 0) then
        do cnt = 1, blk%nrans
          allocate(src_field(size(oldblock)))
          do bb = 1, size(oldblock)
            allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
            src_field(bb)%var = oldblock(bb)%ig%turbprop(cnt,:,:,:)
          enddo
          call apply_interp_map(map, blk%ig%turbprop(cnt,:,:,:), src_field)
          call dealloc_src()
        enddo
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

      endassociate
    end subroutine assign_interpolation

    subroutine assign_homogeneous()
      implicit none
      associate( T0c => T0(1,1,1), p0c => p0(1,1,1), Tc => T(1,1,1), &
                 pc => p(1,1,1), rhoc => rho(1,1,1), Mc => M(1,1,1) )
      sp%massf = 1d-20
      call define_composition(zoneini, sp, T0c, p0c)

      ! R
      Rgas = sum(Runi*sp%massf/sp%w)
      ! Temperature
      if (T0c==0 .and. Tc==0) Tc = pc/(Rgas*rhoc)
      if (T0c/=0 .and. Tc==0) Tc = T02T(T0c,Mc,sp)
      ! Mach
      cp_ = sum(sp%massf*sp%cp(:,nint(Tc)))
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
                stop
              endif
              enddo
              blk%ig%temperature(i,j,k) = Tc
              call assign_velocity_components(i, j, k, vel)
              blk%ig%pressure(i,j,k) = pc
              if (isnan(blk%ig%pressure(i,j,k))) then
                write(*,*) '[ERROR] NaN in pressure assignment'
                stop
              endif
          endif

      enddo; enddo; enddo
      !$omp end parallel
      endassociate
    end subroutine assign_homogeneous

    subroutine assign_variable()
      implicit none

      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)

          sp%massf = 1d-20
          call define_composition(zoneini, sp, T0(i,j,k), p0(i,j,k))

          ! R
          Rgas = sum(Runi*sp%massf/sp%w)

          ! Temperature
          if (T0(i,j,k)==0 .and. T(i,j,k)==0) T(i,j,k) = p(i,j,k)/(Rgas*rho(i,j,k))
          if (T0(i,j,k)/=0 .and. T(i,j,k)==0) T(i,j,k) = T02T(T0(i,j,k),M(i,j,k),sp)
          cp_ = sum(sp%massf*sp%cp(:,nint(T(i,j,k))))
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
                  stop
                endif
              enddo
              a = sqrt(gamma*Rgas*T(i,j,k))
              vel = M(i,j,k)*a
              blk%ig%temperature(i,j,k) = T(i,j,k)
              call assign_velocity_components(i, j, k, vel)
              blk%ig%pressure(i,j,k) = p(i,j,k)
              if (isnan(blk%ig%pressure(i,j,k))) then
                write(*,*) '[ERROR] NaN in pressure assignment'
                stop
              endif
          endif

      enddo; enddo; enddo
    end subroutine assign_variable

    subroutine assign_nozzle()
      implicit none
      real(R8), allocatable :: radius_ext(:), radius_int(:), area(:)
      integer :: ib1, ib2, ib3, throat_cell, L_threshold_cell

      associate( T0c => T0(1,1,1), p0c => p0(1,1,1) )
      ! Assign species mass fractions (if equilibrium also pressure and temperature may be assigned)
      sp%massf = 1d-20
      call define_composition(zoneini, sp, T0c, p0c)

      allocate(radius_ext(1:blk%dim(1)))
      allocate(radius_int(1:blk%dim(1)))
      allocate(area(1:blk%dim(1)))

      Rgas = sum(Runi*sp%massf/sp%w)
      cp_ = sum(sp%massf*sp%cp(:,nint(T0c)))
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

      do i = ib1, ib2, ip
        do s = 1, sp%n
          blk%ig%density(s,i,:,:) = sp%massf(s)*p0c/(Rgas*T0c)
        enddo
        blk%ig%pressure(i,:,:) = p0c
        blk%ig%velocity(:,i,:,:) = 0.0
        blk%ig%temperature(i,:,:) = T0c
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

      here = 1.0
      if (dirSize>=1) here(1) = blk%center(i,j,k)%c(dir(1))
      if (dirSize>=2) here(2) = blk%center(i,j,k)%c(dir(2))
      if (dirSize>=3) here(3) = blk%center(i,j,k)%c(dir(3))
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

      ! Default to zero if angles are unphysically large (undefined in config)
      if (alpha>2026d0) alpha = 0d0
      if (beta>2026d0)  beta = 0d0

      if (ux==0.d0) then
        blk%ig%velocity(1,i,j,k) = vel_mag*cos(alpha)*cos(beta)
      else
        blk%ig%velocity(1,i,j,k) = ux
      endif

      if (uy==0.d0) then
        blk%ig%velocity(2,i,j,k) = vel_mag*cos(alpha)*sin(beta)
      else
        blk%ig%velocity(2,i,j,k) = uy
      endif

      if (uz==0.d0) then
        blk%ig%velocity(3,i,j,k) = vel_mag*sin(beta)
      else
        blk%ig%velocity(3,i,j,k) = uz
      endif

      do l = 1, 3
        if (isnan(blk%ig%velocity(l,i,j,k))) then
          write(*,*) '[ERROR] NaN in velocity assignment'
        endif
      enddo

    end subroutine assign_velocity_components

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
      stop
    end select

    call read_ascii_table(varfile, file_dir, file_var, ios)
    if (ios/=0) then
      write(*,*) '[ERROR] Could not read file: ', trim(varfile)
      stop
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
        stop
      endif
    enddo; enddo; enddo
    !$omp end parallel

  end subroutine assign_from_1D_table  

end module ic_ig_mod