module build_BC_mod
  use ir_precision
  use finer, only: file_ini
  use species, only: obj_species
  use phase_module, only: phase_type
  use ATLAS_high_level
  use lib_bc
  use BC_build_plate
  implicit none
  private
  public:: build_BC

  real(8), allocatable :: Atot(:)

  type :: bc_file_type
    character(len=256)   :: name
    character(len=5)     :: var
    integer              :: length, width
    real(8), allocatable :: dirArray1(:), dirArray2(:), array(:,:)
  end type bc_file_type

  contains

  subroutine build_BC(phase,sini,blocks)
    use TOM, only: delthe, meshType
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
    real(8)                        :: patchrange(4)
    character(len=30)              :: wholestring, args(3), phase_name, nametemp

    n_blocks_phase = 0
    !Calcolo l'area intera di ogni faccia (considerando tutti i blocchi)
    allocate(Atot(blocks(1)%nfaces))
    Atot = 0.0
    do  b = 1, size(blocks)
      do ff = 1, size(blocks(b)%face(:))
        do n = 1, blocks(b)%face(ff)%Nn
            do m = 1, blocks(b)%face(ff)%Nm
                Atot(ff) = Atot(ff) + blocks(b)%face(ff)%center(m,n)%area
            enddo
        enddo
      enddo
    enddo

    ! Loop over each block
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

      ! Loop over each phase and check if the associated phase name of the current block matches the phase name.
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
        if (meshtype==1.and.error/=0) then
        ! Multiple 1D domains default to the the first one unless specified otherwise.
        call sini%get(section_name='BCB-Block1', option_name='face'//trim(str(.true.,ff)), &
                                                              val=block%face(ff)%bc%name, error=error)
        write(*,*) 'Missing entry for 1D domain, defaulting to BCB-Block1'
        endif

        if (error/=0) then
          if (ff<=2 .and. meshtype/=1) then
            write(*,*)'[ERROR] Missing face entry for face ', ff, ' in block ', b
            stop
          else
            if (delthe==0.d0 .or. meshType == 1) then
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


  subroutine build_cell(b,f,face,nrans,ini_i,phase)
    use TOM, only: meshType
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
    real(8), parameter             :: pi=4.0d0*atan(1.0d0)
    integer                        :: error, ios, iosold, cnt_bc=0, n_files, n_files_plate
    integer                        :: i, j, m, n, f_, mi, me, ni, ne, ninj
    character(len=256)             :: line
    character(len=7)               :: dirID, fileDirID
    integer                        :: dirSize=0, fileDirSize=0, type_, unit, default_type
    integer, allocatable           :: dir(:), fileDir(:)
    real(8), allocatable           :: here(:), try(:)
    real(8)                        :: var=0.0, a1, a2, b1, b2, c11, c12, c21, c22, range(4)
    real(8)                        :: radial_distance, z_input
    real(8), allocatable           :: A_inj(:), x_inj(:), y_inj(:)
    real(8)                        :: radius
    logical                        :: found(8)
    character(len=:), allocatable  :: option_pairs(:)
    character(len=256)             :: infile_dummy
    logical                        :: file_present, tecfile_present, index_based, injection_plate
    real(8), allocatable           :: Inj_phi_R(:,:)
    integer                        :: inj_unit
    character(len=256)             :: inj_output_file

    call ini_o%free
    call ini_o%add(section_name='cell')
    file_present=.false.; tecfile_present=.false.; index_based=.false.; injection_plate=.false.

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

    if (index_based) then
      call ini_i%get(section_name='face',option_name='file-direction',val=fileDirID, error=error)
      if (error==0) then
        found = .false.
        if (allocated(here)) deallocate(here)
        fileDirSize = len_trim(fileDirID)
        allocate(fileDir(1:fileDirSize)); allocate(here(1:fileDirSize))
        do i = 1, fileDirSize
          if (index(fileDirID,'x')/=0 .and. .not.found(1)) then
            fileDir(i) = 1; found(1)=.true.
          elseif (index(fileDirID,'y')/=0 .and. .not.found(2)) then
            fileDir(i) = 2; found(2)=.true.
          elseif (index(fileDirID,'z')/=0 .and. .not.found(3)) then
            fileDir(i) = 3; found(3)=.true.
          elseif (index(fileDirID,'r')/=0 .and. .not.found(4)) then
            fileDir(i) = 4; found(4)=.true.
          elseif (index(fileDirID,'t')/=0 .and. .not.found(5)) then
            fileDir(i) = 5; found(5)=.true.
          elseif (index(fileDirID,'i')/=0 .and. .not.found(6)) then
            fileDir(i) = 6; found(6)=.true.; index_based=.true.
          elseif (index(fileDirID,'j')/=0 .and. .not.found(7)) then
            fileDir(i) = 7; found(7)=.true.; index_based=.true.
          elseif (index(fileDirID,'k')/=0 .and. .not.found(8)) then
            fileDir(i) = 8; found(8)=.true.; index_based=.true.
          endif
        enddo
      endif
    endif

    call ini_i%get(section_name='face', option_name='type', val=type_, error=error)
    do while (ini_i%loop(section_name='face', option_pairs=option_pairs))
      call ini_o%add(section_name='cell', option_name=option_pairs(1), val=option_pairs(2))
    enddo

    ! Check file presence
    n_files=0
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
        if (allocated(here)) deallocate(here)
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
          allocate(x_inj(1:length)); x_inj = 0.0d0
          allocate(y_inj(1:length)); y_inj = 0.0d0
          allocate(plate_file%center(1:length, 1:2))
          allocate(plate_file%radius(1:length))
          allocate(plate_file%face_inj(1:length))
          do i = 1, length
            read(unit,*) plate_file%id(i), plate_file%center(i,1), plate_file%center(i,2), plate_file%radius(i), plate_file%face_inj(i)
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
          allocate(plate_file%face_inj(1:length))
          read(unit,*) plate_file%Plateshape !Either "Round" or "Square"
          do i = 1, length
            read(unit,*) plate_file%inj_row(i), plate_file%phase_row(i), plate_file%face_inj(i)
          enddo
          allocate(A_inj(1:sum(plate_file%inj_row(:)))); A_inj = 0.d0
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
                      var = (bc_file(f_)%array(i,1)-bc_file(f_)%array(i-1,1))/                  &
                            (bc_file(f_)%dirArray1(i)-bc_file(f_)%dirArray1(i-1))               &
                            *(here(1)-bc_file(f_)%dirArray1(i-1)) + bc_file(f_)%array(i-1,1)
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
                do ninj = 1, plate_file%length
                  radial_distance = sqrt((here(1)-plate_file%center(ninj,dir(1)))**2)
                  if (radial_distance <= plate_file%radius(ninj)) then
                    cnt_bc = cnt_bc + 1
                    face%center(m,n)%bc%definition = type_
                    call ini_o%add(section_name='cell', option_name='id_inj', val=plate_file%id(ninj))
                    call ini_o%add(section_name='cell', option_name='face_inj', val=plate_file%face_inj(ninj))
                    A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area * z_input
                    x_inj(ninj) = x_inj(ninj) + face%center(m,n)%c(1) * face%center(m,n)%area * z_input
                    y_inj(ninj) = y_inj(ninj) + face%center(m,n)%c(2) * face%center(m,n)%area * z_input
                    exit
                  endif
                enddo
                call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
              type is (KAFFS_plate_type)
               ! PER ALEX, algoritmo per casi tipo TIC
                 call Full_plate_2D(plate_file, face, n, m ,dir, Inj_phi_R,type_,A_inj,z_input,ini_o)
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
            call Build_Sectors(plate_file,face,Atot(f),Inj_phi_R,dir)
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
                        c11 = bc_file(f_)%array(i-1,j-1); c12 = bc_file(f_)%array(i-1, j )
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
                  do ninj = 1, plate_file%length
                    radial_distance = sqrt((here(1)-plate_file%center(ninj,1))**2+(here(2)-plate_file%center(ninj,2))**2)
                    if (radial_distance <= plate_file%radius(ninj)) then
                      cnt_bc = cnt_bc + 1
                      face%center(m,n)%bc%definition = type_
                      call ini_o%add(section_name='cell', option_name='id_inj', val=plate_file%id(ninj))
                      call ini_o%add(section_name='cell', option_name='face_inj', val=plate_file%face_inj(ninj))
                      A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area
                      x_inj(ninj) = x_inj(ninj) + face%center(m,n)%c(1) * face%center(m,n)%area
                      y_inj(ninj) = y_inj(ninj) + face%center(m,n)%c(2) * face%center(m,n)%area
                      exit
                    endif
                  enddo
                  call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
                type is (KAFFS_plate_type)          
                  ! PER ALEX, METTI implementazione per casi full 3D
                  ! Eccolo!
                  call Injector_mapping(plate_file,here,Inj_phi_R,n,m,face,A_inj,type_,ini_o)
                  call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)

              end select 
            endif
        enddo; enddo
      end select

      ! Write injection plate output file with injector info
      if (injection_plate .and. allocated(A_inj)) then
        select type (plate_file)
        type is (real_plate_type)
          write(inj_output_file, '(A,I0,A,I0,A)') 'injector_data_block', b, '_face', f, '.dat'
          open(newunit=inj_unit, file=trim(inj_output_file), status='replace', action='write')
          write(inj_unit, '(A)') '# Injector_ID    X_center    Y_center    Equiv_Radius'
          do ninj = 1, plate_file%length
            if (A_inj(ninj) > 0.0d0) then
              if (meshType == -2) then
                radius = A_inj(ninj) / (2.0d0 * z_input)
              else
                radius = sqrt(A_inj(ninj) / pi)
              endif
              write(inj_unit, '(I8,3E16.8)') plate_file%id(ninj), &
                    x_inj(ninj)/A_inj(ninj), y_inj(ninj)/A_inj(ninj), radius
            else
              write(inj_unit, '(I8,3E16.8)') plate_file%id(ninj), &
                    plate_file%center(ninj,1), plate_file%center(ninj,2), 0.0d0
            endif
          enddo
          close(inj_unit)
          write(*,*) 'Injector data written to: ', trim(inj_output_file)
        end select
      endif

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

      ni = max(ni,1); ne = min(ne,face%Nn)
      mi = max(mi,1); me = min(me,face%Nm)

      select case (fileDirSize)
      case(0)
        do n = ni, ne
          do m = mi, me
            face%center(m,n)%bc%definition = type_
            call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
          enddo
        enddo
      
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
            if (fileDir(1)==5) bc_file(f_)%dirArray1 = bc_file(f_)%dirArray1*pi/180
            endassociate
          enddo
        endif
        do n = ni, ne; do m = mi, me
          here(1) = face%center(m,n)%c(fileDir(1))
          if (file_present) then
            ! Interpolazione lineare
            do f_ = 1, n_files
              if (here(1)>bc_file(f_)%dirArray1(1) .and. here(1)<=bc_file(f_)%dirArray1(bc_file(f_)%length)) then
                do i = 2, bc_file(f_)%length
                  if (here(1)>bc_file(f_)%dirArray1(i-1) .and. here(1)<=bc_file(f_)%dirArray1(i)) then
                    var = (bc_file(f_)%array(i,1)-bc_file(f_)%array(i-1,1))/                  &
                          (bc_file(f_)%dirArray1(i)-bc_file(f_)%dirArray1(i-1))               &
                          *(here(1)-bc_file(f_)%dirArray1(i-1)) + bc_file(f_)%array(i-1,1)
                    call ini_o%add(section_name='cell', option_name=trim(bc_file(f_)%var), val=var)
                    exit
                  endif
                enddo
              endif
            enddo
          endif
          face%center(m,n)%bc%definition = type_
          call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
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
              if (allocated(try)) deallocate(try)
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
            if (fileDir(1)==5) bc_file(f_)%dirArray1(:) = bc_file(f_)%dirArray1(:)*pi/180
            if (fileDir(2)==5) bc_file(f_)%dirArray2(:) = bc_file(f_)%dirArray2(:)*pi/180
            endassociate
          enddo
        endif

        do n = ni, ne; do m = mi, me
            here(1) = face%center(m,n)%c(fileDir(1))
            here(2) = face%center(m,n)%c(fileDir(2))
            if (file_present) then
              ! Doppia interpolazione lineare
              do f_ = 1, n_files
                do i = 2, bc_file(f_)%length
                  if (here(1)>=bc_file(f_)%dirArray1(i-1) .and. here(1)<=bc_file(f_)%dirArray1(i)) then
                    do j = 2, bc_file(f_)%width
                      if (here(2)>bc_file(f_)%dirArray2(j-1) .and. here(2)<=bc_file(f_)%dirArray2(j)) then
                        a1 = bc_file(f_)%dirArray1(i-1); a2 = bc_file(f_)%dirArray1(i)
                        b1 = bc_file(f_)%dirArray2(j-1); b2 = bc_file(f_)%dirArray2(j)
                        c11 = bc_file(f_)%array(i-1,j-1); c12 = bc_file(f_)%array(i-1, j )
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
            face%center(m,n)%bc%definition = type_
            call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
        enddo; enddo
      end select

    endif

  end subroutine build_cell

end module build_BC_mod
