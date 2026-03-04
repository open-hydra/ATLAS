! Injection plate mapping: build injector sectors and assign cells to injectors.
! Supports round (radial/angular sectors) and square (index-based strips) plates.
module BC_build_plate
  use, intrinsic :: iso_fortran_env, only: R8 => real64
  use ATLAS_high_level, only: obj_face
  use finer,            only: file_ini
  use variables,        only: llen
  implicit none
  private

  real(R8), parameter :: PI    = 4.0_R8 * atan(1.0_R8)
  real(R8), parameter :: TWOPI = 2.0_R8 * PI

  type, abstract, public :: plate_file_type
    character(len=llen)  :: name
    integer              :: length
    integer, allocatable :: id(:)
  end type plate_file_type

  type, extends(plate_file_type), public :: real_plate_type
    real(R8), allocatable :: center(:,:)
    real(R8), allocatable :: radius(:)
    integer,  allocatable :: face_inj(:)
  end type real_plate_type

  type, extends(plate_file_type), public :: KAFFS_plate_type
    character(len=llen)  :: Plateshape
    integer, allocatable :: inj_row(:)
    real(R8), allocatable :: phase_row(:)
    integer, allocatable :: face_inj(:)
    character(3)         :: Side
  end type KAFFS_plate_type

  public :: Build_Sectors, Injector_mapping, Full_plate_2D

