!>Per-cell BC builder: handles spatially-varying BC assignment with
! 1-D / 2-D file interpolation and index-based cell ranges.
module bc_cell_builder_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use bc_block_mod
  use bc_injection_plate_mod
  implicit none
  private
  public :: build_face

  real(R8), parameter :: pi=4.0d0*atan(1.0d0)

contains

  subroutine build_face(ib,if,face,ini_i,phase,source_ini)
    use finer,          only: file_ini
    use phase_mod,      only: phase_t
    use bcb_config_mod, only: bcb_face_runtime_config_t, load_bcb_face_runtime_config
    use direction_mod,  only: parse_direction
    use bc_names_mod,   only: check_assignment_no_input, check_assignment_with_input
    use grid_mod,       only: mesh_cfg
    use io_external_mod
    implicit none
    integer,        intent(in)     :: ib, if
    type(obj_face), intent(inout)  :: face
    type(file_ini), intent(in)     :: ini_i
    type(phase_t),  intent(in)     :: phase
    type(file_ini), intent(in)     :: source_ini
    ! Local
    type(file_ini)                :: ini_o
    type(file_ini)                :: ini_inner, ini_outer
    logical                       :: file_present, index_based, file_multipatch
    logical                       :: file_named_multipatch
    logical                       :: full_plate
    class(plate_file_type), allocatable :: plate_file
    type(bc_file_type)            :: bc_file(12)
    real(R8), allocatable         :: A_inj(:), x_inj(:), y_inj(:)
    real(R8), allocatable         :: Inj_phi_R(:,:)
    real(R8)                      :: z_input
    integer                       :: cnt_bc
    integer                       :: error
    integer                       :: n_files
    integer                       :: i, m, n, f
    character(len=7)              :: dirID, fileDirID
    character(len=20)             :: definition
    character(len=20)             :: definition_inner, definition_outer
    character(len=50)             :: inner_patch_name, outer_patch_name
    integer                       :: dirSize, fileDirSize
    integer, allocatable          :: dir(:), fileDir(:)
    real(R8), allocatable         :: here(:)
    real(R8)                      :: var, rng(4)
    character(len=:), allocatable :: option_pairs(:)
    type(bcb_face_runtime_config_t) :: face_cfg

    file_present=.false.; index_based=.false.; file_multipatch=.false.
    file_named_multipatch = .false.
    dirSize = 0; fileDirSize = 0; var = 0._R8; cnt_bc = 0; z_input = 1.0_R8
    definition_inner = ''
    definition_outer = ''
    inner_patch_name = ''
    outer_patch_name = ''

    ! Centralized FACE option parsing.
    call load_bcb_face_runtime_config(ini_i, 'face', face_cfg)

    definition = face_cfg%definition
    dirID = face_cfg%direction
    rng = face_cfg%range
    file_multipatch = face_cfg%has_range_file
    inner_patch_name = face_cfg%inner_patch
    outer_patch_name = face_cfg%outer_patch
    file_named_multipatch = file_multipatch .and. face_cfg%has_inner_patch .and. face_cfg%has_outer_patch

    ! Populate CELL ini with the options from the FACE section
    call ini_o%free
    call ini_o%add(section_name='cell')
    do while (ini_i%loop(section_name='face', option_pairs=option_pairs))
      call ini_o%add(section_name='cell', option_name=option_pairs(1), val=option_pairs(2))
    enddo

    if (file_named_multipatch) then
      call init_named_patch_ini(trim(inner_patch_name), ini_inner, definition_inner)
      call init_named_patch_ini(trim(outer_patch_name), ini_outer, definition_outer)
    endif
  
    ! Parse direction string; detect injection plate suffix before truncating.
    if (face_cfg%has_direction) then
      dirSize = len_trim(dirID)
      call parse_direction(dirID(1:dirSize), dir, dirSize, index_based)
      allocate(here(1:dirSize))
    endif

    ! Check range for multipatch assignment, set to huge() if not present or invalid
    if (face_cfg%has_range) then
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

    if (file_multipatch) then
      call read_plate_config(ini_o, face_cfg%range_file, plate_file, full_plate, z_input)
      call read_plate_file(plate_file, A_inj, x_inj, y_inj)
    endif

    ! Dispatch to the appropriate cell assignment handler
    if (index_based) then
      call assign_cells_index()
    else
      call assign_cells_spatial()
    endif

  contains

    ! Assign BCs via spatial coordinate matching with 1D/2D file
    ! interpolation, multipatch ranges and injection plate mapping.
    subroutine assign_cells_spatial()
      implicit none
      logical :: has_injector

      ! Importing data from files and/or apply multipatch
      select case (dirSize)
        ! One dimensional variation
        case(1)
          if (file_present) then
            do f = 1, n_files
              call read_bc_file_1d(bc_file(f), dir(1))
            enddo
          endif
        !$omp parallel private(m,n,var,f,has_injector) &
        !$omp firstprivate(ini_o,here) &
        !$omp do collapse(2) schedule(dynamic)
        do n = 1, face%Nn; do m = 1, face%Nm
            here(1) = face%center(m,n)%c(dir(1))
            if (file_present) then
              do f = 1, n_files
                if (interp_linear_1d(bc_file(f), here(1), var)) then
                  call ini_o%add(section_name='cell', &
                    option_name=trim(bc_file(f)%var), val=var)
                endif
              enddo
            endif
            ! Build facet BC
            if (here(1)>rng(1) .and. here(1)<=rng(2) .and. .not.file_multipatch) then
              face%center(m,n)%bc%definition = definition
              call face%center(m,n)%bc%build(ini_o,'cell',phase)
            endif
            if (file_multipatch) then
              select type (plate_file)
              type is (real_plate_type)
                !$omp critical(real_plate)
                if (file_named_multipatch) then
                  call map_real_plate_cell(plate_file, here, [dir(1)], m, n, &
                    face, definition_inner, 1.0_R8, A_inj, x_inj, y_inj, &
                    ini_o, cnt_bc, has_injector)
                else
                  call map_real_plate_cell(plate_file, here, [dir(1)], m, n, &
                    face, definition, 1.0_R8, A_inj, x_inj, y_inj, ini_o, &
                    cnt_bc, has_injector)
                endif
                !$omp end critical(real_plate)
                if (file_named_multipatch) then
                  if (has_injector) then
                    call face%center(m,n)%bc%build(ini_inner,'cell',phase)
                  else
                    face%center(m,n)%bc%definition = trim(definition_outer)
                    call face%center(m,n)%bc%build(ini_outer,'cell',phase)
                  endif
                else
                  if (.not. has_injector) then
                    face%center(m,n)%bc%definition = trim(definition)
                  endif
                  call face%center(m,n)%bc%build(ini_o,'cell',phase)
                endif
              type is (KAFFS_plate_type)
                !$omp critical(kaffs_plate)
                call Full_plate_2D(plate_file, face, n, m, dir, Inj_phi_R, &
                  definition, A_inj, z_input, ini_o)
                !$omp end critical(kaffs_plate)
                call face%center(m,n)%bc%build(ini_o,'cell',phase)
              end select
            endif
        enddo; enddo
        !$omp end parallel

      ! Two dimensional variaton
      case(2)
        if (file_present) then
          do f = 1, n_files
            call read_bc_file_2d(bc_file(f), dir(1:2))
          enddo
        endif

        ! Build injector sectors for KAFFS plates (must precede OMP parallel region)
        if (file_multipatch) then
          select type (plate_file)
            type is (KAFFS_plate_type)
              call Build_Sectors(plate_file, face, sum(face%center(:,:)%area), &
                Inj_phi_R, dir)
          end select
        endif

        !$omp parallel private(m,n,var,f,has_injector) &
        !$omp firstprivate(ini_o,here) &
        !$omp do collapse(2) schedule(dynamic)
        do n = 1, face%Nn; do m = 1, face%Nm
            here(1) = face%center(m,n)%c(dir(1))
            here(2) = face%center(m,n)%c(dir(2))
            if (file_present) then
              do f = 1, n_files
                if (interp_bilinear_2d(bc_file(f), here(1), here(2), var)) then
                  call ini_o%add(section_name='cell', &
                    option_name=trim(bc_file(f)%var), val=var)
                endif
              enddo
            endif
            ! Build facet BC
            if (here(1)>=rng(1) .and. here(1)<=rng(2) .and. &
                here(2)>=rng(3) .and. here(2)<=rng(4) .and. .not.file_multipatch) then
              face%center(m,n)%bc%definition = definition
              call face%center(m,n)%bc%build(ini_o,'cell',phase)
            endif
            if (file_multipatch) then
              select type (plate_file)
              type is (real_plate_type)
                !$omp critical(real_plate)
                if (file_named_multipatch) then
                  call map_real_plate_cell(plate_file, here, [1, 2], m, n, &
                    face, definition_inner, 1.0_R8, A_inj, x_inj, y_inj, &
                    ini_o, cnt_bc, has_injector)
                else
                  call map_real_plate_cell(plate_file, here, [1, 2], m, n, &
                    face, definition, 1.0_R8, A_inj, x_inj, y_inj, ini_o, &
                    cnt_bc, has_injector)
                endif
                !$omp end critical(real_plate)
                if (file_named_multipatch) then
                  if (has_injector) then
                    call face%center(m,n)%bc%build(ini_inner,'cell',phase)
                  else
                    face%center(m,n)%bc%definition = trim(definition_outer)
                    call face%center(m,n)%bc%build(ini_outer,'cell',phase)
                  endif
                else
                  if (.not. has_injector) then
                    face%center(m,n)%bc%definition = trim(definition)
                  endif
                  call face%center(m,n)%bc%build(ini_o,'cell',phase)
                endif
              type is (KAFFS_plate_type)
                !$omp critical(kaffs_plate)
                call Injector_mapping(plate_file, here, Inj_phi_R, n, m, face, &
                  A_inj, definition, ini_o)
                !$omp end critical(kaffs_plate)
                call face%center(m,n)%bc%build(ini_o,'cell',phase)
              end select
            endif
        enddo; enddo
        !$omp end parallel
      end select

      ! Write injector output data for real plates
      if (file_multipatch .and. allocated(A_inj)) then
        select type (plate_file)
        type is (real_plate_type)
          call write_injector_data(plate_file, A_inj, x_inj, y_inj, &
            ib, if, mesh_cfg%meshType, z_input)
        end select
      end if

    end subroutine assign_cells_spatial


    subroutine init_named_patch_ini(patch_name, patch_ini, patch_definition)
      implicit none
      character(len=*), intent(in)    :: patch_name
      type(file_ini),   intent(inout) :: patch_ini
      character(len=20), intent(out)  :: patch_definition
      integer                        :: local_error

      call patch_ini%free
      call patch_ini%add(section_name='cell')

      do while (ini_i%loop(section_name='face', option_pairs=option_pairs))
        if (trim(option_pairs(1)) /= 'inner-patch' .and. &
            trim(option_pairs(1)) /= 'outer-patch') then
          call patch_ini%add(section_name='cell', option_name=option_pairs(1), &
            val=option_pairs(2))
        endif
      enddo

      do while (source_ini%loop(section_name=patch_name, option_pairs=option_pairs))
        call patch_ini%add(section_name='cell', option_name=option_pairs(1), &
          val=option_pairs(2))
      enddo

      call patch_ini%get(section_name='cell', option_name='type', &
        val=patch_definition, error=local_error)
      if (local_error == 0) then
        call check_assignment_with_input(trim(patch_definition), patch_definition)
      else
        call check_assignment_no_input(trim(patch_name), patch_definition)
      endif
    end subroutine init_named_patch_ini


    ! Assign BCs using explicit index ranges (i,j,k) with optional
    ! 1D/2D file interpolation on a separate coordinate axis.
    subroutine assign_cells_index()
      implicit none
      integer :: i, mi, me, ni, ne


      mi = 0; me = huge(1)
      ni = 0; ne = huge(1)

      do i = 1, dirSize
        select case (if)

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
            face%center(m,n)%bc%definition = definition
            call face%center(m,n)%bc%build(ini_o,'cell',phase)
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
              if (interp_linear_1d(bc_file(f), here(1), var)) then
                call ini_o%add(section_name='cell', &
                  option_name=trim(bc_file(f)%var), val=var)
              endif
            enddo
          endif
          face%center(m,n)%bc%definition = definition
          call face%center(m,n)%bc%build(ini_o,'cell',phase)
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
                if (interp_bilinear_2d(bc_file(f), here(1), here(2), var)) then
                  call ini_o%add(section_name='cell', &
                    option_name=trim(bc_file(f)%var), val=var)
                endif
              enddo
            endif
            face%center(m,n)%bc%definition = definition
            call face%center(m,n)%bc%build(ini_o,'cell',phase)
        enddo; enddo
        !$omp end parallel
      end select

    end subroutine assign_cells_index

  end subroutine build_face

end module bc_cell_builder_mod
