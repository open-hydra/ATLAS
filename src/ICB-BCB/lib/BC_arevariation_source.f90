module area_variation_mod
  ! Stand-alone utilities to read an x–area profile from INI,
  ! interpolate onto block nodes, and write INPUT/blockN_area.dat
  !
  ! ---- external dependencies ----
  use ir_precision 
  use finer,            only: file_ini
  use ATLAS_high_level, only: ATLAS_block
  use variables,        only: outpath
  ! -------------------------------
  implicit none
  private
  public :: build_areavariation

contains

  subroutine build_areavariation(sini, blocks, out_dir, verbose)
    ! Process all blocks: reads option `x-area-variation` from
    !   [<section_prefix><b>]  (e.g., BCB-Block1, BCB-Block2, ...),
    ! interpolates onto block centerline x, and writes:
    !   <out_dir>/block<b>_area.dat
    type(ATLAS_block), intent(in) :: blocks(:)
    type(file_ini),    intent(in) :: sini
    character(len=*),  intent(in), optional :: out_dir
    logical,           intent(in), optional :: verbose

    integer :: b
    character(len=256) :: section_name


    do b = 1, size(blocks)
      section_name = 'BCB-Block'//trim(str(.true.,b))   
!      write(section_name, '(A,I0)') trim(section_prefix), b
      call x_area_variation_for_block(blocks(b), sini, section_name, b, out_dir, verbose)
    end do
  end subroutine build_areavariation


  subroutine x_area_variation_for_block(block, sini, section_name, block_id, out_dir, verbose)
    ! Single-block entry point. If `x-area-variation` is absent in section,
    ! the routine returns silently.
    type(ATLAS_block), intent(in) :: block
    type(file_ini),    intent(in) :: sini
    character(len=*),  intent(in) :: section_name
    integer,           intent(in) :: block_id
    character(len=*),  intent(in), optional :: out_dir
    logical,           intent(in), optional :: verbose

    character(len=512) :: area_file
    character(len=256) :: folder, outfile
    integer :: ierr

    real(8), allocatable :: xin(:), ain(:)
    real(8), allocatable :: aout(:)

    call sini%get(section_name=section_name, option_name='x-area-variation', &
                 val=area_file, error=ierr)

    if (ierr /= 0 .or. len_trim(area_file) == 0) return

    ! 1) read (x,A) pairs from ASCII (skips blank/#/! lines)
    call read_two_columns_ascii(area_file, xin, ain)
    call sort_pair_by_x(xin, ain)

    ! 3) interpolate with clamped extrapolation at ends
    allocate(aout(0:block%dim(1))) ! Per ora, area variation unicamente lungo x
    call interp1_linear(xin, ain, block%node(0:block%dim(1),1,1)%c(1), aout)

    ! 4) write output
    folder = outpath
    if (present(out_dir)) folder = trim(out_dir)
    write(outfile, '(A,"/block",I0,"_area.dat")') trim(folder), block_id
    call write_xy(outfile, block%node(0:block%dim(1),1,1)%c(1), aout)

    if (present(verbose)) then
      if (verbose) write(*,'(A,I0,2A)') '   [x-area] Block ', block_id, ' -> ', trim(outfile)
    end if

  end subroutine x_area_variation_for_block


  ! ==================== helpers ====================

  subroutine read_two_columns_ascii(filename, x, a)
    ! Read ASCII file with two columns: x  A(x)
    ! Skips empty lines and lines starting with # or !
    character(len=*), intent(in) :: filename
    real(8), allocatable, intent(out) :: x(:), a(:)

    integer :: u, ios, n
    character(len=1024) :: line
    real(8) :: tx, ta

    ! First pass: count valid rows
    n = 0
    open(newunit=u, file=trim(filename), status='old', action='read', iostat=ios)
    if (ios /= 0) then
      write(*,*) '[ERROR] Cannot open x-area file: ', trim(filename)
      stop
    end if
    do
      read(u, '(A)', iostat=ios) line
      if (ios /= 0) exit
      if (len_trim(line) == 0) cycle
      if (line(1:1) == '#' .or. line(1:1) == '!') cycle
      read(line, *, iostat=ios) tx, ta
      if (ios == 0) n = n + 1
    end do
    close(u)

    if (n <= 0) then
      write(*,*) '[ERROR] x-area file empty or invalid: ', trim(filename)
      stop
    end if

    ! Second pass: read data
    allocate(x(n), a(n))
    open(newunit=u, file=trim(filename), status='old', action='read', iostat=ios)
    if (ios /= 0) then
      write(*,*) '[ERROR] Cannot re-open x-area file: ', trim(filename)
      stop
    end if
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
  end subroutine read_two_columns_ascii


  pure subroutine sort_pair_by_x(x, y)
    real(8), intent(inout) :: x(:), y(:)
    integer :: i, j, n
    real(8) :: tx, ty
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


  subroutine interp1_linear(xin, yin, xout, yout)
    ! Linear interpolation; clamped at ends; guards identical knots.
    real(8), intent(in)  :: xin(:), yin(:), xout(:)
    real(8), intent(out) :: yout(:)
    integer :: i, j, n
    real(8) :: t, denom

    n = size(xin)
    if (n < 2) then
      if (n == 1) then
        yout = yin(1)
      else
        yout = 0d0
      end if
      return
    end if

    j = 1
    do i = 1, size(xout)
      if (xout(i) <= xin(1)) then
        yout(i) = yin(1)
      else if (xout(i) >= xin(n)) then
        yout(i) = yin(n)
      else
        do while (xout(i) > xin(j+1) .and. j < n-1)
          j = j + 1
        end do
        denom = xin(j+1) - xin(j)
        if (denom == 0d0) then
          yout(i) = yin(j)
        else
          t = (xout(i) - xin(j)) / denom
          yout(i) = (1d0 - t)*yin(j) + t*yin(j+1)
        end if
      end if
    end do
  end subroutine interp1_linear

  subroutine write_xy(outfile, x, y)
    character(len=*), intent(in) :: outfile
    real(8), intent(in) :: x(:), y(:)
    integer :: u, ios, i
    open(newunit=u, file=trim(outfile), status='replace', action='write', iostat=ios)
    if (ios /= 0) then
      write(*,*) '[ERROR] Cannot write: ', trim(outfile)
      stop
    end if
    do i = 1, size(x)
      write(u,'(*(1X,E23.15E3))') x(i), y(i) !FR_P format
    end do
    close(u)
  end subroutine write_xy

end module area_variation_mod
