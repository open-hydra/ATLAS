! Area variation along a direction (x, y, r, theta).
! Reads 1D (coordinate, area) profile from an ASCII file specified in the INI,
! interpolates it onto the 2D block-face nodes, and writes outpath/blockN_area.dat
module area_variation_mod
  use, intrinsic :: iso_fortran_env, only: R8 => real64
  use finer,      only: file_ini
  use grid_mod,   only: block_type
  use global_mod
  implicit none
  private
  public :: build_area_variation

  real(R8), parameter :: PI    = 4.0_R8 * atan(1.0_R8)
  real(R8), parameter :: TWOPI = 2.0_R8 * PI

  character(len=18), parameter :: outpath = 'fromATLAStoSolver/'

  integer, parameter :: NDIR = 4
  character(len=20), parameter :: DIR_KEYS(NDIR) = &
    [character(len=20) :: 'x-areavariation','y-areavariation', &
                          'r-areavariation','theta-areavariation']

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
      section_name = 'BCB-Block'//trim(bstr)
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

    character(len=llen) :: area_file, outfile
    integer :: ierr, idir, ni, nj

    real(R8), allocatable :: xin(:), ain(:), aout(:,:), coord(:,:)

    ! Try each direction key; take the first one found
    do idir = 1, NDIR
      call sini%get(section_name=section_name, option_name=trim(DIR_KEYS(idir)), val=area_file, error=ierr)
      if (ierr == 0 .and. len_trim(area_file) > 0) exit
    end do
    if (ierr /= 0 .or. len_trim(area_file) == 0) return

    ni = block%dim(1); nj = block%dim(2)

    ! 1) read (coord, A) pairs from ASCII
    call read_area_profile(area_file, xin, ain)
    if (idir == NDIR) xin(:) = xin(:) * PI / 180.0_R8   ! theta: deg -> rad
    call sort_pair_by_x(xin, ain)

    ! 2) build coordinate array for the chosen direction
    coord = get_direction_coord(block%node(0:ni,0:nj,0)%c(1), block%node(0:ni,0:nj,0)%c(2), DIR_KEYS(idir))

    ! 3) interpolate with clamped extrapolation at ends
    allocate(aout(0:ni,0:nj))
    call interp1_linear(xin, ain, coord, aout)

    ! 4) write output
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

    select case(trim(adjustl(dir_key)))
    case('x-areavariation');     coord = xn
    case('y-areavariation');     coord = yn
    case('r-areavariation');     coord = sqrt(xn**2 + yn**2)
    case('theta-areavariation'); coord = modulo(atan2(yn, xn), TWOPI)
    case default
      error stop '[area_variation] invalid direction key'
    end select
  end function get_direction_coord


  !----------------------------------------
  ! Read (coordinate, area) pairs from ASCII file (skip # and ! comments)
  subroutine read_area_profile(filename, x, a)
    character(len=*), intent(in) :: filename
    real(R8), allocatable, intent(out) :: x(:), a(:)

    integer :: u, ios, n
    character(len=10*llen) :: line
    real(R8) :: tx, ta

    ! First pass: count valid rows
    n = 0
    open(newunit=u, file=trim(filename), status='old', action='read', iostat=ios)
    if (ios /= 0) stop "[ERROR] Cannot open area file: "//trim(filename)
    do
      read(u, '(A)', iostat=ios) line
      if (ios /= 0) exit
      if (len_trim(line) == 0) cycle
      if (line(1:1) == '#' .or. line(1:1) == '!') cycle
      read(line, *, iostat=ios) tx, ta
      if (ios == 0) n = n + 1
    end do
    close(u)

    if (n <= 0) stop "[ERROR] Area file empty or invalid: "//trim(filename)

    ! Second pass: read data
    allocate(x(n), a(n))
    open(newunit=u, file=trim(filename), status='old', action='read', iostat=ios)
    if (ios /= 0) stop "[ERROR] Cannot re-open area file: "//trim(filename)
    n = 0
    do
      read(u, '(A)', iostat=ios) line
      if (ios /= 0) exit
      if (len_trim(line) == 0) cycle
      if (line(1:1) == '#' .or. line(1:1) == '!') cycle
      read(line, *, iostat=ios) tx, ta
      if (ios /= 0) cycle
      n = n + 1
      x(n) = tx
      a(n) = ta
    end do
    close(u)
  end subroutine read_area_profile


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
  ! Linear interpolation with end-clamping (xin must be sorted)
  subroutine interp1_linear(xin, yin, xout, yout)
    real(R8), intent(in)  :: xin(:), yin(:), xout(:,:)
    real(R8), intent(out) :: yout(:,:)
    integer :: i, j, k, n
    real(R8) :: t

    n = size(xin)
    if (n < 2) then
      if (n == 1) then
        yout = yin(1)
      else
        yout = 0.0_R8
      end if
      return
    end if

    !$omp parallel do collapse(2) private(i,k,j,t)
    do k = 1, size(xout, dim=2)
      do i = 1, size(xout, dim=1)
        if (xout(i,k) <= xin(1)) then
          yout(i,k) = yin(1)
        else if (xout(i,k) >= xin(n)) then
          yout(i,k) = yin(n)
        else
          j = maxloc(xin, dim=1, mask=(xin <= xout(i,k)))
          if (xin(j+1) == xin(j)) then
            yout(i,k) = yin(j)
          else
            t = (xout(i,k) - xin(j)) / (xin(j+1) - xin(j))
            yout(i,k) = (1.0_R8 - t)*yin(j) + t*yin(j+1)
          end if
        end if
      end do
    end do
    !$omp end parallel do
  end subroutine interp1_linear


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
