module bc_connection_mod
  use grid_mod, only: fmn2ijk, mesh_cfg
  use bc_block_mod
  implicit none
  private
  public:: find_periodic, find_connect

contains

  subroutine find_periodic(blk)
    implicit none
    type(BC_block), intent(inout) :: blk(:)
    integer :: f1,m1,n1,b1,b2,f2,m2,n2,i2,j2,k2
    integer :: nb
    integer, allocatable :: nx(:), ny(:), nz(:)
    integer :: ib1,i1,j1,k1,if1
    integer :: ib2,if2
    integer :: di11(6),dj11(6),dk11(6)
    integer :: di01(6),dj01(6),dk01(6)
    integer :: di10(6),dj10(6),dk10(6)
    integer :: di00(6),dj00(6),dk00(6)

    real(8) :: x00,x10,x01,x11
    real(8) :: y00,y10,y01,y11
    real(8) :: z00,z10,z01,z11
    real(8) :: eix2up,eiy2up,eiz2up
    real(8) :: ejx1do,ejy1do,ejz1do
    real(8) :: ejx2do,ejy2do,ejz2do
    real(8) :: eix1do,eiy1do,eiz1do
    real(8) :: eix2do,eiy2do,eiz2do
    real(8) :: ejx2up,ejy2up,ejz2up

    real(8) :: aa(3,3),bb(3,3)
    real(8) :: dumii, dumij, dumji, dumjj
    integer :: nn

    nb = size(blk)
    allocate(nx(nb)); allocate(ny(nb)); allocate(nz(nb))

    do b1 = 1, nb
      nx(b1) = blk(b1)%dim(1)
      ny(b1) = blk(b1)%dim(2)
      nz(b1) = blk(b1)%dim(3)
    enddo

    do b1 = 1, nb
      do f1 = 1, blk(b1)%nfaces
        !$omp parallel private(m1,n1,b2,f2,m2,n2,i2,j2,k2)
        !$omp do collapse(2)
        do n1 = 1, blk(b1)%face(f1)%Nn
          do m1 = 1, blk(b1)%face(f1)%Nm
            if (blk(b1)%face(f1)%center(m1,n1)%bc%gp_id==201 .and. &
                blk(b1)%face(f1)%center(m1,n1)%bc%connection(3)>0) then
              if (blk(b1)%face(f1)%center(m1,n1)%bc%connection(1)==0) then
                b2 = b1
              else
                b2 = blk(b1)%face(f1)%center(m1,n1)%bc%connection(1)
                if (b1==b2) b2 = blk(b1)%face(f1)%center(m1,n1)%bc%connection(2)
              endif
              f2 = blk(b1)%face(f1)%center(m1,n1)%bc%connection(3)
              if (f1==f2) f2 = blk(b1)%face(f1)%center(m1,n1)%bc%connection(4)
              blk(b1)%face(f1)%center(m1,n1)%bc%adj_assigned = .true.
              m2 = m1
              n2 = n1
              call fmn2ijk(f2,m2,n2,nx(b2),ny(b2),nz(b2),i2,j2,k2)
              if (mesh_cfg%meshType == -2) then
              ! ----- Caso 2D: b, i, j, f -----
                blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(1) = b2
                blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(2) = i2
                blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(3) = j2
                blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(4) = f2
              else
                ! ----- Caso 3D: b, i, j, k, f -----
                blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(1) = b2
                blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(2) = i2
                blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(3) = j2
                blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(4) = k2
                blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(5) = f2
              end if
            endif
          enddo
        enddo
        !$omp end parallel
      enddo
    enddo

    ! The cells are paired by their face indices: right only when the two faces are images of each other
    call check_periodic_images(blk)

    ! parte sperimentale per la determinazione degli indici delle
    ! celle adiacenti a quella a cui e'connessa
    ! questa parte e' necessaria nel caso di flag VISC attivo

    di11(1) =-1; dj11(1) = 0; dk11(1) = 0
    di01(1) =-1; dj01(1) =-1; dk01(1) = 0
    di10(1) =-1; dj10(1) = 0; dk10(1) =-1
    di00(1) =-1; dj00(1) =-1; dk00(1) =-1

    di11(2) = 0; dj11(2) = 0; dk11(2) = 0
    di01(2) = 0; dj01(2) =-1; dk01(2) = 0
    di10(2) = 0; dj10(2) = 0; dk10(2) =-1
    di00(2) = 0; dj00(2) =-1; dk00(2) =-1

    di11(3) = 0; dj11(3) =-1; dk11(3) = 0
    di01(3) =-1; dj01(3) =-1; dk01(3) = 0
    di10(3) = 0; dj10(3) =-1; dk10(3) =-1
    di00(3) =-1; dj00(3) =-1; dk00(3) =-1

    di11(4) = 0; dj11(4) = 0; dk11(4) = 0
    di01(4) =-1; dj01(4) = 0; dk01(4) = 0
    di10(4) = 0; dj10(4) = 0; dk10(4) =-1
    di00(4) =-1; dj00(4) = 0; dk00(4) =-1

    di11(5) = 0; dj11(5) = 0; dk11(5) =-1
    di01(5) =-1; dj01(5) = 0; dk01(5) =-1
    di10(5) = 0; dj10(5) =-1; dk10(5) =-1
    di00(5) =-1; dj00(5) =-1; dk00(5) =-1

    di11(6) = 0; dj11(6) = 0; dk11(6) = 0
    di01(6) =-1; dj01(6) = 0; dk01(6) = 0
    di10(6) = 0; dj10(6) =-1; dk10(6) = 0
    di00(6) =-1; dj00(6) =-1; dk00(6) = 0

    di11 =di11+1; dj11 =dj11+1; dk11 = dk11+1
    di01 =di01+1; dj01 =dj01+1; dk01 = dk01+1
    di10 =di10+1; dj10 =dj10+1; dk10 =dk10+1
    di00 =di00+1; dj00 =dj00+1; dk00 =dk00+1

    do b1 = 1, nb
    do f1 = 1, blk(b1)%nfaces
      !$omp parallel private(m1,n1,ib1,ib2,if1,if2,i1,j1,k1,i2,j2,k2, &
      !$omp   x00,x10,x01,x11,y00,y10,y01,y11,z00,z10,z01,z11, &
      !$omp   eix1do,eiy1do,eiz1do,ejx1do,ejy1do,ejz1do, &
      !$omp   eix2do,eiy2do,eiz2do,ejx2do,ejy2do,ejz2do, &
      !$omp   eix2up,eiy2up,eiz2up,ejx2up,ejy2up,ejz2up, &
      !$omp   aa,bb,nn,dumii,dumij,dumji,dumjj)
      !$omp do collapse(2)
      do n1 = 1, blk(b1)%face(f1)%Nn
        do m1 = 1, blk(b1)%face(f1)%Nm

          if (blk(b1)%face(f1)%center(m1,n1)%bc%adj_assigned) then

            ! legge dati della faccia di contorno
            if1 = f1; ib1 = b1
            call fmn2ijk(f1,m1,n1,nx(b1),ny(b1),nz(b1),i1,j1,k1)
            i1 = i1-1; j1 = j1-1; k1 = k1-1

            x11 = blk(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(1)
            y11 = blk(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(2)
            z11 = blk(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(3)

            x01 = blk(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(1)
            y01 = blk(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(2)
            z01 = blk(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(3)

            x10 = blk(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(1)
            y10 = blk(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(2)
            z10 = blk(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(3)

            x00 = blk(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(1)
            y00 = blk(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(2)
            z00 = blk(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(3)

            eix1do= 0.5*(x11+x10)-0.5*(x01+x00)
            eiy1do= 0.5*(y11+y10)-0.5*(y01+y00)
            eiz1do= 0.5*(z11+z10)-0.5*(z01+z00)

            ejx1do= 0.5*(x11+x01)-0.5*(x10+x00)
            ejy1do= 0.5*(y11+y01)-0.5*(y10+y00)
            ejz1do= 0.5*(z11+z01)-0.5*(z10+z00)

            ! legge  dati della faccia a cui e' connessa la faccia di contorno

            if (mesh_cfg%meshType == -2) then
              ib2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(1)
              i2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(2)-1
              j2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(3)-1
              k2 = 0
              if2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(4)
            else
              ib2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(1)
              i2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(2)-1
              j2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(3)-1
              k2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(4)-1
              if2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(5)
            endif

            x11 = blk(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(1)
            y11 = blk(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(2)
            z11 = blk(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(3)

            x01 = blk(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(1)
            y01 = blk(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(2)
            z01 = blk(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(3)

            x10 = blk(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(1)
            y10 = blk(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(2)
            z10 = blk(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(3)

            x00 = blk(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(1)
            y00 = blk(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(2)
            z00 = blk(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(3)

            ! calcola base covariante associata alla faccia connessa

            eix2do= 0.5*(x11+x10)-0.5*(x01+x00)
            eiy2do= 0.5*(y11+y10)-0.5*(y01+y00)
            eiz2do= 0.5*(z11+z10)-0.5*(z01+z00)

            ejx2do= 0.5*(x11+x01)-0.5*(x10+x00)
            ejy2do= 0.5*(y11+y01)-0.5*(y10+y00)
            ejz2do= 0.5*(z11+z01)-0.5*(z10+z00)

            aa(1,1)=eix2do; aa(1,2)=eiy2do; aa(1,3)=eiz2do
            aa(2,1)=ejx2do; aa(2,2)=ejy2do; aa(2,3)=ejz2do
            ! aggiunge alla base definita sulla faccia il vettore perpr.
            ! ai due vettori della base (ottenuto tramite il prodotto vettore)
            aa(3,1)=  aa(1,2)*aa(2,3)-aa(1,3)*aa(2,2)
            aa(3,2)=-(aa(1,1)*aa(2,3)-aa(1,3)*aa(2,1))
            aa(3,3)=  aa(1,1)*aa(2,2)-aa(1,2)*aa(2,1)

            ! calcolo base controvariante associata alla faccia connessa
            nn=3
            call invmat(aa,bb,nn)

            eix2up=bb(1,1)
            eiy2up=bb(2,1)
            eiz2up=bb(3,1)

            ejx2up=bb(1,2)
            ejy2up=bb(2,2)
            ejz2up=bb(3,2)

            ! calcolo prodotti scalari tra i vettori della base covariante della
            ! faccia di contorno e la base controvariante della faccia connessa.

            dumii=eix1do*eix2up+eiy1do*eiy2up+eiz1do*eiz2up
            dumij=eix1do*ejx2up+eiy1do*ejy2up+eiz1do*ejz2up
            dumji=ejx1do*eix2up+ejy1do*eiy2up+ejz1do*eiz2up
            dumjj=ejx1do*ejx2up+ejy1do*ejy2up+ejz1do*ejz2up

            blk(b1)%face(f1)%center(m1,n1)%bc%connection(1) = NINT(dumii)
            blk(b1)%face(f1)%center(m1,n1)%bc%connection(2) = NINT(dumij)
            blk(b1)%face(f1)%center(m1,n1)%bc%connection(3) = NINT(dumji)
            blk(b1)%face(f1)%center(m1,n1)%bc%connection(4) = NINT(dumjj)

            ! The cells of the two faces are paired with the same indices on the face (m2 = m1, n2 = n1, above): the
            ! orientation is the identity, as AFUS sets it for its periodic BC (type 6, find_connect.F). The products of
            ! the two bases are not: the faces of a sector are turned by its angle, and with cells longer along one
            ! direction of the face than along the other a few degrees round the cross products to nonzero steps (up to
            ! 6 on the side faces of the 66 channels of a cooling jacket, 5.45 deg apart)
            blk(b1)%face(f1)%center(m1,n1)%bc%connection(1:4) = [1, 0, 0, 1]

          endif
        enddo
      enddo
      !$omp end parallel
    enddo
    enddo

  end subroutine find_periodic


  !> Geometric check of the periodic pairs (201). find_periodic pairs cell (m, n) of a face with cell (m, n) of the
  !> other face, which is right only when one face is the image of the other by a rigid motion x -> R x + t, with the
  !> nodes in the same index order: the solvers take the cells of the other face as ghost cells moved by that motion
  !> (FUSS fits it at set-up and makes the same check). For each periodic face (b1, f1) <- (b2, f2) the motion is fitted
  !> to the corners of the paired cells (least squares, B. K. P. Horn, J. Opt. Soc. Am. A 4, 1987), printed, and BCB
  !> stops when
  !>  - the two faces do not have the same numbers of cells along them;
  !>  - a corner lands farther than PERIODIC_MISFIT_MAX of the smallest half cell (across face f1) from the image of
  !>    its partner: nodes that do not coincide (another distribution along the face, cells in another order) or faces
  !>    that are not images of each other.
  subroutine check_periodic_images(blk)
    implicit none
    type(BC_block), intent(in) :: blk(:)
    real(8), parameter :: PERIODIC_MISFIT_MAX = 1d-3
    integer  :: b1, f1, b2, f2, m1, n1, dm, dn, c, np, kf
    logical  :: found, failed
    real(8)  :: pc(3), qc(3), S(3,3), R(3,3), t(3), misfit, hmin, ang, w(3), ax(3)
    real(8), allocatable :: p(:,:), q(:,:)

    kf = 5                                   ! index of the partner face in ci_properties (b, i, j, k, f)
    if (mesh_cfg%meshType == -2) kf = 4      ! 2-D records: b, i, j, f
    failed = .false.

    do b1 = 1, size(blk)
      do f1 = 1, blk(b1)%nfaces

        ! The periodic cells of the face and their partner face
        np = 0
        found = .false.
        b2 = 0; f2 = 0
        do n1 = 1, blk(b1)%face(f1)%Nn
          do m1 = 1, blk(b1)%face(f1)%Nm
            associate (bc => blk(b1)%face(f1)%center(m1,n1)%bc)
              if (bc%gp_id == 201 .and. bc%adj_assigned) then
                if (.not. found) then
                  b2 = bc%ci_properties(1)
                  f2 = bc%ci_properties(kf)
                  found = .true.
                endif
                np = np + 1
              endif
            end associate
          enddo
        enddo
        if (np == 0) cycle

        if (blk(b2)%face(f2)%Nm /= blk(b1)%face(f1)%Nm .or. blk(b2)%face(f2)%Nn /= blk(b1)%face(f1)%Nn) then
          write(*,'(*(g0))') '[ERROR] periodic faces: block ', b1, ' face ', f1, ' (', blk(b1)%face(f1)%Nm, ' x ', &
            blk(b1)%face(f1)%Nn, ' cells) and block ', b2, ' face ', f2, ' (', blk(b2)%face(f2)%Nm, ' x ', &
            blk(b2)%face(f2)%Nn, ' cells) do not have the same cells along them'
          failed = .true.
          cycle
        endif

        ! Corners of the paired cells: q on face f1, p the same corner on face f2
        allocate(p(3,4*np), q(3,4*np))
        c = 0
        hmin = huge(1d0)
        do n1 = 1, blk(b1)%face(f1)%Nn
          do m1 = 1, blk(b1)%face(f1)%Nm
            if (blk(b1)%face(f1)%center(m1,n1)%bc%gp_id /= 201 .or. &
                .not. blk(b1)%face(f1)%center(m1,n1)%bc%adj_assigned) cycle
            do dn = 0, 1
              do dm = 0, 1
                c = c + 1
                q(:,c) = face_node(blk(b1), f1, m1-1+dm, n1-1+dn, 0)
                p(:,c) = face_node(blk(b2), f2, m1-1+dm, n1-1+dn, 0)
                hmin = min(hmin, 0.5d0*norm2(face_node(blk(b1), f1, m1-1+dm, n1-1+dn, 1) - q(:,c)))
              enddo
            enddo
          enddo
        enddo

        ! Rigid motion q ~ R p + t and the largest distance of a corner from the image of its partner
        pc = sum(p, dim=2) / c
        qc = sum(q, dim=2) / c
        S = matmul(p - spread(pc, 2, c), transpose(q - spread(qc, 2, c)))
        call horn_rotation(S, R)
        t = qc - matmul(R, pc)
        misfit = maxval(norm2(matmul(R, p) + spread(t, 2, c) - q, dim=1))

        ang = acos(max(-1d0, min(1d0, 0.5d0*(R(1,1) + R(2,2) + R(3,3) - 1d0)))) * 180d0 / acos(-1d0)
        w = [R(3,2) - R(2,3), R(1,3) - R(3,1), R(2,1) - R(1,2)]
        ax = 0d0
        if (norm2(w) > 0d0) ax = w / norm2(w)
        write(*,'(A,I0,A,I0,A,I0,A,I0,A,F11.6,A,3F9.5,A,3ES11.3,A,ES9.2,A)') '  Periodic faces: block ', b1, &
          ' face ', f1, ' <- block ', b2, ' face ', f2, ': rotation ', ang, ' deg about (', ax, '), t = (', t, &
          ') m, misfit ', misfit / hmin, ' half cell'

        if (misfit > PERIODIC_MISFIT_MAX * hmin) then
          write(*,'(A,I0,A,I0,A,I0,A,I0,A,ES10.3,A,ES10.3,A)') '[ERROR] periodic faces: block ', b1, ' face ', f1, &
            ' and block ', b2, ' face ', f2, ' are not images by a rigid motion (misfit ', misfit, ' m, half cell ', &
            hmin, ' m)'
          write(*,'(A)') '        the nodes of the two faces must coincide, one face turned or moved onto the other, '// &
            'with the cells in the same index order'
          failed = .true.
        endif
        deallocate(p, q)

      enddo
    enddo

    if (failed) stop 1

  end subroutine check_periodic_images


  !> Node (mm, nn) (0 to Nm, 0 to Nn) of face f of a block, or with `inward` = 1 the node one layer inside the block.
  function face_node(b, f, mm, nn, inward) result(x)
    implicit none
    type(BC_block), intent(in) :: b
    integer,        intent(in) :: f, mm, nn, inward
    real(8) :: x(3)
    integer :: i, j, k, nd

    call fmn2ijk(f, mm, nn, b%dim(1), b%dim(2), b%dim(3), i, j, k)
    select case (f)            ! the plane of nodes of the face: 0 on the faces 1, 3, 5, dim on 2, 4, 6
      case (1); i = inward
      case (2); i = b%dim(1) - inward
      case (3); j = inward
      case (4); j = b%dim(2) - inward
      case (5); k = inward
      case (6); k = b%dim(3) - inward
    end select
    x = 0d0
    nd = min(3, size(b%node(i,j,k)%c))
    x(1:nd) = b%node(i,j,k)%c(1:nd)

  end function face_node


  !> Rotation R that best takes the set p onto the set q (q - qc ~ R (p - pc)), from their cross-covariance
  !> S(a,c) = sum (p_a - pc_a)(q_c - qc_c) (Horn 1987): the unit quaternion of the largest eigenvalue of the symmetric
  !> matrix N(S).
  subroutine horn_rotation(S, R)
    implicit none
    real(8), intent(in)  :: S(3,3)
    real(8), intent(out) :: R(3,3)
    real(8) :: N(4,4), V(4,4), lam(4), e(4)
    integer :: m(1)

    N(1,1) = S(1,1) + S(2,2) + S(3,3)
    N(1,2) = S(2,3) - S(3,2) ; N(1,3) = S(3,1) - S(1,3) ; N(1,4) = S(1,2) - S(2,1)
    N(2,2) = S(1,1) - S(2,2) - S(3,3)
    N(2,3) = S(1,2) + S(2,1) ; N(2,4) = S(3,1) + S(1,3)
    N(3,3) = - S(1,1) + S(2,2) - S(3,3)
    N(3,4) = S(2,3) + S(3,2)
    N(4,4) = - S(1,1) - S(2,2) + S(3,3)
    N(2,1) = N(1,2) ; N(3,1) = N(1,3) ; N(4,1) = N(1,4) ; N(3,2) = N(2,3) ; N(4,2) = N(2,4) ; N(4,3) = N(3,4)

    call jacobi_eigen4(N, lam, V)
    m = maxloc(lam)
    e = V(:,m(1)) / norm2(V(:,m(1)))     ! (w, x, y, z)
    R(1,1) = e(1)**2 + e(2)**2 - e(3)**2 - e(4)**2
    R(1,2) = 2d0 * (e(2)*e(3) - e(1)*e(4))
    R(1,3) = 2d0 * (e(2)*e(4) + e(1)*e(3))
    R(2,1) = 2d0 * (e(2)*e(3) + e(1)*e(4))
    R(2,2) = e(1)**2 - e(2)**2 + e(3)**2 - e(4)**2
    R(2,3) = 2d0 * (e(3)*e(4) - e(1)*e(2))
    R(3,1) = 2d0 * (e(2)*e(4) - e(1)*e(3))
    R(3,2) = 2d0 * (e(3)*e(4) + e(1)*e(2))
    R(3,3) = e(1)**2 - e(2)**2 - e(3)**2 + e(4)**2

  end subroutine horn_rotation


  !> Eigenvalues lam and eigenvectors (columns of V) of a symmetric 4x4 matrix A0: cyclic Jacobi rotations until the
  !> off-diagonal part is below 1e-15 of the norm of A0 (W. H. Press et al., Numerical Recipes, sec. 11.1).
  subroutine jacobi_eigen4(A0, lam, V)
    implicit none
    real(8), intent(in)  :: A0(4,4)
    real(8), intent(out) :: lam(4), V(4,4)
    real(8) :: A(4,4), off, nrm, theta, tt, cc, ss, apq, app, aqq, akp, akq
    integer :: sweep, ip, iq, k

    A = A0
    V = 0d0
    do k = 1, 4
      V(k,k) = 1d0
    enddo
    nrm = sqrt(sum(A**2))
    do sweep = 1, 100
      off = 0d0
      do ip = 1, 3
        do iq = ip + 1, 4
          off = off + A(ip,iq)**2
        enddo
      enddo
      if (sqrt(off) <= 1d-15 * nrm .or. nrm == 0d0) exit
      do ip = 1, 3
        do iq = ip + 1, 4
          apq = A(ip,iq)
          if (apq == 0d0) cycle
          app = A(ip,ip) ; aqq = A(iq,iq)
          theta = (aqq - app) / (2d0 * apq)
          tt = sign(1d0, theta) / (abs(theta) + sqrt(theta**2 + 1d0))
          cc = 1d0 / sqrt(tt**2 + 1d0)
          ss = tt * cc
          do k = 1, 4
            if (k == ip .or. k == iq) cycle
            akp = A(k,ip) ; akq = A(k,iq)
            A(k,ip) = cc * akp - ss * akq ; A(ip,k) = A(k,ip)
            A(k,iq) = ss * akp + cc * akq ; A(iq,k) = A(k,iq)
          enddo
          A(ip,ip) = app - tt * apq
          A(iq,iq) = aqq + tt * apq
          A(ip,iq) = 0d0 ; A(iq,ip) = 0d0
          do k = 1, 4
            akp = V(k,ip) ; akq = V(k,iq)
            V(k,ip) = cc * akp - ss * akq
            V(k,iq) = ss * akp + cc * akq
          enddo
        enddo
      enddo
    enddo
    do k = 1, 4
      lam(k) = A(k,k)
    enddo

  end subroutine jacobi_eigen4



  !> `skip_chimera` leaves the faces declared 'chimera' to the overset search.
  !> BC-force-connect summary (called by find_connect). The face-centre matching works cell by cell: on a face
  !> declared with another BC (inlet, gsi, wall, symmetry, ...) the cells that coincide with a cell of another
  !> block are written as a connection (101/103) and the other cells keep the declared BC. This is the designed
  !> use of the switch (docs/user-guide/bcb/connectivity.md): an injection plate declared inlet whose holes are
  !> blocks of their own needs no multipatch. One [LOG] line per such face; a [WARNING] only for a declared
  !> section left with no cell on the face (the declaration has no effect there). The cells of one face are
  !> contiguous in the find_connect ordering (block, face, n, m).
  subroutine report_forced_connections(blk, b, f, m, n, def0, def, prop)
    implicit none
    type(BC_block), intent(in) :: blk(:)
    integer, intent(in) :: b(:), f(:), m(:), n(:), def0(:), def(:), prop(:,:)
    integer :: i, k, i0, i1, nconn, nkept, np, nw, ifirst
    integer :: partner(8)
    logical :: seen
    character(len=20) :: nm
    character(len=120) :: blist
    character(len=12) :: tmp
    i0 = 1
    do while (i0 <= size(b))
      i1 = i0
      do while (i1 < size(b))
        if (b(i1+1) /= b(i0) .or. f(i1+1) /= f(i0)) exit
        i1 = i1 + 1
      enddo
      nconn = 0; nkept = 0; np = 0; partner = 0; ifirst = 0
      do i = i0, i1
        if (def0(i) == 100 .or. def0(i) == 101 .or. def0(i) == 103) cycle   ! declared connection/chimera
        if (ifirst == 0) ifirst = i
        if (def(i) == 101 .or. def(i) == 103) then
          nconn = nconn + 1
          if (np < size(partner)) then
            if (.not. any(partner(1:np) == prop(i,1))) then
              np = np + 1; partner(np) = prop(i,1)
            endif
          endif
        else
          nkept = nkept + 1
        endif
      enddo
      if (nconn > 0) then
        blist = ''
        do k = 1, np
          write(tmp,'(I0)') partner(k); blist = trim(blist)//' '//trim(tmp)
        enddo
        write(*,'(A,I0,A,I0,A,I0,A,A,A,I0,A)') ' [LOG] BC-force-connect: block ', blk(b(i0))%id, ' face ', f(i0), ': ', &
          nconn, ' cells connected to block(s)', trim(blist), ', ', nkept, ' cells keep the declared BC ['// &
          trim(blk(b(ifirst))%face(f(ifirst))%center(m(ifirst),n(ifirst))%bc%name)//']'
        do i = i0, i1   ! one check per declared section of the face: is any of its cells left with the declared BC?
          if (def0(i) == 100 .or. def0(i) == 101 .or. def0(i) == 103) cycle
          if (def(i) /= 101 .and. def(i) /= 103) cycle
          nm = blk(b(i))%face(f(i))%center(m(i),n(i))%bc%name
          seen = .false.
          do k = i0, i - 1
            if (def0(k) == 100 .or. def0(k) == 101 .or. def0(k) == 103) cycle
            if (def(k) /= 101 .and. def(k) /= 103) cycle
            if (blk(b(k))%face(f(k))%center(m(k),n(k))%bc%name == nm) then
              seen = .true.; exit
            endif
          enddo
          if (seen) cycle
          nw = 0
          do k = i0, i1
            if (def0(k) == 100 .or. def0(k) == 101 .or. def0(k) == 103) cycle
            if (def(k) == 101 .or. def(k) == 103) cycle
            if (blk(b(k))%face(f(k))%center(m(k),n(k))%bc%name == nm) nw = nw + 1
          enddo
          if (nw == 0) write(*,'(A,I0,A,I0,A)') '[WARNING] BC-force-connect: block ', blk(b(i0))%id, ' face ', f(i0), &
            ': every cell declared ['//trim(nm)//'] is connected to another block, the declared BC has no effect '// &
            '(declare the face connection, or set BC-force-connect = F to keep the declared BC)'
        enddo
      endif
      i0 = i1 + 1
    enddo
  end subroutine report_forced_connections


  subroutine find_connect(blk,force_connect,skip_chimera)
    use bc_names_mod, only: MARKER_CONN, MARKER_Chim
    implicit none
    type(BC_block), intent(inout) :: blk(:)
    logical, intent(in) :: force_connect
    logical, intent(in), optional :: skip_chimera
    real(8), allocatable  :: x(:), y(:), z(:)
    integer, allocatable :: b(:), f(:), n(:), m(:), def(:), prop(:,:), match(:)
    integer, allocatable :: def0(:)
    logical, allocatable :: adj(:), usable(:), declared(:)
    logical :: no_chimera
    integer :: nmissing
    integer :: nb, nbound
    integer, allocatable :: nboundb(:)
    integer, allocatable :: nx(:), ny(:), nz(:)
    integer :: f1,m1,n1,b1,b2,f2,m2,n2,i,j,blocal
    integer :: ib1,i1,j1,k1,if1,p1
    integer :: ib2,i2,j2,k2,if2,p2
    integer :: di11(6),dj11(6),dk11(6)
    integer :: di01(6),dj01(6),dk01(6)
    integer :: di10(6),dj10(6),dk10(6)
    integer :: di00(6),dj00(6),dk00(6)

    real(8) :: x00,x10,x01,x11
    real(8) :: y00,y10,y01,y11
    real(8) :: z00,z10,z01,z11
    real(8) :: eix2up,eiy2up,eiz2up
    real(8) :: ejx1do,ejy1do,ejz1do
    real(8) :: ejx2do,ejy2do,ejz2do
    real(8) :: eix1do,eiy1do,eiz1do
    real(8) :: eix2do,eiy2do,eiz2do
    real(8) :: ejx2up,ejy2up,ejz2up

    real(8) :: aa(3,3),bb(3,3)
    real(8) :: dum1, dumii, dumij, dumji, dumjj
    integer :: nn

    ! si calcola le distanze dal centro della faccia dai centri di tutte le altre
    ! faccie di contorno dei blocchi
    ! se tale distanza e' mininore della tolleranza allora
    ! le due faccie sono connesse

    if (mesh_cfg%meshType==-1) return

    no_chimera = .false.
    if (present(skip_chimera)) no_chimera = skip_chimera

    nb = size(blk)
    allocate(nboundb(nb))
    allocate(nx(nb)); allocate(ny(nb)); allocate(nz(nb))

    ! Store data in local variables
    nbound = 0; nboundb = 0; blocal = 1
    do b1 = 1, nb
      nx(b1) = blk(b1)%dim(1)
      ny(b1) = blk(b1)%dim(2)
      nz(b1) = blk(b1)%dim(3)
      do f1 = 1, blk(b1)%nfaces
        nboundb(b1) = nboundb(b1)+(blk(b1)%face(f1)%Nm*blk(b1)%face(f1)%Nn)
        nbound = nbound+(blk(b1)%face(f1)%Nm*blk(b1)%face(f1)%Nn)
      enddo
    enddo
    allocate(x(1:nbound)); allocate(y(1:nbound)); allocate(z(1:nbound))
    allocate(b(1:nbound)); allocate(f(1:nbound)); allocate(m(1:nbound))
    allocate(n(1:nbound)); allocate(def(1:nbound)); allocate(adj(1:nbound))
    allocate(usable(1:nbound)); allocate(declared(1:nbound))

    if (mesh_cfg%meshType == -2) then
      allocate(prop(1:nbound,1:4))
    else
      allocate(prop(1:nbound,1:5))
    endif

    i = 0
    do b1 = 1, nb
      do f1 = 1, blk(b1)%nfaces
        do n1 = 1, blk(b1)%face(f1)%Nn
          do m1 = 1, blk(b1)%face(f1)%Nm
            i = i +1
            associate( this => blk(b1)%face(f1)%center(m1,n1) )
            def(i) = this%bc%gp_id
            adj(i) = this%bc%adj_assigned
            declared(i) = trim(this%bc%definition)==trim(MARKER_CONN)
            usable(i) = (def(i)==100 .or. force_connect) .and. &
                        .not.(no_chimera .and. trim(this%bc%definition)==trim(MARKER_Chim))
            x(i) = this%c(1)
            y(i) = this%c(2)
            z(i) = this%c(3)
            m(i) = m1
            n(i) = n1
            f(i) = f1
            b(i) = b1
            endassociate
          enddo
        enddo
      enddo
    enddo

    ! Phase 1: parallel distance search — find match candidate for each i
    allocate(match(1:nbound))
    match = 0
    !$omp parallel do schedule(dynamic) private(i,j,blocal,dum1)
    do i = 1, nbound
      if (.not.usable(i)) cycle
      if (adj(i)) cycle
      blocal = 1
      do while (i>sum(nboundb(1:blocal)))
        blocal = blocal+1
      enddo
      do j = sum(nboundb(1:blocal))+1, nbound
        if (.not.usable(j)) cycle
        if (adj(j)) cycle
        dum1 = (x(i)-x(j))**2 + (y(i)-y(j))**2 + (z(i)-z(j))**2
        if (sqrt(dum1)<1d-7) then
          match(i) = j
          exit
        endif
      enddo
    enddo
    !$omp end parallel do

    def0 = def   ! BC codes as declared, before the connection overwrites them (BC-force-connect diagnostic)
    ! Phase 2: serial apply — no race conditions
    do i = 1, nbound
      j = match(i)
      if (j==0) cycle 
      if (adj(i) .or. adj(j)) cycle
      
      b1 = b(i); f1 = f(i); m1 = m(i); n1 = n(i)
      b2 = b(j); f2 = f(j); m2 = m(j); n2 = n(j)
      call fmn2ijk(f1,m1,n1,nx(b1),ny(b1),nz(b1),i1,j1,k1)
      call fmn2ijk(f2,m2,n2,nx(b2),ny(b2),nz(b2),i2,j2,k2)
      def(i) = 103; def(j) = 103
      do p1 = 1, size(blk(b1)%associated_phase)
        do p2 = 1, size(blk(b2)%associated_phase)
          if (blk(b1)%associated_phase(p1)%name==blk(b2)%associated_phase(p2)%name) then
            def(i) = 101; def(j) = 101
          endif
        enddo
      enddo
      if (mesh_cfg%meshType == -2) then
        adj(i) = .true.
        prop(i,1) = b2; prop(i,2) = i2; prop(i,3) = j2; prop(i,4) = f2
        adj(j) = .true.
        prop(j,1) = b1; prop(j,2) = i1; prop(j,3) = j1; prop(j,4) = f1
      else
        adj(i) = .true.
        prop(i,1) = b2; prop(i,2) = i2; prop(i,3) = j2; prop(i,4) = k2; prop(i,5) = f2
        adj(j) = .true.
        prop(j,1) = b1; prop(j,2) = i1; prop(j,3) = j1; prop(j,4) = k1; prop(j,5) = f1
      endif
    enddo
    deallocate(match)

    ! BC-force-connect: the declared BC of the cells connected above is replaced cell by cell (report_forced_connections)
    if (force_connect) call report_forced_connections(blk, b, f, m, n, def0, def, prop)

    nmissing = count(declared .and. .not.adj)
    if (nmissing>0) then
      write(*,'(A,I0,A)') ' [WARNING] ', nmissing, ' cells declared as connection found no matching face center'
      write(*,'(A)')      '           they are left to the chimera search if it is enabled'
      do i = 1, nbound
        if (declared(i) .and. .not.adj(i)) then
          write(*,'(A,4(X,I0))') '           first unmatched (block, face, m, n):', b(i), f(i), m(i), n(i)
          exit
        endif
      enddo
    endif


    do b1 = 1, nb
      do f1 = 1, blk(b1)%nfaces
        ! Recalculate linear offset for this (b1,f1) pair
        i = 0
        do b2 = 1, b1-1
          do f2 = 1, blk(b2)%nfaces
            i = i + blk(b2)%face(f2)%Nm * blk(b2)%face(f2)%Nn
          enddo
        enddo
        do f2 = 1, f1-1
          i = i + blk(b1)%face(f2)%Nm * blk(b1)%face(f2)%Nn
        enddo
        !$omp parallel private(m1,n1,j)
        !$omp do collapse(2)
        do n1 = 1, blk(b1)%face(f1)%Nn
          do m1 = 1, blk(b1)%face(f1)%Nm
            j = i + (n1-1)*blk(b1)%face(f1)%Nm + m1
            if ((def(j)==101 .or. def(j)==103) .and. adj(j)) then
              blk(b1)%face(f1)%center(m1,n1)%bc%gp_id = def(j)
              blk(b1)%face(f1)%center(m1,n1)%bc%adj_assigned = adj(j)
              blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(:) = prop(j,:)
              if (any(prop(j,:)==0)) then
                !$omp critical(conn_print)
                write(*,*) "[ERROR] Connection not found"
                write(*,*) "        b, f, m, n", b1, f1, m1, n1
                !$omp end critical(conn_print)
                stop 1
              endif
            endif
          enddo
        enddo
        !$omp end parallel
      enddo
    enddo

    di11(1) =-1; dj11(1) = 0; dk11(1) = 0
    di01(1) =-1; dj01(1) =-1; dk01(1) = 0
    di10(1) =-1; dj10(1) = 0; dk10(1) =-1
    di00(1) =-1; dj00(1) =-1; dk00(1) =-1

    di11(2) = 0; dj11(2) = 0; dk11(2) = 0
    di01(2) = 0; dj01(2) =-1; dk01(2) = 0
    di10(2) = 0; dj10(2) = 0; dk10(2) =-1
    di00(2) = 0; dj00(2) =-1; dk00(2) =-1

    di11(3) = 0; dj11(3) =-1; dk11(3) = 0
    di01(3) =-1; dj01(3) =-1; dk01(3) = 0
    di10(3) = 0; dj10(3) =-1; dk10(3) =-1
    di00(3) =-1; dj00(3) =-1; dk00(3) =-1

    di11(4) = 0; dj11(4) = 0; dk11(4) = 0
    di01(4) =-1; dj01(4) = 0; dk01(4) = 0
    di10(4) = 0; dj10(4) = 0; dk10(4) =-1
    di00(4) =-1; dj00(4) = 0; dk00(4) =-1

    di11(5) = 0; dj11(5) = 0; dk11(5) =-1
    di01(5) =-1; dj01(5) = 0; dk01(5) =-1
    di10(5) = 0; dj10(5) =-1; dk10(5) =-1
    di00(5) =-1; dj00(5) =-1; dk00(5) =-1

    di11(6) = 0; dj11(6) = 0; dk11(6) = 0
    di01(6) =-1; dj01(6) = 0; dk01(6) = 0
    di10(6) = 0; dj10(6) =-1; dk10(6) = 0
    di00(6) =-1; dj00(6) =-1; dk00(6) = 0

    di11 =di11+1; dj11 =dj11+1; dk11 = dk11+1
    di01 =di01+1; dj01 =dj01+1; dk01 = dk01+1
    di10 =di10+1; dj10 =dj10+1; dk10 =dk10+1
    di00 =di00+1; dj00 =dj00+1; dk00 =dk00+1

    do b1 = 1, nb
    do f1 = 1, blk(b1)%nfaces
      !$omp parallel private(m1,n1,ib1,ib2,if1,if2,i1,j1,k1,i2,j2,k2, &
      !$omp   x00,x10,x01,x11,y00,y10,y01,y11,z00,z10,z01,z11, &
      !$omp   eix1do,eiy1do,eiz1do,ejx1do,ejy1do,ejz1do, &
      !$omp   eix2do,eiy2do,eiz2do,ejx2do,ejy2do,ejz2do, &
      !$omp   eix2up,eiy2up,eiz2up,ejx2up,ejy2up,ejz2up, &
      !$omp   aa,bb,nn,dumii,dumij,dumji,dumjj)
      !$omp do collapse(2)
      do n1 = 1, blk(b1)%face(f1)%Nn
        do m1 = 1, blk(b1)%face(f1)%Nm

          ! The periodic faces (201) keep the orientation of find_periodic, the identity of their index map
          if (blk(b1)%face(f1)%center(m1,n1)%bc%adj_assigned .and. &
              blk(b1)%face(f1)%center(m1,n1)%bc%gp_id /= 201) then

            if1 = f1; ib1 = b1
            call fmn2ijk(f1,m1,n1,nx(b1),ny(b1),nz(b1),i1,j1,k1)
            i1 = i1-1; j1 = j1-1; k1 = k1-1

            x11 = blk(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(1)
            y11 = blk(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(2)
            z11 = blk(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(3)

            x01 = blk(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(1)
            y01 = blk(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(2)
            z01 = blk(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(3)

            x10 = blk(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(1)
            y10 = blk(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(2)
            z10 = blk(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(3)

            x00 = blk(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(1)
            y00 = blk(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(2)
            z00 = blk(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(3)

            eix1do= 0.5*(x11+x10)-0.5*(x01+x00)
            eiy1do= 0.5*(y11+y10)-0.5*(y01+y00)
            eiz1do= 0.5*(z11+z10)-0.5*(z01+z00)

            ejx1do= 0.5*(x11+x01)-0.5*(x10+x00)
            ejy1do= 0.5*(y11+y01)-0.5*(y10+y00)
            ejz1do= 0.5*(z11+z01)-0.5*(z10+z00)

            if (mesh_cfg%meshType == -2) then
              ib2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(1)
              i2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(2)-1
              j2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(3)-1
              k2 = 0
              if2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(4)
            else
              ib2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(1)
              i2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(2)-1
              j2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(3)-1
              k2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(4)-1
              if2 = blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(5)
            endif

            x11 = blk(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(1)
            y11 = blk(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(2)
            z11 = blk(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(3)

            x01 = blk(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(1)
            y01 = blk(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(2)
            z01 = blk(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(3)

            x10 = blk(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(1)
            y10 = blk(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(2)
            z10 = blk(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(3)

            x00 = blk(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(1)
            y00 = blk(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(2)
            z00 = blk(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(3)

            eix2do= 0.5*(x11+x10)-0.5*(x01+x00)
            eiy2do= 0.5*(y11+y10)-0.5*(y01+y00)
            eiz2do= 0.5*(z11+z10)-0.5*(z01+z00)

            ejx2do= 0.5*(x11+x01)-0.5*(x10+x00)
            ejy2do= 0.5*(y11+y01)-0.5*(y10+y00)
            ejz2do= 0.5*(z11+z01)-0.5*(z10+z00)

            aa(1,1)=eix2do; aa(1,2)=eiy2do; aa(1,3)=eiz2do
            aa(2,1)=ejx2do; aa(2,2)=ejy2do; aa(2,3)=ejz2do
            aa(3,1)=  aa(1,2)*aa(2,3)-aa(1,3)*aa(2,2)
            aa(3,2)=-(aa(1,1)*aa(2,3)-aa(1,3)*aa(2,1))
            aa(3,3)=  aa(1,1)*aa(2,2)-aa(1,2)*aa(2,1)

            nn=3
            call invmat(aa,bb,nn)

            eix2up=bb(1,1)
            eiy2up=bb(2,1)
            eiz2up=bb(3,1)

            ejx2up=bb(1,2)
            ejy2up=bb(2,2)
            ejz2up=bb(3,2)

            dumii=eix1do*eix2up+eiy1do*eiy2up+eiz1do*eiz2up
            dumij=eix1do*ejx2up+eiy1do*ejy2up+eiz1do*ejz2up
            dumji=ejx1do*eix2up+ejy1do*eiy2up+ejz1do*eiz2up
            dumjj=ejx1do*ejx2up+ejy1do*ejy2up+ejz1do*ejz2up

            blk(b1)%face(f1)%center(m1,n1)%bc%connection(1) = NINT(dumii)
            blk(b1)%face(f1)%center(m1,n1)%bc%connection(2) = NINT(dumij)
            blk(b1)%face(f1)%center(m1,n1)%bc%connection(3) = NINT(dumji)
            blk(b1)%face(f1)%center(m1,n1)%bc%connection(4) = NINT(dumjj)

          endif
        enddo
      enddo
      !$omp end parallel
    enddo
    enddo

    do b1 = 1, nb
      do f1 = 1, blk(b1)%nfaces
        ! Recalculate linear offset for this (b1,f1) pair
        i = 0
        do b2 = 1, b1-1
          do f2 = 1, blk(b2)%nfaces
            i = i + blk(b2)%face(f2)%Nm * blk(b2)%face(f2)%Nn
          enddo
        enddo
        do f2 = 1, f1-1
          i = i + blk(b1)%face(f2)%Nm * blk(b1)%face(f2)%Nn
        enddo
        !$omp parallel private(m1,n1,j)
        !$omp do collapse(2)
        do n1 = 1, blk(b1)%face(f1)%Nn
          do m1 = 1, blk(b1)%face(f1)%Nm
            j = i + (n1-1)*blk(b1)%face(f1)%Nm + m1
            if ((def(j)==101 .or. def(j)==103) .and. adj(j)) &
              blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(1) = blk(prop(j,1))%id
            ! Periodic faces (201, find_periodic): the partner block is the number of the mesh (the blocks key of the
            ! section), which the loop above has used as an index; the BC file of the phase numbers its own blocks
            ! (blk%id), as for the connections. With the blocks of more than one phase in the mesh the two differ
            if (def(j)==201 .and. adj(j)) then
              blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(1) = &
                blk(blk(b1)%face(f1)%center(m1,n1)%bc%ci_properties(1))%id
            endif
          enddo
        enddo
        !$omp end parallel
      enddo
    enddo

  end subroutine find_connect

subroutine invmat(a,b,r)
  implicit none
  integer :: r,j,i,k,l
  real(8) :: a(3,3),b(3,3),c(3,3)
  real(8) :: s, t
  
      do 2 i=1,r
        do 3 j=1,r
          b(i,j)=0.d+00
          c(i,j)=a(i,j)
3       continue
2     continue
      do 1 i=1,r
        b(i,i)=1.d+00
1     continue
      do 10 j=1,r
        do 20 i=j,r
          if(a(i,j).ne.0.) goto 210
20      continue
        do 21 i=1,r
          if(a(j,i).ne.0.) goto 211
21      continue
        error stop 'invmat: singular matrix'
211     error stop 'invmat: singular matrix'
210     do 30 k=1,r
         s=a(j,k)
         a(j,k)=a(i,k)
         a(i,k)=s
         s=b(j,k)
         b(j,k)=b(i,k)
         b(i,k)=s
30      continue
        t=1/a(j,j)
        do 40 k=1,r
          a(j,k)=t*a(j,k)
          b(j,k)=t*b(j,k)
40      continue
        do 50 l=1,r
          if(l.eq.j) goto 50
          t=-a(l,j)
          do 60 k=1,r
            a(l,k)=a(l,k)+t*a(j,k)
            b(l,k)=b(l,k)+t*b(j,k)
60        continue
50      continue
10    continue
      do 110 i=1,r
        do 120 j=1,r
          a(i,j)=c(i,j)
120     continue
110   continue
      end

end module bc_connection_mod