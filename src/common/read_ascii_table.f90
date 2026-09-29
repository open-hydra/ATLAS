module io_ascii_table_mod
  use global_mod, only: llen
  implicit none
  private
  public :: read_ascii_table

contains

  !> Read (coordinate, value) pairs. The coordinate column must be monotone (error -4 names the row where it
  !> turns back); a decreasing column is returned in increasing order, since the callers interpolate on an
  !> increasing column. A caller that sorts the pairs itself passes check_order = .false. and gets the rows in
  !> file order. error: 0 = read, > 0 = the file cannot be opened, -1 = no row of two numbers, -2 = the rows
  !> changed between the two passes, -4 = not monotone.
  subroutine read_ascii_table(varfile, file_dir, file_var, error, check_order)
    implicit none
    character(len=*), intent(in) :: varfile
    logical, intent(in), optional :: check_order
    real(8), dimension(:), allocatable, intent(out) :: file_dir, file_var
    integer :: ios, file_length, i, unitfile, error, nline
    logical :: up, check
    character(len=10*llen) :: line
    real(8) :: tmp_dir, tmp_var, tmp_extra

    file_length=0; error=0
    open(newunit=unitfile,file=trim(varfile),status='old',action='read',iostat=ios)
    if (ios /= 0) then
      error = ios
      return
    endif
    ! A non-blank, non-comment line that is not two numbers is skipped, as upstream does (a header
    ! row without #); a WARNING names it, since a typo in a data row drops that point. A row with more
    ! than two numbers is read as its first two, as upstream does; a WARNING names it too, since a
    ! third column may mean that the file is not the two-column table the key expects (a comment or a
    ! word after the two numbers is not a number: no WARNING).
    nline = 0
    do
      read(unitfile,'(A)',iostat=ios) line
      if (ios /= 0) exit
      nline = nline + 1
      if (len_trim(line) == 0) cycle
      line = adjustl(line)
      if (line(1:1) == '#' .or. line(1:1) == '!') cycle
      read(line,*,iostat=ios) tmp_dir, tmp_var
      if (ios /= 0) then
        write(*,'(A,I0,A)') '[WARNING] table file '//trim(varfile)//': line ', nline, &
                            ' is not two numbers (coordinate value), skipped: '//trim(line)
        cycle
      endif
      tmp_extra = -huge(1.0d0)   ! left unchanged by a null value or a slash after the two numbers
      read(line,*,iostat=ios) tmp_dir, tmp_var, tmp_extra
      if (ios == 0 .and. tmp_extra /= -huge(1.0d0)) &
        write(*,'(A,I0,A)') '[WARNING] table file '//trim(varfile)//': line ', nline, &
                            ' holds more than two numbers: the first two are read (coordinate value), the rest'// &
                            ' is ignored: '//trim(line)
      file_length = file_length+1
    enddo

    if (file_length <= 0) then
      close(unitfile)
      error = -1
      return
    endif

    rewind(unitfile)
    allocate(file_dir(1:file_length))
    allocate(file_var(1:file_length))
    i = 0
    do
      read(unitfile,'(A)',iostat=ios) line
      if (ios /= 0) exit
      if (len_trim(line) == 0) cycle
      line = adjustl(line)
      if (line(1:1) == '#' .or. line(1:1) == '!') cycle
      read(line,*,iostat=ios) tmp_dir, tmp_var
      if (ios /= 0) cycle
      i = i + 1
      if (i > file_length) exit
      file_dir(i) = tmp_dir
      file_var(i) = tmp_var
    enddo

    if (i /= file_length) then
      error = -2
    endif

    ! The interpolation assumes an ordered coordinate column: a table that turns back would be
    ! interpolated between the wrong rows.
    check = .true.
    if (present(check_order)) check = check_order
    if (check .and. error == 0 .and. file_length > 2) then
      up = file_dir(file_length) >= file_dir(1)
      do i = 2, file_length
        if ((up .and. file_dir(i) < file_dir(i-1)) .or. (.not.up .and. file_dir(i) > file_dir(i-1))) then
          write(*,'(A,I0,A,ES12.5,A,ES12.5,A)') '[ERROR] table file '//trim(varfile)//': the coordinate column is not'// &
                 ' monotone at row ', i, ' (', file_dir(i), ' after ', file_dir(i-1), ')'
          error = -4
          exit
        endif
      enddo
    endif
    ! A decreasing column (monotone, first coordinate above the last) is given back in increasing order.
    if (check .and. error == 0 .and. file_length > 1) then
      if (file_dir(file_length) < file_dir(1)) then
        file_dir = file_dir(file_length:1:-1)
        file_var = file_var(file_length:1:-1)
      endif
    endif

    close(unitfile)
  end subroutine read_ascii_table

end module io_ascii_table_mod