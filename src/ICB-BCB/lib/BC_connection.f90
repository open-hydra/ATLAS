module BC_connection
  use TOM, only: fmn2ijk, meshType
  use ATLAS_high_level
  implicit none
  private
  public:: find_periodic, find_connect

contains

  subroutine find_periodic(block)
    implicit none
    type(ATLAS_block), intent(inout) :: block(:)
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

    nb = size(block)
    allocate(nx(nb)); allocate(ny(nb)); allocate(nz(nb))

    do b1 = 1, nb
      nx(b1) = block(b1)%dim(1)
      ny(b1) = block(b1)%dim(2)
      nz(b1) = block(b1)%dim(3)
    enddo

    do b1 = 1, nb
      do f1 = 1, block(b1)%nfaces
        do n1 = 1, block(b1)%face(f1)%Nn
          do m1 = 1, block(b1)%face(f1)%Nm
            associate( this => block(b1)%face(f1)%center(m1,n1) )
            if (this%bc%definition==77 .and. this%bc%connection(3)>0) then
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
              if (meshType == -2) then
              ! ----- Caso 2D: b, i, j, f -----
                this%bc%properties(1) = b2
                this%bc%properties(2) = i2
                this%bc%properties(3) = j2
                this%bc%properties(4) = f2
              else
                ! ----- Caso 3D: b, i, j, k, f -----
                this%bc%properties(1) = b2
                this%bc%properties(2) = i2
                this%bc%properties(3) = j2
                this%bc%properties(4) = k2
                this%bc%properties(5) = f2
              end if
              ! this%bc%properties(1) = b2
              ! this%bc%properties(2) = i2
              ! this%bc%properties(3) = j2
              ! this%bc%properties(4) = k2
              ! this%bc%properties(5) = f2
              !this%bc%connection(1) = 1
              !this%bc%connection(2) = 0
              !this%bc%connection(3) = 0
              !this%bc%connection(4) = 1
            endif
            endassociate
          enddo
        enddo
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
    do f1 = 1, block(b1)%nfaces
      do n1 = 1, block(b1)%face(f1)%Nn
        do m1 = 1, block(b1)%face(f1)%Nm

          if (block(b1)%face(f1)%center(m1,n1)%bc%adj_assigned) then
            
            associate( this => block(b1)%face(f1)%center(m1,n1) )

            ! legge dati della faccia di contorno
            if1 = f1; ib1 = b1
            call fmn2ijk(f1,m1,n1,nx(b1),ny(b1),nz(b1),i1,j1,k1)
            i1 = i1-1; j1 = j1-1; k1 = k1-1

            x11 = block(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(1)
            y11 = block(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(2)
            z11 = block(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(3)

            x01 = block(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(1)
            y01 = block(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(2)
            z01 = block(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(3)

            x10 = block(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(1)
            y10 = block(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(2)
            z10 = block(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(3)

            x00 = block(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(1)
            y00 = block(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(2)
            z00 = block(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(3)

            eix1do= 0.5*(x11+x10)-0.5*(x01+x00)
            eiy1do= 0.5*(y11+y10)-0.5*(y01+y00)
            eiz1do= 0.5*(z11+z10)-0.5*(z01+z00)

            ejx1do= 0.5*(x11+x01)-0.5*(x10+x00)
            ejy1do= 0.5*(y11+y01)-0.5*(y10+y00)
            ejz1do= 0.5*(z11+z01)-0.5*(z10+z00)

            ! legge  dati della faccia a cui e' connessa la faccia di contorno

            if (meshType == -2) then
              ib2 = nint(this%bc%properties(1))
              i2 = nint(this%bc%properties(2))-1
              j2 = nint(this%bc%properties(3))-1
              k2 = 0
              if2 = nint(this%bc%properties(4))
            else
              ib2 = nint(this%bc%properties(1))
              i2 = nint(this%bc%properties(2))-1
              j2 = nint(this%bc%properties(3))-1
              k2 = nint(this%bc%properties(4))-1
              if2 = nint(this%bc%properties(5))
            endif

            x11 = block(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(1)
            y11 = block(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(2)
            z11 = block(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(3)

            x01 = block(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(1)
            y01 = block(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(2)
            z01 = block(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(3)

            x10 = block(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(1)
            y10 = block(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(2)
            z10 = block(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(3)

            x00 = block(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(1)
            y00 = block(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(2)
            z00 = block(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(3)

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
    enddo
    enddo
    
  end subroutine find_periodic



  !> Based on the find_connect.F file of AFFS
  subroutine find_connect(block,force_connect)
    ! use omp_lib
    implicit none
    type(ATLAS_block), intent(inout) :: block(:)
    logical, intent(in) :: force_connect
    real(8), allocatable  :: x(:), y(:), z(:)
    integer, allocatable :: b(:), f(:), n(:), m(:), def(:), prop(:,:)
    logical, allocatable :: adj(:)
    integer :: nb, nbound
    integer, allocatable :: nboundb(:)
    integer, allocatable :: nx(:), ny(:), nz(:)
    integer :: f1,m1,n1,b1,b2,f2,m2,n2,i,j,bqui
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

    if (meshType==1) return

    nb = size(block)
    allocate(nboundb(nb))
    allocate(nx(nb)); allocate(ny(nb)); allocate(nz(nb))

    ! Store data in local variables
    nbound = 0; nboundb = 0; bqui = 1
    do b1 = 1, nb
      nx(b1) = block(b1)%dim(1)
      ny(b1) = block(b1)%dim(2)
      nz(b1) = block(b1)%dim(3)
      do f1 = 1, block(b1)%nfaces
        nboundb(b1) = nboundb(b1)+(block(b1)%face(f1)%Nm*block(b1)%face(f1)%Nn)
        nbound = nbound+(block(b1)%face(f1)%Nm*block(b1)%face(f1)%Nn)
      enddo
    enddo
    allocate(x(1:nbound)); allocate(y(1:nbound)); allocate(z(1:nbound))
    allocate(b(1:nbound)); allocate(f(1:nbound)); allocate(m(1:nbound))
    allocate(n(1:nbound)); allocate(def(1:nbound)); allocate(adj(1:nbound))

    if (meshType == -2) then
      allocate(prop(1:nbound,1:4))
    else
      allocate(prop(1:nbound,1:5))
    endif

    i = 0
    do b1 = 1, nb
      do f1 = 1, block(b1)%nfaces
        do n1 = 1, block(b1)%face(f1)%Nn
          do m1 = 1, block(b1)%face(f1)%Nm
            i = i +1
            associate( this => block(b1)%face(f1)%center(m1,n1) )
            def(i) = this%bc%definition
            adj(i) = this%bc%adj_assigned
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

    ! Loop over boundary cells to find connections
    do i = 1, nbound
      if (def(i)/=1 .and. .not.force_connect) cycle
      if (adj(i)) cycle
      if (i>sum(nboundb(1:bqui))) bqui = bqui+1
      do j = sum(nboundb(1:bqui))+1, nbound
        if (def(j)/=1 .and. .not.force_connect) cycle
        dum1 = (x(i)-x(j))**2+ &
              (y(i)-y(j))**2+ &
              (z(i)-z(j))**2
        dum1 = sqrt(dum1)
        if (dum1<1d-7) then
          b1 = b(i); f1 = f(i)
          m1 = m(i); n1 = n(i)
          b2 = b(j); f2 = f(j)
          m2 = m(j); n2 = n(j)
          call fmn2ijk(f1,m1,n1,nx(b1),ny(b1),nz(b1),i1,j1,k1)
          call fmn2ijk(f2,m2,n2,nx(b2),ny(b2),nz(b2),i2,j2,k2)
          def(i) = 1000
          def(j) = 1000
          do p1 = 1, size(block(b1)%associated_phase)
            do p2 = 1, size(block(b2)%associated_phase)
              if (block(b1)%associated_phase(p1)%name==block(b2)%associated_phase(p2)%name) then
                def(i) = 1
                def(j) = 1
              endif
            enddo
          enddo

          if (meshType == -2) then
            adj(i) = .true.
            prop(i,1) = b2
            prop(i,2) = i2
            prop(i,3) = j2
            prop(i,4) = f2
                      
            adj(j) = .true.
            prop(j,1) = b1
            prop(j,2) = i1
            prop(j,3) = j1
            prop(j,4) = f1

          else
            adj(i) = .true.
            prop(i,1) = b2
            prop(i,2) = i2
            prop(i,3) = j2
            prop(i,4) = k2
            prop(i,5) = f2
                    
            adj(j) = .true.
            prop(j,1) = b1
            prop(j,2) = i1
            prop(j,3) = j1
            prop(j,4) = k1
            prop(j,5) = f1
          endif
                      
          exit
        endif
      enddo
    enddo


    i = 0
    do b1 = 1, nb
      do f1 = 1, block(b1)%nfaces
        do n1 = 1, block(b1)%face(f1)%Nn
          do m1 = 1, block(b1)%face(f1)%Nm
            i = i +1
            if (def(i)==1 .or. def(i)==1000) then
              associate( this => block(b1)%face(f1)%center(m1,n1) )
              this%bc%definition = def(i)
              this%bc%adj_assigned = adj(i)
              this%bc%properties(1:size(prop,2)) = real(prop(i,:))
              if (product(prop(i,:))==0) then
                write(*,*) " Find connect"
                write(*,*) " Connection not found"
                write(*,*) " b,f,m,n"
                write(*,*) b1, f1, m1, n1
                stop
              endif
              endassociate
            endif
          enddo
        enddo
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
    do f1 = 1, block(b1)%nfaces
      do n1 = 1, block(b1)%face(f1)%Nn
        do m1 = 1, block(b1)%face(f1)%Nm

          if (block(b1)%face(f1)%center(m1,n1)%bc%adj_assigned) then
            
            associate( this => block(b1)%face(f1)%center(m1,n1) )

            ! legge dati della faccia di contorno
            if1 = f1; ib1 = b1
            call fmn2ijk(f1,m1,n1,nx(b1),ny(b1),nz(b1),i1,j1,k1)
            i1 = i1-1; j1 = j1-1; k1 = k1-1

            x11 = block(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(1)
            y11 = block(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(2)
            z11 = block(ib1)%node(i1+di11(if1),j1+dj11(if1),k1+dk11(if1))%c(3)

            x01 = block(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(1)
            y01 = block(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(2)
            z01 = block(ib1)%node(i1+di01(if1),j1+dj01(if1),k1+dk01(if1))%c(3)

            x10 = block(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(1)
            y10 = block(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(2)
            z10 = block(ib1)%node(i1+di10(if1),j1+dj10(if1),k1+dk10(if1))%c(3)

            x00 = block(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(1)
            y00 = block(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(2)
            z00 = block(ib1)%node(i1+di00(if1),j1+dj00(if1),k1+dk00(if1))%c(3)

            eix1do= 0.5*(x11+x10)-0.5*(x01+x00)
            eiy1do= 0.5*(y11+y10)-0.5*(y01+y00)
            eiz1do= 0.5*(z11+z10)-0.5*(z01+z00)

            ejx1do= 0.5*(x11+x01)-0.5*(x10+x00)
            ejy1do= 0.5*(y11+y01)-0.5*(y10+y00)
            ejz1do= 0.5*(z11+z01)-0.5*(z10+z00)

            ! legge  dati della faccia a cui e' connessa la faccia di contorno

            if (meshType == -2) then
              ib2 = nint(this%bc%properties(1))
              i2 = nint(this%bc%properties(2))-1
              j2 = nint(this%bc%properties(3))-1
              k2 = 0
              if2 = nint(this%bc%properties(4))
            else
              ib2 = nint(this%bc%properties(1))
              i2 = nint(this%bc%properties(2))-1
              j2 = nint(this%bc%properties(3))-1
              k2 = nint(this%bc%properties(4))-1
              if2 = nint(this%bc%properties(5))
            endif

            x11 = block(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(1)
            y11 = block(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(2)
            z11 = block(ib2)%node(i2+di11(if2),j2+dj11(if2),k2+dk11(if2))%c(3)

            x01 = block(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(1)
            y01 = block(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(2)
            z01 = block(ib2)%node(i2+di01(if2),j2+dj01(if2),k2+dk01(if2))%c(3)

            x10 = block(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(1)
            y10 = block(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(2)
            z10 = block(ib2)%node(i2+di10(if2),j2+dj10(if2),k2+dk10(if2))%c(3)

            x00 = block(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(1)
            y00 = block(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(2)
            z00 = block(ib2)%node(i2+di00(if2),j2+dj00(if2),k2+dk00(if2))%c(3)

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
    enddo
    enddo

    i = 0
    do b1 = 1, nb
      do f1 = 1, block(b1)%nfaces
        do n1 = 1, block(b1)%face(f1)%Nn
          do m1 = 1, block(b1)%face(f1)%Nm
            i = i +1
            if (def(i)==1 .or. def(i)==1000) then
              associate( this => block(b1)%face(f1)%center(m1,n1) )
              this%bc%properties(1) = block(prop(i,1))%id
              endassociate
            endif
          enddo
        enddo
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
        goto 10
211     write(*,*)'matrice singolare'
        return
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

end module BC_connection