module intersection_mod
  ! Geometry intersection utilities for hexahedral cells.
  ! Provides routines to compute intersections between hexahedra,
  ! check point-in-hexahedron, compute volumes and basic vector ops.
  implicit none
  private
  public :: convexHullVolume
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

  ! Volume of the convex hull of an arbitrary 3D point cloud (incremental
  ! beneath-beyond hull). Returns 0 for degenerate input (fewer than 4 points,
  ! or all points collinear/coplanar), matching scipy.spatial.ConvexHull.
  !
  ! The initial simplex is seeded from extreme points (maximum-separation pair,
  ! farthest-from-line, farthest-from-plane) so it is well conditioned even for
  ! thin/sliver clouds, and visibility uses a tolerance relative to that seed
  ! simplex. This makes the volume robust on the near-degenerate intersections
  ! that arise between overlapping chimera cells.
  subroutine convexHullVolume(pts, n, vol)
    implicit none
    integer, intent(in)  :: n
    real(8), intent(in)  :: pts(3,n)
    real(8), intent(out) :: vol

    ! Generous work-buffer capacity.  A simplicial 3-polytope on n points has at
    ! most 2n-4 faces, so 8*max(n,4) leaves ample head-room; the hard guards
    ! below make an out-of-bounds write impossible even if floating-point noise
    ! on a near-degenerate sliver momentarily breaks the horizon "disk"
    ! invariant (which would otherwise corrupt the heap and abort on return).
    integer :: faces(3, 8*max(n,4))
    integer :: newf(3, 8*max(n,4))
    logical :: visible(8*max(n,4))
    integer :: edges(2, 24*max(n,4))
    integer :: nf, nnew, ne, nkeep
    integer :: i, i1, i2, i3, i4, p, a, b, e, f
    real(8) :: c(3), scale, dmax, dd, vmax, tolv, nrm(3), v0(3), d
    logical :: found_reverse, skip

    vol = 0.d0
    if (n < 4) return

    scale = 0.d0
    do i = 1, n
      scale = max(scale, abs(pts(1,i)), abs(pts(2,i)), abs(pts(3,i)))
    end do
    if (scale <= 0.d0) return

    ! --- Extreme-point seeding of a well-conditioned initial tetrahedron -----
    i1 = 1
    do i = 2, n
      if (pts(1,i) < pts(1,i1)) i1 = i
    end do
    i2 = 0; dmax = -1.d0
    do i = 1, n
      dd = norm(pts(:,i)-pts(:,i1)); if (dd > dmax) then; dmax = dd; i2 = i; end if
    end do
    if (dmax <= 1.d-12*scale) return                       ! all coincident
    i3 = 0; dmax = -1.d0
    do i = 1, n
      dd = norm(cross_product(pts(:,i2)-pts(:,i1), pts(:,i)-pts(:,i1)))
      if (dd > dmax) then; dmax = dd; i3 = i; end if
    end do
    if (dmax <= 1.d-12*scale*scale) return                 ! collinear
    nrm = cross_product(pts(:,i2)-pts(:,i1), pts(:,i3)-pts(:,i1))
    i4 = 0; vmax = -1.d0
    do i = 1, n
      dd = abs(dot_product(nrm, pts(:,i)-pts(:,i1)))
      if (dd > vmax) then; vmax = dd; i4 = i; end if
    end do
    if (vmax <= 1.d-15*scale*scale*scale) return           ! coplanar -> vol 0

    c = 0.25d0*(pts(:,i1)+pts(:,i2)+pts(:,i3)+pts(:,i4))
    nf = 0
    call add_oriented(faces, nf, i1, i2, i3, pts, c)
    call add_oriented(faces, nf, i1, i2, i4, pts, c)
    call add_oriented(faces, nf, i1, i3, i4, pts, c)
    call add_oriented(faces, nf, i2, i3, i4, pts, c)

    ! Visibility tolerance relative to the seed simplex "thickness"
    tolv = 1.d-10 * vmax

    ! --- Incrementally add the remaining points ------------------------------
    do p = 1, n
      if (p==i1 .or. p==i2 .or. p==i3 .or. p==i4) cycle

      ne = 0
      skip = .false.
      do f = 1, nf
        v0  = pts(:, faces(1,f))
        nrm = cross_product(pts(:,faces(2,f))-v0, pts(:,faces(3,f))-v0)
        d   = dot_product(nrm, pts(:,p)-v0)
        visible(f) = (d > tolv)
        if (visible(f)) then
          if (ne+3 > size(edges,2)) then; skip = .true.; exit; end if
          edges(:, ne+1) = [faces(1,f), faces(2,f)]
          edges(:, ne+2) = [faces(2,f), faces(3,f)]
          edges(:, ne+3) = [faces(3,f), faces(1,f)]
          ne = ne + 3
        end if
      end do
      if (skip .or. ne == 0) cycle          ! p interior, or degenerate blow-up

      nnew = 0
      do e = 1, ne
        a = edges(1,e); b = edges(2,e)
        found_reverse = .false.
        do f = 1, ne
          if (edges(1,f)==b .and. edges(2,f)==a) then
            found_reverse = .true.; exit
          end if
        end do
        if (.not. found_reverse) then
          if (nnew+1 > size(newf,2)) then; skip = .true.; exit; end if
          nnew = nnew + 1
          newf(:, nnew) = [a, b, p]
        end if
      end do
      if (skip) cycle

      ! Would the rebuilt face list overrun the buffer?  Only possible on a
      ! degenerate horizon; skip p (treat as interior) rather than corrupt memory.
      nkeep = 0
      do e = 1, nf
        if (.not. visible(e)) nkeep = nkeep + 1
      end do
      if (nkeep + nnew > size(faces,2)) cycle

      f = 0
      do e = 1, nf
        if (.not. visible(e)) then
          f = f + 1
          faces(:,f) = faces(:,e)
        end if
      end do
      nf = f
      do e = 1, nnew
        nf = nf + 1
        faces(:,nf) = newf(:,e)
      end do
    end do

    vol = 0.d0
    do f = 1, nf
      vol = vol + dot_product(pts(:,faces(1,f)), &
                  cross_product(pts(:,faces(2,f)), pts(:,faces(3,f))))
    end do
    vol = abs(vol) / 6.d0

  end subroutine convexHullVolume

  ! Append triangle (ia,ib,ic) oriented so its normal points away from interior c.
  subroutine add_oriented(faces, nf, ia, ib, ic, pts, c)
    implicit none
    integer, intent(inout) :: faces(:,:), nf
    integer, intent(in)    :: ia, ib, ic
    real(8), intent(in)    :: pts(:,:), c(3)
    real(8) :: nrm(3)
    nf = nf + 1
    nrm = cross_product(pts(:,ib)-pts(:,ia), pts(:,ic)-pts(:,ia))
    if (dot_product(nrm, pts(:,ia)-c) >= 0.d0) then
      faces(:,nf) = [ia, ib, ic]
    else
      faces(:,nf) = [ia, ic, ib]
    end if
  end subroutine add_oriented


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

    ! Relative test: the coordinates reach this routine pre-scaled by fs, so an
    ! absolute tolerance on a volume is mesh-size dependent and drops below the
    ! roundoff of V as soon as the cells are not tiny.
    inside = abs(volHex - V) .le. max(toll1, 1.d-8*volHex)

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

    ! Relative for the same reason as pointInsideHexahedron: with pre-scaled
    ! coordinates an absolute area tolerance is far below the accuracy of the
    ! plane-plane intersection point being tested.
    inside = abs(areaQuad - (a1 + a2 + a3 + a4)) .le. max(toll1, 1.d-8*areaQuad)

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
