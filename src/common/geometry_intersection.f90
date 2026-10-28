module intersection_mod
  ! Geometry utilities for the chimera overlap: the volume shared by two hexahedral
  ! cells by tetrahedral clipping, the point-in-hexahedron test, and basic vector ops.
  implicit none
  private
  public :: intersection_type, pointInsideHexahedron, hexOverlapVolume, FaceSelection, &
    TetrahedronVolume, cross_product, norm

  ! Intersection object: donor/receiver IDs and volume info
  type :: intersection_type
    integer   :: receiverID(4)
    integer   :: donorID(4)
    real(8)   :: inter_volume
    real(8)   :: volume_fraction
    logical   :: nodeinside(8)
  end type intersection_type

  real(8), parameter :: toll1 = 1e-4
  real(8), parameter, public :: fs=10000000

contains

  ! pointInsideHexahedron
  ! Test whether point P is inside a hexahedron defined by vertices.
  subroutine pointInsideHexahedron(P, vertices, inside)
    implicit none
    real(8), dimension(3), intent(in)        :: P
    real(8), dimension(3,8), intent(in)      :: vertices
    logical, intent(out)                     :: inside

    real(8)                   :: volHex, V
    real(8), dimension(3)     :: centroid

    ! Reference volume with the SAME face-pyramid decomposition used for P, evaluated
    ! at the centroid. A 5/6-tetrahedron cell volume differs from it by the
    ! volume swept by the non-planar (bilinear) faces: on the cells of a curved mesh
    ! that difference exceeds the tolerance below by orders of magnitude (1e-6..1e-2
    ! relative on an aerospike grid), and every point, the cell centre included,
    ! tested as outside, leaving chimera facelets without donors.
    centroid = sum(vertices, dim=2)/8.d0
    volHex = facePyramidVolume(centroid, vertices)
    V      = facePyramidVolume(P, vertices)

    ! Relative test: the coordinates reach this routine pre-scaled by fs, so an
    ! absolute tolerance on a volume is mesh-size dependent and drops below the
    ! roundoff of V as soon as the cells are not tiny.
    inside = abs(volHex - V) .le. max(toll1, 1.d-8*volHex)

  end subroutine pointInsideHexahedron

  ! facePyramidVolume
  ! Sum of the 12 tetrahedra between P and the two triangles (A,B,C), (A,D,C) of
  ! each face. For every P inside the hexahedron bounded by those triangles it
  ! equals the enclosed volume, whether the faces are planar or not; outside, it
  ! exceeds it.
  function facePyramidVolume(P, vertices) result(V)
    implicit none
    real(8), dimension(3), intent(in)        :: P
    real(8), dimension(3,8), intent(in)      :: vertices
    real(8)                                  :: V

    real(8)                   :: vol1, vol2
    real(8), dimension(3,4)   :: T
    integer                   :: i

    V = 0.d0
    do i = 1, 6
      call FaceSelection(vertices, i, T)
      call TetrahedronVolume(T(:,1), T(:,2), T(:,3), P, vol1)
      call TetrahedronVolume(T(:,1), T(:,4), T(:,3), P, vol2)
      V = V + vol1 + vol2
    end do

  end function facePyramidVolume

  ! hexOverlapVolume
  ! Volume shared by two hexahedra. Each is split into the 24 tetrahedra between
  ! its centroid and the four triangles (face centre, edge) of every face, with
  ! the sign of their orientation: the signed sum is the enclosed volume whatever
  ! the shape of the cell, warped or not convex, and two cells sharing a face
  ! split it the same way, so the cells of a block tile it without gaps or
  ! overlaps. The tetrahedron pairs are intersected exactly (tetOverlapVolume),
  ! which stays accurate on warped cells and on sliver or thin overlaps, where
  ! the face-face intersection of HexahedronIntesectingPoints is ill-conditioned.
  ! vol1 is the volume of hexahedron1 in the same decomposition.
  ! Node order as in the chimera search: 1 + 4*di + dj + 2*dk for the (i,j,k) corner.
  subroutine hexOverlapVolume(hexahedron1, hexahedron2, vol, vol1)
    implicit none
    real(8), dimension(3,8), intent(in) :: hexahedron1, hexahedron2
    real(8), intent(out)                :: vol
    real(8), optional, intent(out)      :: vol1

    real(8) :: t1(3,4,24), t2(3,4,24), s1(24), s2(24), o(3)
    real(8) :: lo1(3,24), hi1(3,24), lo2(3,24), hi2(3,24)
    integer :: a, b

    ! Relative to a node of the cells: the chimera coordinates come scaled by fs
    o = hexahedron1(:,1)
    call hexTetrahedra(hexahedron1, o, t1, s1)
    call hexTetrahedra(hexahedron2, o, t2, s2)
    do a = 1, 24
      lo1(:,a) = minval(t1(:,:,a), dim=2)
      hi1(:,a) = maxval(t1(:,:,a), dim=2)
      lo2(:,a) = minval(t2(:,:,a), dim=2)
      hi2(:,a) = maxval(t2(:,:,a), dim=2)
    end do

    vol = 0.d0
    do b = 1, 24
      if (s2(b) == 0.d0) cycle
      do a = 1, 24
        if (s1(a) == 0.d0) cycle
        if (any(lo1(:,a) > hi2(:,b)) .or. any(lo2(:,b) > hi1(:,a))) cycle
        vol = vol + s1(a)*s2(b)*tetOverlapVolume(t1(:,:,a), t2(:,:,b))
      end do
    end do
    vol = max(vol, 0.d0)

    if (present(vol1)) then
      vol1 = 0.d0
      do a = 1, 24
        vol1 = vol1 + s1(a)*abs(tetSignedVolume(t1(:,:,a)))
      end do
    end if

  end subroutine hexOverlapVolume

  ! hexTetrahedra
  ! The 24 tetrahedra (centroid, face centre, edge) of a hexahedron, translated by -o,
  ! and the sign of their volume relative to the whole cell (+1 everywhere on a
  ! regular cell, whether its (i,j,k) frame is right- or left-handed).
  subroutine hexTetrahedra(vertices, o, t, s)
    implicit none
    real(8), dimension(3,8), intent(in)   :: vertices
    real(8), dimension(3), intent(in)     :: o
    real(8), dimension(3,4,24), intent(out) :: t
    real(8), dimension(24), intent(out)   :: s

    ! The six faces as outward cycles (i-, i+, j-, j+, k-, k+)
    integer, parameter :: face(4,6) = reshape([1,3,4,2, 5,6,8,7, 1,5,7,3, &
                                               2,4,8,6, 1,2,6,5, 3,7,8,4], [4,6])
    real(8) :: v(3,8), c(3), f(3), sv, vol
    integer :: i, e, n

    do i = 1, 8
      v(:,i) = vertices(:,i) - o
    end do
    c = sum(v, dim=2)/8.d0
    n = 0
    vol = 0.d0
    do i = 1, 6
      f = (v(:,face(1,i)) + v(:,face(2,i)) + v(:,face(3,i)) + v(:,face(4,i)))/4.d0
      do e = 1, 4
        n = n + 1
        t(:,1,n) = c
        t(:,2,n) = f
        t(:,3,n) = v(:,face(e,i))
        t(:,4,n) = v(:,face(mod(e,4)+1,i))
        sv = tetSignedVolume(t(:,:,n))
        s(n) = sign(1.d0, sv)
        if (sv == 0.d0) s(n) = 0.d0
        vol = vol + sv
      end do
    end do
    if (vol < 0.d0) s = -s

  end subroutine hexTetrahedra

  ! tetOverlapVolume
  ! Volume of the intersection of two tetrahedra: A clipped by the four half-spaces
  ! of B, the clipped pieces kept as tetrahedra (a plane leaves at most three of one).
  function tetOverlapVolume(A, B) result(vol)
    implicit none
    real(8), dimension(3,4), intent(in) :: A, B
    real(8)                             :: vol

    integer, parameter :: MAXT = 81           ! 3**4 pieces after the four planes
    integer, parameter :: opp(3,4) = reshape([2,3,4, 1,3,4, 1,2,4, 1,2,3], [3,4])
    real(8) :: cur(3,4,MAXT), nxt(3,4,MAXT), nrm(3), q(3), d(4), side
    integer :: ncur, nnxt, f, p, i

    vol = 0.d0
    ncur = 1
    cur(:,:,1) = A
    do f = 1, 4
      ! Plane of the face of B opposite to vertex f, normal towards that vertex
      q    = B(:,opp(1,f))
      nrm  = cross_product(B(:,opp(2,f)) - q, B(:,opp(3,f)) - q)
      side = dot_product(nrm, B(:,f) - q)
      if (side == 0.d0) return                ! B is flat
      if (side < 0.d0) nrm = -nrm
      nnxt = 0
      do p = 1, ncur
        do i = 1, 4
          d(i) = dot_product(nrm, cur(:,i,p) - q)
        end do
        call clipTetrahedron(cur(:,:,p), d, nxt, nnxt)
      end do
      if (nnxt == 0) return
      ncur = nnxt
      cur(:,:,1:ncur) = nxt(:,:,1:ncur)
    end do

    do p = 1, ncur
      vol = vol + abs(tetSignedVolume(cur(:,:,p)))
    end do

  end function tetOverlapVolume

  ! clipTetrahedron
  ! Append to out the part of tetrahedron T where the plane distance d > 0, as
  ! one tetrahedron (one vertex inside) or the three of a prism (two or three inside).
  subroutine clipTetrahedron(T, d, out, nout)
    implicit none
    real(8), dimension(3,4), intent(in)    :: T
    real(8), dimension(4), intent(in)      :: d
    real(8), dimension(:,:,:), intent(inout) :: out
    integer, intent(inout)                 :: nout

    integer :: ins(4), outs(4), nin, nou, i
    real(8) :: p1(3), p2(3), p3(3), x1(3), x2(3), x3(3)

    if (all(d >= 0.d0)) then
      call put(T(:,1), T(:,2), T(:,3), T(:,4))
      return
    end if
    nin = 0; nou = 0
    do i = 1, 4
      if (d(i) > 0.d0) then
        nin = nin + 1; ins(nin) = i
      else
        nou = nou + 1; outs(nou) = i
      end if
    end do

    select case (nin)
    case (1)
      x1 = T(:,ins(1))
      call put(x1, cut(ins(1),outs(1)), cut(ins(1),outs(2)), cut(ins(1),outs(3)))
    case (2)
      ! Prism between the triangles (x1, p1, p2) and (x2, p3, p4), cut on the edges from x1 and x2
      x1 = T(:,ins(1)); x2 = T(:,ins(2))
      p1 = cut(ins(1),outs(1)); p2 = cut(ins(1),outs(2)); p3 = cut(ins(2),outs(1))
      call put(x1, p1, p2, x2)
      call put(p1, p2, x2, p3)
      call put(p2, x2, p3, cut(ins(2),outs(2)))
    case (3)
      ! Prism between the triangle (x1, x2, x3) and its cut along the edges to the outside vertex
      x1 = T(:,ins(1)); x2 = T(:,ins(2)); x3 = T(:,ins(3))
      p1 = cut(ins(1),outs(1)); p2 = cut(ins(2),outs(1)); p3 = cut(ins(3),outs(1))
      call put(x1, x2, x3, p1)
      call put(x2, x3, p1, p2)
      call put(x3, p1, p2, p3)
    end select

  contains

    ! Point of edge i-j on the plane (d(i) > 0 >= d(j))
    function cut(i, j) result(x)
      integer, intent(in) :: i, j
      real(8)             :: x(3)
      x = T(:,i) + (d(i)/(d(i) - d(j)))*(T(:,j) - T(:,i))
    end function cut

    subroutine put(a, b, c, e)
      real(8), intent(in) :: a(3), b(3), c(3), e(3)
      nout = nout + 1
      out(:,1,nout) = a
      out(:,2,nout) = b
      out(:,3,nout) = c
      out(:,4,nout) = e
    end subroutine put

  end subroutine clipTetrahedron

  ! tetSignedVolume
  function tetSignedVolume(T) result(vol)
    implicit none
    real(8), dimension(3,4), intent(in) :: T
    real(8)                             :: vol
    vol = dot_product(T(:,2) - T(:,1), cross_product(T(:,3) - T(:,1), T(:,4) - T(:,1)))/6.d0
  end function tetSignedVolume

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

end module intersection_mod
