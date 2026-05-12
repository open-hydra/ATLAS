!> Shared helpers for BC file I/O, detection and interpolation.
!>
!> Extracted from bc_cell_builder_mod (builder2.f90) to eliminate
!> duplicated 1-D / 2-D file-reading and interpolation code.
module io_external_mod
  use finer, only: file_ini
  use io_ascii_table_mod, only: read_ascii_table
  use bcb_config_mod
  implicit none
  private

  public :: bc_file_type
  public :: detect_bc_files
  public :: read_bc_file_1d
  public :: read_bc_file_2d
  public :: interp_linear_1d
  public :: interp_bilinear_2d

  !> Container for a single BC data file (coordinate arrays + values).
  type :: bc_file_type
    character(len=256)   :: name
    character(len=8)     :: var
    integer              :: length = 0
    integer              :: width  = 0
    real(8), allocatable :: dirArray1(:), dirArray2(:), array(:,:)
  end type bc_file_type

contains

  !> Scan an INI section for all known *-file options and populate
  !> bc_file(:) with the detected entries.
  subroutine detect_bc_files(ini, section, bc_file, n_files)
    type(file_ini),     intent(in)    :: ini
    character(len=*),   intent(in)    :: section
    type(bc_file_type), intent(inout) :: bc_file(:)
    integer,            intent(out)   :: n_files

    character(len=256) :: infile_dummy
    integer            :: k, error

    n_files = 0
    do k = 1, n_variable_file_keys
      call ini%get(section_name=section, option_name=trim(variable_file_keys(k))//'-file', val=infile_dummy, error=error)
      if (error == 0) then
        n_files = n_files + 1
        bc_file(n_files)%var  = trim(variable_file_keys(k))
        bc_file(n_files)%name = infile_dummy
      endif
    enddo
  end subroutine detect_bc_files


  !> Read a one-column data file (coord, value) into bc_file.
  !> Optionally converts the coordinate from degrees to radians
  !> when dir_index == 5 (theta direction).
  subroutine read_bc_file_1d(bf, dir_index)
    type(bc_file_type), intent(inout) :: bf
    integer, intent(in)               :: dir_index

    real(8), parameter :: pi = 4.0d0 * atan(1.0d0)
    real(8), allocatable :: tmp_dir(:), tmp_val(:)
    integer :: ios

    call read_ascii_table(bf%name, tmp_dir, tmp_val, ios)
    if (ios /= 0) then
       write(*,*) '[ERROR] BC file '//trim(bf%name)//' not found'
       stop
    endif
    bf%length = size(tmp_dir)
    call move_alloc(tmp_dir, bf%dirArray1)
    allocate(bf%array(bf%length, 1))
    bf%array(:, 1) = tmp_val
    deallocate(tmp_val)
    if (dir_index == 5) bf%dirArray1 = bf%dirArray1 * pi / 180

  end subroutine read_bc_file_1d


  !> Read a two-dimensional data file with auto-detected width.
  !> Format:  header row of width column-coords, then length rows
  !> of (row-coord, value_1, ..., value_width).
  !> dir_index(1:2) controls optional theta-to-radian conversion.
  subroutine read_bc_file_2d(bf, dir_index)
    type(bc_file_type), intent(inout) :: bf
    integer,            intent(in)    :: dir_index(:)

    real(8), parameter :: pi = 4.0d0 * atan(1.0d0)
    real(8), allocatable :: try(:)
    integer :: unit, ios, i, j

    bf%length = 0; bf%width = 10000; ios = 0
    open(newunit=unit, file=bf%name, status='old', action='read')
    ! Count total lines
    do while (ios == 0)
      read(unit, *, iostat=ios)
      bf%length = bf%length + 1
    enddo
    bf%length = bf%length - 2   ! exclude header & trailing failed read
    ! Detect width by trial reads
    do while (ios /= 0)
      rewind(unit)
      allocate(try(1:bf%width))
      read(unit, *, iostat=ios) try(1:bf%width)
      if (allocated(try)) deallocate(try)
      bf%width = bf%width - 1
    enddo
    bf%width = (bf%width + 2) / (bf%length + 1) - 1
    rewind(unit)
    allocate(bf%dirArray1(1:bf%length))
    allocate(bf%dirArray2(1:bf%width))
    allocate(bf%array(1:bf%length, 1:bf%width))
    read(unit, *) (bf%dirArray2(j), j = 1, bf%width)
    do i = 1, bf%length
      read(unit, *) bf%dirArray1(i), &
        (bf%array(i, j), j = 1, bf%width)
    enddo
    close(unit)
    if (dir_index(1) == 5) bf%dirArray1(:) = bf%dirArray1(:) * pi / 180
    if (dir_index(2) == 5) bf%dirArray2(:) = bf%dirArray2(:) * pi / 180
  end subroutine read_bc_file_2d


  !> 1-D linear interpolation: look up coord in bf%dirArray1 and
  !> return the interpolated value.  Returns .true. if coord falls
  !> within the data range, .false. otherwise.
  function interp_linear_1d(bf, coord, val) result(found)
    type(bc_file_type), intent(in) :: bf
    real(8), intent(in)            :: coord
    real(8), intent(out)           :: val
    logical                        :: found
    integer :: i

    found = .false.
    if (coord > bf%dirArray1(1) .and. &
        coord <= bf%dirArray1(bf%length)) then
      do i = 2, bf%length
        if (coord > bf%dirArray1(i-1) .and. &
            coord <= bf%dirArray1(i)) then
          val = (bf%array(i,1) - bf%array(i-1,1)) &
              / (bf%dirArray1(i) - bf%dirArray1(i-1)) &
              * (coord - bf%dirArray1(i-1)) &
              + bf%array(i-1,1)
          found = .true.
          return
        endif
      enddo
    endif
  end function interp_linear_1d


  !> 2-D bilinear interpolation on bfc%dirArray1 x dirArray2.
  !> Returns .true. if (c1,c2) falls within the data range.
  function interp_bilinear_2d(bf, c1, c2, val) result(found)
    type(bc_file_type), intent(in) :: bf
    real(8), intent(in)            :: c1, c2
    real(8), intent(out)           :: val
    logical                        :: found
    real(8) :: a1, a2, b1, b2, c11, c12, c21, c22
    integer :: i, j

    found = .false.
    do i = 2, bf%length
      if (c1 >= bf%dirArray1(i-1) .and. &
          c1 <= bf%dirArray1(i)) then
        do j = 2, bf%width
          if (c2 > bf%dirArray2(j-1) .and. &
              c2 <= bf%dirArray2(j)) then
            a1  = bf%dirArray1(i-1);  a2  = bf%dirArray1(i)
            b1  = bf%dirArray2(j-1);  b2  = bf%dirArray2(j)
            c11 = bf%array(i-1, j-1); c12 = bf%array(i-1, j)
            c21 = bf%array(i,   j-1); c22 = bf%array(i,   j)
            val = ((b2 - c2) / (b2 - b1) * c11 &
                 + (c2 - b1) / (b2 - b1) * c12) &
                 * (a2 - c1) / (a2 - a1)
            val = val &
                + ((b2 - c2) / (b2 - b1) * c21 &
                 + (c2 - b1) / (b2 - b1) * c22) &
                 * (c1 - a1) / (a2 - a1)
            found = .true.
            return
          endif
        enddo
      endif
    enddo
  end function interp_bilinear_2d

end module io_external_mod
