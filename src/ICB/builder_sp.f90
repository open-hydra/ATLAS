module ic_sp_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  implicit none
  private

  public :: build_SP_field

contains

  subroutine build_SP_field(blk,sp_cfg,IC_type,mat,range,dirSize,dir)
    use phase_mod,                    only: material_t
    use global_mod,                    only: llen
    use ic_block_mod
    use ic_interpolation_old_mod,     only: ensure_old_solution, oldblock
    use ic_interpolation_general_mod, only: interp_map_t, compute_interp_map, apply_interp_map, interpolate_from_file, &
                                            assign_from_1D_table
    use config_mod,                   only: config_sp_t, config_field_source_t, &
                                            sync_interpolation_config

    implicit none
    type(IC_block),   intent(inout) :: blk
    type(config_sp_t), intent(in)   :: sp_cfg
    character(len=*), intent(inout) :: IC_type
    type(material_t), intent(in)    :: mat
    real(R8),         intent(in)    :: range(6)
    integer,          intent(in)    :: dirSize
    integer,          intent(in)    :: dir(:)
    !! Local
    ! Unspecified
    integer                       :: i, j, k
    ! Support fields
    real(R8)                      :: T   (1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    real(R8)                      :: mID_field(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
    ! Full interpolation specific parameters
    character(len=llen)           :: OFF
    integer                       :: oldid
    ! Map-based interpolation
    type(interp_map_t)            :: map
    type(var_block), allocatable  :: src_field(:)
    integer                       :: sb, si, sj, sk

    if (.not.allocated(blk%sp%temperature)) allocate(blk%sp%temperature(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
    if (.not.allocated(blk%sp%mID)) allocate(blk%sp%mID(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))

    T = 0.0_R8
    mID_field = 1.0_R8

    !! Determine material ID (scalar → broadcast to support array)
    do i = 1, mat%n
      if (trim(mat%name(i))==trim(sp_cfg%material)) mID_field = real(i,R8)
    enddo

    if (sp_cfg%interpolation%enabled) IC_type = 'interpolation'

    write(*,*) ' -- SP type = ',trim(IC_type)

    select case (IC_type)

    case ('interpolation')

      OFF = sp_cfg%interpolation%old_solution
      oldid = sp_cfg%interpolation%old_block_id
      call sync_interpolation_config(sp_cfg%interpolation)
      call ensure_old_solution(OFF,'SP')

      ! Build interpolation map (once for all variables)
      call compute_interp_map(map, oldblock, blk, oldid, sp_cfg%interpolation % law)

      ! Temperature
      call wrap_src(oldblock, src_field, 'temperature')
      call apply_interp_map(map, T, src_field)
      call unwrap_src(src_field)

      ! mID (nearest-neighbor only: use stencil point 1)
      !$omp parallel do collapse(3) schedule(static) &
      !$omp& private(i,j,k,sb,si,sj,sk)
      do k = 1, map%dim(3)
        do j = 1, map%dim(2)
          do i = 1, map%dim(1)
            sb = map%src_blk(i,j,k)
            si = map%src_idx(1,1,i,j,k)
            sj = map%src_idx(2,1,i,j,k)
            sk = map%src_idx(3,1,i,j,k)
            mID_field(i,j,k) = oldblock(sb)%sp%mID(si,sj,sk)
          enddo
        enddo
      enddo
      !$omp end parallel do

      call map%destroy()
      deallocate(src_field)

    case default

      call load_zone_field(T, sp_cfg%T)

    end select

    !! Assign support variables to blk (range-filtered): the cell rule of the other writers (cell_in_range).
    !! A direction mixing coordinate and index letters (xi) used to compare the index letters only.
    !$omp parallel do collapse(3) private(i,j,k)
    do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
      if (cell_in_range(i,j,k)) then
        blk%sp%temperature(i,j,k) = T(i,j,k)
        blk%sp%mID(i,j,k) = mID_field(i,j,k)
        blk%set_sp(i,j,k) = .true.
      endif
    enddo; enddo; enddo
    !$omp end parallel do

  contains

    subroutine wrap_src(blocks, sf, field_name)
      type(IC_block),   intent(in)    :: blocks(:)
      type(var_block), allocatable, intent(inout) :: sf(:)
      character(len=*), intent(in)    :: field_name
      integer :: b
      ! the host array was allocated through a non-allocatable dummy of itself (SIGSEGV)
      if (allocated(sf)) deallocate(sf)
      allocate(sf(size(blocks)))
      do b = 1, size(blocks)
        allocate(sf(b)%var(blocks(b)%dim(1), blocks(b)%dim(2), blocks(b)%dim(3)))
        select case (field_name)
        case ('temperature'); sf(b)%var = blocks(b)%sp%temperature
        end select
      enddo
    end subroutine wrap_src

    subroutine unwrap_src(sf)
      type(var_block), intent(inout) :: sf(:)
      integer :: b
      do b = 1, size(sf)
        if (allocated(sf(b)%var)) deallocate(sf(b)%var)
      enddo
    end subroutine unwrap_src

    subroutine load_zone_field(field, field_cfg)
      real(R8), intent(inout) :: field(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
      type(config_field_source_t), intent(in) :: field_cfg

      if (field_cfg%has_value) then
        field = field_cfg%value
        return
      endif

      field = 0.0_R8
      if (.not. field_cfg%has_file) return

      if (field_cfg%has_direction) then
        call assign_from_1D_table(blk, field_cfg%file, field_cfg%direction, field, zone_cells())
      else
        call interpolate_from_file(field, blk, field_cfg%file)
      endif
    end subroutine load_zone_field

    ! the cells of the zone range, those a 1-D profile must cover
    function zone_cells() result(inside)
      logical, allocatable :: inside(:,:,:)
      integer :: ic, jc, kc
      allocate(inside(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))
      do kc = 1, blk%dim(3); do jc = 1, blk%dim(2); do ic = 1, blk%dim(1)
        inside(ic,jc,kc) = cell_in_range(ic,jc,kc)
      enddo; enddo; enddo
    end function zone_cells

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

  end subroutine build_SP_field





end module ic_sp_mod
