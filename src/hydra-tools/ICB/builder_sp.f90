module ic_sp_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  implicit none
  private

  public :: build_SP_field

contains

  subroutine build_SP_field(blk,zoneini,IC_type,mat,range,dirSize,dir,index_based)
    use finer,                        only: file_ini
    use phase_mod,                    only: material_t
    use global_mod,                    only: llen
    use ic_block_mod
    use ic_interpolation_old_mod,     only: ensure_old_solution, oldblock, config_interpolation
    use ic_interpolation_cons_mod
    use ic_interpolation_general_mod, only: interp_map_t, compute_interp_map, apply_interp_map, interpolate_from_file

    implicit none
    type(IC_block),   intent(inout) :: blk
    type(file_ini),   intent(in)    :: zoneini
    character(len=*), intent(inout) :: IC_type
    type(material_t), intent(in)    :: mat
    logical,          intent(in)    :: index_based
    real(R8),         intent(in)    :: range(6)
    integer,          intent(in)    :: dirSize
    integer,          intent(in)    :: dir(:)
    !! Local
    ! Unspecified
    integer                       :: i, j, k
    integer                       :: imin, imax, jmin, jmax, kmin, kmax
    integer                       :: error, errorfile, errordirection
    character(len=16)             :: material_name
    real(R8)                      :: here(3)
    ! 1D Table specific parameters
    character(len=16)             :: val_direction
    character(len=128)            :: val_file
    real(R8)                      :: val_const
    ! Support fields
    real(R8)                      :: qvol(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3))
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
    if (.not.allocated(blk%sp%qvol)) allocate(blk%sp%qvol(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)))

    T = 0.0_R8
    qvol = 0.0_R8
    mID_field = 1.0_R8

    !! Determine material ID (scalar → broadcast to support array)
    call zoneini%get(section_name='zone', option_name='material', val=material_name, error=error)
    do i = 1, mat%n
      if (trim(mat%name(i))==trim(material_name)) mID_field = real(i,R8)
    enddo

    write(*,*) ' -- SP type = ',trim(IC_type)

    select case (IC_type)

    case ('interpolation')

      call zoneini%get(section_name='zone', option_name='old-solution', val=OFF, error=error)
      call zoneini%get(section_name='zone', option_name='old-block-id', val=oldid, error=error)
      if (error/=0) oldid = 0
      call zoneini%get(section_name='zone', option_name='interpolation-law', val=config_interpolation % law, error=error)
      if (config_interpolation % law=='extrude') then
        call zoneini%get(section_name='zone', option_name='theta', val=config_interpolation % theta, error=error)
        call zoneini%get(section_name='zone', option_name='nz', val=config_interpolation % nz, error=error)
      endif
      call ensure_old_solution(OFF,'SP')

      ! Build interpolation map (once for all variables)
      call compute_interp_map(map, oldblock, blk, oldid, config_interpolation % law)

      ! Temperature
      call wrap_src(oldblock, src_field, 'temperature')
      call apply_interp_map(map, T, src_field)
      call unwrap_src(src_field)

      ! qvol
      call wrap_src(oldblock, src_field, 'qvol')
      call apply_interp_map(map, qvol, src_field)
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

      !! Fill T
      ! Uniform value
      call zoneini%get(section_name='zone', option_name='T', val=val_const, error=error)
      if (error==0) T = val_const
      ! 1D file
      call zoneini%get(section_name='zone', option_name='T-file', val=val_file, error=errorfile)
      if (errorfile==0) then
        call zoneini%get(section_name='zone', option_name='T-direction', val=val_direction, error=errordirection)
        if (errordirection==0) then
          call assign_from_1D_table (blk, val_file, val_direction, T)
        else
          ! 3D nearest-neighbor interpolation
          call interpolate_from_file(T, blk, val_file)
        endif
      endif

      !! Fill qvol
      ! Uniform value
      call zoneini%get(section_name='zone', option_name='qvol', val=val_const, error=error)
      if (error==0) qvol = val_const
      ! File-based
      call zoneini%get(section_name='zone', option_name='qvol-file', val=val_file, error=errorfile)
      if (errorfile==0) then
        call zoneini%get(section_name='zone', option_name='qvol-direction', val=val_direction, error=errordirection)
        if (errordirection==0) then
          call assign_from_1D_table (blk, val_file, val_direction, qvol)
        else
          ! 3D conservative interpolation
          call interpolate_conservative(qvol, blk, val_file)
        endif
      endif

    end select

    !! Assign support variables to blk (range-filtered)
    if (.not.index_based) then
      here = 1.0
      !$omp parallel private(i,j,k,here)
      !$omp do collapse(3)
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
          if (dirSize>=1) here(1) = blk%center(i,j,k)%c(dir(1))
          if (dirSize>=2) here(2) = blk%center(i,j,k)%c(dir(2))
          if (dirSize>=3) here(3) = blk%center(i,j,k)%c(dir(3))
          if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
              here(2)>=range(3) .and. here(2)<=range(4) .and. &
              here(3)>=range(5) .and. here(3)<=range(6)) then
            blk%sp%temperature(i,j,k) = T(i,j,k)
            blk%sp%mID(i,j,k) = mID_field(i,j,k)
            blk%sp%qvol(i,j,k) = qvol(i,j,k)
          endif
      enddo; enddo; enddo
      !$omp end parallel

    elseif (index_based) then
      imin = -huge(imin); jmin = -huge(jmin); kmin = -huge(kmin)
      imax = huge(imax); jmax = huge(jmax); kmax = huge(kmax)
      do i = 1, dirSize
        select case(dir(i))
        case(6); imin = nint(range(2*i-1)); imax = nint(range(2*i))
        case(7); jmin = nint(range(2*i-1)); jmax = nint(range(2*i))
        case(8); kmin = nint(range(2*i-1)); kmax = nint(range(2*i))
        end select
      enddo
      !$omp parallel private(i,j,k)
      !$omp do collapse(3)
      do k = 1, blk%dim(3); do j = 1, blk%dim(2); do i = 1, blk%dim(1)
        if (i>=imin .and. i<=imax .and. &
            j>=jmin .and. j<=jmax .and. &
            k>=kmin .and. k<=kmax) then
          blk%sp%temperature(i,j,k) = T(i,j,k)
          blk%sp%mID(i,j,k) = mID_field(i,j,k)
          blk%sp%qvol(i,j,k) = qvol(i,j,k)
        endif
      enddo; enddo; enddo
      !$omp end parallel
    endif

  contains

    subroutine wrap_src(blocks, sf, field_name)
      type(IC_block),   intent(in)    :: blocks(:)
      type(var_block),  intent(inout) :: sf(:)
      character(len=*), intent(in)    :: field_name
      integer :: b
      allocate(src_field(size(blocks)))
      do b = 1, size(blocks)
        allocate(sf(b)%var(blocks(b)%dim(1), blocks(b)%dim(2), blocks(b)%dim(3)))
        select case (field_name)
        case ('temperature'); sf(b)%var = blocks(b)%sp%temperature
        case ('qvol');        sf(b)%var = blocks(b)%sp%qvol
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

  end subroutine build_SP_field



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
      write(*,*) '[ERROR] Unsupported direction in assign_from_1D_table: ', trim(vardirection)
      stop
    end select

    call read_ascii_table(varfile, file_dir, file_var, ios)
    if (ios/=0) then
      write(*,*) '[ERROR] Could not read file: ', trim(varfile)
      stop
    endif

    file_length = size(file_dir)

    if (dir == 5) file_dir(:) = file_dir(:) * acos(-1.0_R8) / 180.0_R8

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


end module ic_sp_mod