contains

  ! Build injector sectors for round or square plates.
  ! Round: radial rings split into angular sectors.
  ! Square: index-based strips along the longest face side.
  subroutine Build_Sectors(plate_file, face, A_face, Inj_phi_R, dir)
    class(KAFFS_plate_type), intent(inout) :: plate_file
    type(obj_face),          intent(in)    :: face
    integer,                 intent(in)    :: dir(:)
    real(R8),                intent(in)    :: A_face
    real(R8), allocatable,   intent(out)   :: Inj_phi_R(:,:)

    real(R8) :: A_per_inj, Ak, phamin, phamax, pha
    real(R8), allocatable :: Rmin(:), Rmax(:), Dpha(:)
    integer  :: injid, mj, spare, ncheck, ncount, ninj, m, n

    if (plate_file%Plateshape == 'Round' .or. plate_file%Plateshape == 'round') then
      ! Round chamber 3D
      injid = 0
      ninj = sum(plate_file%inj_row(:))
      A_per_inj = A_face / ninj
      allocate(Rmin(plate_file%length), Rmax(plate_file%length), Dpha(plate_file%length))
      allocate(Inj_phi_R(5, ninj))

      do m = 1, plate_file%length
        Ak = plate_file%inj_row(m) * A_per_inj

        ! Radial sectors (Rmax, Rmin)
        if (m == 1) then
          Rmin(m) = 0.0_R8
          Rmax(m) = sqrt(Ak / PI)
        else if (m == plate_file%length) then
          Rmax(m) = sqrt(A_face / PI)
          Rmin(m) = sqrt(Rmax(m)**2 - Ak / PI)
        else
          Rmin(m) = Rmax(m - 1)
          Rmax(m) = sqrt(Rmin(m)**2 + Ak / PI)
        end if

        ! Angular sectors (phamin, phamax)
        Dpha(m) = TWOPI / plate_file%inj_row(m)

        do mj = 1, plate_file%inj_row(m)
          injid = injid + 1
          if (plate_file%inj_row(m) == 1) then
            phamin = 0.0_R8
            phamax = TWOPI
          else
            pha = plate_file%phase_row(m) + (mj - 1) * Dpha(m)
            phamin = pha - Dpha(m) * 0.5_R8
            phamax = pha + Dpha(m) * 0.5_R8
            ! Wrap phamin into [0, 2pi)
            if (phamin < 0.0_R8) phamin = phamin + TWOPI
            if (phamin > TWOPI)  phamin = phamin - TWOPI
            ! Wrap phamax into [0, 2pi)
            if (phamax < 0.0_R8) phamax = phamax + TWOPI
            if (phamax > TWOPI)  phamax = phamax - TWOPI
          end if

          Inj_phi_R(1, injid) = Rmax(m)
          Inj_phi_R(2, injid) = Rmin(m)
          Inj_phi_R(3, injid) = phamax
          Inj_phi_R(4, injid) = phamin
          Inj_phi_R(5, injid) = plate_file%face_inj(m)
        end do
      end do

    else if (plate_file%Plateshape == 'Square' .or. plate_file%Plateshape == 'square') then
      ! Square plate: strips along the longest face side
      ninj = sum(plate_file%inj_row(:))
      allocate(Inj_phi_R(5, ninj))
      A_per_inj = A_face / ninj
      injid = 1

      ! Determine longest side
      if (abs(face%center(1, face%Nn)%c(dir(2)) - face%center(1, 1)%c(dir(2))) > &
          abs(face%center(face%Nm, 1)%c(dir(1)) - face%center(1, 1)%c(dir(1)))) then
        ! Nn is the longest
        plate_file%Side = 'n'
        spare  = mod(face%Nn, ninj)
        ncount = 1
        ncheck = 0
        Inj_phi_R(1, 1) = 1
        do n = 1, face%Nn
          if (n < floor(real(face%Nn, R8) / real(ninj, R8)) * injid + ncheck) then
            Inj_phi_R(2, injid) = n
          else
            if (ncount == 2 .and. ncheck < spare) then
              Inj_phi_R(2, injid) = n
              ncount = 0
              ncheck = ncheck + 1
            else
              Inj_phi_R(2, injid) = n
              Inj_phi_R(5, injid) = plate_file%face_inj(1)
              ncount = ncount + 1
              injid = injid + 1
              if (injid > ninj) exit
              Inj_phi_R(1, injid) = n + 1
            end if
          end if
        end do
        Inj_phi_R(2, ninj) = face%Nn
      else
        ! Nm is the longest
        plate_file%Side = 'm'
        spare  = mod(face%Nm, ninj)
        ncount = 1
        ncheck = 0
        Inj_phi_R(1, 1) = 1
        do m = 1, face%Nm
          if (m < floor(real(face%Nm, R8) / real(ninj, R8)) * injid + ncheck) then
            Inj_phi_R(2, injid) = m
          else
            if (ncount == 2 .and. ncheck < spare) then
              Inj_phi_R(2, injid) = m
              ncount = 0
              ncheck = ncheck + 1
            else
              Inj_phi_R(2, injid) = m
              Inj_phi_R(5, injid) = plate_file%face_inj(1)
              ncount = ncount + 1
              injid = injid + 1
              if (injid > ninj) exit
              Inj_phi_R(1, injid) = m + 1
            end if
          end if
        end do
        Inj_phi_R(2, ninj) = face%Nm
      end if
    end if

  end subroutine Build_Sectors


  ! Map a single cell (m, n) to its injector for round or square plates.
  subroutine Injector_mapping(plate_file, here, Inj_phi_R, n, m, face, A_inj, type_, ini_o)
    class(KAFFS_plate_type), intent(inout) :: plate_file
    type(file_ini),          intent(inout) :: ini_o
    type(obj_face),          intent(inout) :: face
    integer,                 intent(in)    :: n, m, type_
    real(R8),                intent(in)    :: here(2)
    real(R8),                intent(inout) :: A_inj(:)
    real(R8),                intent(in)    :: Inj_phi_R(:,:)

    real(R8) :: rinj, anginj, angmin, angmax
    integer  :: ninj

    if (plate_file%Plateshape == 'Round' .or. plate_file%Plateshape == 'round') then
      do ninj = 1, size(Inj_phi_R, 2)
        ! Distance from the center of the plate
        rinj = sqrt(here(1)**2 + here(2)**2)
        ! Associated angle
        anginj = atan2(here(2), here(1))
        if (anginj < 0.0_R8) anginj = anginj + TWOPI

        angmin = Inj_phi_R(4, ninj)
        angmax = Inj_phi_R(3, ninj)
        ! Handle sector crossing the 0/2pi boundary
        if (angmin > angmax) then
          angmin = angmin - TWOPI
          if (anginj > PI) anginj = anginj - TWOPI
        end if

        ! Check: Rmin <= r <= Rmax  .and.  angmin <= angle <= angmax
        if (Inj_phi_R(2, ninj) <= rinj .and. Inj_phi_R(1, ninj) >= rinj .and. &
            angmin <= anginj .and. angmax >= anginj) then
          face%center(m, n)%bc%definition = type_
          A_inj(ninj) = A_inj(ninj) + face%center(m, n)%area
          call ini_o%add(section_name='cell', option_name='id_inj', val=ninj)
          call ini_o%add(section_name='cell', option_name='face_inj', val=Inj_phi_R(5, ninj))
          exit
        else
          if (ninj == size(Inj_phi_R, 2)) &
            stop "[ERROR] Plate is not fully covered, cell is missing an injector"
        end if
      end do

    else if (plate_file%Plateshape == 'Square' .or. plate_file%Plateshape == 'square') then
      ! Square plate: check index range along the longest side
      do ninj = 1, size(Inj_phi_R, 2)
        if (plate_file%Side == 'n') then
          if (Inj_phi_R(1, ninj) <= n .and. Inj_phi_R(2, ninj) >= n) then
            face%center(m, n)%bc%definition = type_
            A_inj(ninj) = A_inj(ninj) + face%center(m, n)%area
            call ini_o%add(section_name='cell', option_name='id_inj', val=ninj)
            call ini_o%add(section_name='cell', option_name='face_inj', val=Inj_phi_R(5, ninj))
          end if
        else if (plate_file%Side == 'm') then
          if (Inj_phi_R(1, ninj) <= m .and. Inj_phi_R(2, ninj) >= m) then
            face%center(m, n)%bc%definition = type_
            A_inj(ninj) = A_inj(ninj) + face%center(m, n)%area
            call ini_o%add(section_name='cell', option_name='id_inj', val=ninj)
            call ini_o%add(section_name='cell', option_name='face_inj', val=Inj_phi_R(5, ninj))
          end if
        end if
      end do
    end if

  end subroutine Injector_mapping


  ! 2D full-plate mapping (square only): builds sectors and maps cell in one call.
  ! NOTE: shares logic with Build_Sectors + Injector_mapping (square case),
  ! but adds z_input area scaling and allocates Inj_phi_R internally.
  subroutine Full_plate_2D(plate_file, face, n, m, dir, Inj_phi_R, type_, A_inj, z_input, ini_o)
    class(KAFFS_plate_type), intent(inout) :: plate_file
    type(file_ini),          intent(inout) :: ini_o
    type(obj_face),          intent(inout) :: face
    integer,                 intent(in)    :: dir(:)
    integer,                 intent(in)    :: type_, n, m
    real(R8),                intent(in)    :: z_input
    real(R8),                intent(inout) :: A_inj(:)
    real(R8), allocatable,   intent(out)   :: Inj_phi_R(:,:)

    integer :: ninj, injid, spare, ncheck, ncount, mm, nn

    ninj = sum(plate_file%inj_row(:))
    allocate(Inj_phi_R(5, ninj))
    injid = 1

    ! Determine longest side and build index strips
    if (abs(face%center(1, face%Nn)%c(dir(1)) - face%center(1, 1)%c(dir(1))) > &
        abs(face%center(face%Nm, 1)%c(dir(1)) - face%center(1, 1)%c(dir(1)))) then
      plate_file%Side = 'n'
      spare  = mod(face%Nn, ninj)
      ncount = 1
      ncheck = 0
      Inj_phi_R(1, 1) = 1
      do nn = 1, face%Nn
        if (nn < floor(real(face%Nn, R8) / real(ninj, R8)) * injid + ncheck) then
          Inj_phi_R(2, injid) = nn
        else
          if (ncount == 2 .and. ncheck < spare) then
            Inj_phi_R(2, injid) = nn
            ncount = 0
            ncheck = ncheck + 1
          else
            Inj_phi_R(2, injid) = nn
            Inj_phi_R(5, injid) = plate_file%face_inj(1)
            ncount = ncount + 1
            injid = injid + 1
            if (injid > ninj) exit
            Inj_phi_R(1, injid) = nn + 1
          end if
        end if
      end do
      Inj_phi_R(2, ninj) = face%Nn
    else
      plate_file%Side = 'm'
      spare  = mod(face%Nm, ninj)
      ncount = 1
      ncheck = 0
      Inj_phi_R(1, 1) = 1
      do mm = 1, face%Nm
        if (mm < floor(real(face%Nm, R8) / real(ninj, R8)) * injid + ncheck) then
          Inj_phi_R(2, injid) = mm
        else
          if (ncount == 2 .and. ncheck < spare) then
            Inj_phi_R(2, injid) = mm
            ncount = 0
            ncheck = ncheck + 1
          else
            Inj_phi_R(2, injid) = mm
            Inj_phi_R(5, injid) = plate_file%face_inj(1)
            ncount = ncount + 1
            injid = injid + 1
            if (injid > ninj) exit
            Inj_phi_R(1, injid) = mm + 1
          end if
        end if
      end do
      Inj_phi_R(2, ninj) = face%Nm
    end if

    ! Map cell (m, n) to injector with z_input area scaling
    do ninj = 1, size(Inj_phi_R, 2)
      if (plate_file%Side == 'n') then
        if (Inj_phi_R(1, ninj) <= n .and. Inj_phi_R(2, ninj) >= n) then
          face%center(m, n)%bc%definition = type_
          A_inj(ninj) = A_inj(ninj) + face%center(m, n)%area * z_input
          call ini_o%add(section_name='cell', option_name='id_inj', val=ninj)
          call ini_o%add(section_name='cell', option_name='face_inj', val=Inj_phi_R(5, ninj))
        end if
      else if (plate_file%Side == 'm') then
        if (Inj_phi_R(1, ninj) <= m .and. Inj_phi_R(2, ninj) >= m) then
          face%center(m, n)%bc%definition = type_
          A_inj(ninj) = A_inj(ninj) + face%center(m, n)%area * z_input
          call ini_o%add(section_name='cell', option_name='id_inj', val=ninj)
          call ini_o%add(section_name='cell', option_name='face_inj', val=Inj_phi_R(5, ninj))
        end if
      end if
    end do

  end subroutine Full_plate_2D

end module BC_build_plate
