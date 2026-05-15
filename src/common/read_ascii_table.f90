module io_ascii_table_mod
  use global_mod, only: llen
  implicit none
  private
  public :: read_ascii_table

contains

  subroutine read_ascii_table(varfile, file_dir, file_var, error)
    implicit none
    character(len=*), intent(in) :: varfile
    real(8), dimension(:), allocatable, intent(out) :: file_dir, file_var
    integer :: ios, file_length, i, unitfile, error
    character(len=10*llen) :: line
    real(8) :: tmp_dir, tmp_var

    file_length=0; error=0
    open(newunit=unitfile,file=trim(varfile),status='old',action='read',iostat=ios)
    if (ios /= 0) then
      error = ios
      return
    endif
    do
      read(unitfile,'(A)',iostat=ios) line
      if (ios /= 0) exit
      if (len_trim(line) == 0) cycle
      if (line(1:1) == '#' .or. line(1:1) == '!') cycle
      read(line,*,iostat=ios) tmp_dir, tmp_var
      if (ios == 0) file_length = file_length+1
      ios = 0
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

    close(unitfile)
  end subroutine read_ascii_table

end module io_ascii_table_mod