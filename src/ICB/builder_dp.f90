module ic_dp_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  implicit none

contains

  subroutine build_DP_field(blk,dp_cfg,IC_type,mat,range,dirSize,dir)
    use ic_block_mod
    use phase_mod, only: material_t
    use global_mod, only: llen
    use ic_interpolation_old_mod,     only: ensure_old_solution, oldblock
    use ic_interpolation_general_mod, only: interp_map_t, compute_interp_map, apply_interp_map
    use config_mod,                   only: config_dp_t, config_interpolation, &
                                            sync_interpolation_config
    implicit none
    type(IC_block),   intent(inout) :: blk
    type(config_dp_t), intent(in)   :: dp_cfg
    character(len=*), intent(inout) :: IC_type
    type(material_t), intent(in)    :: mat
    real(R8),         intent(in)    :: range(6)
    integer,          intent(in)    :: dirSize
    integer,          intent(in)    :: dir(:)
    integer                         :: i, j, k, nnn, g
    real(R8)                        :: rho
    ! Interpolation-specific locals
    character(len=llen)             :: OFF
    integer                         :: oldid
    type(interp_map_t)              :: map
    type(var_block), allocatable    :: src_field(:)
    integer                         :: bb, m_i, cnt_vel
    ! the cells of this zone, and the dispersed state of the other cells kept aside by an interpolation zone
    logical, allocatable            :: inz(:,:,:)
    real(R8), allocatable           :: sv_rho(:,:,:,:), sv_vel(:,:,:,:,:), sv_T(:,:,:,:), sv_nP(:,:,:,:), sv_pp(:,:,:,:)

    nnn = 0
    do k = 1, mat%n
      nnn = nnn + mat%npCP(k)
    enddo

    if (.not.allocated(blk%dp%density)) then
      allocate(blk%dp%density       ( nnn ,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%dp%velocity      (nnn,3,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%dp%temperature   ( nnn ,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%dp%nP            ( nnn ,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      allocate(blk%dp%pseudopressure( nnn ,1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
    endif

    ! The dispersed keys of a zone apply to the cells of that zone, like its gas keys: the cells of its
    ! range (a coordinate letter compares the cell centre, an index letter the cell index, as the gas
    ! writer does) and the cells that the gas writer of the zone wrote outside it (the plenum rows of a
    ! nozzle zone). A block without zones is one zone that covers every cell.
    allocate(inz(blk%dim(1),blk%dim(2),blk%dim(3)))
    do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
      inz(i,j,k) = cell_in_range(i,j,k)
    enddo; enddo; enddo
    if (allocated(blk%zone_ig)) inz = inz .or. blk%zone_ig

    OFF = dp_cfg%interpolation%old_solution
    oldid = dp_cfg%interpolation%old_block_id
    call sync_interpolation_config(dp_cfg%interpolation)
    if (dp_cfg%interpolation%enabled) IC_type = 'interpolation'

    if (IC_type == 'interpolation') then
      write(*,*) ' -- CD type = interpolation'

      ! Pass the known population count so the reader locates each population's
      ! fields by the authoritative number instead of dividing the file's
      ! variable count (which breaks when extra trailing variables are present).
      call ensure_old_solution(OFF, 'CD', nnn)
      call compute_interp_map(map, oldblock, blk, oldid, config_interpolation % law)
      ! the interpolation fills the whole block: the state of the cells outside the zone (set by other
      ! zones) is kept aside here and put back after it, as the gas writer does
      if (.not. all(inz)) then
        sv_rho = blk%dp%density
        sv_vel = blk%dp%velocity
        sv_T   = blk%dp%temperature
        sv_nP  = blk%dp%nP
        sv_pp  = blk%dp%pseudopressure
      endif

      ! ---- Per-population per-field interpolation ----
      allocate(src_field(size(oldblock)))

      do m_i = 1, nnn

        ! density
        do bb = 1, size(oldblock)
          allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
          src_field(bb)%var = oldblock(bb)%dp%density(m_i,:,:,:)
        enddo
        call apply_interp_map(map, blk%dp%density(m_i,:,:,:), src_field)
        call dealloc_src()

        ! velocity (3 components)
        do cnt_vel = 1, 3
          do bb = 1, size(oldblock)
            allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
            src_field(bb)%var = oldblock(bb)%dp%velocity(m_i,cnt_vel,:,:,:)
          enddo
          call apply_interp_map(map, blk%dp%velocity(m_i,cnt_vel,:,:,:), src_field)
          call dealloc_src()
        enddo

        ! temperature
        do bb = 1, size(oldblock)
          allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
          src_field(bb)%var = oldblock(bb)%dp%temperature(m_i,:,:,:)
        enddo
        call apply_interp_map(map, blk%dp%temperature(m_i,:,:,:), src_field)
        call dealloc_src()

        ! nP
        do bb = 1, size(oldblock)
          allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
          src_field(bb)%var = oldblock(bb)%dp%nP(m_i,:,:,:)
        enddo
        call apply_interp_map(map, blk%dp%nP(m_i,:,:,:), src_field)
        call dealloc_src()

        ! pseudopressure (only when active)
        if (blk%neuler >= 1) then
          do bb = 1, size(oldblock)
            allocate(src_field(bb)%var(oldblock(bb)%dim(1), oldblock(bb)%dim(2), oldblock(bb)%dim(3)))
            src_field(bb)%var = oldblock(bb)%dp%pseudopressure(m_i,:,:,:)
          enddo
          call apply_interp_map(map, blk%dp%pseudopressure(m_i,:,:,:), src_field)
          call dealloc_src()
        endif

      enddo

      call map%destroy()
      deallocate(src_field)
      if (allocated(sv_rho)) then
        do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
          if (inz(i,j,k)) cycle
          blk%dp%density(:,i,j,k)        = sv_rho(:,i,j,k)
          blk%dp%velocity(:,:,i,j,k)     = sv_vel(:,:,i,j,k)
          blk%dp%temperature(:,i,j,k)    = sv_T(:,i,j,k)
          blk%dp%nP(:,i,j,k)             = sv_nP(:,i,j,k)
          blk%dp%pseudopressure(:,i,j,k) = sv_pp(:,i,j,k)
        enddo; enddo; enddo
      endif
      blk%set_dp = blk%set_dp .or. inz
      return
    endif

    blk%neuler = dp_cfg%neuler
    if (.not. dp_cfg%has_rp) then
      write(*,'(A)') "[ERROR] you must provide either dp or rp for CD"
      stop 1
    endif

    if (sum(dp_cfg%krho)==0.0) then
      IC_type = 'vacuum'
    elseif (sum(dp_cfg%krho)/=0.0 .and. product(dp_cfg%kT)==1.0_R8) then
      IC_type = 'thermo-mechanical equilibrium'
    elseif (sum(dp_cfg%krho)/=0.0 .and. product(dp_cfg%kT)/=1.0_R8) then
      IC_type = 'mechanical equilibrium'
    endif

    write(*,*) ' -- CD type = ',trim(IC_type)

    select case (IC_type)
    case ('vacuum')

      ! the pseudo-pressure too, whatever neuler: the band is written when the block's neuler asks for it,
      ! and another zone of the block may set neuler
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (.not. inz(i,j,k)) cycle
        blk%dp%density(:,i,j,k) = 1d-20
        blk%dp%velocity(:,1:3,i,j,k) = 1d-20
        blk%dp%temperature(:,i,j,k) = 1d-20
        blk%dp%nP(:,i,j,k) = 1d-20
        blk%dp%pseudopressure(:,i,j,k) = 1D-20
      enddo; enddo; enddo
      blk%set_dp = blk%set_dp .or. inz

    case('equilibrium', 'thermo-mechanical equilibrium', 'mechanical equilibrium')

    if (.not. any(blk%associated_phase%type == 'IG')) then
      write(*,'(A,I0,A,I0,A)') '[ERROR] build_DP_field block ', blk%id, ': the dispersed phase is initialised from the'// &
        ' gas state of the block (krho, kT), and the block builds no ideal-gas phase: add the gas phase to the key'// &
        ' phase of [ICB-Block', blk%id, '] (or give krho = 0)'
      stop 1
    endif
    do g = 1, nnn
      if (dp_cfg%krho(g)==0.0_R8) then
        do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
          if (.not. inz(i,j,k)) cycle
          blk%dp%density(g,i,j,k) = 0.0
          blk%dp%velocity(g,1:3,i,j,k) = 0.0
          blk%dp%temperature(g,i,j,k) = 0.0
          blk%dp%nP(g,i,j,k) = 0.0
        enddo; enddo; enddo
      else
        ! the dispersed state is derived from the gas state of the cell, which the gas writer of this
        ! zone has just written in the cells of the zone (a cell whose gas state is not written is skipped)
        !$omp parallel do collapse(3) private(i,j,k,rho)
        do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
              if (.not. (inz(i,j,k) .and. blk%set_ig(i,j,k))) cycle
              blk%dp%density(g,i,j,k) = sum(blk%ig%density(:,i,j,k)) * dp_cfg%krho(g)
              blk%dp%velocity(g,1:3,i,j,k) = blk%ig%velocity(:,i,j,k)
              blk%dp%temperature(g,i,j,k) = blk%ig%temperature(i,j,k) * dp_cfg%kT(g)
              rho = mat%rho(g,nint(blk%ig%temperature(i,j,k)))
              blk%dp%np(g,i,j,k) = blk%dp%density(g,i,j,k) / &
                                   (4.0/3.0*3.14*rho*dp_cfg%rp(g)**3)
        enddo; enddo; enddo
        !$omp end parallel do
      endif
      ! the pseudo-pressure too, whatever neuler (see the vacuum case)
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (inz(i,j,k)) blk%dp%pseudopressure(g,i,j,k) = dp_cfg%Pp(g)
      enddo; enddo; enddo
    enddo
    if (any(dp_cfg%krho(1:nnn) /= 0.0_R8)) then
      blk%set_dp = blk%set_dp .or. (inz .and. blk%set_ig)
    else
      blk%set_dp = blk%set_dp .or. inz
    endif

    end select

  contains

    ! the cell rule of the gas writer (cell_in_range of build_IG_field): a coordinate letter compares the
    ! cell centre, an index letter (i, j, k) the cell index; the limits are included
    logical function cell_in_range(i, j, k)
      integer, intent(in) :: i, j, k
      real(R8)            :: here(3)
      integer             :: n
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

    subroutine dealloc_src()
      integer :: bb_tmp
      do bb_tmp = 1, size(src_field)
        if (allocated(src_field(bb_tmp)%var)) deallocate(src_field(bb_tmp)%var)
      enddo
    end subroutine dealloc_src

  end subroutine build_DP_field

end module ic_dp_mod
