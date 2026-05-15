module st_builder_mod
  use, intrinsic :: iso_fortran_env, only: R8 => real64
  use finer, only: file_ini
  use io_ascii_table_mod, only: read_ascii_table
  use st_block_mod
  use grid_mod, only: block_type
  use global_mod
  use config_stb_mod, only: config_t
  implicit none
  private
  public :: build_st

  real(R8), parameter :: PI    = 4.0_R8 * atan(1.0_R8)
  real(R8), parameter :: TWOPI = 2.0_R8 * PI

contains

  ! Main subroutine to build source terms fields in all blocks from INI configuration
  subroutine build_st(sini, blocks, var_blocks)
    use ir_precision, only: str
    use config_stb_mod, only: load_var_config
    implicit none
    type(file_ini),              intent(in)  :: sini
    type(block_type),            intent(in)  :: blocks(:)
    type(st_block), allocatable, intent(out) :: var_blocks(:)

    integer :: b
    character(len=30) :: section_name
    type(config_t) :: cfg

    allocate(var_blocks(1:size(blocks)))
    
    do b = 1, size(blocks)
      var_blocks(b)%id = b
      section_name = 'STB-Block'//str(.true., b)
      
      ! Load qvol configuration from INI
      call load_var_config(section_name, sini, 'qvol', cfg)
      
      ! Build appropriate type
      if (cfg%var%has_value) then
        call build_uniform(cfg, blocks(b), var_blocks(b))
      else if (cfg%var%has_file .and. cfg%var%has_direction) then
        call build_1d(cfg, blocks(b), var_blocks(b))
      endif

    enddo
  end subroutine build_st

  ! Build uniform (constant value throughout the block)
  subroutine build_uniform(cfg, block, var_blk)
    implicit none
    type(config_t), intent(in) :: cfg
    type(block_type), intent(in) :: block
    type(st_block), intent(inout) :: var_blk
    
    call var_blk%allocate(block%dim(1), block%dim(2), block%dim(3))
    var_blk%is_uniform = .true.
    var_blk%uniform_value = cfg%var%value
    var_blk%var = cfg%var%value
    
    write(*,'(A,I3,A,ES12.5)') '   Block ', var_blk%id, ' - Uniform qvol = ', cfg%var%value
  end subroutine build_uniform

  ! Build 1D distribution of qvol (read from coordinate-value pairs file)
  ! Interpolates onto block cell centers using configured direction
  subroutine build_1d(cfg, block, var_blk)
    use math_utils_mod, only: interp_1d
    implicit none
    type(config_t), intent(in) :: cfg
    type(block_type), intent(in) :: block
    type(st_block), intent(inout) :: var_blk
    
    real(R8), allocatable :: xin(:), qin(:)
    real(R8), allocatable :: coord(:,:,:)
    integer :: i, j, k, ni, nj, nk, ierr
    real(R8) :: coord_val, interp_val
    logical :: found

    ni = block%dim(1); nj = block%dim(2); nk = block%dim(3)

    ! Read 1D profile (coord, value) from ASCII table
    call read_ascii_table(cfg%var%file, xin, qin, ierr)
    if (ierr /= 0) then
      write(*,*) '[ERROR] Cannot read qvol file: ', trim(cfg%var%file)
      stop
    endif
    
    call var_blk%allocate(ni, nj, nk)

    ! Get coordinate array for the chosen direction
    allocate(coord(0:ni, 0:nj, 0:nk))
    coord = get_direction_coord(block%node(0:ni,0:nj,0:nk)%c(1), &
                                block%node(0:ni,0:nj,0:nk)%c(2), &
                                block%node(0:ni,0:nj,0:nk)%c(3), cfg%var%direction)

    ! Interpolate onto cell centers
    do k = 1, nk
      do j = 1, nj
        do i = 1, ni
          ! Average node values at cell corners to get center coordinate
          coord_val = 0.25_R8 * (coord(i-1,j-1,k) + coord(i,j-1,k) + &
                                 coord(i-1,j,k)   + coord(i,j,k))
          if (nk > 1) then
            coord_val = coord_val * 0.5_R8
            coord_val = coord_val + 0.25_R8 * (coord(i-1,j-1,k-1) + coord(i,j-1,k-1) + &
                                               coord(i-1,j,k-1)   + coord(i,j,k-1)) * 0.5_R8
          endif
          found = interp_1d(coord_val, xin, qin, size(xin), interp_val)
          var_blk%var(i,j,k) = interp_val
        enddo
      enddo
    enddo

    write(*,'(A,I3,A,A)') '   Block ', var_blk%id, ' - 1D distribution qvol using ', trim(cfg%var%direction)

    deallocate(xin, qin, coord)
  end subroutine build_1d

  ! Extract coordinate value from node positions based on direction key
  function get_direction_coord(xn, yn, zn, dir_key) result(coord)
    use direction_mod, only: parse_direction
    real(R8), intent(in) :: xn(:,:,:), yn(:,:,:), zn(:,:,:)
    character(*), intent(in) :: dir_key
    real(R8) :: coord(size(xn,1), size(xn,2), size(xn,3))
    integer, allocatable :: dir(:)
    integer :: ndir
    logical :: index_based

    call parse_direction(dir_key, dir, ndir, index_based)

    if (size(dir) < 1) then
      error stop '[st_builder] invalid direction key'
    endif

    select case(dir(1))
    case(1); coord = xn
    case(2); coord = yn
    case(3); coord = zn
    case(4); coord = sqrt(xn**2 + yn**2)
    case(5); coord = modulo(atan2(yn, xn), TWOPI)
    case default
      error stop '[st_builder] invalid direction key'
    end select

    if (allocated(dir)) deallocate(dir)
  end function get_direction_coord

end module st_builder_mod
