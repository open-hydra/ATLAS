!> Per-cell BC builder: handles spatially-varying BC assignment with
!> 1-D / 2-D file interpolation, injection plate mapping, Tecplot
!> import, and index-based cell ranges.
!>
!> Extracted from build_BC_mod (builder.f90) to reduce file size
!> and isolate the cell-level logic from the block-level orchestrator.
module cell_builder_mod
  use ir_precision
  use finer, only: file_ini
  use phase_module, only: phase_type
  use ATLAS_high_level
  use lib_bc
  use BC_build_plate
  use direction_mod, only: parse_direction
  implicit none
  private
  public :: build_cell

  type :: bc_file_type
    character(len=256)   :: name
    character(len=5)     :: var
    integer              :: length, width
    real(8), allocatable :: dirArray1(:), dirArray2(:), array(:,:)
  end type bc_file_type

contains

  subroutine build_cell(b,f,face,nrans,ini_i,phase,Atot_f)
    use ATLAS_Mod_Grid, only: mesh_cfg
    implicit none
    integer, intent(in)            :: b, f
    type(obj_face)                 :: face
    type(file_ini), intent(in)     :: ini_i
    type(file_ini)                 :: ini_o
    type(phase_type), intent(in)   :: phase
    integer, intent(in)            :: nrans
    real(8), intent(in)            :: Atot_f
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
      dirSize = len_trim(dirID)
      ! Se leggo xplate o yplate (dirSize == 6), dirSize lo metto uguale a 1
      ! Se leggo xyplate (dirSize == 7), dirSize lo metto uguale a 2
      if (dirSize == 6) dirSize = 1
      if (dirSize == 7) dirSize = 2
      call parse_direction(dirID(1:dirSize), dir, dirSize, index_based)
      allocate(here(1:dirSize))
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
        if (allocated(here)) deallocate(here)
        call parse_direction(fileDirID, fileDir, fileDirSize, index_based)
        allocate(here(1:fileDirSize))
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
        !$omp parallel private(m,n,var,f_,i,ninj,radial_distance) firstprivate(ini_o,here) &
        !$omp reduction(+:cnt_bc) reduction(+:A_inj,x_inj,y_inj)
        !$omp do collapse(2) schedule(dynamic)
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
                 !$omp critical(kaffs_plate)
                 call Full_plate_2D(plate_file, face, n, m ,dir, Inj_phi_R,type_,A_inj,z_input,ini_o)
                 !$omp end critical(kaffs_plate)
                 call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
              end select
            endif
        enddo; enddo
        !$omp end parallel

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
            call Build_Sectors(plate_file,face,Atot_f,Inj_phi_R,dir)
          end select
        endif

        !$omp parallel private(m,n,var,f_,i,j,a1,a2,b1,b2,c11,c12,c21,c22,ninj,radial_distance) &
        !$omp firstprivate(ini_o,here) reduction(+:cnt_bc) reduction(+:A_inj,x_inj,y_inj)
        !$omp do collapse(2) schedule(dynamic)
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
                  !$omp critical(kaffs_plate)
                  call Injector_mapping(plate_file,here,Inj_phi_R,n,m,face,A_inj,type_,ini_o)
                  !$omp end critical(kaffs_plate)
                  call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)

              end select
            endif
        enddo; enddo
        !$omp end parallel
      end select

      ! Write injection plate output file with injector info
      if (injection_plate .and. allocated(A_inj)) then
        select type (plate_file)
        type is (real_plate_type)
          write(inj_output_file, '(A,I0,A,I0,A)') &
            'injector_data_block', b, '_face', f, '.dat'
          open(newunit=inj_unit, file=trim(inj_output_file), &
               status='replace', action='write')
          write(inj_unit, '(A)') &
            '# Injector_ID    X_center    Y_center    Equiv_Radius'
          do ninj = 1, plate_file%length
            if (A_inj(ninj) > 0.0d0) then
              if (mesh_cfg%meshType == -2) then
                radius = A_inj(ninj) / (2.0d0 * z_input)
              else
                radius = sqrt(A_inj(ninj) / pi)
              endif
              write(inj_unit, '(I8,3E16.8)') plate_file%id(ninj), &
                x_inj(ninj)/A_inj(ninj), &
                y_inj(ninj)/A_inj(ninj), radius
            else
              write(inj_unit, '(I8,3E16.8)') plate_file%id(ninj), &
                plate_file%center(ninj,1), &
                plate_file%center(ninj,2), 0.0d0
            endif
          enddo
          close(inj_unit)
          write(*,*) 'Injector data written to: ', &
            trim(inj_output_file)
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
              call ini_o%add(section_name='cell', &
                option_name=trim(bc_file(1)%var), val=var)
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
        !$omp parallel private(m,n) firstprivate(ini_o)
        !$omp do collapse(2)
        do n = ni, ne
          do m = mi, me
            face%center(m,n)%bc%definition = type_
            call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
          enddo
        enddo
        !$omp end parallel
      
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
        !$omp parallel private(m,n,var,f_,i) firstprivate(ini_o,here)
        !$omp do collapse(2)
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
        !$omp end parallel

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
              read(unit,*) bc_file(f_)%dirArray1(i), &
                (bc_file(f_)%array(i,j),j=1,width)
            enddo
            close(unit)
            if (fileDir(1)==5) &
              bc_file(f_)%dirArray1(:) = bc_file(f_)%dirArray1(:)*pi/180
            if (fileDir(2)==5) &
              bc_file(f_)%dirArray2(:) = bc_file(f_)%dirArray2(:)*pi/180
            endassociate
          enddo
        endif

        !$omp parallel private(m,n,var,f_,i,j,a1,a2,b1,b2,c11,c12,c21,c22) &
        !$omp firstprivate(ini_o,here)
        !$omp do collapse(2)
        do n = ni, ne; do m = mi, me
            here(1) = face%center(m,n)%c(fileDir(1))
            here(2) = face%center(m,n)%c(fileDir(2))
            if (file_present) then
              ! Doppia interpolazione lineare
              do f_ = 1, n_files
                do i = 2, bc_file(f_)%length
                  if (here(1)>=bc_file(f_)%dirArray1(i-1) &
                      .and. here(1)<=bc_file(f_)%dirArray1(i)) then
                    do j = 2, bc_file(f_)%width
                      if (here(2)>bc_file(f_)%dirArray2(j-1) &
                          .and. here(2)<=bc_file(f_)%dirArray2(j)) then
                        a1 = bc_file(f_)%dirArray1(i-1)
                        a2 = bc_file(f_)%dirArray1(i)
                        b1 = bc_file(f_)%dirArray2(j-1)
                        b2 = bc_file(f_)%dirArray2(j)
                        c11 = bc_file(f_)%array(i-1,j-1)
                        c12 = bc_file(f_)%array(i-1, j )
                        c21 = bc_file(f_)%array( i ,j-1)
                        c22 = bc_file(f_)%array(i, j )
                        var = ((b2-here(2))/(b2-b1)*c11 &
                              +(here(2)-b1)/(b2-b1)*c12) &
                              *(a2-here(1))/(a2-a1)
                        var = var+((b2-here(2))/(b2-b1)*c21 &
                              +(here(2)-b1)/(b2-b1)*c22) &
                              *(here(1)-a1)/(a2-a1)
                        call ini_o%add(section_name='cell', &
                          option_name=trim(bc_file(f_)%var), val=var)
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
        !$omp end parallel
      end select

    endif

  end subroutine build_cell

end module cell_builder_mod
