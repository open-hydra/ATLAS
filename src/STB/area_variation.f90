! Area variation along a direction (x, y, r, theta).
! Reads 1D (coordinate, area) profile from an ASCII file specified in the INI,
! interpolates it onto the 2D block-face nodes, and writes outpath/blockN_area.dat
module area_variation_mod
  use, intrinsic :: iso_fortran_env, only: R8 => real64
  use finer,      only: file_ini
  use io_ascii_table_mod, only: read_ascii_table
  use math_utils_mod, only: interp_1d
  use direction_mod, only: parse_direction
  use grid_mod,   only: block_type
  use config_stb_mod, only: config_area_variation_t, load_area_variation_config
  use global_mod
  implicit none
  private
  public :: build_area_variation

  real(R8), parameter :: PI    = 4.0_R8 * atan(1.0_R8)
  real(R8), parameter :: TWOPI = 2.0_R8 * PI

  character(len=18), parameter :: outpath = 'fromATLAStoSolver/'

contains

  !----------------------------------------
  ! Loop over blocks, look up area profile in INI and write output file
  subroutine build_area_variation(sini, blocks)
    type(block_type), intent(in) :: blocks(:)
    type(file_ini),    intent(in) :: sini

    integer :: b
    character(len=llen) :: section_name
    character(len=16)   :: bstr

    call execute_command_line('mkdir -p '//trim(outpath))

    do b = 1, size(blocks)
      write(bstr, '(I0)') b
      section_name = 'STB-Block'//trim(bstr)
      call area_variation_for_block(blocks(b), sini, section_name, b)
    end do
  end subroutine build_area_variation


  !----------------------------------------
  ! Find direction key in INI, read profile, interpolate onto nodes, write output
  subroutine area_variation_for_block(block, sini, section_name, block_id)
    type(block_type), intent(in) :: block
    type(file_ini),    intent(in) :: sini
    character(len=*),  intent(in) :: section_name
    integer,           intent(in) :: block_id

    character(len=llen) :: outfile
    integer :: ierr, ni, nj

    real(R8), allocatable :: xin(:), ain(:), aout(:,:), coord(:,:)
    type(config_area_variation_t) :: cfg

    call load_area_variation_config(section_name, sini, cfg)
    if (.not. cfg%has_profile) return

    ! Read (coord, A) pairs from shared ASCII utility
    call read_ascii_table(cfg%file, xin, ain, ierr)
    if (ierr /= 0) then
      write(*,*) '[ERROR] Cannot read area variation file: ', trim(cfg%file)
      stop
    endif

    ni = block%dim(1); nj = block%dim(2)

    ! theta profiles are provided in degrees; internal coordinates use radians
    if (trim(cfg%direction) == 't') xin(:) = xin(:) * PI / 180.0_R8
    call sort_pair_by_x(xin, ain)

    ! Build coordinate array for selected direction
    coord = get_direction_coord(block%node(0:ni,0:nj,0)%c(1), &
                                block%node(0:ni,0:nj,0)%c(2), cfg%direction)

    ! Interpolate with clamped extrapolation at ends
    allocate(aout(0:ni,0:nj))
    call interpolate_area(xin, ain, coord, aout)

    ! Write output
    write(outfile, '(A,"/block",I0,"_area.dat")') trim(outpath), block_id
    call write_area(outfile, aout)

    if (verbose) write(*,'(A,I0,2A)') '   [area] Block ', block_id, ' -> ', trim(outfile)

  end subroutine area_variation_for_block


  !----------------------------------------
  ! Node coordinate in the chosen direction (x, y, r, theta)
  function get_direction_coord(xn, yn, dir_key) result(coord)
    real(R8), intent(in) :: xn(:,:), yn(:,:)
    character(len=*), intent(in) :: dir_key
    real(R8) :: coord(size(xn,1), size(xn,2))
    integer, allocatable :: dir(:)
    integer :: ndir
    logical :: index_based

    call parse_direction(dir_key, dir, ndir, index_based)

    if (size(dir) < 1) then
      error stop '[area_variation] invalid direction key'
    endif

    select case(dir(1))
    case(1); coord = xn
    case(2); coord = yn
    case(4); coord = sqrt(xn**2 + yn**2)
    case(5); coord = modulo(atan2(yn, xn), TWOPI)
    case default
      error stop '[area_variation] invalid direction key'
    end select

    if (allocated(dir)) deallocate(dir)
  end function get_direction_coord


  !----------------------------------------
  ! Sort two parallel arrays by ascending x (selection sort)
  pure subroutine sort_pair_by_x(x, y)
    real(R8), intent(inout) :: x(:), y(:)
    integer :: i, j, n
    real(R8) :: tx, ty
    n = size(x)
    do i = 1, n-1
      do j = i+1, n
        if (x(j) < x(i)) then
          tx = x(i); x(i) = x(j); x(j) = tx
          ty = y(i); y(i) = y(j); y(j) = ty
        end if
      end do
    end do
  end subroutine sort_pair_by_x


  !----------------------------------------
  ! 1-D interpolation using shared utility with end-clamping
  subroutine interpolate_area(xin, ain, coord, aout)
    real(R8), intent(in)  :: xin(:), ain(:), coord(:,:)
    real(R8), intent(out) :: aout(:,:)
    integer :: i, j
    real(R8) :: interp_val
    logical :: found

    if (size(xin) == 0) then
      aout = 0.0_R8
      return
    endif

    do j = 1, size(coord, dim=2)
      do i = 1, size(coord, dim=1)
        found = interp_1d(coord(i,j), xin, ain, size(xin), interp_val)
        if (found) then
          aout(i,j) = interp_val
        else if (coord(i,j) <= xin(1)) then
          aout(i,j) = ain(1)
        else
          aout(i,j) = ain(size(ain))
        endif
      enddo
    enddo
  end subroutine interpolate_area


  !----------------------------------------
  ! Write area matrix to ASCII file
  subroutine write_area(outfile, a)
    character(len=*), intent(in) :: outfile
    real(R8), intent(in) :: a(:,:)
    integer :: u, ios, i, j
    open(newunit=u, file=trim(outfile), status='replace', action='write', iostat=ios)
    if (ios /= 0) stop "[ERROR] Cannot write: "//trim(outfile)
    do j = 1, size(a, dim=2)
      do i = 1, size(a, dim=1)
        write(u,'(*(1X,E23.15E3))') a(i,j)
      enddo
    end do
    close(u)
  end subroutine write_area

end module area_variation_mod
