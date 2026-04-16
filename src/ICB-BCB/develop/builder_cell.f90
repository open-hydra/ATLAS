!> Per-cell BC builder: handles spatially-varying BC assignment with
!> 1-D / 2-D file interpolation, injection plate mapping, Tecplot
!> import, and index-based cell ranges.
!>
!> Extracted from build_BC_mod (builder.f90) to reduce file size
!> and isolate the cell-level logic from the block-level orchestrator.
module bc_cell_builder_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use ir_precision
  use bc_block_mod
  use bc_injection_plate_mod
  implicit none
  private
  public :: build_cell

contains

  subroutine build_cell(ib,if,face,nrans,ini_i,phase,Atot_f)
    use finer,          only: file_ini
    use grid_mod,       only: mesh_cfg
    use phase_mod,      only: phase_t
    use direction_mod,  only: parse_direction
    use io_external_mod
    implicit none
    integer, intent(in)            :: ib, if
    type(obj_face)                 :: face
    type(file_ini), intent(in)     :: ini_i
    type(file_ini)                 :: ini_o
    type(phase_t), intent(in)      :: phase
    integer, intent(in)            :: nrans
    real(R8), intent(in)           :: Atot_f
    ! Local
    logical                        :: file_present, index_based, injection_plate
    type(bc_file_type)             :: bc_file(12)
    logical                        :: full_plate ! if true, KAFFS-like plate
    class(plate_file_type), allocatable :: plate_file
    real(R8), parameter             :: pi=4.0d0*atan(1.0d0)
    integer                        :: error, error1, error2
    integer                        :: cnt_bc=0, n_files
    integer                        :: i, m, n, f, mi, me, ni, ne
    character(len=7)               :: dirID, fileDirID
    integer                        :: dirSize=0, fileDirSize=0, type_, default_type
    integer, allocatable           :: dir(:), fileDir(:)
    real(R8), allocatable           :: here(:)
    real(R8)                        :: var=0.0, rng(4)
    real(R8)                        :: z_input
    real(R8), allocatable           :: A_inj(:), x_inj(:), y_inj(:)
    character(len=:), allocatable  :: option_pairs(:)
    real(R8), allocatable           :: Inj_phi_R(:,:)

    file_present=.false.; index_based=.false.; injection_plate=.false.

    ! Scan FACE ini for BC file options and other relevant settings
    call ini_i%get(section_name='face', option_name='direction', val=dirID, error=error1)
    call ini_i%get(section_name='face', option_name='range',     val=rng,   error=error2)
    call ini_i%get(section_name='face', option_name='type',      val=type_, error=error)

    ! Populate CELL ini with the options from the FACE section
    call ini_o%free
    call ini_o%add(section_name='cell')
    do while (ini_i%loop(section_name='face', option_pairs=option_pairs))
      call ini_o%add(section_name='cell', option_name=option_pairs(1), val=option_pairs(2))
    enddo

  
    ! Parse direction string and determine if index-based assignment is needed.
    if (error1==0) then
      dirSize = len_trim(dirID)
      if (dirSize == 6) dirSize = 1 ! xplate or yplate case
      if (dirSize == 7) dirSize = 2 ! xyplate case
      call parse_direction(dirID(1:dirSize), dir, dirSize, index_based, injection_plate)
      allocate(here(1:dirSize))
    endif

    ! Check range for multipatch assignment, set to huge() if not present or invalid
    if (error2==0) then
      do i = dirSize*2+1, 4 ; rng(i) = (-1.0)**i*huge(rng(i)) ; enddo
    else
      do i = 1, 4 ; rng(i) = (-1.0)**i*huge(rng(i)) ; enddo
    endif

    ! Convert theta range (if present) from degrees to rad
    if (dir(1)==5) rng(1:2) = rng(1:2)*pi/180
    if (dirSize>1) then
      if (dir(2)==5) rng(3:4) = rng(3:4)*pi/180
    endif

    if (index_based) then
      call ini_i%get(section_name='face',option_name='file-direction',val=fileDirID, error=error)
      if (error==0) then
        if (allocated(here)) deallocate(here)
        call parse_direction(fileDirID, fileDir, fileDirSize, index_based)
        allocate(here(1:fileDirSize))
      endif
    endif

    ! Check file presence
    call detect_bc_files(ini_o, 'cell', bc_file, n_files)
    if (n_files>0) file_present = .true.

    ! ! Read injection plate configuration and data (if present)
    ! call read_plate_config(ini_o, plate_file, full_plate, default_type, z_input)
    ! if (.not.allocated(plate_file) .and. injection_plate) then
    !   write(*,*) '[ERROR], injection plate patch without plate file'
    !   stop
    ! else if (allocated(plate_file) .and. injection_plate) then
    !   call read_plate_file(plate_file, A_inj, x_inj, y_inj)
    ! end if

    ! --- Dispatch to the appropriate cell assignment handler ---
    if (.not.index_based) then
      call assign_cells_spatial()
    else
      call assign_cells_index()
    endif

  contains

    !> Assign BCs via spatial coordinate matching with 1D/2D file
    !> interpolation, multipatch ranges and injection plate mapping.
    subroutine assign_cells_spatial()
      implicit none

      ! Importing data from files and/or apply multipatch
      select case (dirSize)
        ! One dimensional variation
        case(1)
          if (file_present) then
            do f = 1, n_files
              call read_bc_file_1d(bc_file(f), dir(1))
            enddo
          endif
        !$omp parallel private(m,n,var,f) &
        !$omp firstprivate(ini_o,here) &
        !$omp reduction(+:cnt_bc) reduction(+:A_inj,x_inj,y_inj)
        !$omp do collapse(2) schedule(dynamic)
        do n = 1, face%Nn; do m = 1, face%Nm
            here(1) = face%center(m,n)%c(dir(1))
            if (file_present) then
              do f = 1, n_files
                if (interp_linear_1d(bc_file(f), here(1), var)) call ini_o%add(section_name='cell', option_name=trim(bc_file(f)%var), val=var)
              enddo
            endif
            ! Build facet BC
            if (here(1)>rng(1) .and. here(1)<=rng(2) .and. .not.injection_plate) then
              cnt_bc = cnt_bc+1
              face%center(m,n)%bc%definition = type_
              call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            endif
            ! if (injection_plate) then
            !   select type (plate_file)
            !   type is (real_plate_type)
            !     call map_real_plate_cell(plate_file, here, &
            !       [dir(1)], m, n, face, default_type, type_, &
            !       z_input, A_inj, x_inj, y_inj, ini_o, cnt_bc)
            !     call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            !   type is (KAFFS_plate_type)
            !    ! PER ALEX, algoritmo per casi tipo TIC
            !      !$omp critical(kaffs_plate)
            !      call Full_plate_2D(plate_file, face, n, m ,dir, Inj_phi_R,type_,A_inj,z_input,ini_o)
            !      !$omp end critical(kaffs_plate)
            !      call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            !   end select
            ! endif
        enddo; enddo
        !$omp end parallel

      ! Two dimensional variaton
      case(2)
        if (file_present) then
          do f = 1, n_files
            call read_bc_file_2d(bc_file(f), dir(1:2))
          enddo
        endif

        !Costruisco i settori di plate associati ad ogni iniettore sia Cilindrico "Round" che Rettangolare "Squared"
        ! if (injection_plate) then
        !   select type (plate_file)
        !     type is (KAFFS_plate_type) 
        !     call Build_Sectors(plate_file,face,Atot_f,Inj_phi_R,dir)
        !   end select
        ! endif

        !$omp parallel private(m,n,var,f) &
        !$omp firstprivate(ini_o,here) &
        !$omp reduction(+:cnt_bc) reduction(+:A_inj,x_inj,y_inj)
        !$omp do collapse(2) schedule(dynamic)
        do n = 1, face%Nn; do m = 1, face%Nm
            here(1) = face%center(m,n)%c(dir(1))
            here(2) = face%center(m,n)%c(dir(2))
            if (file_present) then
              do f = 1, n_files
                if (interp_bilinear_2d(bc_file(f), here(1), here(2), var)) call ini_o%add(section_name='cell', option_name=trim(bc_file(f)%var), val=var)
              enddo
            endif
            ! Build facet BC
            if (here(1)>=rng(1) .and. here(1)<=rng(2) .and. &
                here(2)>=rng(3) .and. here(2)<=rng(4) .and. .not.injection_plate) then
              cnt_bc = cnt_bc+1
              face%center(m,n)%bc%definition = type_
              call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            endif
            ! if (injection_plate) then
            !   select type (plate_file)
            !   type is (real_plate_type)
            !     call map_real_plate_cell(plate_file, here, &
            !       [1, 2], m, n, face, default_type, type_, &
            !       1.0d0, A_inj, x_inj, y_inj, ini_o, cnt_bc)
            !     call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            !   type is (KAFFS_plate_type)
            !     !$omp critical(kaffs_plate)
            !     call Injector_mapping(plate_file,here,Inj_phi_R,n,m,face,A_inj,type_,ini_o)
            !     !$omp end critical(kaffs_plate)
            !     call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
            !   end select
            ! endif
        enddo; enddo
        !$omp end parallel
      end select

      ! ! Write injection plate output file with injector info
      ! if (injection_plate .and. allocated(A_inj)) then
      !   select type (plate_file)
      !   type is (real_plate_type)
      !     call write_injector_data(plate_file, A_inj, x_inj, &
      !       y_inj, ib, if, mesh_cfg%meshType, z_input)
      !   end select
      ! end if

    end subroutine assign_cells_spatial


    !> Assign BCs using explicit index ranges (i,j,k) with optional
    !> 1D/2D file interpolation on a separate coordinate axis.
    subroutine assign_cells_index()
      implicit none


      mi = 0; me = huge(1)
      ni = 0; ne = huge(1)

      do i = 1, dirSize
        select case (f)

          case(1:2)
            if (dir(i) == 6) then
              write(*,*) '[ERROR] index i does not vary on face 1/2'
              stop
            elseif (dir(i) == 7) then
              mi = nint(rng(2*(i-1)+1)); me = nint(rng(2*i))
            elseif (dir(i) == 8) then
              ni = nint(rng(2*(i-1)+1)); ne = nint(rng(2*i))
            endif
          
          case(3:4)
            if (dir(i) == 7) then
              write(*,*) '[ERROR] index j does not vary on face 3/4'
              stop
            elseif (dir(i) == 6) then
              mi = nint(rng(2*(i-1)+1)); me = nint(rng(2*i))
            elseif (dir(i) == 8) then
              ni = nint(rng(2*(i-1)+1)); ne = nint(rng(2*i))
            endif

          case(5:6)
            if (dir(i) == 8) then
              write(*,*) '[ERROR] index k does not vary on face 5/6'
              stop
            elseif (dir(i) == 6) then
              mi = nint(rng(2*(i-1)+1)); me = nint(rng(2*i))
            elseif (dir(i) == 7) then
              ni = nint(rng(2*(i-1)+1)); ne = nint(rng(2*i))
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
          do f = 1, n_files
            call read_bc_file_1d(bc_file(f), fileDir(1))
          enddo
        endif
        !$omp parallel private(m,n,var,f) firstprivate(ini_o,here)
        !$omp do collapse(2)
        do n = ni, ne; do m = mi, me
          here(1) = face%center(m,n)%c(fileDir(1))
          if (file_present) then
            do f = 1, n_files
              if (interp_linear_1d(bc_file(f), here(1), var)) call ini_o%add(section_name='cell', option_name=trim(bc_file(f)%var), val=var)
            enddo
          endif
          face%center(m,n)%bc%definition = type_
          call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
        enddo; enddo
        !$omp end parallel

      ! Two dimensional variation
      case(2)
        if (file_present) then
          do f = 1, n_files
            call read_bc_file_2d(bc_file(f), fileDir(1:2))
          enddo
        endif

        !$omp parallel private(m,n,var,f) &
        !$omp firstprivate(ini_o,here)
        !$omp do collapse(2)
        do n = ni, ne; do m = mi, me
            here(1) = face%center(m,n)%c(fileDir(1))
            here(2) = face%center(m,n)%c(fileDir(2))
            if (file_present) then
              do f = 1, n_files
                if (interp_bilinear_2d(bc_file(f), here(1), here(2), var)) call ini_o%add(section_name='cell', option_name=trim(bc_file(f)%var), val=var)
              enddo
            endif
            face%center(m,n)%bc%definition = type_
            call face%center(m,n)%bc%build(nrans,ini_o,'cell',phase)
        enddo; enddo
        !$omp end parallel
      end select

    end subroutine assign_cells_index

  end subroutine build_cell

end module bc_cell_builder_mod
