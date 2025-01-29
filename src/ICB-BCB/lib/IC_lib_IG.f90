module IC_lib_IG
  implicit none

  real(8), parameter :: runi=8314.51d0

contains

  subroutine build_IG_field(block,zoneini,IC_type,sp,range,dirSize,dir)
    use variables, only: nrans
    use ATLAS_high_level
    use finer, only: file_ini
    use Interpolator
    use species
    implicit none
    type(ATLAS_block), intent(inout)  :: block
    type(file_ini), intent(in)        :: zoneini
    character(len=*), intent(inout)   :: IC_type
    real(8), intent(in)               :: range(6)
    integer, intent(in)               :: dirSize
    type(obj_species), intent(inout)  :: sp
    integer                       :: dir(:)
    integer                       :: i, ip, j, s, k, error
    real(8)                       :: Rgas, gamma, rho, vel, del, a, cp_
    real(8)                       :: M0, mach
    real(8)                       :: alpha, beta, M, p0, T0, p, T, ux, uy, uz, mit, kappa, omega, rhoRij
    real(8)                       :: throat_area, dx, dy, dz, zeta, phi
    character(len=llen)           :: OMF, OFF, OSF
    integer                       :: oldid
    real(8)                       :: here(3)
    real(8)                       :: R1, uTF
    character(len=2)              :: nozzle_dir
    real(8)                       :: L_threshold

    M = 0d0; p0 = 0.0; p = 0.0
    call zoneini%get(section_name='zone', option_name='mach', val=M, error=error)
    call zoneini%get(section_name='zone', option_name='p0',   val=p0, error=error)
    if (error==0) p0 = p0*1d+5
    call zoneini%get(section_name='zone', option_name='T0',   val=T0, error=error)
    if (error/=0) T0 = 0.0
    call zoneini%get(section_name='zone', option_name='p',    val=p, error=error)
    if (error==0) p = p*1d+5
    call zoneini%get(section_name='zone', option_name='rho',  val=rho, error=error)
    if (error/=0) rho = 0.0
    call zoneini%get(section_name='zone', option_name='T',    val=T, error=error)
    if (error/=0) T = 0.0
    call zoneini%get(section_name='zone', option_name='alpha',val=alpha, error=error)
    if (error/=0) alpha = 0.0
    call zoneini%get(section_name='zone', option_name='beta', val=beta, error=error)
    if (error/=0) beta = 0.0
    call zoneini%get(section_name='zone', option_name='u', val=ux, error=error)
    if (error/=0) ux = 0.0
    call zoneini%get(section_name='zone', option_name='v', val=uy, error=error)
    if (error/=0) uy = 0.0
    call zoneini%get(section_name='zone', option_name='w', val=uz, error=error)
    if (error/=0) uz = 0.0

    ! Turbulence specific parameters
    call zoneini%get(section_name='zone', option_name='mit', val=mit, error=error)
    if (error/=0) mit = 0.0
    call zoneini%get(section_name='zone', option_name='kappa', val=kappa, error=error)
    if (error/=0) kappa = 0.0
    call zoneini%get(section_name='zone', option_name='omega', val=omega, error=error)
    if (error/=0) omega = 0.0
    call zoneini%get(section_name='zone', option_name='rhoRij', val=rhoRij, error=error)
    if (error/=0) rhoRij = 0.0

    ! 1D specific parameters
    call zoneini%get(section_name='zone', option_name='R1',   val=R1, error=error)
    call zoneini%get(section_name='zone', option_name='uTF', val=uTF, error=error)

    ! Nozzle specific parameters
    call zoneini%get(section_name='zone', option_name='nozzle-direction',  val=nozzle_dir, error=error)
    if (error/=0) nozzle_dir = 'dx'
    call zoneini%get(section_name='zone', option_name='nozzle-threshold',  val=L_threshold, error=error)
    if (error/=0) L_threshold = huge(alpha)

    ! Interpolation specific parameters
    onespecies = .true.
    call zoneini%get(section_name='zone', option_name='oldmesh', val=OMF, error=error)
    if (error/=0) OMF = 'Darwin'
    call zoneini%get(section_name='zone', option_name='oldspecies', val=OSF, error=error)
    if (error==0) onespecies = .false.
    call zoneini%get(section_name='zone', option_name='oldsolution', val=OFF, error=error)
    if (error==0) IC_type = 'interpolation'
    call zoneini%get(section_name='zone', option_name='oldid', val=oldid, error=error)
    if (error/=0) oldid = 0
    call zoneini%get(section_name='zone', option_name='law', val=law, error=error)
    if (error/=0) law = 'outlaw'
    if (law=='extrude') then
      call zoneini%get(section_name='zone', option_name='theta', val=thetamax_extrude, error=error)
      if (error/=0) thetamax_extrude = float(90)
      call zoneini%get(section_name='zone', option_name='nz', val=nz_extrude, error=error)
      if (error/=0) nz_extrude = int(4)
    endif

    sp%massf = 1d-20

    ! Assign species mass fractions (if equilibrium also pressure and temperature may be assigned)
    call define_composition(zoneini, sp, T0, p0)

    if (.not.allocated(block%density)) then
        allocate(block%density(sp%n,1:block%dim(1),1:block%dim(2),1:block%dim(3)))
        allocate(block%velocity(3,1:block%dim(1),1:block%dim(2),1:block%dim(3)))
        allocate(block%pressure(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
        allocate(block%temperature(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
        if (nrans>0) allocate(block%turbprop(nrans,1:block%dim(1),1:block%dim(2),1:block%dim(3)))
    endif

    write(*,*) ' -- IG type = ',trim(IC_type)

    select case (IC_type)
    case ('interpolation')

        call intersol(block,OMF,OFF,OSF,oldid)

    case ('homogeneous')

        ! R
        Rgas = sum(Runi*sp%massf/sp%w)

        ! Temperature
        if (T0==0 .and. T==0) T = p/(Rgas*rho)
        if (T0/=0 .and. T==0) T = T02T(T0,sp%massf,sp%cp,sp%dcp,sp%h,M,Rgas)
        cp_ = sum(sp%massf*sp%cp(:,nint(T)))
        gamma = cp_/(cp_-Rgas)
        del = 0.5*(gamma-1)
        ! Mach
        if (M==0) M = sqrt((ux*ux+uy*uy+uz*uz)/(gamma*Rgas*T))
        ! Pressure
        if (p0==0 .and. p==0) p = T * (Rgas*rho)
        if (p0/=0 .and. p==0) p = p0/((1+del*M*M)**(gamma/(gamma-1)))
        ! Density  
        if (rho==0) then
        rho = p/(Rgas*T)
        endif

        here = 1.0
        do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)
            if (dirSize>=1) here(1) = block%center(i,j,k)%c(dir(1))
            if (dirSize>=2) here(2) = block%center(i,j,k)%c(dir(2))
            if (dirSize>=3) here(3) = block%center(i,j,k)%c(dir(3))
            if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
                here(2)>=range(3) .and. here(2)<=range(4) .and. &
                here(3)>=range(5) .and. here(3)<=range(6)) then
                do s = 1, sp%n
                block%density(s,i,j,k) = rho*sp%massf(s)
                enddo
                a = sqrt(gamma*Rgas*T)
                vel = M*a
                block%temperature(i,j,k) = T
                if (ux==0) then
                block%velocity(1,i,j,k) = vel*cos(alpha)*cos(beta)
                else
                block%velocity(1,i,j,k) = ux
                endif
                if (uy==0) then
                block%velocity(2,i,j,k) = vel*cos(alpha)*sin(beta)
                else
                block%velocity(2,i,j,k) = uy
                endif
                if (uz==0) then
                block%velocity(3,i,j,k) = vel*sin(beta)
                else
                block%velocity(3,i,j,k) = uz
                endif
                block%pressure(i,j,k) = p
            endif
        enddo; enddo; enddo

    case ('1D-centcomp' , '1D-cubcomp')

        Rgas = sum(Runi*sp%massf/sp%w)
        cp_ = sum(sp%massf*sp%cp(:,1))
        gamma = cp_/(cp_-Rgas)
        del = 0.5*(gamma-1)

        here = 1.0
        do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)
              if (dirSize>=1) here(1) = block%center(i,j,k)%c(dir(1))
              if (dirSize>=2) here(2) = block%center(i,j,k)%c(dir(2))
              if (dirSize>=3) here(3) = block%center(i,j,k)%c(dir(3))
              if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
                  here(2)>=range(3) .and. here(2)<=range(4) .and. &
                  here(3)>=range(5) .and. here(3)<=range(6)) then
                select case(IC_type)
                  case('1D-centcomp'); call centered_compression()
                  case('1D-cubcomp');  call cubic_compression()
                end select
                block%velocity(2,i,j,k) = 0.0
                block%velocity(3,i,j,k) = 0.0
              endif
        enddo; enddo; enddo

    case ('nozzle')

        call nozzle1D()

    end select

    
    ! Turbulence specific parameters
    if (nrans==1) then
        block%turbprop(1,:,:,:) = mit
        if(mit/=0.0) block%turbprop(1,:,:,:) = mit
    elseif (nrans==2) then
        if(kappa/=0.0) block%turbprop(1,:,:,:) = kappa
        if(omega/=0.0) block%turbprop(2,:,:,:) = omega
    elseif (nrans==7) then
        if(rhoRij/=0.0) block%turbprop(1:3,:,:,:) = rhoRij
        block%turbprop(4:6,:,:,:) = 1d-8
        if(omega/=0.0) block%turbprop(7,:,:,:) = omega
    endif

  
  contains


    subroutine nozzle1D()
      implicit none
      real(8), allocatable :: radius_ext(:), radius_int(:), area(:)
      integer :: ib1, ib2, throat_cell, L_threshold_cell

      allocate(radius_ext(1:block%dim(1)))
      allocate(radius_int(1:block%dim(1)))
      allocate(area(1:block%dim(1)))

      Rgas = sum(Runi*sp%massf/sp%w)
      cp_ = sum(sp%massf*sp%cp(:,nint(T0)))
      gamma = cp_/(cp_-Rgas)
      del = 0.5*(gamma-1)

      do i = 1, block%dim(1)
        radius_ext(i) = sqrt( 0.25*(block%node(i-1,block%dim(2),0)%c(2)+block%node(i,block%dim(2),0)%c(2))**2 + &
                              0.25*(block%node(i-1,block%dim(2),0)%c(3)+block%node(i,block%dim(2),0)%c(3))**2 )
        radius_int(i) = sqrt( 0.25*(block%node(i-1,0,0)%c(2)+block%node(i,0,0)%c(2))**2 + &
                              0.25*(block%node(i-1,0,0)%c(3)+block%node(i,0,0)%c(3))**2 )
      enddo
      area = acos(-1d0)*abs(radius_ext*radius_ext-radius_int*radius_int)
      throat_cell = minloc(area,1)
      throat_area = area(throat_cell)

      L_threshold_cell = 0
      ib1 = 1; ib2 = block%dim(1); ip = 1
      do i = ib1, ib2
        if (block%center(i,1,1)%c(1)>L_threshold) then
          L_threshold_cell = i
          exit
        endif
      enddo

      if (nozzle_dir=='dx') then
        ip = 1
        ib1 = L_threshold_cell+1
        ib2 = block%dim(1)
      elseif (nozzle_dir=='sx') then
        ip = -1
        ib1 = L_threshold_cell-1
        ib2 = 0
      endif

      do i = 1, ib1-1, ip
        do s = 1, sp%n
          block%density(s,i,:,:) = sp%massf(s)*p0/(Rgas*T0)
        enddo
        block%pressure(i,:,:) = p0
        block%velocity(:,i,:,:) = 0.0
      enddo

      do i = ib1, ib2, ip
        M0 = 0.001
        if (i>throat_cell) M0 = 1.30
        call legge_aree(area(i),M0,Mach,throat_area,gamma)
        here = 1.0
        do k = 1, block%dim(3)
          do j = 1, block%dim(2)
            if (dirSize>=1) here(1) = block%center(i,j,k)%c(dir(1))
            if (dirSize>=2) here(2) = block%center(i,j,k)%c(dir(2))
            if (dirSize>=3) here(3) = block%center(i,j,k)%c(dir(3))
            if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
                here(2)>=range(3) .and. here(2)<=range(4) .and. &
                here(3)>=range(5) .and. here(3)<=range(6)) then
              dx = block%center(i,j,k)%c(1)-block%center(i-1,j,k)%c(1)
              dy = block%center(i,j,k)%c(2)-block%center(i-1,j,k)%c(2)
              dz = block%center(i,j,k)%c(3)-block%center(i-1,j,k)%c(3)
              zeta = atan(dy/sqrt(dx*dx+dz*dz))
              phi = atan(dz/dx)
              do s = 1, sp%n
                block%density(s,i,j,k) = sp%massf(s)*p0/(Rgas*T0)/((1+del*(Mach**2))**(0.5/del))
              enddo
              block%pressure(i,j,k) = p0/((1+del*(Mach**2))**(gamma/(2*del)))
              block%velocity(1,i,j,k) = Mach*sqrt(gamma*Rgas*T0/(1+del*(Mach**2)))*cos(zeta)*cos(phi)
              block%velocity(2,i,j,k) = Mach*sqrt(gamma*Rgas*T0/(1+del*(Mach**2)))*sin(zeta)
              block%velocity(3,i,j,k) = Mach*sqrt(gamma*Rgas*T0/(1+del*(Mach**2)))*cos(zeta)*sin(phi)
              block%temperature(i,j,k) = T0/(1+del*(Mach**2))
            endif
          end do 
        end do
      end do

    end subroutine nozzle1D

    ! 1D specific ICs

    ! Centered compression assuming rest for the state ahead of the compression wave
    subroutine centered_compression()
      implicit none
      real(8) :: alpha(2), pol
      alpha(1) = uTF; alpha(2) = -1/(range(2)-range(1))
      pol = alpha(1)+alpha(2)*(here(1)-range(1))
      block%velocity(1,i,j,k) = (pol-R1)/(1.d0+del)
      a = R1+del*block%velocity(1,i,j,k)
      block%pressure(i,j,k) = (a/R1)**(gamma/del)
      do s = 1, sp%n
        block%density(s,i,j,k) = gamma*block%pressure(i,j,k)/(a*a)*sp%massf(s)
      enddo
    end subroutine centered_compression
    
    ! Cubic compression assuming rest for the state ahead of the compression wave
    subroutine cubic_compression()
      implicit none
      real(8) :: alpha(4), pol, csi
      alpha(1) = uTF; alpha(2) = 0
      alpha(3) = 3*(R1-uTF)/((range(2)-range(1))**2)
      alpha(4) = -2*(R1-uTF)/((range(2)-range(1))**3)
      csi = here(1)-range(1)
      pol = alpha(1)+alpha(2)*csi+alpha(3)*csi**2+alpha(4)*csi**3
      block%velocity(1,i,j,k) = (pol-R1)/(1.d0+del)
      a = R1+del*block%velocity(1,i,j,k)
      block%pressure(i,j,k) = (a/R1)**(gamma/del)
      do s = 1, sp%n
        block%density(s,i,j,k) = gamma*block%pressure(i,j,k)/(a*a)*sp%massf(s)
      enddo
    end subroutine cubic_compression

  end subroutine build_IG_field

  !> Newton-Raphson procedure for areas law
  pure subroutine legge_aree(a,x0,m2,at,gamma)
    implicit none
    real(8), intent(in)  :: a
    real(8), intent(in)  :: x0
    real(8), intent(out) :: m2
    real(8), intent(in)  :: at, gamma
    real(8)              :: m_new, m_old, m_aux
    real(8)              :: f, fprime
    real(8)              :: k, d
    integer              :: iter

    k = 0.5*(gamma+1.)
    d = 0.5*(gamma-1.)
    m_old = x0
    m_aux = x0
    m_new = 1.
    iter = 0

    do while (abs(m_new-m_aux)>=1e-10)
      m_aux = m_old
      f = (((1.+d*(m_old**2.))/k)**(0.5*k/d))/m_old-(a/at)
      fprime = -(((1.+d*(m_old**2.))/k)**(0.5*k/d))/(m_old**2.)+((1+d*(m_old**2.))/k)**(0.5*k/d-1.)
      m_new=m_old-(f/fprime)

      m_old=m_new
      iter = iter+1
      if (iter>1e+5) error stop ('--- Max iterations number reached ---')
    end do

    m2 = m_new

  end subroutine legge_aree


  !> Newton-Raphson procedure for T0
  pure function T02T(T0,ci,cp,dcp,h,M,Rgas) result(T)
    implicit none
    real(8), intent(in)  :: ci(:)
    real(8), intent(in)  :: T0,M,Rgas
    real(8), intent(in)  :: cp(:,:),dcp(:,:),h(:,:)
    real(8)              :: T
    real(8)              :: TT,Tnew,H0,h_tot,cp_tot,dcp_tot,FT,DFT
    real(8), parameter   :: toll=1.d-8
    integer              :: s

    Tnew = T0*0.95
    H0 = 0.0
    do s = 1, size(ci)
      H0 = H0+ci(s)*(h(s,idint(T0))+(h(s,idint(T0)+1)-h(s,idint(T0)))*(T0-idint(T0)))
    enddo

    FT  = 1.0
    DFT = 1.0
    TT  = 1.0
    do while (abs(FT/(DFT*TT))>toll)
      TT = Tnew
      cp_tot = 0.0
      dcp_tot = 0.0
      h_tot = 0.0
      do s = 1, size(ci)
        cp_tot = cp_tot+ci(s)*(cp(s,idint(TT))+(cp(s,idint(TT)+1)-cp(s,idint(TT)))*(TT-idint(TT)))
        dcp_tot = dcp_tot+ci(s)*(dcp(s,idint(TT))+(dcp(s,idint(TT)+1)-dcp(s,idint(TT)))*(TT-idint(TT)))
        h_tot = h_tot+ci(s)*(h(s,idint(TT))+(h(s,idint(TT)+1)-h(s,idint(TT)))*(TT-idint(TT)))
      enddo
      FT = H0-h_tot-0.5d0*M*M*cp_tot/(cp_tot-Rgas)*Rgas*TT
      DFT = -cp_tot-0.5d0*M*M*Rgas*(cp_tot*(cp_tot-Rgas)-TT*dcp_tot*Rgas)/(cp_tot-Rgas)**2
      Tnew = TT-FT/DFT
    enddo

    T = TT

  end function T02T

end module IC_lib_IG