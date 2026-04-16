module intersection_mod
  ! Geometry intersection utilities for hexahedral cells.
  ! Provides routines to compute intersections between hexahedra,
  ! check point-in-hexahedron, compute volumes and basic vector ops.
  implicit none
  private
  public :: IntersectionVolumes 
  public :: intersection_type, HexahedronIntesectingPoints, pointInsideHexahedron, &
    intersectQuadrangles, clipLineToQuadrangle, intersectLines3D, isPointInQuadrangle, &
    linePlaneIntersection, FaceSelection, HexahedronVolume, TetrahedronVolume, &
    cross_product, norm, round

  ! Intersection object: donor/receiver IDs and volume info
  type :: intersection_type
    integer   :: receiverID(4)
    integer   :: donorID(4)
    real(8)   :: inter_volume
    real(8)   :: volume_fraction
    logical   :: nodeinside(8)
  end type intersection_type

  real(8), parameter :: toll1 = 1e-4, toll2 = 1e-5
  real(8), parameter, public :: fs=10000000

contains

  ! Fortran interface to Python script for computing intersection volumes
  subroutine IntersectionVolumes(python_path,ni,intersection)
    implicit none
    character(len=*), intent(in)                        :: python_path
    integer, intent(in)                                 :: ni
    type(intersection_type), allocatable, intent(inout) :: intersection(:)
    integer :: unitfile1, ios, i

    !% Allocate and store intersections info
    allocate(intersection(1:ni))
    open(newunit=unitfile1,file='couples.txt',iostat=ios)
    if ( ios /= 0 ) stop "Error opening couples.txt"
    do i = 1, ni
        read(unitfile1,*) intersection(i)%receiverID, intersection(i)%donorID
        read(unitfile1,*) intersection(i)%nodeinside
    enddo
    close(unitfile1)

    !% Compute the convex hull (intersection) volume with a python script and import the values
    call execute_command_line('python3 -B  '//trim(python_path))
    open(newunit=unitfile1,file='volumes.txt',iostat=ios)
    if ( ios /= 0 ) stop "Error opening volumes.txt"
    do i = 1, ni
        read(unitfile1,*,iostat=ios) intersection(i)%inter_volume
        intersection(i)%inter_volume = intersection(i)%inter_volume/(fs**3)
        if (ios/=0) stop "Error reading volumes.txt"
    enddo
    close(unitfile1)

  end subroutine IntersectionVolumes


  ! HexahedronIntesectingPoints
  ! Collect intersection points between two hexahedra. Returns a
  ! contiguous array of unique intersection points (3*#points).
  subroutine HexahedronIntesectingPoints(hexahedron1, hexahedron2, real_points, nodeinside)
    implicit none
    real(8), dimension(3,8), intent(in)      :: hexahedron1, hexahedron2
    real(8), allocatable, intent(out)        :: real_points(:)
    logical, optional, intent(inout)         :: nodeinside(8)

    integer                                  :: num_unique
    integer                                  :: i, j, numInt, tot, old_tot

    real(8), dimension(3,4)                  :: T1, T2
    real(8), dimension(24)                   :: new_points
    real(8), dimension(24*36+16*3)           :: points   ! fixed maximum buffer
    real(8), dimension(3)                    :: pr1, pr2
    real(8), dimension(24*36+16*3)           :: unique_points

    logical                                  :: isIntersect, is_unique
    logical                                  :: inside1, inside2

    old_tot = 0
    tot     = 0
    do i = 1, 6
      call FaceSelection(hexahedron1, i, T1)
      do j = 1, 6
        call FaceSelection(hexahedron2, j, T2)
        call intersectQuadrangles(T1, T2, new_points, isIntersect, numInt)
        if (isIntersect .eqv. .true.) then
          tot = old_tot + numInt*3
          points(old_tot+1:tot) = new_points(1:numInt*3)
          old_tot = tot
        end if
      end do
    end do

    ! Check hexahedron vertices for containment in the other
    do i = 1, 8
      call pointInsideHexahedron(hexahedron1(:,i), hexahedron2, inside1)
      call pointInsideHexahedron(hexahedron2(:,i), hexahedron1, inside2)
      if (present(nodeinside)) then
        if (.not. nodeinside(i)) nodeinside(i) = inside1
      end if
      if (inside1 .eqv. .true.) then
        tot = old_tot + 3
        points(old_tot+1:tot) = hexahedron1(:,i)
        old_tot = tot
      end if
      if (inside2 .eqv. .true.) then
        tot = old_tot + 3
        points(old_tot+1:tot) = hexahedron2(:,i)
        old_tot = tot
      end if
    end do

    ! Remove repeated points by rounding and unique filtering
    points = round(points, 10, size(points))
    num_unique = 0
    do i = 1, tot, 3
      pr1 = points(i:i+2)
      is_unique = .true.
      do j = 1, num_unique
        pr2 = unique_points(j*3-2:j*3)
        if ((pr1(1) .eq. pr2(1)) .and. (pr1(2) .eq. pr2(2)) .and. (pr1(3) .eq. pr2(3))) then
          is_unique = .false.
          exit
        end if
      end do
      if (is_unique) then
        num_unique = num_unique + 1
        unique_points(num_unique*3-2:num_unique*3) = pr1
      end if
    end do

    allocate(real_points(num_unique*3))
    do i = 1, num_unique*3, 3
      real_points(i:i+2) = unique_points(i:i+2)
    end do

  end subroutine HexahedronIntesectingPoints

  ! pointInsideHexahedron
  ! Test whether point P is inside a hexahedron defined by vertices.
  subroutine pointInsideHexahedron(P, vertices, inside)
    implicit none
    real(8), dimension(3), intent(in)        :: P
    real(8), dimension(3,8), intent(in)      :: vertices
    logical, intent(out)                     :: inside

    real(8)                   :: volHex, V, vol1, vol2
    real(8), dimension(3,4)   :: T
    real(8), dimension(3)     :: A, B, C, D
    integer                   :: i

    call HexahedronVolume(vertices, volHex)
    V = 0.0
    do i = 1, 6
      call FaceSelection(vertices, i, T)
      A = T(:,1)
      B = T(:,2)
      C = T(:,3)
      D = T(:,4)
      call TetrahedronVolume(A, B, C, P, vol1)
      call TetrahedronVolume(A, D, C, P, vol2)
      V = V + vol1 + vol2
    end do

    if (abs(volHex - V) .lt. toll1) then
      inside = .true.
    else
      inside = .false.
    end if

  end subroutine pointInsideHexahedron

  ! intersectQuadrangles
  ! Compute intersection points between two planar quadrangles (T1, T2).
  subroutine intersectQuadrangles(T1, T2, pts, isIntersect, numInt)
    implicit none
    real(8), dimension(3,4), intent(in) :: T1, T2
    real(8), dimension(24), intent(out) :: pts
    logical, intent(out)                :: isIntersect
    integer, intent(out)                :: numInt

    real(8), dimension(3) :: A, B, C, D, E, F, G, H
    real(8), dimension(3) :: N1, N2, P, dir
    integer               :: numInt1, numInt2
    integer               :: check, size1, size2
    integer               :: i
    real(8), dimension(12):: segment1, segment2

    A = T1(:,1)
    B = T1(:,2)
    C = T1(:,3)
    D = T1(:,4)
    E = T2(:,1)
    F = T2(:,2)
    G = T2(:,3)
    H = T2(:,4)

    N1 = cross_product(B - A, C - A)
    N2 = cross_product(F - E, G - E)
    if (norm(cross_product(N1, N2)) .lt. toll1) then
      isIntersect = .false.
      numInt = 0
      pts(1:24) = 100.0
      return
    end if

    call linePlaneIntersection(N1, D, N2, H, P, dir, check)
    if (check .eq. 2) then
      call clipLineToQuadrangle(P, dir, A, B, C, D, E, F, G, H, segment1, numInt1)
      call clipLineToQuadrangle(P, dir, E, F, G, H, A, B, C, D, segment2, numInt2)
      numInt = numInt1 + numInt2
      if (numInt .eq. 0) then
        isIntersect = .false.
        pts(1:24) = 100.0
        return
      else
        isIntersect = .true.
        if ((numInt1 .ne. 0) .and. (numInt2 .ne. 0)) then
          size1 = numInt1*3
          size2 = numInt2*3
          do i = 1, size1
            pts(i) = segment1(i)
          end do
          do i = size1+1, size1+size2
            pts(i) = segment2(i-size1)
          end do
        else if (numInt1 .ne. 0) then
          size1 = numInt1*3
          do i = 1, size1
            pts(i) = segment1(i)
          end do
        else if (numInt2 .ne. 0) then
          size2 = numInt2*3
          do i = 1, size2
            pts(i) = segment2(i)
          end do
        end if
      end if
    else
      isIntersect = .false.
      numInt = 0
      pts(1:24) = 100.0
      return
    end if

  end subroutine intersectQuadrangles

  ! clipLineToQuadrangle
  ! Clip intersection line to quadrangle edges and return intersection points
  subroutine clipLineToQuadrangle(P, dir, A, B, C, D, E, F, G, H, segment, numInt)
    implicit none
    real(8), dimension(3), intent(in)  :: P, dir, A, B, C, D, E, F, G, H
    real(8), dimension(12), intent(out) :: segment
    integer, intent(out)                :: numInt

    real(8), dimension(3) :: ip1, ip2, ip3, ip4
    logical               :: intsec1, intsec2, intsec3, intsec4
    integer               :: i

    i = 1
    numInt = 0
    call intersectLines3D(P, dir, A, B, E, F, G, H, ip1, intsec1)
    if (intsec1 .eqv. .true.) then
      segment(i)   = ip1(1)
      segment(i+1) = ip1(2)
      segment(i+2) = ip1(3)
      i = i + 3
      numInt = numInt + 1
    end if

    call intersectLines3D(P, dir, B, C, E, F, G, H, ip2, intsec2)
    if (intsec2 .eqv. .true.) then
      segment(i)   = ip2(1)
      segment(i+1) = ip2(2)
      segment(i+2) = ip2(3)
      i = i + 3
      numInt = numInt + 1
    end if

    call intersectLines3D(P, dir, C, D, E, F, G, H, ip3, intsec3)
    if (intsec3 .eqv. .true.) then
      segment(i)   = ip3(1)
      segment(i+1) = ip3(2)
      segment(i+2) = ip3(3)
      i = i + 3
      numInt = numInt + 1
    end if

    call intersectLines3D(P, dir, D, A, E, F, G, H, ip4, intsec4)
    if (intsec4 .eqv. .true.) then
      segment(i)   = ip4(1)
      segment(i+1) = ip4(2)
      segment(i+2) = ip4(3)
      i = i + 3
      numInt = numInt + 1
    end if

    if (numInt .eq. 0) then
      segment(i:12) = 100.0
      return
    end if

  end subroutine clipLineToQuadrangle

  ! intersectLines3D
  ! Find intersection point between a line (P1 + t*dir1) and segment P2-P3,
  ! then check containment within quadrangle E,F,G,H.
  subroutine intersectLines3D(P1, dir1, P2, P3, E, F, G, H, ip, intsec)
    implicit none
    real(8), dimension(3), intent(in)  :: P1, dir1, P2, P3, E, F, G, H
    real(8), dimension(3), intent(out) :: ip
    logical, intent(out)               :: intsec

    real(8), dimension(3) :: dir2, cross_d1d2
    logical               :: is_parallel, is_collinear
    real(8)               :: num, den, t
    integer               :: i
    logical, dimension(3):: cond
    logical               :: inside

    dir2 = P3 - P2
    cross_d1d2 = cross_product(dir1, dir2)
    if (norm(cross_d1d2) < toll1) then
      if (norm(cross_product(P2 - P1, dir1)) < toll1) then
        is_parallel = .false.
        is_collinear = .true.
      else
        is_parallel = .true.
        is_collinear = .false.
      end if
      intsec = .false.
      ip(1:3) = 100.0
      return
    else
      is_parallel = .false.
      is_collinear = .false.
    end if

    num = dot_product(cross_product(P2 - P1, dir2), cross_d1d2)
    den = dot_product(cross_d1d2, cross_d1d2)
    t = num / den
    ip = P1 + t * dir1

    do i = 1, 3
      if (P2(i) .ge. P3(i)) then
        if ((ip(i) .ge. (P3(i) - toll2)) .and. (ip(i) .le. (P2(i) + toll2))) then
          cond(i) = .true.
        else
          cond(i) = .false.
        end if
      else
        if ((ip(i) .ge. (P2(i) - toll1)) .and. (ip(i) .le. (P3(i) + toll2))) then
          cond(i) = .true.
        else
          cond(i) = .false.
        end if
      end if
    end do

    if ((cond(1) .eqv. .false.) .or. (cond(2) .eqv. .false.) .or. (cond(3) .eqv. .false.)) then
      intsec = .false.
      ip(1:3) = 100.0
      return
    end if

    call isPointInQuadrangle(ip, E, F, G, H, inside)
    if (inside .eqv. .false.) then
      intsec = .false.
      ip(1:3) = 100.0
      return
    end if

    intsec = .true.

  end subroutine intersectLines3D

  ! isPointInQuadrangle
  ! Determine if point P is inside quadrangle ABCD (planar test via triangle areas)
  subroutine isPointInQuadrangle(P, A, B, C, D, inside)
    implicit none
    real(8), dimension(3), intent(in) :: P, A, B, C, D
    logical, intent(out)               :: inside
    real(8)                           :: areaQuad, a1, a2, a3, a4

    areaQuad = 0.5 * norm(cross_product(B - A, C - A))
    areaQuad = areaQuad + 0.5 * norm(cross_product(C - A, D - A))

    a1 = 0.5 * norm(cross_product(A - P, B - P))
    a2 = 0.5 * norm(cross_product(B - P, C - P))
    a3 = 0.5 * norm(cross_product(C - P, D - P))
    a4 = 0.5 * norm(cross_product(D - P, A - P))

    if (abs(areaQuad - (a1 + a2 + a3 + a4)) .le. toll1) then
      inside = .true.
    else
      inside = .false.
    end if

  end subroutine isPointInQuadrangle

  ! linePlaneIntersection
  ! Compute intersection line (point P and direction dir) between planes (N1,P1) and (N2,P2)
  subroutine linePlaneIntersection(N1, P1, N2, P2, P, dir, check)
    implicit none
    real(8), dimension(3), intent(in)  :: N1, P1, N2, P2
    real(8), dimension(3), intent(out) :: P, dir
    integer, intent(out)                :: check

    real(8)                :: d1, d2
    real(8), dimension(3)  :: V
    integer                :: i, maxc

    dir = cross_product(N1, N2)
    d1  = - dot_product(N1, P1)
    d2  = - dot_product(N2, P2)

    if (norm(dir) < toll1) then
      V = P1 - P2
      if (dot_product(N1, V) .eq. 0) then
        check = 1
        return
      else
        check = 0
        return
      end if
    else
      check = 2
    end if

    do i = 1, 3
      if (abs(dir(i)) .eq. maxval(abs(dir))) then
        maxc = i
      end if
    end do

    if (maxc .eq. 1) then
      P(1) = 0.0
      P(2) = (d2*N1(3) - d1*N2(3)) / dir(1)
      P(3) = (d1*N2(2) - d2*N1(2)) / dir(1)
    else if (maxc .eq. 2) then
      P(1) = (d1*N2(3) - d2*N1(3)) / dir(2)
      P(2) = 0.0
      P(3) = (d2*N1(1) - d1*N2(1)) / dir(2)
    else if (maxc .eq. 3) then
      P(1) = (d2*N1(2) - d1*N2(2)) / dir(3)
      P(2) = (d1*N2(1) - d2*N1(1)) / dir(3)
      P(3) = 0.0
    end if

  end subroutine linePlaneIntersection

  ! FaceSelection
  ! Return the 4 vertices of face `id` from 3x8 `vertices` in 3x4 `face`.
  subroutine FaceSelection(vertices, id, face)
    implicit none
    real(8), dimension(3,8), intent(in)  :: vertices
    integer, intent(in)                  :: id
    real(8), dimension(3,4), intent(out) :: face

    integer               :: i
    real(8), dimension(3) :: A, B, C, D
    integer, parameter    :: index_map(24) = (/ 1,2,4,3, &
      1,3,7,5, &
      1,2,6,5, &
      2,4,8,6, &
      3,4,8,7, &
      5,6,8,7 /)

    i = id*4 - 3
    A = vertices(:, index_map(i))
    B = vertices(:, index_map(i+1))
    C = vertices(:, index_map(i+2))
    D = vertices(:, index_map(i+3))
    face = reshape((/ A, B, C, D /), (/ 3, 4 /))

  end subroutine FaceSelection

  ! HexahedronVolume
  ! Compute hexahedron volume by summing tetrahedron volumes
  subroutine HexahedronVolume(vertices, vol)
    implicit none
    real(8), dimension(3,8), intent(in) :: vertices
    real(8), intent(out)                :: vol

    integer               :: i
    real(8), dimension(3):: A, B, C, D
    real(8)               :: partialVol
    integer, parameter    :: index_map(24) = (/ 1,2,4,8, &
      2,5,6,8, &
      1,5,8,2, &
      1,3,4,8, &
      5,7,8,1, &
      1,3,7,8 /)

    vol = 0.0
    do i = 1, 24, 4
      A = vertices(:, index_map(i))
      B = vertices(:, index_map(i+1))
      C = vertices(:, index_map(i+2))
      D = vertices(:, index_map(i+3))
      call TetrahedronVolume(A, B, C, D, partialVol)
      vol = vol + partialVol
    end do

  end subroutine HexahedronVolume

  ! TetrahedronVolume
  subroutine TetrahedronVolume(A, B, C, D, vol)
    implicit none
    real(8), dimension(3), intent(in)  :: A, B, C, D
    real(8), intent(out)               :: vol

    real(8), dimension(3) :: AB, AC, AD

    AB = B - A
    AC = C - A
    AD = D - A
    vol = abs(dot_product(AB, cross_product(AC, AD))) / 6.0

  end subroutine TetrahedronVolume

  ! cross_product
  function cross_product(x, y) result(xprod)
    implicit none
    real(8), dimension(3) :: x, y
    real(8), dimension(3) :: xprod
    xprod(1) = x(2)*y(3) - x(3)*y(2)
    xprod(2) = x(3)*y(1) - x(1)*y(3)
    xprod(3) = x(1)*y(2) - x(2)*y(1)
  end function cross_product

  ! norm
  function norm(x) result(normx)
    implicit none
    real(8), dimension(3) :: x
    real(8)               :: normx
    normx = sqrt(x(1)**2 + x(2)**2 + x(3)**2)
  end function norm

  ! round
  function round(val, n, dim) result(roundedval)
    implicit none
    integer :: n, dim, i
    real(8), dimension(dim) :: val
    real(8), dimension(dim) :: roundedval
    do i = 1, dim
      roundedval(i) = anint(val(i) * 10.0**n) / 10.0**n
    end do
  end function round

end module intersection_mod
