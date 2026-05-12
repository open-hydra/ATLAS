module io_ascii_table_mod
  implicit none
  private
  public :: read_ascii_table

contains

  subroutine read_ascii_table(varfile, file_dir, file_var, error)
    implicit none
    character(len=*), intent(in) :: varfile
    real(8), dimension(:), allocatable, intent(out) :: file_dir, file_var
    integer :: ios, file_length, i, unitfile, error

    file_length=0; error=0
    open(newunit=unitfile,file=trim(varfile),status='old',action='read',iostat=ios)
    if (ios /= 0) then
      error = ios
      return
    endif
    do while (ios==0)
      read(unitfile,*,iostat=ios)
      file_length = file_length+1
    enddo
    file_length = file_length-1
    rewind(unitfile)
    allocate(file_dir(1:file_length))
    allocate(file_var(1:file_length))
    do i = 1, file_length
      read(unitfile,*) file_dir(i), file_var(i)
    enddo
    close(unitfile)
  end subroutine read_ascii_table

end module io_ascii_table_mod