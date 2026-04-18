!>Per-cell BC builder: handles spatially-varying BC assignment with
! 1-D / 2-D file interpolation and index-based cell ranges.
module bc_cell_builder_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use bc_block_mod
  implicit none
  private
  public :: build_face

  real(R8), parameter :: pi=4.0d0*atan(1.0d0)

contains

  subroutine build_face(ib,if,face,ini_i,phase)
    use finer,          only: file_ini
    use phase_mod,      only: phase_t
    use direction_mod,  only: parse_direction
    use bc_names_mod,   only: check_assignment_no_input, check_assignment_with_input
    use io_external_mod
    implicit none
    integer,        intent(in)     :: ib, if
    type(obj_face), intent(inout)  :: face
    type(file_ini), intent(in)     :: ini_i
    type(phase_t),  intent(in)     :: phase
    ! Local
    type(file_ini)                :: ini_o
    logical                       :: file_present, index_based
    type(bc_file_type)            :: bc_file(12)
    integer                       :: error, error1, error2
    integer                       :: n_files
    integer                       :: i, m, n, f
    character(len=7)              :: dirID, fileDirID
    character(len=20)             :: name, definition
    integer                       :: dirSize, fileDirSize
    integer, allocatable          :: dir(:), fileDir(:)
    real(R8), allocatable         :: here(:)
    real(R8)                      :: var, rng(4)
    character(len=:), allocatable :: option_pairs(:)

    file_present=.false.; index_based=.false.
    dirSize = 0; fileDirSize = 0; var = 0._R8

    ! Scan FACE ini for BC file options and other relevant settings
    call ini_i%get(section_name='face', option_name='direction', val=dirID,  error=error1)
    call ini_i%get(section_name='face', option_name='range',     val=rng,    error=error2)

    ! Check for BC type presence. If not present, look for name and check if it corresponds to a known type without input data.
    call ini_i%get(section_name='face', option_name='type', val=definition, error=error)
    if (error/=0) then
      call ini_i%get(section_name='face', option_name='name', val=name, error=error)
      call check_assignment_no_input(name, definition)
    endif

    ! Populate CELL ini with the options from the FACE section
    call ini_o%free
    call ini_o%add(section_name='cell')
    do while (ini_i%loop(section_name='face', option_pairs=option_pairs))
      call ini_o%add(section_name='cell', option_name=option_pairs(1), val=option_pairs(2))
    enddo
  
    ! Parse direction string and determine if index-based assignment is needed.
    if (error1==0) then
      dirSize = len_trim(dirID)
      call parse_direction(dirID(1:dirSize), dir, dirSize, index_based)
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
        !$omp do collapse(2) schedule(dynamic)
        do n = 1, face%Nn; do m = 1, face%Nm
            here(1) = face%center(m,n)%c(dir(1))
            if (file_present) then
              do f = 1, n_files
                if (interp_linear_1d(bc_file(f), here(1), var)) call ini_o%add(section_name='cell', option_name=trim(bc_file(f)%var), val=var)
              enddo
            endif
            ! Build facet BC
            if (here(1)>rng(1) .and. here(1)<=rng(2)) then
              face%center(m,n)%bc%definition = definition
              call face%center(m,n)%bc%build(ini_o,'cell',phase)
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

        !$omp parallel private(m,n,var,f) &
        !$omp firstprivate(ini_o,here) &
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
                here(2)>=rng(3) .and. here(2)<=rng(4) ) then
              face%center(m,n)%bc%definition = definition
              call face%center(m,n)%bc%build(ini_o,'cell',phase)
            endif
        enddo; enddo
        !$omp end parallel
      end select

    end subroutine assign_cells_spatial


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
              if (interp_linear_1d(bc_file(f), here(1), var)) call ini_o%add(section_name='cell', option_name=trim(bc_file(f)%var), val=var)
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
                if (interp_bilinear_2d(bc_file(f), here(1), here(2), var)) call ini_o%add(section_name='cell', option_name=trim(bc_file(f)%var), val=var)
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
