!>@file BCB_Q2D_Map.f90
!>@brief Mapping di soluzioni Q2D (line probes) su facce 3D cilindriche.
!>
!> Mappa dati da una line probe Q2D (nastro 1D periodico) su una faccia di griglia 3D cilindrica.
!> La coordinata "piatta" del Q2D viene arrotolata sulla circonferenza del cilindro.
!>
!> @author Alessandro Montanari

module BCB_Q2D_Map
  use, intrinsic :: iso_fortran_env, only: R8 => real64
  use variables, only: verbose
  use ATLAS_high_level
  use ATLAS_IO_fields, only: read_mesh
  use Lib_ORION_data
  use Lib_Tecplot
  use strings, only: lowercase, parse
  use IR_Precision, only: str, FR_P
  implicit none
  private

  real(R8), parameter :: PI = 4.0_R8 * atan(1.0_R8)
  real(R8), parameter :: TWOPI = 2.0_R8 * PI
  real(R8), parameter :: EPS = 1.0e-12_R8

  type, public :: Q2D_strip_type
    integer :: npts, nvar
    real(R8), allocatable :: theta(:), vars(:,:)
    character(32), allocatable :: varnames(:)
    integer :: circ_idx   ! auto-detected: 1=x, 2=y
  end type

  public :: run_q2d_bc_map

