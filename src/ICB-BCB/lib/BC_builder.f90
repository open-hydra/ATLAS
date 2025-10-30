module build_BC_mod
  use ir_precision
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

  type, abstract :: plate_file_type
    character(len=256)   :: name
    integer              :: length
    integer, allocatable :: id(:) 
  end type plate_file_type

  type, extends(plate_file_type) :: real_plate_type
    real(8), allocatable :: center(:,:)
    real(8), allocatable :: radius(:)
  end type real_plate_type

  type, extends(plate_file_type) :: KAFFS_plate_type  
    character(len=256)   :: Plateshape
    integer, allocatable :: inj_row(:) 
    real(8), allocatable :: phase_row(:)
  end type 

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
    character(len=4)               :: ind, dirID
    character(len=7)               :: patchdirection
    character(len=50)              :: patchname, section_name
    integer                        :: ff, n, m, p, b
    real(8)                        :: patchrange(4), Atot(6)
    character(len=30)              :: wholestring, args(3), phase_name, nametemp

    n_blocks_phase = 0
    b = size(blocks)
    !Calcolo l'area intera di ogni faccia (considerando tutti i blocchi)
    do  b = 1, size(blocks)
      do ff = 1, size(blocks(b)%face(:))
        do n = 1, blocks(b)%face(ff)%Nn
            do m = 1, blocks(b)%face(ff)%Nm
                Atot(ff) = Atot(ff) + blocks(b)%face(ff)%center(m,n)%area
            enddo
        enddo
      enddo
    enddo


    do b = 1, size(blocks)
      section_name = 'BCB-Block'//trim(str(.true.,b))   
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
      do ff = 1, block%nfaces

        call sini%get(section_name=section_name, option_name='face'//trim(str(.true.,ff)), &
                                                              val=block%face(ff)%bc%name, error=error)

        if (error/=0) then
          if (ff<=2) then
            write(*,*)'[ERROR] Missing face entry for face ', ff, ' in block ', b
            stop
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
        if (error/=0 .and. .not.multipatch) then
          write(*,*)'[ERROR] Missing type entry for face ', ff, ' in block ', b
          stop
        endif

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
                call build_cell(b,ff,block%face(ff),nrans,patchini,block%associated_phase(m),Atot)
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
              call build_cell(b,ff,block%face(ff),nrans,faceini,block%associated_phase(m),Atot)
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
                block%face(ff)%center(m,n)%bc%IG_time_properties = block%face(ff)%bc%IG_time_properties
                block%face(ff)%center(m,n)%bc%IG_time_BC = block%face(ff)%bc%IG_time_BC
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


  subroutine build_cell(b,f,face,nrans,ini_i,phase,Atot)
    implicit none
    integer, intent(in)            :: b, f
    type(obj_face)                 :: face
    type(file_ini), intent(in)     :: ini_i
    type(file_ini)                 :: ini_o
    type(phase_type), intent(in)   :: phase
    integer, intent(in)            :: nrans
    type(bc_file_type)             :: bc_file(12)
    logical                        :: full_plate ! if true, KAFFS-like plate
    class(plate_file_type), allocatable :: plate_file
    real(8), parameter             :: pi=4.0*atan(1.0)
    integer                        :: error, ios, iosold, cnt_bc=0, n_files, n_files_plate
    integer                        :: i, j, m, n, f_, mi, me, ni, ne, ninj
    character(len=256)             :: line
    character(len=7)               :: dirID
    integer                        :: dirSize=0, type_, unit, default_type
    integer, allocatable           :: dir(:)
    real(8), allocatable           :: here(:), try(:)
    real(8)                        :: var=0.0, a1, a2, b1, b2, c11, c12, c21, c22, range(4)
    real(8)                        :: radial_distance, z_input
    real(8), allocatable           :: A_inj(:)
    logical                        :: found(8)
    character(len=:), allocatable  :: option_pairs(:)
    character(len=256)             :: infile_dummy
    logical                        :: file_present=.false., tecfile_present=.false., index_based=.false., injection_plate=.false.
    real(8), intent(in)            :: Atot(6)
    real(8)                        :: Aplate, A_per_inj, Ak, phamin, phamax, pha, Asquare, rinj,anginj, angmin, angmax
    REAL(8), allocatable           :: Rmin(:),Rmax(:),Dpha(:),Inj_phi_R(:,:)
    integer                        :: injid, mj, spare,ncheck,ncount, mm, nn
    character(3)                   :: Side

    call ini_o%free
    call ini_o%add(section_name='cell')

    call ini_i%get(section_name='face', option_name='direction', val=dirID, error=error)
    if (error==0) then
      found = .false.
      dirSize = len_trim(dirID)
      ! Se leggo xplate o yplate (dirSize == 6), dirSize lo metto uguale a 1
      ! Se leggo xyplate (dirSize == 7), dirSize lo metto uguale a 2
      if (dirSize == 6) dirSize = 1
      if (dirSize == 7) dirSize = 2
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

    ! Controllo plate
    if (index(dirID,'plate')/=0) then
      injection_plate=.true.
    endif

    ! Check range for multipatch
    call ini_i%get(section_name='face',option_name='range',val=range, error=error)
    if (error==0) then
      do i = dirSize*2+1, 4 ; range(i) = (-1.0)**i*huge(range(i)) ; enddo
    else
      do i = 1, 4 ; range(i) = (-1.0)**i*huge(range(i)) ; enddo
    endif

    ! Convert theta range (if present) from degrees to rad
    if (dir(1)==5) range(1:2) = range(1:2)*pi/180
    if (dirSize>1) then
      if (dir(2)==5) range(3:4) = range(3:4)*pi/180
    endif

    call ini_i%get(section_name='face', option_name='type', val=type_, error=error)
    do while (ini_i%loop(section_name='face', option_pairs=option_pairs))
      call ini_o%add(section_name='cell', option_name=option_pairs(1), val=option_pairs(2))
    enddo

    ! Check file presence
    n_files=0
    file_present=.false.; tecfile_present=.false.
    call ini_o%get(section_name='cell', option_name='ks-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'ks'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='q-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'q'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='T-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'T'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='Tref-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'Tref'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='hconv-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'hconv'; bc_file(n_files)%name = infile_dummy
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
    call ini_o%get(section_name='cell', option_name='a-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'a'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='n-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'n'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='pRef-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'pRef'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='rhoGrain-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'rhoGrain'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='Taf-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'Taf'; bc_file(n_files)%name = infile_dummy
    endif
    call ini_o%get(section_name='cell', option_name='SFgeo-file', val=infile_dummy, error=error)
    if (error==0) then
      n_files = n_files+1; bc_file(n_files)%var = 'SFgeo'; bc_file(n_files)%name = infile_dummy
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

    ! File for injection plate
    n_files_plate = 0
    call ini_o%get(section_name='cell', option_name='plate-file', val=infile_dummy, error=error)
   
    if (error==0) then
      n_files_plate = n_files_plate + 1
    endif
    if (n_files_plate > 0) then
      call ini_o%get(section_name='cell', option_name='full-plate', val=full_plate, error=error)
      
      if (error/=0) then
        write(*,*) 'Default plate topology is center/radius'
        full_plate = .false.
      endif
      if (full_plate) then
        allocate(KAFFS_plate_type :: plate_file)
        plate_file%name = infile_dummy
      else
        allocate(real_plate_type :: plate_file)
      
        plate_file%name = infile_dummy
        call ini_o%get(section_name='cell', option_name='plate-type', val=default_type, error=error)
        if (error/=0) then
          write(*,*) 'No plate type specified, default plate type is simmetry'
          default_type = 3
        endif
        call ini_o%get(section_name='cell', option_name='z-hydra', val=z_input, error=error)
        if (error/=0) then
          write(*,*) 'No z_input given, you cannot do Q2D/MOSKA connection'
        endif
    
      endif
    endif
    ! Check if the file is in free-format or Tecplot-format
    if (n_files_plate==0 .and. injection_plate) then
      write(*,*) '[ERROR], injection plate patch without plate file'
      stop
    elseif (n_files_plate>0 .and. injection_plate) then
      ! Injection plate file
        associate( length=> plate_file%length )
        length=0; ios = 0
        open(newunit=unit,file=plate_file%name,status='old',action='read')
        select type (plate_file)
        type is (real_plate_type)
          do while (ios==0)
            read(unit,*,iostat=ios)
            length = length+1
          enddo
          length = length-1
          rewind(unit)
          allocate(plate_file%id(1:length))
          allocate(A_inj(1:length)); A_inj = 0.d0
          allocate(plate_file%center(1:length, 1:2))
          allocate(plate_file%radius(1:length))
          do i = 1, length
            read(unit,*) plate_file%id(i), plate_file%center(i,1), plate_file%center(i,2), plate_file%radius(i)
          enddo
        type is (KAFFS_plate_type)
          do while (ios==0)
            read(unit,*,iostat=ios)
            length = length+1 ! number of rows
          enddo
          length = length - 2
          rewind(unit)
          allocate(plate_file%inj_row(1:length))
          allocate(plate_file%phase_row(1:length))
          read(unit,*) plate_file%Plateshape !Either "Round" or "Square"
          do i = 1, length
            read(unit,*) plate_file%inj_row(i), plate_file%phase_row(i)
          enddo
        end select
        close(unit)
        endassociate
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
            if (here(1)>range(1) .and. here(1)<=range(2) .and. .not.injection_plate) then
              cnt_bc = cnt_bc+1
              face%center(m,n)%bc%definition = type_
              call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            endif
            if (injection_plate) then
              select type (plate_file)
              type is (real_plate_type)                
                face%center(m,n)%bc%definition = default_type
                ! Loop sul numero di iniettori che legge, prima iterazione dando numero di iniettori e loro raggio
                do ninj = 1, plate_file%length
                  radial_distance = sqrt((here(1)-plate_file%center(ninj,dir(1)))**2)
                  if (radial_distance <= plate_file%radius(ninj)) then
                    cnt_bc = cnt_bc + 1
                    face%center(m,n)%bc%definition = type_
                    ! Qua metti un if type_ == connessione MOSKA/Q2D
                    call ini_o%add(section_name='cell', option_name='id_inj', val=plate_file%id(ninj))
                    ! Costruisci la lunghezza dell'interfaccia nella direzione della connessione con Q2D
                    ! A_inj(ninj) = A_inj(nìnj) + Areacalcolata
                    A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area * z_input
                  endif
                call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
                enddo
              type is (KAFFS_plate_type)
              ! PER ALEX, algoritmo per casi tipo TIC
               ninj = sum(plate_file%inj_row(:))
               allocate(A_inj(1:ninj)); A_inj = 0.d0
               allocate(Inj_phi_R(4,ninj))
                if (abs(face%center(1,face%Nn)%c(dir(1))-face%center(1,1)%c(dir(1)))>abs(face%center(face%Nm,1)%c(dir(1))-face%center(1,1)%c(dir(1)))) then
                    spare = (real(face%Nn)/real(ninj) - floor(real(face%Nn)/real(ninj)))*ninj
                    ncount = 1
                    ncheck = 0
                    Side = 'n'
                    do nn = 1,face%Nn
                        do mm = 1,face%Nm
                          Asquare = Asquare + face%center(mm,nn)%area
                          
                        enddo
                        if (nn<(floor(real(face%Nn)/real(ninj))*(injid)+ncheck)) then
                          if (nn==1) then
                          Inj_phi_R(1,injid) = 1 
                          endif
                          Inj_phi_R(2,injid) = nn
                        else
                          
                          if (ncount==2.and.ncheck<spare) then
                            Inj_phi_R(2,injid) = nn
                            ncount = 0
                            ncheck = ncheck + 1
                          else
                            Inj_phi_R(2,injid) = nn
                            Asquare = 0.0
                            ncount = ncount + 1
                            injid = injid + 1
                            Inj_phi_R(1,injid) = nn+1
                          endif
                        endif
                    enddo
                
                else
                    Side = 'm'
                    spare = (real(face%Nm)/real(ninj) - floor(real(face%Nm)/real(ninj)))*ninj
                    ncount = 0
                    ncheck = 0
                    do mm = 1,face%Nm
                        do nn = 1,face%Nn
                          
                        Asquare = Asquare + face%center(mm,nn)%area
    
                        enddo
                        if (mm<(floor(real(face%Nm)/real(ninj))*(injid)+ncheck)) then
                          if (mm==1) then
                          Inj_phi_R(1,injid) = 1 
                          endif
                          Inj_phi_R(2,injid) = mm
                    
                        else

                          
                          if (ncount==2.and.ncheck<spare) then
                            Inj_phi_R(2,injid) = mm
                            ncount = 0
                            ncheck = ncheck + 1
                          else
                            Inj_phi_R(2,injid) = mm
                            Asquare = 0.0
                            ncount = ncount + 1
                            injid = injid + 1
                            Inj_phi_R(1,injid) = mm+1
                          endif
                        endif
                    enddo
                
                endif
                  do ninj = 1,size(Inj_phi_R(1,:))
                    if (Side=='n') then

                        if (Inj_phi_R(1,ninj)<=n .and. Inj_phi_R(2,ninj)>=n) then
                              cnt_bc = cnt_bc + 1
                              face%center(m,n)%bc%definition = type_
                              A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area * z_input  
                              call ini_o%add(section_name='cell', option_name='id_inj', val= ninj) 
                        endif

                    elseif (Side=='m') then
                      
                        if (Inj_phi_R(1,ninj)<=m .and. Inj_phi_R(2,ninj)>=m)  then
                          cnt_bc = cnt_bc + 1
                          
                          face%center(m,n)%bc%definition = type_
                          A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area * z_input
                          call ini_o%add(section_name='cell', option_name='id_inj', val= ninj) 
                        endif
                    
                    endif

                  enddo
                    call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)


              end select
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

        !Costruisco i settori di plate associati ad ogni iniettore sia Cilindrico "Round" che Rettangolare "Squared"
        if (injection_plate) then
          select type (plate_file)
            type is (KAFFS_plate_type) 
              if (plate_file%Plateshape=='Round'.or.plate_file%Plateshape=='round') then
                !Motore Cilindrico 3D
                injid = 0
                Aplate = Atot(f)
                ninj = sum(plate_file%inj_row(:))
                A_per_inj = Aplate/ninj
                allocate(Rmin(plate_file%length),Rmax(plate_file%length),Dpha(plate_file%length))
                allocate(Inj_phi_R(4,ninj))
                allocate(A_inj(1:ninj)); A_inj = 0.d0
                do m = 1,plate_file%length
                  Ak = plate_file%inj_row(m) * A_per_inj

                  if (m==1) then
                    Rmin(m) = 0
                    Rmax(m) = sqrt(Ak/pi)
                  elseif (m==plate_file%length) then
                    Rmax(m) = sqrt(Aplate/pi)
                    Rmin(m) = sqrt(Rmax(m)**2 - Ak/pi)
                  else
                    Rmin(m) = Rmax(m-1)
                    Rmax(m) = sqrt(Rmin(m)**2 + Ak/pi)
                  endif
                
                  Dpha(m) = 2*pi/(plate_file%inj_row(m))

                  do mj = 1,plate_file%inj_row(m)
                    injid = injid + 1 
                    if (plate_file%inj_row(m)==1) then 
                      phamin = 0.0
                      phamax = 2*pi
                    else
                      pha = plate_file%phase_row(m) + (mj-1)*Dpha(m)
                      phamin = pha - Dpha(m)*0.5
                      phamax = pha + Dpha(m)*0.5
                        if (phamin<0) then
                            phamin = phamin + 2*pi
                        endif
                        if (phamin>2*pi) then
                            phamin = phamin - 2*pi
                        endif
                        if (phamax<0) then
                            phamin = phamin + 2*pi
                        endif
                        if (phamax>2*pi) then
                            phamin = phamin - 2*pi
                        endif
                    endif
                      !Rmax
                      Inj_phi_R(1, injid) = Rmax(m)
                      !Rmin
                      Inj_phi_R(2, injid) = Rmin(m)
                      !Phimax
                      Inj_phi_R(3, injid) = phamax
                      !Phimin
                      Inj_phi_R(4, injid) = phamin
                      
                  enddo
                enddo
              elseif (plate_file%Plateshape=='Square'.or.plate_file%Plateshape=='square') then
                !Motore Rettangolare 3D
                Aplate = 0.0
                injid = 0
                !Calcolo l'area di tutta la plate
                do n = 1, face%Nn; do m = 1, face%Nm
                  Aplate = Aplate + face%center(m,n)%area
                enddo;enddo
                ninj = sum(plate_file%inj_row(:))
                allocate(A_inj(1:ninj)); A_inj = 0.d0
                allocate(Inj_phi_R(4,ninj))
                A_per_inj = Aplate/ninj
                injid = 1
                
                !Cerco il lato più grande della camera
                if (abs(face%center(1,face%Nn)%c(dir(2))-face%center(1,1)%c(dir(2)))>abs(face%center(face%Nm,1)%c(dir(1))-face%center(1,1)%c(dir(1)))) then
                 !Nn È il lato più lungo
                 Side = 'n'
                  spare = (real(face%Nn)/real(ninj) - floor(real(face%Nn)/real(ninj)))*ninj
                  ncount = 1
                  ncheck = 0
                  do n = 1,face%Nn
                      do m = 1,face%Nm
                        Asquare = Asquare + face%center(m,n)%area
                        
                      enddo
                      if (n<(floor(real(face%Nn)/real(ninj))*(injid)+ncheck)) then
                        if (n==1) then
                        Inj_phi_R(1,injid) = 1 
                        endif
                        Inj_phi_R(2,injid) = n
                      else
                         
                        if (ncount==2.and.ncheck<spare) then
                          Inj_phi_R(2,injid) = n
                          ncount = 0
                          ncheck = ncheck + 1
                        else
                          Inj_phi_R(2,injid) = n
                          Asquare = 0.0
                          ncount = ncount + 1
                          injid = injid + 1
                          Inj_phi_R(1,injid) = n+1
                        endif
                      endif
                  enddo
                      Inj_phi_R(1,ninj) = face%Nn
                else
                  !Nm È il lato più lungo
                  Side = 'm'
                  spare = (real(face%Nm)/real(ninj) - floor(real(face%Nm)/real(ninj)))*ninj
                  ncount = 0
                  ncheck = 0
                  do m = 1,face%Nm
                      do n = 1,face%Nn
                        Asquare = Asquare + face%center(m,n)%area
  
                      enddo
                      if (m<(floor(real(face%Nm)/real(ninj))*(injid)+ncheck)) then
                        if (m==1) then
                        Inj_phi_R(1,injid) = 1 
                        endif
                        Inj_phi_R(2,injid) = m
                   
                      else

                        
                        if (ncount==2.and.ncheck<spare) then
                          Inj_phi_R(2,injid) = m
                          ncount = 0
                          ncheck = ncheck + 1
                        else
                          Inj_phi_R(2,injid) = m
                          Asquare = 0.0
                          ncount = ncount + 1
                          injid = injid + 1
                          Inj_phi_R(1,injid) = m+1
                        endif
                      endif
                  enddo
                  Inj_phi_R(2,ninj) = face%Nm
                 
                endif
                
              endif

          end select
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
            if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
                here(2)>=range(3) .and. here(2)<=range(4) .and. .not.injection_plate) then
              cnt_bc = cnt_bc+1
              face%center(m,n)%bc%definition = type_
              call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            endif
            if (injection_plate) then
              select type (plate_file)
                type is (real_plate_type)                
                  face%center(m,n)%bc%definition = default_type
                  ! Loop sul numero di iniettori che legge, prima iterazione dando numero di iniettori e loro raggio
                  do ninj = 1, plate_file%length
                   
                    radial_distance = sqrt((here(1)-plate_file%center(ninj,1))**2+(here(2)-plate_file%center(ninj,2))**2)

                    if (radial_distance <= plate_file%radius(ninj)) then
                      cnt_bc = cnt_bc + 1
                      face%center(m,n)%bc%definition = type_
                      call ini_o%add(section_name='cell', option_name='id_inj', val=plate_file%id(ninj))   
                      ! Costruisci l'area dell'interfaccia e sommala per ogni ninj
                      ! A_inj(ninj) = A_inj(nìnj) + Areacalcolata           
                      A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area    
                    endif
                  call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
                  enddo
                type is (KAFFS_plate_type)          
                  ! PER ALEX, METTI implementazione per casi full 3D
                  ! Eccolo!
                  !Round plate
                  if (plate_file%Plateshape=='Round'.or.plate_file%Plateshape=='round') then
                    do ninj = 1,size(Inj_phi_R(1,:))
                      !Distance from the center of the plate
                      rinj = sqrt(here(1)**2 + here(2)**2)
                      ! Associated angle
                      anginj = atan2(here(2),here(1))

                      if (anginj<0) anginj = anginj + 2*pi
                    
                      angmin = Inj_phi_R(4,ninj);
                      angmax = Inj_phi_R(3,ninj);
                      if (angmin>angmax) then
                        angmin = angmin-2*pi
                        if (anginj>pi) then
                          anginj = anginj - 2*pi
                        endif
                      endif
                      !Check if    Rmin(inj)  <r-cell< Rmax(inj)  .and. Anglemin(inj)  < angle-cell < Anglemax(inj) 
                      if ((Inj_phi_R(2,ninj) <= rinj) .and. (Inj_phi_R(1,ninj) >= rinj) .and. (angmin <= anginj) .and. (angmax >= anginj)) then
                            cnt_bc = cnt_bc + 1
                            face%center(m,n)%bc%definition = type_
                            A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area  
                            call ini_o%add(section_name='cell', option_name='id_inj', val= ninj) 
                            exit
                      else
                        if (ninj==size(Inj_phi_R(1,:))) then
                          stop 'Plate is not fully covered, cell is missing an injector'
                        endif
                      endif
                      

                    enddo
                    call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
                    
                  elseif (plate_file%Plateshape=='Square'.or.plate_file%Plateshape=='square') then
                    !Squared plate
                    ! Injectors are supposed lined-up on the longest side/direction of the rectangular engine
                    ! Each injector has two index along such direction. We just have to check if n-min(inj) <n< n-max(inj) or m-min(inj) <m< m-max(inj)
                    do ninj = 1,size(Inj_phi_R(1,:))
                      if (Side=='n') then

                        if (Inj_phi_R(1,ninj)<=n .and. Inj_phi_R(2,ninj)>=n) then
                              cnt_bc = cnt_bc + 1
                              face%center(m,n)%bc%definition = type_
                              A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area  
                              call ini_o%add(section_name='cell', option_name='id_inj', val= ninj) 
                        endif

                    elseif (Side=='m') then
                      
                        if (Inj_phi_R(1,ninj)<=m .and. Inj_phi_R(2,ninj)>=m)  then
                          cnt_bc = cnt_bc + 1
                          
                          face%center(m,n)%bc%definition = type_
                          A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area  
                          call ini_o%add(section_name='cell', option_name='id_inj', val= ninj) 
                        endif
                    
                    endif

                    
                    enddo
                    call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)

                  endif

              end select 
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
