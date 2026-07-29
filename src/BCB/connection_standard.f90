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
            associate( this => blk(b1)%face(f1)%center(m1,n1) )
            if (this%bc%gp_id==201 .and. this%bc%connection(3)>0) then
              if (this%bc%connection(1)==0) then
                b2 = b1
              else
                b2 = this%bc%connection(1)
                if (b1==b2) b2 = this%bc%connection(2)
              endif
              f2 = this%bc%connection(3)
              if (f1==f2) f2 = this%bc%connection(4)
              this%bc%adj_assigned = .true.
              m2 = m1
              n2 = n1
              call fmn2ijk(f2,m2,n2,nx(b2),ny(b2),nz(b2),i2,j2,k2)
              if (mesh_cfg%meshType == -2) then
              ! ----- Caso 2D: b, i, j, f -----
                this%bc%ci_properties(1) = b2
                this%bc%ci_properties(2) = i2
                this%bc%ci_properties(3) = j2
                this%bc%ci_properties(4) = f2
              else
                ! ----- Caso 3D: b, i, j, k, f -----
                this%bc%ci_properties(1) = b2
                this%bc%ci_properties(2) = i2
                this%bc%ci_properties(3) = j2
                this%bc%ci_properties(4) = k2
                this%bc%ci_properties(5) = f2
              end if
            endif
            endassociate
          enddo
        enddo
        !$omp end parallel
      enddo
    enddo

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

            associate( this => blk(b1)%face(f1)%center(m1,n1) )

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
              ib2 = this%bc%ci_properties(1)
              i2 = this%bc%ci_properties(2)-1
              j2 = this%bc%ci_properties(3)-1
              k2 = 0
              if2 = this%bc%ci_properties(4)
            else
              ib2 = this%bc%ci_properties(1)
              i2 = this%bc%ci_properties(2)-1
              j2 = this%bc%ci_properties(3)-1
              k2 = this%bc%ci_properties(4)-1
              if2 = this%bc%ci_properties(5)
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

            this%bc%connection(1) = NINT(dumii)
            this%bc%connection(2) = NINT(dumij)
            this%bc%connection(3) = NINT(dumji)
            this%bc%connection(4) = NINT(dumjj)

            endassociate
          endif
        enddo
      enddo
      !$omp end parallel
    enddo
    enddo

  end subroutine find_periodic



  !> Based on the find_connect.F file of AFFS
  !> `skip_chimera` leaves the faces declared 'chimera' to the overset search.
  subroutine find_connect(blk,force_connect,skip_chimera)
    use bc_names_mod, only: MARKER_CONN, MARKER_Chim
    implicit none
    type(BC_block), intent(inout) :: blk(:)
    logical, intent(in) :: force_connect
    logical, intent(in), optional :: skip_chimera
    real(8), allocatable  :: x(:), y(:), z(:)
    integer, allocatable :: b(:), f(:), n(:), m(:), def(:), prop(:,:), match(:)
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
              associate( this => blk(b1)%face(f1)%center(m1,n1) )
              this%bc%gp_id = def(j)
              this%bc%adj_assigned = adj(j)
              this%bc%ci_properties(:) = prop(j,:)
              if (any(prop(j,:)==0)) then
                !$omp critical(conn_print)
                write(*,*) "[ERROR] Connection not found"
                write(*,*) "        b, f, m, n", b1, f1, m1, n1
                !$omp end critical(conn_print)
                stop
              endif
              endassociate
            endif
          enddo
        enddo
        !$omp end parallel
      enddo
    enddo

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

            associate( this => blk(b1)%face(f1)%center(m1,n1) )

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
              ib2 = this%bc%ci_properties(1)
              i2 = this%bc%ci_properties(2)-1
              j2 = this%bc%ci_properties(3)-1
              k2 = 0
              if2 = this%bc%ci_properties(4)
            else
              ib2 = this%bc%ci_properties(1)
              i2 = this%bc%ci_properties(2)-1
              j2 = this%bc%ci_properties(3)-1
              k2 = this%bc%ci_properties(4)-1
              if2 = this%bc%ci_properties(5)
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

            this%bc%connection(1) = NINT(dumii)
            this%bc%connection(2) = NINT(dumij)
            this%bc%connection(3) = NINT(dumji)
            this%bc%connection(4) = NINT(dumjj)

            endassociate
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
          enddo
        enddo
        !$omp end parallel
      enddo
    enddo

  end subroutine find_connect


!    subroutine di inversione di matrice
!    a     : matrice r*r da invertire  reale
!    b     : matrice r*r invertita
!    r     : dimensione (max 20)      intero
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