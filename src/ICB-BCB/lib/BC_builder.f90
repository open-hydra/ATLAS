module build_BC_mod
  use finer, only: file_ini
  use species, only: obj_species
  use phase_module, only: phase_type
  use ATLAS_high_level
  use lib_bc
  implicit none
  private
  public:: build_BC

  type :: bc_file_type
    character(len=256)   :: name
    character(len=5)     :: var
    integer              :: length, width
    real(8), allocatable :: dirArray1(:), dirArray2(:), array(:,:)
  end type bc_file_type

  contains

  subroutine build_BC(phase,sini,blocks)
    use TOM, only: delthe
    use variables, only: nrans
    use strings, only: parse
    use ATLAS_IO, only: read_idealgas_properties, read_cdp_properties
    implicit none
    type(phase_type), intent(in)     :: phase(:)
    type(ATLAS_block), intent(inout) :: blocks(:)
    type(file_ini), intent(in)       :: sini
    !> Local variables
    integer                        :: n_blocks_phase(size(phase))
    logical                        :: cell_dependent, multipatch=.false.
    type(file_ini)                 :: faceini, patchini
    integer                        :: error, error_patch=0
    character(len=:), allocatable  :: option_pairs(:)
    character(len=4)               :: ind, indb, dirID
    character(len=2)               :: patchdirection
    character(len=50)              :: patchname, section_name
    integer                        :: ff, n, m, p, b
    real(8)                        :: patchrange(4)
    character(len=30)              :: wholestring, args(3), phase_name

    n_blocks_phase = 0

    do b = 1, size(blocks)
      write(indb,'(I4)') b
      section_name = 'BCB-Block'//adjustl(indb)   
      associate(block => blocks(b))

      do while (sini%loop(section_name=section_name, option_pairs=option_pairs))
        call faceini%add(section_name=section_name, option_name=option_pairs(1), val=option_pairs(2))
      enddo

      ! Look for phases solved in block b
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

      ! Loop through each phase and check if the associated phase name of the current block matches the phase name.
      ! If a match is found, increment the count of blocks for that phase and assign the block ID accordingly.
      do p = 1, size(phase)
        do m = 1, size(block%associated_phase)
          if (block%associated_phase(m)%name==phase(p)%name) then
            n_blocks_phase(p) = n_blocks_phase(p)+1
            block%id = n_blocks_phase(p)
          endif
        enddo
      enddo

      ! Read phase properties (if any)
      do p = 1, size(block%associated_phase)
        if (block%associated_phase(p)%name=='') then
          phase_name = ''
        else
          phase_name = trim(block%associated_phase(p)%name)//'-'
        endif
        if (block%associated_phase(p)%type=='IG') then
          call read_idealgas_properties(trim(phase_name),block%associated_phase(p)%species)
        endif
        if (block%associated_phase(p)%type=='CD') then
          call read_cdp_properties(trim(phase_name),block%associated_phase(p)%material)
        endif
        if (.not.allocated(block%associated_phase(p)%species%massf)) &
        allocate(block%associated_phase(p)%species%massf(1:block%associated_phase(p)%species%n))
        block%associated_phase(p)%species%massf = 1d-20
        if (.not.allocated(block%associated_phase(p)%material%npcp)) block%associated_phase(p)%material%n = 0
      enddo
    
      ! Look for faces bc definition
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

        ! Face-related INI source
        multipatch = .false.
        call faceini%free
        call faceini%add(section_name='face')
        do while (sini%loop(section_name=trim(block%face(ff)%bc%name), option_pairs=option_pairs))
          call faceini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
          if (index(option_pairs(1),'patch')>0) multipatch=.true.
        enddo
        if (error/=0 .and. .not.multipatch) error stop ( 'Missing type entry' )

        ! BC building depending on specific case
        if (multipatch) then
          
          ! Multipatch BCs
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
          ! Single patch with/without varying properties BCs
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
    type(bc_file_type)             :: bc_file(12)
    real(8), parameter             :: pi=4.0*atan(1.0)
    integer                        :: error, ios, iosold, cnt_bc=0, n_files
    integer                        :: i, j, m, n, f_, mi, me, ni, ne
    character(len=256)             :: line
    character(len=3)               :: dirID
    integer                        :: dirSize=0, type_, unit
    integer, allocatable           :: dir(:)
    real(8), allocatable           :: here(:), try(:)
    real(8)                        :: var=0.0, a1, a2, b1, b2, c11, c12, c21, c22, range(4)
    logical                        :: found(8)
    character(len=:), allocatable  :: option_pairs(:)
    character(len=256)             :: infile_dummy
    logical                        :: file_present=.false., tecfile_present=.false., index_based=.false.

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

    ! Check range for mulipatch
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

    ! Check file presence
    n_files=0
    file_present=.false.; tecfile_present=.false.
    call ini_o%get(section_name='cell', option_name='hs-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'hs'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='q-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'q'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='T-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'T'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='Taw-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'Taw'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='hg-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'hg'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='phi-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'phi'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='SF-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'SF'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='qrad-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'qrad'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='alpha-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'alpha'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='beta-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'beta'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='g-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'g'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='krho-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'krho'; bc_file(n_files)%name = infile_dummy
    endif

    ! Check if the file is in free-format or Tecplot-format
    if (n_files>0) then
      if (index(bc_file(1)%name,'.tec')>0) then
        tecfile_present = .true.
        if(allocated(here)) deallocate(here)
        allocate(here(2))
      else
        file_present = .true.
      endif
    endif

    if (.not.tecfile_present .and. .not.index_based) then

      ! Importing data from files and/or apply multipatch
      select case (dirSize)
      ! One dimensional variation
      case(1)
        if (file_present) then
          do f_ = 1, n_files
            associate( length=> bc_file(f_)%length )
            length=0; ios=0
            open(newunit=unit,file=bc_file(f_)%name,status='old',action='read')
            do while (ios==0)
              read(unit,*,iostat=ios)
              length = length+1
            enddo
            length = length-1
            rewind(unit)
            allocate(bc_file(f_)%dirArray1(1:length))
            allocate(bc_file(f_)%array(1:length,1))
            do i = 1, length
              read(unit,*) bc_file(f_)%dirArray1(i), bc_file(f_)%array(i,1)
            enddo
            close(unit)
            if (dir(1)==5) bc_file(f_)%dirArray1 = bc_file(f_)%dirArray1*pi/180
            endassociate
          enddo
        endif
        do n = 1, face%Nn; do m = 1, face%Nm
            here(1) = face%center(m,n)%c(dir(1))
            if (file_present) then
              ! Interpolazione lineare
              do f_ = 1, n_files
                if (here(1)>bc_file(f_)%dirArray1(1) .and. here(1)<=bc_file(f_)%dirArray1(bc_file(f_)%length)) then
                  do i = 2, bc_file(f_)%length
                    if (here(1)>bc_file(f_)%dirArray1(i-1) .and. here(1)<=bc_file(f_)%dirArray1(i)) then
                      var = (bc_file(f_)%array(i,1)-bc_file(f_)%array(i-1,1))/(bc_file(f_)%dirArray1(i)-bc_file(f_)%dirArray1(i-1))*(here(1)-bc_file(f_)%dirArray1(i-1))+bc_file(f_)%array(i-1,1)
                      call ini_o%add(section_name='cell', option_name=trim(bc_file(f_)%var), val=var)
                      exit
                    endif
                  enddo
                endif
              enddo
            endif
            ! Multipatch
            if (here(1)>range(1) .and. here(1)<=range(2)) then
              cnt_bc = cnt_bc+1
              face%center(m,n)%bc%definition = type_
              call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            endif
        enddo; enddo
      ! Two dimensional variaton
      case(2)
        if (file_present) then
          do f_ = 1, n_files
            associate( length=> bc_file(f_)%length, width=> bc_file(f_)%width )
            length=0; width=10000; ios=0
            open(newunit=unit,file=bc_file(f_)%name,status='old',action='read')
            do while (ios==0)
              read(unit,*,iostat=ios)
              length = length+1
            enddo
            length = length-2
            do while(ios/=0)
              rewind(unit)
              allocate(try(1:width))
              read(unit,*,iostat=ios) try(1:width)
              deallocate(try)
              width = width-1
            enddo
            width = (width+2)/(length+1)-1
            rewind(unit)
            allocate(bc_file(f_)%dirArray1(1:length))
            allocate(bc_file(f_)%dirArray2(1:width))
            allocate(bc_file(f_)%array(1:length,1:width))
            read(unit,*) (bc_file(f_)%dirArray2(j),j=1,width)
            do i = 1, length
              read(unit,*) bc_file(f_)%dirArray1(i), (bc_file(f_)%array(i,j),j=1,width)
            enddo
            close(unit)
            if (dir(1)==5) bc_file(f_)%dirArray1(:) = bc_file(f_)%dirArray1(:)*pi/180
            if (dir(2)==5) bc_file(f_)%dirArray2(:) = bc_file(f_)%dirArray2(:)*pi/180
            endassociate
          enddo
        endif
        do n = 1, face%Nn; do m = 1, face%Nm
            here(1) = face%center(m,n)%c(dir(1))
            here(2) = face%center(m,n)%c(dir(2))
            if (file_present) then
              ! Doppia interpolazione lineare
              do f_ = 1, n_files
                do i = 2, bc_file(f_)%length
                  if (here(1)>=bc_file(f_)%dirArray1(i-1) .and. here(1)<=bc_file(f_)%dirArray1(i)) then
                    do j = 2, bc_file(f_)%width
                      if (here(2)>bc_file(f_)%dirArray2(j-1) .and. here(2)<=bc_file(f_)%dirArray2(j)) then
                        a1 = bc_file(f_)%dirArray1(i-1); a2 = bc_file(f_)%dirArray1(i)
                        b1 = bc_file(f_)%dirArray2(j-1); b2 = bc_file(f_)%dirArray2(j)
                        c11 = bc_file(f_)%array(i-1,j-1); c12 = bc_file(f_)%array(i,j-1)
                        c21 = bc_file(f_)%array( i ,j-1); c22 = bc_file(f_)%array(i, j )
                        var = ((b2-here(2))/(b2-b1)*c11+(here(2)-b1)/(b2-b1)*c12)*(a2-here(1))/(a2-a1)
                        var = var+((b2-here(2))/(b2-b1)*c21+(here(2)-b1)/(b2-b1)*c22)*(here(1)-a1)/(a2-a1)
                        call ini_o%add(section_name='cell', option_name=trim(bc_file(f_)%var), val=var)
                        exit
                      endif
                    enddo
                  endif
                enddo
              enddo
            endif
            ! Multipatch
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
      ! Importing data from files in Tecplot format

      open(unit=1, file=trim(bc_file(1)%name), status='old', action='read', iostat=ios)
      if (ios /= 0) error stop ("Error opening the file.")

      f_ = 0; iosold = 0
      ! Skip lines upto the desired face and block
      do while(ios /= -1 .and. f_ < 4*(b-1)+f)
        read(1, '(A)', iostat=ios) line
        if (ios == -1) write(*,*) "EOF", bc_file(1)%name
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
      ! Skip geometrical coordinates
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
              call ini_o%add(section_name='cell', option_name=trim(bc_file(1)%var), val=var)
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

end module build_BC_mod
