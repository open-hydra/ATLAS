module ATLAS_IO_Legacy
  use Lib_ORION_data
  implicit none
  private
  public:: read_MISCELA
  public:: read_w
  public:: read_species

  integer:: i,j,k,s
  integer:: unitfile

  contains

  !> Read wm.dat
  subroutine read_w(n, w)
    implicit none
    integer, intent(in) :: n
    real(8), allocatable, intent(inout) :: w(:)
    integer :: ios

    allocate(w(1:n))
    open(unit=1,file='wm.dat',iostat=ios,status='old',action='read')
    if (ios/=0) open(unit=1,file='toAFFS/wm.dat',iostat=ios,status='old',action='read')
    do j = 1, size(w)
      read(1,*) w(j)
    enddo
    if ( ios /= 0 ) stop "Error opening file name"
    close(1)

  end subroutine read_w


  !> read MISCELA (tabella_ms and wm)
  subroutine read_MISCELA(w,cp,dcp,h)
    implicit none
    real(8), dimension(:,:), allocatable, intent(out):: cp, dcp, h
    real(8), dimension(:), allocatable, intent(inout):: w
    integer :: n(2), ios, idum
    real(8) :: dummy

    open(unit=1,file='tabellams.dat',iostat=ios,status='old',action='read')
    if (ios/=0) open(unit=1,file='toAFFS/tabellams.dat',iostat=ios,status='old',action='read')
    if (ios/=0) return
    read(1,*) n(1), n(2)
    allocate(cp(1:n(1),0:n(2)))
    allocate(dcp(1:n(1),0:n(2)))
    allocate(h(1:n(1),0:n(2)))
    do i = 1, n(1)
      do j = 1, n(2)
        read(1,*) idum, idum, h(i,j), dummy, cp(i,j), dcp(i,j), dummy, dummy
      enddo
    enddo
    h(:,0) = h(:,1)
    cp(:,0) = cp(:,1)
    dcp(:,0) = dcp(:,1)
    close(1)

    call read_w(n(1),w)

  end subroutine read_MISCELA

  subroutine read_species(file,n,name)
    implicit none
    character(len=*), intent(in):: file
    integer, intent(inout):: n
    character(len=20), dimension(:), allocatable, intent(inout):: name

    open(newunit=unitFile,file=adjustl(trim(file)),status='unknown')
    read(unitFile,*) n
    allocate(name(1:n))
    do i = 1, n
      read(unitFile,'(A)') name(i)
      name(i) = adjustl(trim(name(i)))
    end do
    close(unitFile)

  end subroutine read_species

end module ATLAS_IO_Legacy
