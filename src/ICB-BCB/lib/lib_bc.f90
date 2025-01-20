module lib_bc
  use finer, only: file_ini
  use species, only: obj_species
  use phase_module, only: phase_type
  use ATLAS_high_level
  use bc
  use chimera
  implicit none
  private
  public:: build_BC
  public:: find_connect
  public:: find_periodic
  public:: chimera_wrapper

  contains

  subroutine build_BC(phase,sini,blocks)
    use TOM, only: delthe
    use variables, only: nrans
    use strings, only: parse
    use ATLAS_IO, only: read_idealgas_properties
    implicit none
    type(phase_type), intent(in)     :: phase(:)
    type(ATLAS_block), intent(inout) :: blocks(:)
    type(file_ini), intent(in)       :: sini
    !> Local variables
    logical                        :: cell_dependent, multipatch=.false.
    type(file_ini)                 :: faceini, patchini
    integer                        :: error, error_patch=0
    character(len=:), allocatable  :: option_pairs(:)
    character(len=4)               :: ind, indb, dirID
    character(len=2)               :: patchdirection
    character(len=50)              :: patchname, section_name
    integer                        :: ff, n, m, p, b, pIG
    real(8)                        :: patchrange(4)
    character(len=30)              :: wholestring, args(3), phase_name

    do b = 1, size(blocks)
      write(indb,'(I4)') b
      section_name = 'BCB-Block'//adjustl(indb)   
      associate(block => blocks(b))

      do while (sini%loop(section_name=section_name, option_pairs=option_pairs))
        call faceini%add(section_name=section_name, option_name=option_pairs(1), val=option_pairs(2))
      enddo

      !> Look for phases solved in block b
      call sini%get(section_name=section_name, option_name='phase', val=wholestring, error=error)
      if (error/=0) then
        allocate(block%associated_phase(1:size(phase)))
        block%associated_phase = phase
      else
        call parse(wholestring,' ',args)
        p = count(args /= '')
        allocate(block%associated_phase(1:p))
        block%associated_phase%name = args(1:p)
        do m = 1, p
          do n = 1, size(phase)
            if (block%associated_phase(m)%name==phase(n)%name) &
              block%associated_phase(m) = phase(n)
          enddo
        enddo
      endif


      ! Read phase properties (if any)
      do p = 1, size(block%associated_phase)
        if (block%associated_phase(p)%name=='') then
          phase_name = ''
        else
          phase_name = trim(block%associated_phase(p)%name)//'-'
        endif
        if (block%associated_phase(p)%type=='IG') then
          pIG = p
          call read_idealgas_properties(trim(phase_name),block%associated_phase(p)%species)
        endif
        if (.not.allocated(block%associated_phase(p)%species%massf)) &
        allocate(block%associated_phase(p)%species%massf(1:block%associated_phase(p)%species%n))
        block%associated_phase(p)%species%massf = 1d-20
      enddo
    
      !> Look for faces bc definition
      do ff = 1, 6

        write(ind,'(I4)') ff
        call sini%get(section_name=section_name, option_name='face'//adjustl(ind), &
                                                              val=block%face(ff)%bc%name, error=error)

        if (error/=0) then
          if (ff<=4) then
            error stop ( 'Missing face entries' )
          else
            if (delthe==0.d0) then
              block%face(ff)%bc%name = 'null'
              block%face(ff)%bc%definition = 0
            else
              block%face(ff)%bc%name = 'axisymmetric'
              block%face(ff)%bc%definition = 2
            endif
            error = 0
          endif
        else
          do while (sini%loop(section_name=trim(block%face(ff)%bc%name), option_pairs=option_pairs))
            call faceini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
            if (index(option_pairs(1),'patch')>0) multipatch=.true.
          enddo
          call sini%get(section_name=trim(block%face(ff)%bc%name), option_name='type', &
                        val=block%face(ff)%bc%definition, error=error)
        endif

        !> Face-related INI source
        multipatch = .false.
        call faceini%free
        call faceini%add(section_name='face')
        do while (sini%loop(section_name=trim(block%face(ff)%bc%name), option_pairs=option_pairs))
          call faceini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
          if (index(option_pairs(1),'patch')>0) multipatch=.true.
        enddo
        if (error/=0 .and. .not.multipatch) error stop ( 'Missing type entry' )

        !> BC building depending on specific case
        if (multipatch) then
          
          !> Multipatch BCs
          call sini%get(section_name=block%face(ff)%bc%name, option_name='direction', &
                        val=patchdirection, error=error)
          if (error==0) then
            write(*,*)' Face n. = ', ff, ' -> ', trim(block%face(ff)%bc%name), ' = multipatch'
            p = 0
            do
              p = p+1; write(ind,'(I4)') p
              call sini%get(section_name=block%face(ff)%bc%name, option_name='patch'//adjustl(ind), &
                                                val=patchname, error=error_patch)
              if (error_patch/=0) exit
              call sini%get(section_name=block%face(ff)%bc%name, option_name='range'//adjustl(ind), &
                                                val=patchrange, error=error)
              call patchini%free
              call patchini%add(section_name='face')
              do while (sini%loop(section_name=patchname, option_pairs=option_pairs))
                call patchini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
              enddo
              call patchini%add(section_name='face', option_name='range', val=patchrange)
              call patchini%add(section_name='face', option_name='direction', val=patchdirection)
              do m = 1, size(block%associated_phase)
                call build_cell(b,ff,block%face(ff),nrans,patchini,block%associated_phase(m))
              enddo
            enddo
          endif
        
        else
          !> Single patch with/without varying properties BCs
          cell_dependent = .false.
          call faceini%get(section_name='face', option_name='direction', val=dirID, error=error)
          if (error==0) cell_dependent=.true.
          if (cell_dependent) then
            write(*,*)' Face n. = ', ff, ' -> ', trim(block%face(ff)%bc%name), ' = single patch with varying properties'
            do m = 1, size(block%associated_phase)
              call build_cell(b,ff,block%face(ff),nrans,faceini,block%associated_phase(m))
            enddo
          else
            write(*,*)' Face n. = ', ff, ' -> ', trim(block%face(ff)%bc%name), ' = single patch'
            do m = 1, size(block%associated_phase)
              call block%face(ff)%bc%build(nrans,faceini,'face',block%associated_phase(m))
            enddo
            do n = 1, block%face(ff)%Nn
              do m = 1, block%face(ff)%Nm
                allocate(block%face(ff)%center(m,n)%bc%properties(1:block%face(ff)%bc%nproperties))
                block%face(ff)%center(m,n)%bc%adj_assigned = .false.
                block%face(ff)%center(m,n)%bc%nproperties = block%face(ff)%bc%nproperties
                block%face(ff)%center(m,n)%bc%connection = block%face(ff)%bc%connection
                block%face(ff)%center(m,n)%bc%definition = block%face(ff)%bc%definition
                block%face(ff)%center(m,n)%bc%properties = block%face(ff)%bc%properties
                block%face(ff)%center(m,n)%bc%species%n = block%face(ff)%bc%species%n
                if (block%face(ff)%bc%species%n>0) &
                  block%face(ff)%center(m,n)%bc%species%massf = block%face(ff)%bc%species%massf
                if (allocated(block%face(ff)%bc%cp_properties)) then
                  allocate(block%face(ff)%center(m,n)%bc%cp_properties &
                                          (size(block%face(ff)%bc%cp_properties,1),size(block%face(ff)%bc%cp_properties,2),size(block%face(ff)%bc%cp_properties,3)))
                  block%face(ff)%center(m,n)%bc%cp_nproperties = block%face(ff)%bc%cp_nproperties
                  block%face(ff)%center(m,n)%bc%cp_properties = block%face(ff)%bc%cp_properties
                endif
              enddo
            enddo
          endif
        endif

      enddo
      write(*,*)
      endassociate
    enddo

  end subroutine build_BC


  subroutine build_cell(b,f,face,nrans,ini_i,phase)
    implicit none
    integer, intent(in)            :: b, f
    type(obj_face)                 :: face
    type(file_ini), intent(in)     :: ini_i
    type(file_ini)                 :: ini_o
    type(phase_type), intent(in)   :: phase
    integer, intent(in)            :: nrans
    real(8), parameter             :: pi=4.0*atan(1.0)
    integer                        :: error, ios, iosold, length, width, cnt_bc=0
    integer                        :: i, j, m, n, f_, mi, me, ni, ne
    character(len=200)             :: infile, line
    character(len=3)               :: dirID
    character(len=5)               :: varname
    integer                        :: dirSize=0, type_
    integer, allocatable           :: dir(:)
    real(8), allocatable           :: dirArray1(:), dirArray2(:), array(:,:), here(:), try(:)
    real(8)                        :: var=0.0, a1, a2, b1, b2, c11, c12, c21, c22, range(4)
    logical                        :: found(8), file_present=.false., tecfile_present=.false., index_based=.false.
    character(len=:), allocatable  :: option_pairs(:)

    call ini_o%free
    call ini_o%add(section_name='cell')

    call ini_i%get(section_name='face', option_name='direction', val=dirID, error=error)
    if (error==0) then
      found = .false.
      dirSize = len_trim(dirID)
      allocate(dir(1:dirSize)); allocate(here(1:dirSize))
      do i = 1, dirSize
        if (index(dirID,'x')/=0 .and. .not.found(1)) then
          dir(i) = 1; found(1)=.true.
        elseif (index(dirID,'y')/=0 .and. .not.found(2)) then
          dir(i) = 2; found(2)=.true.
        elseif (index(dirID,'z')/=0 .and. .not.found(3)) then
          dir(i) = 3; found(3)=.true.
        elseif (index(dirID,'r')/=0 .and. .not.found(4)) then
          dir(i) = 4; found(4)=.true.
        elseif (index(dirID,'t')/=0 .and. .not.found(5)) then
          dir(i) = 5; found(5)=.true.
        elseif (index(dirID,'i')/=0 .and. .not.found(6)) then
          dir(i) = 6; found(6)=.true.; index_based=.true.
        elseif (index(dirID,'j')/=0 .and. .not.found(7)) then
          dir(i) = 7; found(7)=.true.; index_based=.true.
        elseif (index(dirID,'k')/=0 .and. .not.found(8)) then
          dir(i) = 8; found(8)=.true.; index_based=.true.
        endif
      enddo
    endif

    !> Check range for mulipatch
    call ini_i%get(section_name='face',option_name='range',val=range, error=error)
    if (error==0) then
      do i = dirSize*2+1, 4 ; range(i) = (-1.0)**i*huge(range(i)) ; enddo
    else
      do i = 1, 4 ; range(i) = (-1.0)**i*huge(range(i)) ; enddo
    endif
    
    call ini_i%get(section_name='face', option_name='type', val=type_, error=error)
    do while (ini_i%loop(section_name='face', option_pairs=option_pairs))
      call ini_o%add(section_name='cell', option_name=option_pairs(1), val=option_pairs(2))
    enddo

    !> Check file presence
    file_present=.false.; tecfile_present=.false.; found = .false.
    call ini_o%get(section_name='cell', option_name='hs-file', val=infile, error=error)
    if (error==0) then
      varname = 'hs'; found = .true.
    endif
    call ini_o%get(section_name='cell', option_name='q-file', val=infile, error=error)
    if (error==0) then
      varname = 'q'; found = .true.
    endif
    call ini_o%get(section_name='cell', option_name='T-file', val=infile, error=error)
    if (error==0) then
      varname = 'T'; found = .true.
    endif
    call ini_o%get(section_name='cell', option_name='phi-file', val=infile, error=error)
    if (error==0) then
      varname = 'phi'; found = .true.
    endif
    call ini_o%get(section_name='cell', option_name='SF-file', val=infile, error=error)
    if (error==0) then
      varname = 'SF'; found = .true.
    endif
    call ini_o%get(section_name='cell', option_name='qrad-file', val=infile, error=error)
    if (error==0) then
      varname = 'qrad'; found = .true.
    endif
    call ini_o%get(section_name='cell', option_name='alpha-file', val=infile, error=error)
    if (error==0) then
      varname = 'alpha'; found = .true.
    endif
    call ini_o%get(section_name='cell', option_name='beta-file', val=infile, error=error)
    if (error==0) then
      varname = 'beta'; found = .true.
    endif
    call ini_o%get(section_name='cell', option_name='g-file', val=infile, error=error)
    if (error==0) then
      varname = 'g'; found = .true.
    endif

    call ini_o%get(section_name='cell', option_name='krho-file', val=infile, error=error)
    if (error==0) then
      varname = 'krho'; found = .true.
    endif

    !> Check if the file is in free-format or Tecplot-format
    if (found(1)) then
      if (index(infile,'.tec')>0) then
        tecfile_present = .true.
        if(allocated(here)) deallocate(here)
        allocate(here(2))
      else
        file_present = .true.
      endif
    endif

    if (.not.tecfile_present .and. .not.index_based) then

      !> Importing data from files and/or apply multipatch
      select case (dirSize)
      !> One dimensional variation
      case(1)
        length=0; ios=0
        if (file_present) then
          open(unit=1,file=infile,status='old',action='read')
          do while (ios==0)
            read(1,*,iostat=ios)
            length = length+1
          enddo
          length = length-1
          rewind(1)
          allocate(dirArray1(1:length))
          allocate(array(1:length,1))
          do i = 1, length
            read(1,*) dirArray1(i), array(i,1)
          enddo
          close(1)
        endif
        if (dir(1)==5) dirArray1 = dirArray1*pi/180
        do n = 1, face%Nn; do m = 1, face%Nm
            here(1) = face%center(m,n)%c(dir(1))
            if (file_present) then
              !> Interpolazione lineare
              do i = 2, length
                if (here(1)>dirArray1(i-1) .and. here(1)<=dirArray1(i)) then
                  var = (array(i,1)-array(i-1,1))/(dirArray1(i)-dirArray1(i-1))*(here(1)-dirArray1(i-1))+array(i-1,1)
                  call ini_o%add(section_name='cell', option_name=trim(varname), val=var)
                  exit
                endif
              enddo
            endif
            !> Multipatch
            if (here(1)>range(1) .and. here(1)<=range(2)) then
              cnt_bc = cnt_bc+1
              face%center(m,n)%bc%definition = type_
              call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            endif
        enddo; enddo
      !> Two dimensional variaton
      case(2)
        length=0; width=10000; ios=0
        if (file_present) then
          open(unit=1,file=infile,status='old',action='read')
          do while (ios==0)
            read(1,*,iostat=ios)
            length = length+1
          enddo
          length = length-2
          do while(ios/=0)
            rewind(1)
            allocate(try(1:width))
            read(1,*,iostat=ios) try(1:width)
            deallocate(try)
            width = width-1
          enddo
          width = (width+2)/(length+1)-1
          rewind(1)
          allocate(dirArray1(1:length))
          allocate(dirArray2(1:width))
          allocate(array(1:length,1:width))
          read(1,*) (dirArray2(j),j=1,width)
          do i = 1, length
            read(1,*) dirArray1(i), (array(i,j),j=1,width)
          enddo
          close(1)
          if (dir(1)==5) dirArray1(:) = dirArray1(:)*pi/180
          if (dir(2)==5) dirArray2(:) = dirArray2(:)*pi/180
        endif
        do n = 1, face%Nn; do m = 1, face%Nm
            here(1) = face%center(m,n)%c(dir(1))
            here(2) = face%center(m,n)%c(dir(2))
            if (file_present) then
              !> Doppia interpolazione lineare
              do i = 2, length
                if (here(1)>=dirArray1(i-1) .and. here(1)<=dirArray1(i)) then
                  do j = 2, width
                    if (here(2)>dirArray2(j-1) .and. here(2)<=dirArray2(j)) then
                      a1 = dirArray1(i-1); a2 = dirArray1(i)
                      b1 = dirArray2(j-1); b2 = dirArray2(j)
                      c11 = array(i-1,j-1); c12 = array(i,j-1)
                      c21 = array( i ,j-1); c22 = array(i, j )
                      var = ((b2-here(2))/(b2-b1)*c11+(here(2)-b1)/(b2-b1)*c12)*(a2-here(1))/(a2-a1)
                      var = var+((b2-here(2))/(b2-b1)*c21+(here(2)-b1)/(b2-b1)*c22)*(here(1)-a1)/(a2-a1)
                      call ini_o%add(section_name='cell', option_name=trim(varname), val=var)
                      exit
                    endif
                  enddo
                endif
              enddo
            endif
            !> Multipatch
            if (dir(1)==5) range(1:2) = range(1:2)*pi/180
            if (dir(2)==5) range(3:4) = range(3:4)*pi/180
            if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
                here(2)>=range(3) .and. here(2)<=range(4)) then
              cnt_bc = cnt_bc+1
              face%center(m,n)%bc%definition = type_
              call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            endif
        enddo; enddo
      end select
    
    elseif (tecfile_present .and. .not.index_based) then
      !> Importing data from files in Tecplot format

      open(unit=1, file=infile, status='old', action='read', iostat=ios)
      if (ios /= 0) error stop ("Error opening the file.")

      f_ = 0; iosold = 0
      !> Skip lines upto the desired face and block
      do while(ios /= -1 .and. f_ < 4*(b-1)+f)
        read(1, '(A)', iostat=ios) line
        if (ios == -1) write(*,*) "EOF", infile
        ! Check if the line contains a real number
        read(line,*,iostat=ios) var    
        if (index(line,'=')>0 .or. index(line,',')>0) ios=1
        if (ios /= 0) then
          if (iosold==0) f_ = f_+1
        end if
        iosold = ios
      end do
      do while(ios /= 0)
        read(1, '(A)', iostat=ios) line
        read(line,*,iostat=ios) var    
        if (index(line,'=')>0 .or. index(line,',')>0) ios=1
      end do
      !> Skip geometrical coordinates
      do i = 1, (face%Nn+1)*(face%Nm+1)*3-1
        read(1,'(A)') line
      enddo
      do n = 1, face%Nn; do m = 1, face%Nm
          read(1,*) var
          here(1) = face%center(m,n)%c(dir(1))
          if (dirSize>1) then
            here(2) = face%center(m,n)%c(dir(2))
          else
            here(2) = 0.5*(sum(range(3:4)))
          endif
          if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
              here(2)>=range(3) .and. here(2)<=range(4)) then
              cnt_bc = cnt_bc+1
              call ini_o%add(section_name='cell', option_name=trim(varname), val=var)
              face%center(m,n)%bc%definition = type_
              call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            endif
      enddo; enddo

      close(1)

    elseif (index_based) then

      mi = 0; me = huge(1)
      ni = 0; ne = huge(1)

      do i = 1, dirSize
        select case (f)

          case(1:2)
            if (dir(i) == 6) then
              error stop ( 'ERROR: index i does not vary on face 1/2' )
            elseif (dir(i) == 7) then
              mi = nint(range(2*(i-1)+1)); me = nint(range(2*i))
            elseif (dir(i) == 8) then
              ni = nint(range(2*(i-1)+1)); ne = nint(range(2*i))
            endif
          
          case(3:4)
            if (dir(i) == 7) then
              error stop ( 'ERROR: index j does not vary on face 3/4' )
            elseif (dir(i) == 6) then
              mi = nint(range(2*(i-1)+1)); me = nint(range(2*i))
            elseif (dir(i) == 8) then
              ni = nint(range(2*(i-1)+1)); ne = nint(range(2*i))
            endif

          case(5:6)
            if (dir(i) == 8) then
              error stop ( 'ERROR: index k does not vary on face 5/6' )
            elseif (dir(i) == 6) then
              mi = nint(range(2*(i-1)+1)); me = nint(range(2*i))
            elseif (dir(i) == 7) then
              ni = nint(range(2*(i-1)+1)); ne = nint(range(2*i))
            endif
        
        end select
      enddo

      do n = ni, ne
        do m = mi, me
          face%center(m,n)%bc%definition = type_
          call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
        enddo
      enddo

    endif
  
  end subroutine build_cell



  subroutine find_periodic(block)
    use bc
    implicit none
    type(ATLAS_block), intent(inout) :: block(:)
    integer :: f1,m1,n1,b1,b2,f2,m2,n2,i2,j2,k2
    integer :: nb, nx(30), ny(30), nz(30)

    nb = size(block)

    do b1 = 1, nb
      nx(b1) = block(b1)%face(3)%Nm
      ny(b1) = block(b1)%face(1)%Nm
      nz(b1) = block(b1)%face(1)%Nn
    enddo

    do b1 = 1, nb
      do f1 = 1, 2
        do n1 = 1, block(b1)%face(f1)%Nn
          do m1 = 1, block(b1)%face(f1)%Nm
            associate( this => block(b1)%face(f1)%center(m1,n1) )
            if (this%bc%definition==1 .and. this%bc%connection(3)>0) then
              if (this%bc%connection(1)==0) then
                b2 = b1
              else
                b2 = this%bc%connection(1)
                if (b1==b2) b2 = this%bc%connection(2)
              endif
              f2 = this%bc%connection(3)
              if (f1==f2) f2 = this%bc%connection(4)
              this%bc%adj_assigned = .true.
              m2 = m1
              n2 = n1
              call mn2ijk(f2,m2,n2,nx(b2),ny(b2),nz(b2),i2,j2,k2)
              this%bc%properties(1) = b2
              this%bc%properties(2) = i2
              this%bc%properties(3) = j2
              this%bc%properties(4) = k2
              this%bc%properties(5) = f2
            endif
            endassociate
          enddo
        enddo
      enddo
    enddo

  end subroutine find_periodic



  !> Based on the find_connect.F file of AFFS
  subroutine find_connect(block,force_connect)
    ! use omp_lib
    use bc
    implicit none
    type(ATLAS_block), intent(inout) :: block(:)
    logical, intent(in) :: force_connect
    real(8), allocatable  :: x(:), y(:), z(:)
    integer, allocatable :: b(:), f(:), n(:), m(:), def(:), prop(:,:)
    logical, allocatable :: adj(:)
    integer :: nb, nbound, nboundb(30), nx(30), ny(30), nz(30)
    integer :: f1,m1,n1,b1,b2,f2,m2,n2,i,j,bqui
    integer :: ib1,i1,j1,k1,if1
    integer :: ib2,i2,j2,k2,if2
    integer :: di11(6),dj11(6),dk11(6)
    integer :: di01(6),dj01(6),dk01(6)
    integer :: di10(6),dj10(6),dk10(6)
    integer :: di00(6),dj00(6),dk00(6)

    real(8) :: x00,x10,x01,x11
    real(8) :: y00,y10,y01,y11
    real(8) :: z00,z10,z01,z11
    real(8) :: eix2up,eiy2up,eiz2up
    real(8) :: ejx1do,ejy1do,ejz1do
    real(8) :: ejx2do,ejy2do,ejz2do
    real(8) :: eix1do,eiy1do,eiz1do
    real(8) :: eix2do,eiy2do,eiz2do
    real(8) :: ejx2up,ejy2up,ejz2up

    real(8) :: aa(3,3),bb(3,3)
    real(8) :: dum1, dumii, dumij, dumji, dumjj
    integer :: nn

    ! si calcola le distanze dal centro della faccia dai centri di tutte le altre
    ! faccie di contorno dei blocchi
    ! se tale distanza e' mininore della tolleranza allora
    ! le due faccie sono connesse

    nb = size(block)

    ! Store data in local variables
    nbound = 0; nboundb = 0; bqui = 1
    do b1 = 1, nb
      nx(b1) = block(b1)%face(3)%Nm
      ny(b1) = block(b1)%face(1)%Nm
      nz(b1) = block(b1)%face(1)%Nn
      do f1 = 1, 6
        nboundb(b1) = nboundb(b1)+(block(b1)%face(f1)%Nm*block(b1)%face(f1)%Nn)
        nbound = nbound+(block(b1)%face(f1)%Nm*block(b1)%face(f1)%Nn)
      enddo
    enddo
    allocate(x(1:nbound)); allocate(y(1:nbound)); allocate(z(1:nbound))
    allocate(b(1:nbound)); allocate(f(1:nbound)); allocate(m(1:nbound))
    allocate(n(1:nbound)); allocate(def(1:nbound)); allocate(adj(1:nbound))
    allocate(prop(1:nbound,1:5))
    i = 0
    do b1 = 1, nb
      do f1 = 1, 6
        do n1 = 1, block(b1)%face(f1)%Nn
          do m1 = 1, block(b1)%face(f1)%Nm
            i = i +1
            associate( this => block(b1)%face(f1)%center(m1,n1) )
            def(i) = this%bc%definition
            adj(i) = this%bc%adj_assigned
            x(i) = this%c(1)
            y(i) = this%c(2)
            z(i) = this%c(3)
            m(i) = m1
            n(i) = n1
            f(i) = f1
            b(i) = b1
            endassociate
          enddo
        enddo
      enddo
    enddo

    ! Loop over boundary cells to find connections
    do i = 1, nbound
      if (def(i)/=1 .and. .not.force_connect) cycle
      if (adj(i)) cycle
      if (i>sum(nboundb(1:bqui))) bqui = bqui+1
      do j = sum(nboundb(1:bqui))+1, nbound
        if (def(j)/=1 .and. .not.force_connect) cycle
        dum1 = (x(i)-x(j))**2+ &
              (y(i)-y(j))**2+ &
              (z(i)-z(j))**2
        dum1 = sqrt(dum1)
        if (dum1<1d-7) then
          b1 = b(i); f1 = f(i)
          m1 = m(i); n1 = n(i)
          b2 = b(j); f2 = f(j)
          m2 = m(j); n2 = n(j)
          call mn2ijk(f1,m1,n1,nx(b1),ny(b1),nz(b1),i1,j1,k1)
          call mn2ijk(f2,m2,n2,nx(b2),ny(b2),nz(b2),i2,j2,k2)
          def(i) = 1
          adj(i) = .true.
          prop(i,1) = b2
          prop(i,2) = i2
          prop(i,3) = j2
          prop(i,4) = k2
          prop(i,5) = f2
                    
          def(j) = 1
          adj(j) = .true.
          prop(j,1) = b1
          prop(j,2) = i1
          prop(j,3) = j1
          prop(j,4) = k1
          prop(j,5) = f1
                      
          exit
        endif
      enddo
    enddo


    i = 0
    do b1 = 1, nb
      do f1 = 1, 6
        do n1 = 1, block(b1)%face(f1)%Nn
          do m1 = 1, block(b1)%face(f1)%Nm
            i = i +1
            if (def(i)==1) then
              associate( this => block(b1)%face(f1)%center(m1,n1) )
              this%bc%definition = def(i)
              this%bc%adj_assigned = adj(i)
              this%bc%properties = real(prop(i,:))
              if (product(prop(i,1:5))==0) then
                write(*,*) " Find connect"
                write(*,*) " Connection not found"
                write(*,*) " b,f,m,n"
                write(*,*) b1, f1, m1, n1
                stop
              endif
              endassociate
            endif
          enddo
        enddo
      enddo
    enddo

    ! parte sperimentale per la determinazione degli indici delle
    ! celle adiacenti a quella a cui e'connessa
    ! questa parte e' necessaria nel caso di flag VISC attivo

    di11(1) =-1; dj11(1) = 0; dk11(1) = 0
    di01(1) =-1; dj01(1) =-1; dk01(1) = 0
    di10(1) =-1; dj10(1) = 0; dk10(1) =-1
    di00(1) =-1; dj00(1) =-1; dk00(1) =-1

    di11(2) = 0; dj11(2) = 0; dk11(2) = 0
    di01(2) = 0; dj01(2) =-1; dk01(2) = 0
    di10(2) = 0; dj10(2) = 0; dk10(2) =-1
    di00(2) = 0; dj00(2) =-1; dk00(2) =-1

    di11(3) = 0; dj11(3) =-1; dk11(3) = 0
    di01(3) =-1; dj01(3) =-1; dk01(3) = 0
    di10(3) = 0; dj10(3) =-1; dk10(3) =-1
    di00(3) =-1; dj00(3) =-1; dk00(3) =-1

    di11(4) = 0; dj11(4) = 0; dk11(4) = 0
    di01(4) =-1; dj01(4) = 0; dk01(4) = 0
    di10(4) = 0; dj10(4) = 0; dk10(4) =-1
    di00(4) =-1; dj00(4) = 0; dk00(4) =-1

    di11(5) = 0; dj11(5) = 0; dk11(5) =-1
    di01(5) =-1; dj01(5) = 0; dk01(5) =-1
    di10(5) = 0; dj10(5) =-1; dk10(5) =-1
    di00(5) =-1; dj00(5) =-1; dk00(5) =-1

    di11(6) = 0; dj11(6) = 0; dk11(6) = 0
    di01(6) =-1; dj01(6) = 0; dk01(6) = 0
    di10(6) = 0; dj10(6) =-1; dk10(6) = 0
    di00(6) =-1; dj00(6) =-1; dk00(6) = 0

    di11 =di11+1; dj11 =dj11+1; dk11 = dk11+1
    di01 =di01+1; dj01 =dj01+1; dk01 = dk01+1
    di10 =di10+1; dj10 =dj10+1; dk10 =dk10+1
    di00 =di00+1; dj00 =dj00+1; dk00 =dk00+1

    do b1 = 1, nb
    do f1 = 1, 6
      do n1 = 1, block(b1)%face(f1)%Nn
        do m1 = 1, block(b1)%face(f1)%Nm

          if (block(b1)%face(f1)%center(m1,n1)%bc%adj_assigned) then
            
            associate( this => block(b1)%face(f1)%center(m1,n1) )

            ! legge dati della faccia di contorno
            if1 = f1; ib1 = b1
            call mn2ijk(f1,m1,n1,nx(b1),ny(b1),nz(b1),i1,j1,k1)
            i1 = i1-1; j1 = j1-1; k1 = k1-1

            x11 = block(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(1)
            y11 = block(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(2)
            z11 = block(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(3)

            x01 = block(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(1)
            y01 = block(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(2)
            z01 = block(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(3)

            x10 = block(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(1)
            y10 = block(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(2)
            z10 = block(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(3)

            x00 = block(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(1)
            y00 = block(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(2)
            z00 = block(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(3)

            eix1do= 0.5*(x11+x10)-0.5*(x01+x00)
            eiy1do= 0.5*(y11+y10)-0.5*(y01+y00)
            eiz1do= 0.5*(z11+z10)-0.5*(z01+z00)

            ejx1do= 0.5*(x11+x01)-0.5*(x10+x00)
            ejy1do= 0.5*(y11+y01)-0.5*(y10+y00)
            ejz1do= 0.5*(z11+z01)-0.5*(z10+z00)

            ! legge  dati della faccia a cui e' connessa la faccia di contorno

            ib2 = nint(this%bc%properties(1))
            i2 = nint(this%bc%properties(2))-1
            j2 = nint(this%bc%properties(3))-1
            k2 = nint(this%bc%properties(4))-1
            if2 = nint(this%bc%properties(5))

            x11 = block(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(1)
            y11 = block(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(2)
            z11 = block(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(3)

            x01 = block(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(1)
            y01 = block(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(2)
            z01 = block(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(3)

            x10 = block(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(1)
            y10 = block(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(2)
            z10 = block(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(3)

            x00 = block(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(1)
            y00 = block(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(2)
            z00 = block(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(3)

            ! calcola base covariante associata alla faccia connessa

            eix2do= 0.5*(x11+x10)-0.5*(x01+x00)
            eiy2do= 0.5*(y11+y10)-0.5*(y01+y00)
            eiz2do= 0.5*(z11+z10)-0.5*(z01+z00)

            ejx2do= 0.5*(x11+x01)-0.5*(x10+x00)
            ejy2do= 0.5*(y11+y01)-0.5*(y10+y00)
            ejz2do= 0.5*(z11+z01)-0.5*(z10+z00)

            aa(1,1)=eix2do; aa(1,2)=eiy2do; aa(1,3)=eiz2do
            aa(2,1)=ejx2do; aa(2,2)=ejy2do; aa(2,3)=ejz2do
            ! aggiunge alla base definita sulla faccia il vettore perpr.
            ! ai due vettori della base (ottenuto tramite il prodotto vettore)
            aa(3,1)=  aa(1,2)*aa(2,3)-aa(1,3)*aa(2,2)
            aa(3,2)=-(aa(1,1)*aa(2,3)-aa(1,3)*aa(2,1))
            aa(3,3)=  aa(1,1)*aa(2,2)-aa(1,2)*aa(2,1)

            ! calcolo base controvariante associata alla faccia connessa
            nn=3
            call invmat(aa,bb,nn)

            eix2up=bb(1,1)
            eiy2up=bb(2,1)
            eiz2up=bb(3,1)

            ejx2up=bb(1,2)
            ejy2up=bb(2,2)
            ejz2up=bb(3,2)

            ! calcolo prodotti scalari tra i vettori della base covariante della
            ! faccia di contorno e la base controvariante della faccia connessa.

            dumii=eix1do*eix2up+eiy1do*eiy2up+eiz1do*eiz2up
            dumij=eix1do*ejx2up+eiy1do*ejy2up+eiz1do*ejz2up
            dumji=ejx1do*eix2up+ejy1do*eiy2up+ejz1do*eiz2up
            dumjj=ejx1do*ejx2up+ejy1do*ejy2up+ejz1do*ejz2up

            this%bc%connection(1) = NINT(dumii)
            this%bc%connection(2) = NINT(dumij)
            this%bc%connection(3) = NINT(dumji)
            this%bc%connection(4) = NINT(dumjj)

            endassociate
          endif
        enddo
      enddo
    enddo
    enddo

  end subroutine find_connect



subroutine chimera_wrapper(block)
  use intersection_module
  use ATLAS_high_level
  use TOM, only: gc
  use chimera
  implicit none
  type(ATLAS_block), intent(inout) :: block(:)
  character(len=200) :: master_path
  integer                 :: ir,jr,kr,br,ni,nint
  integer                 :: unitfile1, unitfile2
  type(intersection_type), allocatable :: intersection(:)
  logical, allocatable                 :: nodeinside(:,:,:,:)

  !% Look for intersections
  ni = 0; nint = 0
  open(newunit=unitfile1,file='couples.txt')
  open(newunit=unitfile2,file='points.txt')

  ! Loop over the receiver block cells
  do br = 1, size(block)

    allocate(block(br)%face(1)%cell(1-gc:0,                        1-gc:block(br)%dim(2)+gc,          1-gc:block(br)%dim(3)+gc))
    allocate(block(br)%face(2)%cell(block(br)%dim(1)+1:block(br)%dim(1)+gc,1-gc:block(br)%dim(2)+gc,          1-gc:block(br)%dim(3)+gc))
    allocate(block(br)%face(3)%cell(1-gc:block(br)%dim(1)+gc,          1-gc:0,                        1-gc:block(br)%dim(3)+gc))
    allocate(block(br)%face(4)%cell(1-gc:block(br)%dim(1)+gc,          block(br)%dim(2)+1:block(br)%dim(2)+gc,1-gc:block(br)%dim(3)+gc))
    allocate(block(br)%face(5)%cell(1-gc:block(br)%dim(1)+gc,          1-gc:block(br)%dim(2)+gc,          1-gc:0))
    allocate(block(br)%face(6)%cell(1-gc:block(br)%dim(1)+gc,          1-gc:block(br)%dim(2)+gc,          block(br)%dim(3)+1:block(br)%dim(3)+gc))

    ! Face 1
    if (allocated(nodeinside)) deallocate(nodeinside)
    allocate(nodeinside(8,1-gc:0,1-gc:block(br)%dim(2)+gc,1-gc:block(br)%dim(3)+gc))
    nodeinside = .false.
    do kr = 1-gc, block(br)%dim(3)+gc; do jr = 1-gc, block(br)%dim(2)+gc; do ir = 1-gc, 0
      call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[1-gc,1-gc,1-gc])
      ni = ni+nint
    enddo; enddo; enddo

    ! Face 2
    if (allocated(nodeinside)) deallocate(nodeinside)
    allocate(nodeinside(8,block(br)%dim(1)+1:block(br)%dim(1)+gc,1-gc:block(br)%dim(2)+gc,1-gc:block(br)%dim(3)+gc))
    nodeinside = .false.
    do kr = 1-gc, block(br)%dim(3)+gc; do jr = 1-gc, block(br)%dim(2)+gc; do ir = block(br)%dim(1)+1,block(br)%dim(1)+gc
      call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[block(br)%dim(1)+1,1-gc,1-gc])
      ni = ni+nint
    enddo; enddo; enddo

    ! Face 3
    if (allocated(nodeinside)) deallocate(nodeinside)
    allocate(nodeinside(8,1-gc:block(br)%dim(1)+gc,1-gc:0,1-gc:block(br)%dim(3)+gc))
    nodeinside = .false.
    do kr = 1-gc, block(br)%dim(3)+gc; do jr = 1-gc, 0; do ir = 1-gc, block(br)%dim(1)+gc
      call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[1-gc,1-gc,1-gc])
      ni = ni+nint
    enddo; enddo; enddo

    ! Face 4
    if (allocated(nodeinside)) deallocate(nodeinside)
    allocate(nodeinside(8,1-gc:block(br)%dim(1)+gc,block(br)%dim(2)+1:block(br)%dim(2)+gc,1-gc:block(br)%dim(3)+gc))
    nodeinside = .false.
    do kr = 1-gc, block(br)%dim(3)+gc; do jr = block(br)%dim(2)+1, block(br)%dim(2)+gc; do ir = 1-gc, block(br)%dim(1)+gc
      call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[1-gc,block(br)%dim(2)+1,1-gc])
      ni = ni+nint
    enddo; enddo; enddo

    ! Face 5
    if (allocated(nodeinside)) deallocate(nodeinside)
    allocate(nodeinside(8,1-gc:block(br)%dim(1)+gc,1-gc:block(br)%dim(2)+gc,1-gc:0))
    nodeinside = .false.
    do kr = 1-gc, 0; do jr = 1-gc, block(br)%dim(2)+gc; do ir = 1-gc, block(br)%dim(1)+gc
      call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[1-gc,1-gc,1-gc])
      ni = ni+nint
    enddo; enddo; enddo

    ! Face 6
    if (allocated(nodeinside)) deallocate(nodeinside)
    allocate(nodeinside(8,1-gc:block(br)%dim(1)+gc,1-gc:block(br)%dim(2)+gc,block(br)%dim(3)+1:block(br)%dim(3)+gc))
    nodeinside = .false.
    do kr = block(br)%dim(3)+1,block(br)%dim(3)+gc; do jr = 1-gc, block(br)%dim(2)+gc; do ir = 1-gc, block(br)%dim(1)+gc
      call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[1-gc,1-gc,block(br)%dim(3)+1])
      ni = ni+nint
    enddo; enddo; enddo

  enddo

  close(unitfile1); close(unitfile2)

  call get_environment_variable('ATLASDIR',master_path)
  call IntersectionVolumes(trim(master_path)//'/src/lib/convexHull.py',ni,intersection)

  !% Check volume division for receivers
  do br = 1, size(block)
    ! Face 1
    do kr = 1, block(br)%dim(3); do jr = 1, block(br)%dim(2); do ir = 1-gc, 0
      call VolumeFractions(block,br,1,ir,jr,kr,ni,intersection)
    enddo; enddo; enddo
    ! Face 2
    do kr = 1, block(br)%dim(3); do jr = 1, block(br)%dim(2); do ir = block(br)%dim(1)+1,block(br)%dim(1)+gc
      call VolumeFractions(block,br,2,ir,jr,kr,ni,intersection)
    enddo; enddo; enddo
    ! Face 3
    do kr = 1, block(br)%dim(3); do jr = 1-gc, 0; do ir = 1, block(br)%dim(1)
      call VolumeFractions(block,br,3,ir,jr,kr,ni,intersection)
    enddo; enddo; enddo
    ! Face 4
    do kr = 1, block(br)%dim(3); do jr = block(br)%dim(2)+1, block(br)%dim(2)+gc; do ir = 1, block(br)%dim(1)
      call VolumeFractions(block,br,4,ir,jr,kr,ni,intersection)
    enddo; enddo; enddo
    ! Face 5
    do kr = 1-gc, 0; do jr = 1, block(br)%dim(2); do ir = 1, block(br)%dim(1)
      call VolumeFractions(block,br,5,ir,jr,kr,ni,intersection)
    enddo; enddo; enddo
    ! Face 6
    do kr = block(br)%dim(3)+1,block(br)%dim(3)+gc; do jr = 1, block(br)%dim(2); do ir = 1, block(br)%dim(1)
      call VolumeFractions(block,br,6,ir,jr,kr,ni,intersection)
    enddo; enddo; enddo
  enddo

end subroutine chimera_wrapper



subroutine mn2ijk(af,am,an,im,jm,km,Ai,Aj,Ak)
  implicit none
  integer, intent(in) :: af, am, an, im, jm, km
  integer, intent(out) :: Ai, Aj, Ak

  select case (af)
  case(1)
    Ai = 1; Aj = am; Ak = an
  case(2)
    Ai = im; Aj = am; Ak = an
  case(3)
    Ai = am; Aj = 1; Ak = an
  case(4)
    Ai = am; Aj = jm; Ak = an
  case(5)
    Ai = am; Aj = an; Ak = 1
  case(6)
    Ai = am; Aj = an; Ak = km
  end select

end subroutine mn2ijk

!    subroutine di inversione di matrice
!    a     : matrice r*r da invertire  reale
!    b     : matrice r*r invertita
!    r     : dimensione (max 20)      intero
subroutine invmat(a,b,r)
  implicit none
  integer :: r,j,i,k,l
  real(8) :: a(3,3),b(3,3),c(3,3)
  real(8) :: s, t
  
      do 2 i=1,r
        do 3 j=1,r
          b(i,j)=0.d+00
          c(i,j)=a(i,j)
3       continue
2     continue
      do 1 i=1,r
        b(i,i)=1.d+00
1     continue
      do 10 j=1,r
        do 20 i=j,r
          if(a(i,j).ne.0.) goto 210
20      continue
        do 21 i=1,r
          if(a(j,i).ne.0.) goto 211
21      continue
        goto 10
211     write(*,*)'matrice singolare'
        return
210     do 30 k=1,r
         s=a(j,k)
         a(j,k)=a(i,k)
         a(i,k)=s
         s=b(j,k)
         b(j,k)=b(i,k)
         b(i,k)=s
30      continue
        t=1/a(j,j)
        do 40 k=1,r
          a(j,k)=t*a(j,k)
          b(j,k)=t*b(j,k)
40      continue
        do 50 l=1,r
          if(l.eq.j) goto 50
          t=-a(l,j)
          do 60 k=1,r
            a(l,k)=a(l,k)+t*a(j,k)
            b(l,k)=b(l,k)+t*b(j,k)
60        continue
50      continue
10    continue
      do 110 i=1,r
        do 120 j=1,r
          a(i,j)=c(i,j)
120     continue
110   continue
      end


end module lib_bc
