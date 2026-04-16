module ic_rf_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  implicit none

contains

  subroutine build_RF_field(blk,zoneini,IC_type,fl,range,dirSize,dir)
    use variables,                    only: cfg, llen
    use finer,                        only: file_ini
    use phase_mod,                    only: real_fluid_t
    use ic_block_mod
    use ic_interpolation_old_mod,     only: ensure_old_solution, oldblock
    use ic_interpolation_general_mod, only: interp_map_t, compute_interp_map, apply_interp_map, &
                                            interpolate_from_file
    use config_mod,                   only: config_interpolation
    implicit none
    type(IC_block),    intent(inout) :: blk
    type(file_ini),    intent(in)    :: zoneini
    character(len=*),  intent(inout) :: IC_type
    real(R8),          intent(in)    :: range(6)
    integer,           intent(in)    :: dirSize
    type(real_fluid_t),intent(inout) :: fl
    integer,           intent(in)    :: dir(:)
    !! Local
    integer                       :: i, j, k, error
    ! Support fields
    real(R8)  :: p  (1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    real(R8)  :: T  (1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    real(R8)  :: h  (1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    real(R8)  :: vel(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    ! Velocity direction parameters
    real(R8)                      :: alpha, beta, ux, uy, uz
    ! Turbulence parameters
    real(R8)                      :: mit, kappa, omega, rhoRij
    ! Old-solution / interpolation parameters
    character(len=llen)           :: OFF
    integer                       :: oldid
    real(R8)                      :: here(3)
    real(R8)                      :: val_const
    character(len=200)            :: val_file
    character(len=16)             :: val_direction
    integer                       :: errorfile, errordirection
    logical                       :: is_variable
    ! Interpolation-specific locals
    type(interp_map_t)            :: map
    type(var_block), allocatable  :: src_field(:)
    integer                       :: cnt, bb

    is_variable = .false.
    call load_zone_field(p,   'p',   1.d0)
    call load_zone_field(T,   'T',   1.d0)
    call load_zone_field(h,   'h',   1.d0)
    call load_zone_field(vel, 'vel', 1.d0)

    if (is_variable) IC_type = 'variable'

    ! Velocity direction parameters
    call zoneini%get(section_name='zone', option_name='alpha', val=alpha, error=error)
    if (error/=0) alpha = 0.0_R8
    call zoneini%get(section_name='zone', option_name='beta',  val=beta,  error=error)
    if (error/=0) beta  = 0.0_R8
    call zoneini%get(section_name='zone', option_name='u',     val=ux,    error=error)
    if (error/=0) ux = 0.0_R8
    call zoneini%get(section_name='zone', option_name='v',     val=uy,    error=error)
    if (error/=0) uy = 0.0_R8
    call zoneini%get(section_name='zone', option_name='w',     val=uz,    error=error)
    if (error/=0) uz = 0.0_R8

    ! Turbulence parameters
    call zoneini%get(section_name='zone', option_name='mit',    val=mit,    error=error)
    if (error/=0) mit = 0.0_R8
    call zoneini%get(section_name='zone', option_name='kappa',  val=kappa,  error=error)
    if (error/=0) kappa = 0.0_R8
    call zoneini%get(section_name='zone', option_name='omega',  val=omega,  error=error)
    if (error/=0) omega = 0.0_R8
    call zoneini%get(section_name='zone', option_name='rhoRij', val=rhoRij, error=error)
    if (error/=0) rhoRij = 0.0_R8

    ! Interpolation parameters
    call zoneini%get(section_name='zone', option_name='old-solution', val=OFF, error=error)
    if (error==0) IC_type = 'interpolation'
    call zoneini%get(section_name='zone', option_name='old-block-id', val=oldid, error=error)
    if (error/=0) oldid = 0
    call zoneini%get(section_name='zone', option_name='interpolation-law', val=config_interpolation%law, error=error)
    if (error/=0) config_interpolation%law = 'outlaw'
    if (config_interpolation%law=='extrude') then
      call zoneini%get(section_name='zone', option_name='theta', val=config_interpolation%theta, error=error)
      if (error/=0) config_interpolation%theta = 90.0_R8
      call zoneini%get(section_name='zone', option_name='nz', val=config_interpolation%nz, error=error)
      if (error/=0) config_interpolation%nz = 4
    endif

    write(*,*) ' -- RF type = ',trim(IC_type)

    if (.not.allocated(blk%rf%pressure)) then
      allocate(blk%rf%velocity   (3,       1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%rf%pressure   (         1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%rf%enthalpy   (         1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%rf%temperature(         1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      if (cfg%nrans>0) &
        allocate(blk%rf%turbprop(cfg%nrans,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
    endif

    select case (IC_type)

      case ('interpolation')
        call assign_interpolation()

      case ('homogeneous')
        call assign_homogeneous()

      case ('variable')
        call assign_variable()

    end select

    ! Turbulence post-assignment

    ! Turbulence specific parameters
    if (cfg%nrans==1) then

        if(mit/=0.0) blk%rf%turbprop(1,:,:,:) = mit

    elseif (cfg%nrans==2) then

        if(kappa/=0.0) blk%rf%turbprop(1,:,:,:) = kappa
        if(omega/=0.0) blk%rf%turbprop(2,:,:,:) = omega

    elseif (cfg%nrans==7) then

        if(rhoRij/=0.0) blk%rf%turbprop(1:3,:,:,:) = rhoRij
        blk%rf%turbprop(4:6,:,:,:) = 1d-8
        if(omega/=0.0) blk%rf%turbprop(7,:,:,:) = omega

    endif


  contains

    ! -----------------------------------------------------------------------
    subroutine assign_interpolation()
      implicit none

      call ensure_old_solution(OFF, 'RF')
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

      ! 2D -> 3D azimuthal velocity rotation (index law only)
      if (config_interpolation%law == 'index') then
        if (oldblock(max(oldid,1))%dim(3) == 1 .and. blk%dim(3) /= 1) then
          !$omp parallel do collapse(3) private(i,j,k)
          do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
            blk%rf%velocity(2,i,j,k) = blk%rf%velocity(2,i,j,k) * &
              cos(atan2(blk%center(i,j,k)%c(3), blk%center(i,j,k)%c(2)))
            blk%rf%velocity(3,i,j,k) = blk%rf%velocity(3,i,j,k) * &
              sin(atan2(blk%center(i,j,k)%c(3), blk%center(i,j,k)%c(2)))
          enddo; enddo; enddo
          !$omp end parallel do
        endif
      endif

      ! ---- Pressure ----
      allocate(src_field(size(oldblock)))
      do bb = 1, size(oldblock)
        allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
        src_field(bb)%var = oldblock(bb)%rf%pressure
      enddo
      call apply_interp_map(map, blk%rf%pressure, src_field)
      call dealloc_src()

      ! ---- Turbulent properties ----
      if (cfg%nrans > 0) then
        do cnt = 1, cfg%nrans
          allocate(src_field(size(oldblock)))
          do bb = 1, size(oldblock)
            allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), &
                                       oldblock(bb)%dim(3)))
            src_field(bb)%var = oldblock(bb)%rf%turbprop(cnt,:,:,:)
          enddo
          call apply_interp_map(map, blk%rf%turbprop(cnt,:,:,:), src_field)
          call dealloc_src()
        enddo
      endif

      call map%destroy()

      ! Temperature from EOS table (needed for multi-phase coupling)
      !$omp parallel do collapse(3) private(i,j,k)
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        blk%rf%temperature(i,j,k) = ph2T(fl, blk%rf%pressure(i,j,k), blk%rf%enthalpy(i,j,k))
      enddo; enddo; enddo
      !$omp end parallel do

    end subroutine assign_interpolation

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
        endif
      enddo; enddo; enddo

    end subroutine assign_variable

    ! -----------------------------------------------------------------------
    ! Load a field for RF assignment. The field can be either a constant value
    ! or read from a file (Tecplot/1D-profile). scale is a unit-conversion factor
    ! applied when a scalar or file-based value is found.
    subroutine load_zone_field(field, base_name, scale)
      implicit none
      real(R8),         intent(inout) :: field(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
      character(len=*), intent(in)    :: base_name
      real(R8),         intent(in)    :: scale
      character(len=64)               :: file_option, dir_option

      call zoneini%get(section_name='zone', option_name=trim(base_name), val=val_const, error=error)
      if (error==0) then
        field = val_const
        if (scale/=1.d0) field = field*scale
        return
      endif

      field = 0.0_R8
      file_option = trim(base_name)//'-file'
      call zoneini%get(section_name='zone', option_name=trim(file_option), val=val_file, &
                       error=errorfile)
      if (errorfile/=0) return

      is_variable = .true.
      dir_option = trim(base_name)//'-direction'
      call zoneini%get(section_name='zone', option_name=trim(dir_option), val=val_direction, &
                       error=errordirection)
      if (errordirection==0) then
        call assign_from_1D_table(blk, val_file, val_direction, field)
      else
        call interpolate_from_file(field, blk, val_file)
      endif
      if (scale/=1.d0) field = field*scale

    end subroutine load_zone_field

    ! -----------------------------------------------------------------------
    logical function cell_in_range(i, j, k)
      implicit none
      integer, intent(in) :: i, j, k

      here = 1.0_R8
      if (dirSize>=1) here(1) = blk%center(i,j,k)%c(dir(1))
      if (dirSize>=2) here(2) = blk%center(i,j,k)%c(dir(2))
      if (dirSize>=3) here(3) = blk%center(i,j,k)%c(dir(3))
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
      stop
    end select

    call read_ascii_table(varfile, file_dir, file_var, ios)
    if (ios/=0) then
      write(*,*) '[ERROR] Could not read file: ', trim(varfile)
      stop
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
        stop
      endif
    enddo; enddo; enddo
    !$omp end parallel

  end subroutine assign_from_1D_table

end module ic_rf_mod