contains

  !---------------------------------------------------------------------------
  !> Entry point principale per il mapping Q2D -> 3D.
  !---------------------------------------------------------------------------
  subroutine run_q2d_bc_map(meshfile, q2dfile, outfile, face, strip_j_face, cyl_center)
    character(len=*), intent(in) :: meshfile, q2dfile, outfile
    integer, intent(in)          :: face, strip_j_face
    real(R8), intent(in)         :: cyl_center(3)

    type(orion_data) :: mesh_orion, q2d_orion
    type(ATLAS_block), allocatable :: blocks(:)
    type(Q2D_strip_type) :: strip
    integer :: b, nzones, zone, ax_idx
    real(R8), allocatable :: times(:)
    character(len=32), allocatable :: varnames(:)
    integer :: file_unit
    logical :: file_opened

    ax_idx = face_to_axis(face)

    ! Lettura mesh 3D
    if (verbose) write(*,'(A,A)') " [LOG] Reading 3D mesh: ", trim(meshfile)
    call read_mesh(mesh_orion, trim(meshfile))
    call import_nodes(input=mesh_orion, output=blocks)
    call build_geometry(blocks)

    if (verbose) write(*,'(A,3F10.4)') " [LOG] Cylinder center: ", cyl_center

    ! Lettura Q2D
    if (verbose) write(*,'(A,A)') " [LOG] Reading Q2D file: ", trim(q2dfile)
    q2d_orion%tec%format = 'ascii'
    if (tec_read_structured_multiblock(orion=q2d_orion, filename=trim(q2dfile)) /= 0) &
      stop "[ERROR] Failed to read Q2D file"
    if (.not. allocated(q2d_orion%block)) stop "[ERROR] Q2D file has no zones"
    nzones = size(q2d_orion%block)

    call read_solutiontimes(q2dfile, times, nzones)
    call get_varnames(q2d_orion%varnames, varnames)

    if (verbose) then
      write(*,'(A,I0,A,I0)') " [LOG] Zones: ", nzones, ", Variables: ", size(varnames)
      write(*,'(A,I0,A,I0)') " [LOG] Face: ", face, ", Axis: ", ax_idx
    endif

    ! Apri file output una volta sola
    file_opened = .false.
    do zone = 1, nzones
      call extract_strip(q2d_orion, zone, varnames, strip_j_face, strip)
      if (zone == 1) call validate_strip(strip)

      do b = 1, size(blocks)
        call process_block(blocks(b), strip, ax_idx, cyl_center, face, &
                           outfile, file_unit, file_opened, times(zone), b, zone)
      enddo
    enddo
    if (file_opened) close(file_unit)

    if (verbose) write(*,'(A,A)') " [LOG] Output: ", trim(outfile)
  end subroutine


  !---------------------------------------------------------------------------
  subroutine extract_strip(orion, zone, varnames, j_face, strip)
    type(orion_data), intent(in) :: orion
    integer, intent(in) :: zone
    character(len=*), intent(in) :: varnames(:)
    integer, intent(in) :: j_face
    type(Q2D_strip_type), intent(out) :: strip
    integer :: i, v, npts, nvar_input
    real(R8) :: range_x, range_y, s_min, s_max
    real(R8), allocatable :: centers(:)

    npts = orion%block(zone)%Ni
    nvar_input = size(orion%block(zone)%vars, 1)
    strip%npts = npts
    strip%nvar = size(varnames)
    allocate(strip%theta(npts), strip%vars(strip%nvar, npts), strip%varnames(strip%nvar))
    allocate(centers(npts))
    strip%varnames = varnames
    strip%vars = 0.0_R8

    ! Auto-detect circ_idx: coordinata con range maggiore
    range_x = maxval(orion%block(zone)%mesh(1, 0:npts, j_face, 0)) - &
              minval(orion%block(zone)%mesh(1, 0:npts, j_face, 0))
    range_y = maxval(orion%block(zone)%mesh(2, 0:npts, j_face, 0)) - &
              minval(orion%block(zone)%mesh(2, 0:npts, j_face, 0))
    strip%circ_idx = merge(1, 2, range_x > range_y)

    ! Centri-cella nella coordinata circonferenziale
    do i = 1, npts
      centers(i) = 0.5_R8 * (orion%block(zone)%mesh(strip%circ_idx, i-1, j_face, 0) + &
                              orion%block(zone)%mesh(strip%circ_idx, i, j_face, 0))
    enddo

    ! Converti in theta: [0, 2pi)
    s_min = minval(centers)
    s_max = maxval(centers)
    if (s_max - s_min < 1.0e-12_R8) stop "[ERROR] Q2D circ range <= 0"
    do i = 1, npts
      strip%theta(i) = (centers(i) - s_min) / (s_max - s_min) * TWOPI
    enddo

    ! Variabili
    do v = 1, min(strip%nvar, nvar_input)
      strip%vars(v,:) = orion%block(zone)%vars(v, 1:npts, 1, 1)
    enddo

    ! Garantisci theta crescente (se la strip ha coordinata decrescente, inverti)
    if (strip%theta(1) > strip%theta(npts)) then
      strip%theta = strip%theta(npts:1:-1)
      strip%vars  = strip%vars(:, npts:1:-1)
    endif

    deallocate(centers)
  end subroutine


  !---------------------------------------------------------------------------
  subroutine validate_strip(strip)
    type(Q2D_strip_type), intent(in) :: strip
    if (strip%npts < 2) stop "[ERROR] Q2D strip < 2 points"
    if (strip%nvar < 1) stop "[ERROR] Q2D strip has no variables"
    if (strip%circ_idx < 1 .or. strip%circ_idx > 2) stop "[ERROR] circ_idx auto-detect failed"
  end subroutine


  !---------------------------------------------------------------------------
  subroutine process_block(block, strip, ax_idx, center, face, &
                           filename, file_unit, file_opened, time, b_num, z_num)
    type(ATLAS_block), intent(in) :: block
    type(Q2D_strip_type), intent(in) :: strip
    integer, intent(in) :: ax_idx, face, b_num, z_num
    real(R8), intent(in) :: center(3), time
    character(len=*), intent(in) :: filename
    integer, intent(inout) :: file_unit
    logical, intent(inout) :: file_opened

    integer :: n1, n2, i1, i2, v
    real(R8), allocatable :: nodes(:,:,:), centers(:,:,:), vars(:,:,:)

    call face_dims(block%dim, face, n1, n2)
    call extract_geometry(block, face, n1, n2, nodes, centers)

    allocate(vars(strip%nvar, n1, n2))
    call interpolate_vars(centers, vars, strip, ax_idx, center, n1, n2)

    ! Scrittura Tecplot (apri file solo alla prima chiamata)
    if (.not. file_opened) then
      open(newunit=file_unit, file=trim(filename), status='REPLACE', form='formatted')
      file_opened = .true.
      write(file_unit,'(A)',advance='no') ' VARIABLES ="x" "y" "z"'
      do v = 1, strip%nvar
        write(file_unit,'(A)',advance='no') ' "'//trim(strip%varnames(v))//'"'
      enddo
      write(file_unit,*)
    endif

    write(file_unit,'(A,I0,A,I0,A,I0,A,I0,A)',advance='no') &
      ' ZONE T="B', b_num, '_T', z_num, '", I=', n1+1, ', J=', n2+1, ', K=1, DATAPACKING=BLOCK'
    if (strip%nvar > 1) then
      write(file_unit,'(A,I0,A)',advance='no') ', VARLOCATION=([1-3]=NODAL,[4-', 3+strip%nvar, ']=CELLCENTERED)'
    else
      write(file_unit,'(A)',advance='no') ', VARLOCATION=([1-3]=NODAL,[4]=CELLCENTERED)'
    endif
    if (time >= 0.0_R8) write(file_unit,'(A,ES15.8)',advance='no') ', SOLUTIONTIME=', time
    write(file_unit,*)

    write(file_unit, FR_P) ((nodes(1,i1,i2), i1=0,n1), i2=0,n2)
    write(file_unit, FR_P) ((nodes(2,i1,i2), i1=0,n1), i2=0,n2)
    write(file_unit, FR_P) ((nodes(3,i1,i2), i1=0,n1), i2=0,n2)
    do v = 1, strip%nvar
      write(file_unit, FR_P) ((vars(v,i1,i2), i1=1,n1), i2=1,n2)
    enddo
  end subroutine


  !---------------------------------------------------------------------------
  !> Interpola variabili Q2D sulla faccia 3D con trasformazione velocita'.
  !> Interpolazione periodica in theta-space.
  !---------------------------------------------------------------------------
  subroutine interpolate_vars(centers, vars, strip, ax_idx, center, n1, n2)
    real(R8), intent(in) :: centers(:,:,:), center(3)
    real(R8), intent(out) :: vars(:,:,:)
    type(Q2D_strip_type), intent(in) :: strip
    integer, intent(in) :: ax_idx, n1, n2

    integer :: i1, i2, v, i0_, i1_, p1, p2, u_idx, v_idx, w_idx, tang_idx, ax_vel_idx
    real(R8) :: theta, wt, vt, va, st, ct, comp(3)
    logical :: has_vel

    u_idx = find_var(strip%varnames, 'u')
    v_idx = find_var(strip%varnames, 'v')
    w_idx = find_var(strip%varnames, 'w')

    ! Mappa Q2D vel -> tangenziale/assiale
    if (strip%circ_idx == 1) then
      tang_idx = u_idx; ax_vel_idx = v_idx
    else
      tang_idx = v_idx; ax_vel_idx = u_idx
    endif
    has_vel = (tang_idx > 0 .or. ax_vel_idx > 0)

    ! Piano perpendicolare all'asse (terna destra)
    select case(ax_idx)
      case(1); p1 = 2; p2 = 3
      case(2); p1 = 3; p2 = 1
      case default; p1 = 1; p2 = 2
    end select

    !$OMP PARALLEL DO PRIVATE(i1,i2,v,theta,i0_,i1_,wt,vt,va,st,ct,comp) COLLAPSE(2)
    do i2 = 1, n2
      do i1 = 1, n1
        theta = compute_theta(centers(:,i1,i2), center, ax_idx)
        call periodic_search(strip%theta, strip%npts, theta, i0_, i1_, wt)

        comp = 0.0_R8
        if (has_vel) then
          vt = 0.0_R8; va = 0.0_R8
          if (tang_idx > 0) vt = (1.0_R8 - wt) * strip%vars(tang_idx,i0_) + wt * strip%vars(tang_idx,i1_)
          if (ax_vel_idx > 0) va = (1.0_R8 - wt) * strip%vars(ax_vel_idx,i0_) + wt * strip%vars(ax_vel_idx,i1_)
          st = sin(theta); ct = cos(theta)
          comp(ax_idx) = va
          comp(p1) = -vt * st
          comp(p2) =  vt * ct
        endif

        do v = 1, strip%nvar
          if (v == u_idx) then
            vars(v,i1,i2) = comp(1)
          elseif (v == v_idx) then
            vars(v,i1,i2) = comp(2)
          elseif (v == w_idx) then
            vars(v,i1,i2) = comp(3)
          else
            vars(v,i1,i2) = (1.0_R8 - wt) * strip%vars(v,i0_) + wt * strip%vars(v,i1_)
          endif
        enddo
      enddo
    enddo
    !$OMP END PARALLEL DO
  end subroutine


  !---------------------------------------------------------------------------
  subroutine extract_geometry(block, face, n1, n2, nodes, centers)
    type(ATLAS_block), intent(in) :: block
    integer, intent(in) :: face, n1, n2
    real(R8), allocatable, intent(out) :: nodes(:,:,:), centers(:,:,:)
    integer :: i1, i2

    allocate(nodes(3, 0:n1, 0:n2), centers(3, n1, n2))

    do i2 = 0, n2
      do i1 = 0, n1
        nodes(:,i1,i2) = get_face_node(block, face, i1, i2)
      enddo
    enddo

    do i2 = 1, n2
      do i1 = 1, n1
        centers(:,i1,i2) = block%face(face)%center(i1,i2)%c(1:3)
      enddo
    enddo
  end subroutine


  !---------------------------------------------------------------------------
  pure function get_face_node(block, face, i1, i2) result(c)
    type(ATLAS_block), intent(in) :: block
    integer, intent(in) :: face, i1, i2
    real(R8) :: c(3)
    select case(face)
      case(1); c = block%node(0, i1, i2)%c(1:3)
      case(2); c = block%node(block%dim(1), i1, i2)%c(1:3)
      case(3); c = block%node(i1, 0, i2)%c(1:3)
      case(4); c = block%node(i1, block%dim(2), i2)%c(1:3)
      case(5); c = block%node(i1, i2, 0)%c(1:3)
      case(6); c = block%node(i1, i2, block%dim(3))%c(1:3)
      case default; c = 0.0_R8
    end select
  end function


  !---------------------------------------------------------------------------
  pure subroutine face_dims(dim, face, n1, n2)
    integer, intent(in) :: dim(3), face
    integer, intent(out) :: n1, n2
    select case(face)
      case(1,2); n1 = dim(2); n2 = dim(3)
      case(3,4); n1 = dim(1); n2 = dim(3)
      case default; n1 = dim(1); n2 = dim(2)
    end select
  end subroutine


  !---------------------------------------------------------------------------
  pure integer function face_to_axis(face) result(ax)
    integer, intent(in) :: face
    select case(face)
      case(1,2); ax = 1
      case(3,4); ax = 2
      case default; ax = 3
    end select
  end function


  !---------------------------------------------------------------------------
  integer function find_var(varnames, name) result(idx)
    character(len=*), intent(in) :: varnames(:), name
    integer :: i
    idx = -1
    do i = 1, size(varnames)
      if (lowercase(trim(varnames(i))) == lowercase(trim(name))) then
        idx = i; return
      endif
    enddo
  end function


  !---------------------------------------------------------------------------
  !> Estrae nomi variabili da Q2D e aggiunge 'w' se mancante (per output 3D).
  subroutine get_varnames(input, output)
    character(len=*), intent(in) :: input(:)
    character(len=32), allocatable, intent(out) :: output(:)
    integer :: offset, n, nout, i
    logical :: has_w

    n = size(input); offset = 0
    if (n >= 2 .and. lowercase(trim(input(1))) == 'x' .and. lowercase(trim(input(2))) == 'y') then
      offset = 2
      if (n >= 3 .and. lowercase(trim(input(3))) == 'z') offset = 3
    endif

    if (n - offset <= 0) stop "[ERROR] Q2D has no variables"

    ! Verifica se 'w' esiste già
    has_w = .false.
    do i = offset+1, n
      if (lowercase(trim(input(i))) == 'w') has_w = .true.
    enddo

    ! Alloca con spazio per 'w' se mancante
    nout = n - offset
    if (.not. has_w) nout = nout + 1
    allocate(output(nout))
    output(1:n-offset) = input(offset+1:n)
    if (.not. has_w) output(nout) = 'w'
  end subroutine


  !---------------------------------------------------------------------------
  subroutine read_solutiontimes(filename, times, nzones)
    use, intrinsic :: iso_fortran_env, only: iostat_end
    character(len=*), intent(in) :: filename
    integer, intent(in) :: nzones
    real(R8), allocatable, intent(out) :: times(:)
    integer :: u, ios, z, ia
    character(len=500) :: line
    character(len=100) :: args(40), subargs(2)

    allocate(times(nzones)); times = -1.0_R8
    open(newunit=u, file=trim(filename), status='old', iostat=ios)
    if (ios /= 0) return

    z = 0
    do
      read(u, '(A)', iostat=ios) line
      if (ios == iostat_end) exit
      if (index(lowercase(line), 'zone') > 0) then
        z = z + 1
        if (z > nzones) exit
        if (index(lowercase(line), 'solutiontime') > 0) then
          call parse(line, ',', args)
          do ia = 1, size(args)
            if (index(lowercase(args(ia)), 'solutiontime') > 0) then
              call parse(args(ia), '=', subargs)
              read(subargs(2), *, iostat=ios) times(z)
              exit
            endif
          enddo
        endif
      endif
    enddo
    close(u)
  end subroutine

  !---------------------------------------------------------------------------
  !> Angolo theta da coordinate cartesiane per cilindro con asse ax_idx.
  !> Terna destra per tutti gli assi.
  !---------------------------------------------------------------------------
  pure real(R8) function compute_theta(xyz, center, ax_idx) result(theta)
    real(R8), intent(in) :: xyz(3), center(3)
    integer, intent(in)  :: ax_idx
    real(R8) :: d(3), c1, c2

    d = xyz - center
    select case(ax_idx)
      case(1); c1 = d(2); c2 = d(3)  ! asse x: piano y-z
      case(2); c1 = d(3); c2 = d(1)  ! asse y: piano z-x
      case default; c1 = d(1); c2 = d(2)  ! asse z: piano x-y
    end select
    theta = modulo(atan2(c2, c1), TWOPI)
  end function


  !---------------------------------------------------------------------------
  !> Ricerca lineare periodica su array ordinato crescente in [0, 2pi).
  !> Trova la coppia (i0, i1) che racchiude theta_tgt, con gap periodico.
  !---------------------------------------------------------------------------
  pure subroutine periodic_search(theta_arr, n, theta_tgt, i0, i1, w)
    real(R8), intent(in)  :: theta_arr(:)
    integer, intent(in)   :: n
    real(R8), intent(in)  :: theta_tgt
    integer, intent(out)  :: i0, i1
    real(R8), intent(out) :: w
    integer :: i
    real(R8) :: gap

    if (n <= 1) then
      i0 = 1; i1 = 1; w = 0.0_R8; return
    endif

    do i = 1, n - 1
      if (theta_tgt >= theta_arr(i) .and. theta_tgt < theta_arr(i+1)) then
        i0 = i; i1 = i + 1
        gap = theta_arr(i1) - theta_arr(i0)
        if (gap > EPS) then
          w = (theta_tgt - theta_arr(i0)) / gap
        else
          w = 0.0_R8
        endif
        return
      endif
    enddo

    ! Gap periodico: tra ultimo e primo elemento
    i0 = n; i1 = 1
    gap = (theta_arr(1) + TWOPI) - theta_arr(n)
    if (gap > EPS) then
      if (theta_tgt >= theta_arr(n)) then
        w = (theta_tgt - theta_arr(n)) / gap
      else
        w = (theta_tgt + TWOPI - theta_arr(n)) / gap
      endif
    else
      w = 0.0_R8
    endif
    w = max(0.0_R8, min(1.0_R8, w))
  end subroutine

end module BCB_Q2D_Map
