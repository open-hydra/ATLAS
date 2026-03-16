module ATLAS_read_phase
  use Lib_ORION_data
  implicit none
  private
  public :: read_idealgas_properties
  public :: read_cdp_properties
  public :: read_phase

contains

  subroutine read_idealgas_properties(prefix, sp)
    use species
    use strings, only: parse
    use Lib_Tecplot
    implicit none
    character(len=*), intent(in):: prefix
    type(obj_species), intent(inout) :: sp
    integer           :: ios, i, n, unitfile, start, Ti1, Ti2, dummy_i, dummy1, dummy23
    character(256)    :: wholestring, args(2)
    character(512)    :: wmfile, thermofile(2)
    type(ORION_data)  :: orion

    open(newunit=unitFile,file=trim(prefix)//'phase.txt',status='old',iostat=ios)
    if (ios/=0) then
      write(*,*) '[WARNING] phase file '//trim(prefix)//'phase.txt'//' not found'
      return
    endif
    ios = 0; n = -1
    read(unitfile,*)!skip first line
    do while(ios==0)
      read(unitFile,'(A)',iostat=ios) wholestring
      n = n + 1
    enddo
    sp%n = n
    allocate(sp%name(1:n))
    allocate(sp%w(1:n))
    rewind(unitFile)
    read(unitfile,*)!skip first line
    do i = 1, n
      read(unitFile,'(A)') wholestring
      call parse(wholestring,' ',args)
      sp%name(i) = trim(adjustl(args(1)))
      read(args(2),*) sp%w(i)
    end do
    close(unitFile)

    ! File 2: thermo
    ios = tec_read_points_multivars(orion,4,trim(prefix)//'thermo.dat')
    if (ios/=0) then
      write(*,*) '[WARNING] thermo file, '//trim(prefix)//'thermo.dat'//' not found'
      return
    endif
    dummy1  = lbound(orion%block(1)%mesh, dim=2)
    dummy23 = lbound(orion%block(1)%mesh, dim=3)
    Ti1 = nint(orion%block(1)%mesh(1,dummy1,dummy23,dummy23))
    Ti2 = Ti1 + ubound(orion%block(1)%mesh, dim=2) - dummy1
    start = Ti1
    if (Ti1==1) Ti1 = 0
    allocate(sp%cp(1:sp%n,Ti1:Ti2))
    allocate(sp%dcp(1:sp%n,Ti1:Ti2))
    allocate(sp%h(1:sp%n,Ti1:Ti2))
    allocate(sp%s(1:sp%n,Ti1:Ti2))
    dummy23 = lbound(orion%block(1)%vars, dim=3)
    do i = 1, sp%n
      sp%cp(i,start:Ti2) = orion%block(i)%vars(1,:,dummy23,dummy23)
      sp%h(i,start:Ti2) = orion%block(i)%vars(2,:,dummy23,dummy23)
      sp%s(i,start:Ti2) = orion%block(i)%vars(3,:,dummy23,dummy23)
      sp%dcp(i,start:Ti2) = orion%block(i)%vars(4,:,dummy23,dummy23)
    enddo
    if (Ti1 == 0) then
      sp%cp(:,0) = sp%cp(:,1)
      sp%h(:,0) = 0.d0
      sp%s(:,0) = sp%s(:,1)
      sp%dcp(:,0) = sp%dcp(:,1)
    endif

  end subroutine read_idealgas_properties


  subroutine read_cdp_properties(prefix, mat)
    use material_module
    use strings, only: parse
    use Lib_Tecplot
    implicit none
    character(len=*), intent(in):: prefix
    type(obj_material), intent(inout) :: mat
    integer :: i, n, ios, Ti1, Ti2, unitfile
    character(len=30) :: wholestring, args(2)
    type(orion_data) :: orion

    open(newunit=unitFile,file=trim(prefix)//'phase.txt',status='old',iostat=ios)
    if (ios/=0) return!error stop ("Error reading phase file")
    ios = 0; n = -1
    read(unitfile,*)!skip first line
    do while(ios==0)
      read(unitFile,'(A)',iostat=ios) wholestring
      n = n + 1
    enddo
    mat%n = n
    allocate(mat%name(1:n))
    allocate(mat%npCP(1:n))
    rewind(unitFile)
    read(unitfile,*)!skip first line
    do i = 1, n
      read(unitFile,'(A)') wholestring
      call parse(wholestring,' ',args)
      mat%name(i) = trim(adjustl(args(1)))
      read(args(2),*,iostat=ios) mat%npCP(i)
    end do
    close(unitFile)

    ios = tec_read_points_multivars(orion,3,trim(prefix)//'properties.dat')
    if (ios/=0) return!error stop ("Error reading ideal-gas thermo file")
    Ti1 = nint(orion%block(1)%mesh(1,1,1,1))
    Ti2 = Ti1 + orion%block(1)%Ni - 1
    allocate(mat%cp(1:mat%n,Ti1:Ti2))
    allocate(mat%rho(1:mat%n,Ti1:Ti2))
    allocate(mat%h(1:mat%n,Ti1:Ti2))
    do i = 1, mat%n
      mat%cp(i,Ti1:Ti2) = orion%block(i)%vars(1,1:orion%block(1)%Ni,1,1)
      mat%rho(i,Ti1:Ti2) = orion%block(i)%vars(2,:,1,1)
      mat%h(i,Ti1:Ti2) = orion%block(i)%vars(3,:,1,1)
    enddo

  end subroutine read_cdp_properties


  subroutine read_phase(phase)
    use strings, only: parse
    use phase_module, only: phase_type
    implicit none
    type(phase_type), allocatable, intent(out) :: phase(:)
    character(len=128) :: filename, stringa(2)
    integer :: m, i, num_files, u, ios, num_mat
    character(len=128), allocatable :: file_list(:)
    character(len=128) :: type, dummy

    ! Get the list of .txt files in the current directory
    call get_file_list(file_list, num_files)

    ! Check if the file is a species file (ideal-gas) or a material file (condensed-dispersed or a solid phase)
    if (num_files>=1) then
      allocate(phase(num_files))
      phase%type = 'JD'
      do i = 1, size(phase)
        filename = trim(adjustl(file_list(i)))
        ! Check if the phase has a name. If not, an empty string is returned
        call parse(filename,'-',stringa)
        if (stringa(2)=='') then
          stringa(2) = stringa(1)
          stringa(1) = ''
        endif
        if (index(stringa(2),'phase')>0) then
          open(newunit=u, file=filename, status="old")
          read(u,'(A)',iostat=ios) type
          if (index(type,'condensed-dispersed')>0) then
            phase(i)%type = 'CD'
          elseif (index(type,'solid')>0) then
            phase(i)%type = 'SP'
          elseif (index(type,'ideal-gas')>0) then
            phase(i)%type = 'IG'
          else
            write(*,*) 'Error: unknown phase type'
            stop
          endif
          close(u)
        endif
        phase(i)%name = stringa(1)
      end do
      deallocate(file_list)
    else
      ! If no species or material file is present, the ideal-gas phase is assumed
      allocate(phase(1))
      phase%type = 'IG'
      phase%name = ''
    endif

  end subroutine read_phase


  subroutine get_file_list(file_list, num_files)
      implicit none
      character(len=*), allocatable, intent(out) :: file_list(:)
      integer, intent(out) :: num_files
      character(len=256) :: line
      integer :: ios, unit, u

      open(newunit=u, file="filelist.txt", status="old", action="read", iostat=ios)

      num_files = 0
      do
        read(u, '(A)', iostat=ios) line
        if (ios /= 0) exit
        num_files = num_files + 1
      end do

      rewind(u)
      allocate(file_list(num_files))

      do unit = 1, num_files
        read(u, '(A)', iostat=ios) file_list(unit)
      end do

      close(u)
  end subroutine get_file_list

end module ATLAS_read_phase
