module ic_dp_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  implicit none

contains

  subroutine build_DP_field(blk,dp_cfg,IC_type,mat)
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
    integer                         :: i, j, k, nnn, g
    real(R8)                        :: rho
    ! Interpolation-specific locals
    character(len=llen)             :: OFF
    integer                         :: oldid
    type(interp_map_t)              :: map
    type(var_block), allocatable    :: src_field(:)
    integer                         :: bb, m_i, cnt_vel

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

    OFF = dp_cfg%interpolation%old_solution
    oldid = dp_cfg%interpolation%old_block_id
    call sync_interpolation_config(dp_cfg%interpolation)
    if (dp_cfg%interpolation%enabled) IC_type = 'interpolation'

    if (IC_type == 'interpolation') then
      write(*,*) ' -- CD type = interpolation'

      call ensure_old_solution(OFF, 'CD')
      call compute_interp_map(map, oldblock, blk, oldid, config_interpolation % law)

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
      return
    endif

    blk%neuler = dp_cfg%neuler
    if (.not. dp_cfg%has_rp) then
      stop "[ERROR] you must provide either dp or rp for CD"
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

      blk%dp%density(:,:,:,:) = 1d-20
      blk%dp%velocity(:,1:3,:,:,:) = 1d-20
      blk%dp%temperature(:,:,:,:) = 1d-20
      blk%dp%nP(:,:,:,:) = 1d-20
      if (blk%neuler==1 .or. blk%neuler==6) then
        blk%dp%pseudopressure(:,:,:,:) = 1D-20
      endif

    case('equilibrium', 'thermo-mechanical equilibrium', 'mechanical equilibrium')

    do g = 1, nnn
      if (dp_cfg%krho(g)==0.0_R8) then
        blk%dp%density(g,:,:,:) = 0.0
        blk%dp%velocity(g,1:3,:,:,:) = 0.0
        blk%dp%temperature(g,:,:,:) = 0.0
        blk%dp%nP(g,:,:,:) = 0.0
      else
        blk%dp%density(g,:,:,:) = sum(blk%ig%density(:,:,:,:), dim=1) * dp_cfg%krho(g)
        blk%dp%velocity(g,1:3,:,:,:) = blk%ig%velocity(:,:,:,:)
        blk%dp%temperature(g,:,:,:) = blk%ig%temperature(:,:,:) * dp_cfg%kT(g)
        !$omp parallel do collapse(3) private(i,j,k,rho)
        do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
              rho = mat%rho(g,nint(blk%ig%temperature(i,j,k)))
              blk%dp%np(g,i,j,k) = blk%dp%density(g,i,j,k) / &
                                   (4.0/3.0*3.14*rho*dp_cfg%rp(g)**3)
        enddo; enddo; enddo
        !$omp end parallel do
      endif
      if (blk%neuler==1 .or. blk%neuler==6) then
        blk%dp%pseudopressure(g,:,:,:) = dp_cfg%Pp(g)
      endif
    enddo

    end select

  contains

    subroutine dealloc_src()
      integer :: bb_tmp
      do bb_tmp = 1, size(src_field)
        if (allocated(src_field(bb_tmp)%var)) deallocate(src_field(bb_tmp)%var)
      enddo
    end subroutine dealloc_src

  end subroutine build_DP_field

end module ic_dp_mod
