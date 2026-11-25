!> compute_volume (grid_mod) against volumes computed here: the integral of det J of the trilinear map of the eight
!> nodes by Gauss quadrature (exact: det J is of degree 2 in each variable), and closed forms for plane-faced cells.
program cell_volume_check
  use grid_mod, only: block_type
  implicit none
  integer, parameter :: R8 = kind(1.d0)
  !> (a, b, c) of node 1 + a + 2 b + 4 c of a cell, the order of compute_volume
  integer, parameter :: cn(3,8) = reshape([0,0,0, 1,0,0, 0,1,0, 1,1,0, 0,0,1, 1,0,1, 0,1,1, 1,1,1], [3,8])
  integer            :: nfail
  integer(8)         :: seed

  nfail = 0
  seed  = 20261125_8

  call twisted_cells()
  call tiled_box()
  call plane_faced_cells()
  call flat_cell()

  if (nfail > 0) then
    write(*,'(A,I0,A)') 'cell_volume_check: ', nfail, ' check(s) FAILED'
    stop 1
  endif
  write(*,'(A)') 'cell_volume_check: all checks passed'

contains

  !> Single cells, a cube of side h whose nodes are moved by up to t h per coordinate (twisted faces), far from the
  !> origin: the volume of the trilinear cell to round-off
  subroutine twisted_cells()
    type(block_type) :: b
    real(R8) :: p(3,8), o(3), h, t, v, emax
    real(R8), parameter :: twist(3) = [0.05_R8, 0.2_R8, 0.4_R8]
    integer  :: n, m, l
    do l = 1, 3
      t = twist(l)
      emax = 0
      do n = 1, 400
        h = 10._R8**(-6 + 6*rnd01())
        o = 1.e3_R8*h*rnd3()
        do m = 1, 8
          p(:,m) = o + h*(real(cn(:,m), R8) + t*rnd3())
        enddo
        call one_cell(b, p)
        call b%compute_volume([0, 0, 0])
        v = abs(gauss_volume(p))
        emax = max(emax, abs(b%vol(1,1,1) - v)/v)
        call b%destroy()
      enddo
      call check('twisted cells, nodes moved by up to '//trim(num(t))//' h, relative error', emax, 1.e-12_R8)
    enddo
  end subroutine twisted_cells

  !> A block of 5 x 4 x 3 cells in the box [0,2] x [0,1.5] x [0,1], every node moved by up to 0.3 cell: inner nodes in
  !> the three directions, nodes of the outer faces within their face, so that these stay plane. The volumes tile the
  !> box, each is that of its trilinear cell (one layer of ghost cells included), and the mirror image of the block,
  !> left-handed, has the same volumes
  subroutine tiled_box()
    integer, parameter :: ni = 5, nj = 4, nk = 3
    real(R8), parameter :: L(3) = [2._R8, 1.5_R8, 1._R8]
    type(block_type) :: b, bm
    real(R8) :: x(3,-1:ni+1,-1:nj+1,-1:nk+1), h(3), p(3,8), v, emax, s
    integer  :: n(3), i, j, k, m, d, ijk(3)
    n = [ni, nj, nk]
    h = L/real(n, R8)
    do k = -1, nk+1; do j = -1, nj+1; do i = -1, ni+1
      ijk = [i, j, k]
      do d = 1, 3
        x(d,i,j,k) = h(d)*ijk(d)
        if (ijk(d) > 0 .and. ijk(d) < n(d)) x(d,i,j,k) = x(d,i,j,k) + 0.3_R8*h(d)*rnd()
      enddo
    enddo; enddo; enddo

    call set_block(b, x, ni, nj, nk, 1)
    call b%compute_volume([1, 1, 1])
    s = sum(b%vol(1:ni,1:nj,1:nk))
    call check('tiled box, sum of the volumes against the box, relative', abs(s - product(L))/product(L), 1.e-13_R8)
    emax = 0
    do k = 0, nk+1; do j = 0, nj+1; do i = 0, ni+1
      do m = 1, 8
        p(:,m) = x(:, i-1+cn(1,m), j-1+cn(2,m), k-1+cn(3,m))
      enddo
      v = abs(gauss_volume(p))
      emax = max(emax, abs(b%vol(i,j,k) - v)/v)
    enddo; enddo; enddo
    call check('tiled box, each cell (ghost cells included) against its trilinear volume, relative', emax, 1.e-12_R8)

    x(1,:,:,:) = -x(1,:,:,:)
    call set_block(bm, x, ni, nj, nk, 1)
    call bm%compute_volume([1, 1, 1])
    call check('tiled box mirrored (left-handed), largest |volume / right-handed volume - 1|', &
               maxval(abs(bm%vol/b%vol - 1._R8)), 1.e-14_R8)
    call b%destroy()
    call bm%destroy()
  end subroutine tiled_box

  !> Cells with plane faces, whose volume has a closed form: an affine image of the unit cube (|det A|), a frustum of
  !> a square pyramid (H (a^2 + a b + b^2)/3) and a cell of a wedge, its k faces the meridional cell turned by
  !> -delta/2 and +delta/2 about the x axis (sin delta (x2 - x1) (r2^2 - r1^2)/2)
  subroutine plane_faced_cells()
    type(block_type) :: b
    real(R8) :: A(3,3), o(3), p(3,8), v, sa, sb, hh, x1, x2, r1, r2, delta, r
    integer  :: m
    A = reshape([1.3_R8, 0.2_R8, -0.4_R8, 0.5_R8, 0.9_R8, 0.1_R8, -0.3_R8, 0.6_R8, 1.1_R8], [3,3])
    o = [101._R8, -57._R8, 33._R8]
    do m = 1, 8
      p(:,m) = o + matmul(A, real(cn(:,m), R8))
    enddo
    v = abs(A(1,1)*(A(2,2)*A(3,3) - A(2,3)*A(3,2)) - A(1,2)*(A(2,1)*A(3,3) - A(2,3)*A(3,1)) &
          + A(1,3)*(A(2,1)*A(3,2) - A(2,2)*A(3,1)))
    call one_cell(b, p)
    call b%compute_volume([0, 0, 0])
    call check('affine image of a cube against |det A|, relative', abs(b%vol(1,1,1) - v)/v, 1.e-13_R8)
    call b%destroy()

    sa = 2._R8; sb = 0.7_R8; hh = 1.6_R8
    do m = 1, 8
      p(1:2,m) = merge(sb, sa, cn(3,m) == 1)*(real(cn(1:2,m), R8) - 0.5_R8)
      p(3,m)   = hh*cn(3,m)
    enddo
    v = hh*(sa**2 + sa*sb + sb**2)/3._R8
    call one_cell(b, p)
    call b%compute_volume([0, 0, 0])
    call check('frustum of a square pyramid against H (a^2 + a b + b^2)/3, relative', abs(b%vol(1,1,1) - v)/v, &
               1.e-13_R8)
    call b%destroy()

    x1 = 0.3_R8; x2 = 0.45_R8; r1 = 0.02_R8; r2 = 0.05_R8; delta = 5._R8*acos(-1._R8)/180._R8
    do m = 1, 8
      r = merge(r2, r1, cn(2,m) == 1)
      p(:,m) = [merge(x2, x1, cn(1,m) == 1), r*cos(delta/2), merge(1._R8, -1._R8, cn(3,m) == 1)*r*sin(delta/2)]
    enddo
    v = sin(delta)*(x2 - x1)*(r2**2 - r1**2)/2
    call one_cell(b, p)
    call b%compute_volume([0, 0, 0])
    call check('wedge cell against sin(delta) (x2 - x1) (r2^2 - r1^2)/2, relative', abs(b%vol(1,1,1) - v)/v, &
               1.e-13_R8)
    call b%destroy()
  end subroutine plane_faced_cells

  !> A cell whose eight nodes lie in one plane has no volume
  subroutine flat_cell()
    type(block_type) :: b
    real(R8) :: p(3,8)
    integer  :: m
    do m = 1, 8
      p(:,m) = real(cn(:,m), R8) + 0.1_R8*rnd3()
      p(3,m) = 0
    enddo
    call one_cell(b, p)
    call b%compute_volume([0, 0, 0])
    call check('cell with its nodes in one plane, volume', abs(b%vol(1,1,1)), 0._R8)
    call b%destroy()
  end subroutine flat_cell

  !> Signed volume of the trilinear cell of nodes p (node m at cn(:,m) of the unit cube): Gauss quadrature of det J at
  !> 3 x 3 x 3 points, on the nodes relative to node 1
  real(R8) function gauss_volume(p) result(v)
    real(R8), intent(in) :: p(3,8)
    real(R8) :: q(3,8), J(3,3), g(3), w(3), s(3)
    integer  :: a, bb, c, m
    g = [0.5_R8 - 0.5_R8*sqrt(0.6_R8), 0.5_R8, 0.5_R8 + 0.5_R8*sqrt(0.6_R8)]
    w = [5._R8, 8._R8, 5._R8]/18._R8
    do m = 1, 8
      q(:,m) = p(:,m) - p(:,1)
    enddo
    v = 0
    do c = 1, 3; do bb = 1, 3; do a = 1, 3
      s = [g(a), g(bb), g(c)]
      J = 0
      do m = 1, 8
        J(:,1) = J(:,1) + q(:,m)*dlin(cn(1,m))*lin(cn(2,m), s(2))*lin(cn(3,m), s(3))
        J(:,2) = J(:,2) + q(:,m)*lin(cn(1,m), s(1))*dlin(cn(2,m))*lin(cn(3,m), s(3))
        J(:,3) = J(:,3) + q(:,m)*lin(cn(1,m), s(1))*lin(cn(2,m), s(2))*dlin(cn(3,m))
      enddo
      v = v + w(a)*w(bb)*w(c)*(J(1,1)*(J(2,2)*J(3,3) - J(3,2)*J(2,3)) - J(1,2)*(J(2,1)*J(3,3) - J(3,1)*J(2,3)) &
                               + J(1,3)*(J(2,1)*J(3,2) - J(3,1)*J(2,2)))
    enddo; enddo; enddo
  end function gauss_volume

  !> 1-D shape function of the end a (0 or 1) at s, and its derivative
  pure real(R8) function lin(a, s)
    integer, intent(in)  :: a
    real(R8), intent(in) :: s
    lin = merge(s, 1._R8 - s, a == 1)
  end function lin

  pure real(R8) function dlin(a)
    integer, intent(in) :: a
    dlin = merge(1._R8, -1._R8, a == 1)
  end function dlin

  !> A block of one cell, nodes p
  subroutine one_cell(b, p)
    type(block_type), intent(inout) :: b
    real(R8), intent(in) :: p(3,8)
    real(R8) :: x(3,0:1,0:1,0:1)
    integer  :: m
    do m = 1, 8
      x(:, cn(1,m), cn(2,m), cn(3,m)) = p(:,m)
    enddo
    call set_block(b, x, 1, 1, 1, 0)
  end subroutine one_cell

  !> A block of ni x nj x nk cells, nodes x with g ghost layers
  subroutine set_block(b, x, ni, nj, nk, g)
    type(block_type), intent(inout) :: b
    integer, intent(in)  :: ni, nj, nk, g
    real(R8), intent(in) :: x(3,-g:ni+g,-g:nj+g,-g:nk+g)
    integer :: i, j, k
    b%dim = [ni, nj, nk]
    allocate(b%node(-g:ni+g,-g:nj+g,-g:nk+g))
    do k = -g, nk+g; do j = -g, nj+g; do i = -g, ni+g
      b%node(i,j,k)%c(1:3) = x(:,i,j,k)
      b%node(i,j,k)%c(4:5) = 0
    enddo; enddo; enddo
  end subroutine set_block

  subroutine check(what, err, tol)
    character(len=*), intent(in) :: what
    real(R8), intent(in) :: err, tol
    if (err <= tol) then
      write(*,'(A,ES10.3,A,ES9.2,A)') 'PASS ', err, ' (tol ', tol, ')  '//what
    else
      write(*,'(A,ES10.3,A,ES9.2,A)') 'FAIL ', err, ' (tol ', tol, ')  '//what
      nfail = nfail + 1
    endif
  end subroutine check

  character(len=8) function num(x)
    real(R8), intent(in) :: x
    write(num,'(F8.2)') x
    num = adjustl(num)
  end function num

  !> Uniform in [0, 1) and in [-1, 1): the minimal standard generator (Park and Miller), the same sequence with every
  !> compiler
  real(R8) function rnd01()
    seed = mod(16807_8*seed, 2147483647_8)
    rnd01 = real(seed - 1, R8)/2147483646._R8
  end function rnd01

  real(R8) function rnd()
    rnd = 2._R8*rnd01() - 1._R8
  end function rnd

  !> Three of them, drawn in order
  function rnd3() result(v)
    real(R8) :: v(3)
    integer  :: d
    do d = 1, 3
      v(d) = rnd()
    enddo
  end function rnd3

end program cell_volume_check
