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
    real(8)                       :: Rgas, gamma, vel, del, a, cp_
    real(8)                       :: M0, mach
    real(8)                       :: alpha, beta, ux, uy, uz, mit, kappa, omega, rhoRij
    real(8)                       :: throat_area, dx, dy, dz, zeta, phi
    character(len=llen)           :: OMF, OFF, OSF
    integer                       :: oldid
    real(8)                       :: here(3)
    real(8)                       :: R1, uTF
    character(len=2)              :: nozzle_dir
    real(8)                       :: L_threshold
    real(8), dimension(1:block%dim(1),1:block%dim(2),1:block%dim(3)) :: M, p0, T0, p, T, rho
    real(8)                       :: val_const
    character(len=200)            :: val_file
    character(len=16)             :: val_direction
    integer                       :: errorfile, errordirection
    logical                       :: is_variable


    is_variable = .false.
    call zoneini%get(section_name='zone', option_name='mach', val=val_const, error=error)
    if (error/=0) then
      M = 0.0d0
      call zoneini%get(section_name='zone', option_name='mach-file', val=val_file, error=errorfile)
      if (errorfile==0) then
        is_variable = .true.
        call zoneini%get(section_name='zone', option_name='mach-direction', val=val_direction, error=errordirection)
        if (errordirection==0) then
          call read_file_direction (M, block, val_file, val_direction)
        else
          call read_file_tec (M, block, val_file)
        endif
      endif
    else
      M = val_const
    endif

    call zoneini%get(section_name='zone', option_name='p0', val=val_const, error=error)
    if (error/=0) then
      p0 = 0.0d0
      call zoneini%get(section_name='zone', option_name='p0-file', val=val_file, error=errorfile)      
      if (errorfile==0) then
        is_variable = .true.
        call zoneini%get(section_name='zone', option_name='p0-direction', val=val_direction, error=errordirection)
        if (errordirection==0) then
          call read_file_direction (p0, block, val_file, val_direction)
        else
          call read_file_tec (p0, block, val_file)
        endif
      endif
    else
      p0 = val_const
    endif
    p0 = p0*1d+5

    call zoneini%get(section_name='zone', option_name='T0', val=val_const, error=error)
    if (error/=0) then
      T0 = 0.0d0
      call zoneini%get(section_name='zone', option_name='T0-file', val=val_file, error=errorfile)      
      if (errorfile==0) then
        is_variable = .true.
        call zoneini%get(section_name='zone', option_name='T0-direction', val=val_direction, error=errordirection)
        if (errordirection==0) then
          call read_file_direction (T0, block, val_file, val_direction)
        else
          call read_file_tec (T0, block, val_file)
        endif
      endif
    else
      T0 = val_const
    endif

    call zoneini%get(section_name='zone', option_name='p', val=val_const, error=error)
    if (error/=0) then
      p = 0.0d0
      call zoneini%get(section_name='zone', option_name='p-file', val=val_file, error=errorfile)      
      if (errorfile==0) then
        is_variable = .true.
        call zoneini%get(section_name='zone', option_name='p-direction', val=val_direction, error=errordirection)
        if (errordirection==0) then
          call read_file_direction (p, block, val_file, val_direction)
        else
          call read_file_tec (p, block, val_file)
        endif
      endif
    else
      p = val_const
    endif
    p = p*1d+5

    call zoneini%get(section_name='zone', option_name='T', val=val_const, error=error)
    if (error/=0) then
      T = 0.0d0
      call zoneini%get(section_name='zone', option_name='T-file', val=val_file, error=errorfile)      
      if (errorfile==0) then
        is_variable = .true.
        call zoneini%get(section_name='zone', option_name='T-direction', val=val_direction, error=errordirection)
        if (errordirection==0) then
          call read_file_direction (T, block, val_file, val_direction)
        else
          call read_file_tec (T, block, val_file)
        endif
      endif
    else
      T = val_const
    endif

    call zoneini%get(section_name='zone', option_name='rho', val=val_const, error=error)
    if (error/=0) then
      rho = 0.0d0
      call zoneini%get(section_name='zone', option_name='rho-file', val=val_file, error=errorfile)      
      if (errorfile==0) then
        is_variable = .true.
        call zoneini%get(section_name='zone', option_name='rho-direction', val=val_direction, error=errordirection)
        if (errordirection==0) then
          call read_file_direction (rho, block, val_file, val_direction)
        else
          call read_file_tec (rho, block, val_file)
        endif
      endif
    else
      rho = val_const
    endif

    if (is_variable) IC_type = 'variable'

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

    write(*,*) ' -- IG type = ',trim(IC_type)

    if (.not.allocated(block%density)) then
      allocate(block%density(sp%n,1:block%dim(1),1:block%dim(2),1:block%dim(3)))
      allocate(block%velocity(3,1:block%dim(1),1:block%dim(2),1:block%dim(3)))
      allocate(block%pressure(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
      allocate(block%temperature(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
      if (nrans>0) allocate(block%turbprop(nrans,1:block%dim(1),1:block%dim(2),1:block%dim(3)))
    endif


    select case (IC_type)

      case ('interpolation')

        call intersol(block,OMF,OFF,OSF,oldid)


      case ('homogeneous')

        sp%massf = 1d-20
        call define_composition(zoneini, sp, T0(1,1,1), p0(1,1,1))

        here = 1.0

        do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)

            ! R
            Rgas = sum(Runi*sp%massf/sp%w)

            ! Temperature
            if (T0(1,1,1)==0 .and. T(1,1,1)==0) T(1,1,1) = p(1,1,1)/(Rgas*rho(1,1,1))
            if (T0(1,1,1)/=0 .and. T(1,1,1)==0) T(1,1,1) = T02T(T0(1,1,1),sp%massf,sp%cp,sp%dcp,sp%h,M(1,1,1),Rgas)
            cp_ = sum(sp%massf*sp%cp(:,nint(T(1,1,1))))
            gamma = cp_/(cp_-Rgas)
            del = 0.5*(gamma-1)
            ! Mach
            if (M(1,1,1)==0) M(1,1,1) = sqrt((ux*ux+uy*uy+uz*uz)/(gamma*Rgas*T(1,1,1)))
            ! Pressure
            if (p0(1,1,1)==0 .and. p(1,1,1)==0) p(1,1,1) = T(1,1,1) * (Rgas*rho(1,1,1))
            if (p0(1,1,1)/=0 .and. p(1,1,1)==0) p(1,1,1) = p0(1,1,1)/((1+del*M(1,1,1)*M(1,1,1))**(gamma/(gamma-1)))
            ! Density  
            if (rho(1,1,1)==0) rho(1,1,1) = p(1,1,1)/(Rgas*T(1,1,1))

            if (dirSize>=1) here(1) = block%center(i,j,k)%c(dir(1))
            if (dirSize>=2) here(2) = block%center(i,j,k)%c(dir(2))
            if (dirSize>=3) here(3) = block%center(i,j,k)%c(dir(3))
            if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
                here(2)>=range(3) .and. here(2)<=range(4) .and. &
                here(3)>=range(5) .and. here(3)<=range(6)) then
                do s = 1, sp%n
                block%density(s,i,j,k) = rho(1,1,1)*sp%massf(s)
                enddo
                a = sqrt(gamma*Rgas*T(1,1,1))
                vel = M(1,1,1)*a
                block%temperature(i,j,k) = T(1,1,1)
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
                block%pressure(i,j,k) = p(1,1,1)
            endif

        enddo; enddo; enddo


      case ('variable')

        here = 1.0

        do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)

            sp%massf = 1d-20
            call define_composition(zoneini, sp, T0(i,j,k), p0(i,j,k))

            ! R
            Rgas = sum(Runi*sp%massf/sp%w)

            ! Temperature
            if (T0(i,j,k)==0 .and. T(i,j,k)==0) T(i,j,k) = p(i,j,k)/(Rgas*rho(i,j,k))
            if (T0(i,j,k)/=0 .and. T(i,j,k)==0) T(i,j,k) = T02T(T0(i,j,k),sp%massf,sp%cp,sp%dcp,sp%h,M(i,j,k),Rgas)
            cp_ = sum(sp%massf*sp%cp(:,nint(T(i,j,k))))
            gamma = cp_/(cp_-Rgas)
            del = 0.5*(gamma-1)
            ! Mach
            if (M(i,j,k)==0) M(i,j,k) = sqrt((ux*ux+uy*uy+uz*uz)/(gamma*Rgas*T(i,j,k)))
            ! Pressure
            if (p0(i,j,k)==0 .and. p(i,j,k)==0) p(i,j,k) = T(i,j,k) * (Rgas*rho(i,j,k))
            if (p0(i,j,k)/=0 .and. p(i,j,k)==0) p(i,j,k) = p0(i,j,k)/((1+del*M(i,j,k)*M(i,j,k))**(gamma/(gamma-1)))
            ! Density  
            if (rho(i,j,k)==0) rho(i,j,k) = p(i,j,k)/(Rgas*T(i,j,k))

            if (dirSize>=1) here(1) = block%center(i,j,k)%c(dir(1))
            if (dirSize>=2) here(2) = block%center(i,j,k)%c(dir(2))
            if (dirSize>=3) here(3) = block%center(i,j,k)%c(dir(3))
            if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
                here(2)>=range(3) .and. here(2)<=range(4) .and. &
                here(3)>=range(5) .and. here(3)<=range(6)) then
                do s = 1, sp%n
                block%density(s,i,j,k) = rho(i,j,k)*sp%massf(s)
                enddo
                a = sqrt(gamma*Rgas*T(i,j,k))
                vel = M(i,j,k)*a
                block%temperature(i,j,k) = T(i,j,k)
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
                block%pressure(i,j,k) = p(i,j,k)
            endif

        enddo; enddo; enddo


      case ('1D-centcomp' , '1D-cubcomp')

        ! Assign species mass fractions (if equilibrium also pressure and temperature may be assigned)
        sp%massf = 1d-20
        call define_composition(zoneini, sp, T0(1,1,1), p0(1,1,1))

        here = 1.0

        do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)

              Rgas = sum(Runi*sp%massf/sp%w)
              cp_ = sum(sp%massf*sp%cp(:,1))
              gamma = cp_/(cp_-Rgas)
              del = 0.5*(gamma-1)

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

        ! Assign species mass fractions (if equilibrium also pressure and temperature may be assigned)
        sp%massf = 1d-20
        call define_composition(zoneini, sp, T0(1,1,1), p0(1,1,1))

        call nozzle1D()

    end select

    ! Turbulence specific parameters
    if (nrans==1) then
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
      cp_ = sum(sp%massf*sp%cp(:,nint(T0(1,1,1))))
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
        ib1 = block%dim(1)
        ib2 = L_threshold_cell+1
      endif

      do i = ib1, ib2, ip
        do s = 1, sp%n
          block%density(s,i,:,:) = sp%massf(s)*p0(1,1,1)/(Rgas*T0(1,1,1))
        enddo
        block%pressure(i,:,:) = p0(1,1,1)
        block%velocity(:,i,:,:) = 0.0
      enddo

      do i = ib1, ib2, ip
        M0 = 0.001
        if (ip*i > ip*throat_cell) M0 = 1.30
        call legge_aree(area(i),M0,Mach,throat_area,gamma)
        Mach = Mach * ip
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
                block%density(s,i,j,k) = sp%massf(s)*p0(1,1,1)/(Rgas*T0(1,1,1))/((1+del*(Mach**2))**(0.5/del))
              enddo
              block%pressure(i,j,k) = p0(1,1,1)/((1+del*(Mach**2))**(gamma/(2*del)))
              block%velocity(1,i,j,k) = Mach*sqrt(gamma*Rgas*T0(1,1,1)/(1+del*(Mach**2)))*cos(zeta)*cos(phi)
              block%velocity(2,i,j,k) = Mach*sqrt(gamma*Rgas*T0(1,1,1)/(1+del*(Mach**2)))*sin(zeta)
              block%velocity(3,i,j,k) = Mach*sqrt(gamma*Rgas*T0(1,1,1)/(1+del*(Mach**2)))*cos(zeta)*sin(phi)
              block%temperature(i,j,k) = T0(1,1,1)/(1+del*(Mach**2))
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


  subroutine read_file_direction (var, block, varfile, vardirection)
    use ATLAS_high_level
    implicit none
    type(ATLAS_block), intent(inout)  :: block
    character(len=200), intent(in)    :: varfile
    character(len=16), intent(in)     :: vardirection
    real(8), dimension(1:block%dim(1),1:block%dim(2),1:block%dim(3)), intent(inout) :: var
    ! Local
    integer :: dir, ios, file_length, i, j, k, f
    real(8), dimension(:), allocatable :: file_dir, file_var
    real(8) :: coord, coordm, coordp, varm, varp

      
    if (trim(vardirection) == 'x') dir = 1
    if (trim(vardirection) == 'y') dir = 2
    if (trim(vardirection) == 'z') dir = 3

    file_length=0; ios=0
    open(unit=1,file=trim(varfile),status='old',action='read')
    do while (ios==0)
      read(1,*,iostat=ios)
      file_length = file_length+1
    enddo
    file_length = file_length-1
    rewind(1)
    allocate(file_dir(1:file_length))
    allocate(file_var(1:file_length))
    do i = 1, file_length
      read(1,*) file_dir(i), file_var(i)
    enddo
    close(1)

    do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)
      coord = block%center(i,j,k)%c(dir)
      do f = 1, file_length
        if (coord < file_dir(1) .or. coord > file_dir(file_length) ) then
          exit
        elseif (coord < file_dir(f)) then
          coordm = file_dir(f-1)
          coordp = file_dir(f)
          varm = file_var(f-1)
          varp = file_var(f)
          var(i,j,k) = varm + (coord-coordm)/(coordp-coordm)*(varp-varm)
          exit
        endif
      enddo
        
    enddo; enddo; enddo

  end subroutine read_file_direction


  subroutine read_file_tec ( var, block, varfile )
    use ATLAS_high_level
    use chimera, only: fs
    use intersection_module
    use Lib_ORION_data
    use Lib_Tecplot
    use TOM
    implicit none
    type(ATLAS_block), intent(inout)  :: block
    character(len=200), intent(in)    :: varfile
    real(8), dimension(1:block%dim(1),1:block%dim(2),1:block%dim(3)), intent(inout) :: var
    !Local
    type(Orion_Data) :: IOfield
    integer          :: error, i, j, k, d, ii, jj, kk
    type(var_block) :: var_tec
    real(8)                                  :: mindist
    real(8), dimension(:,:,:), allocatable   :: dx, dy, dz, dist
    integer, dimension(3)                    :: ind
    real*8, dimension(3,8)                   :: cell
    logical                                  :: inside_loc, inside

    
    IOfield%tec%format = 'ascii'
    error = tec_read_structured_multiblock( orion=IOfield, filename=trim(varfile) )

    allocate(var_tec%node   (0:IOfield%block(1)%Ni,0:IOfield%block(1)%Nj,0:IOfield%block(1)%Nk))
    allocate(var_tec%center (1:IOfield%block(1)%Ni,1:IOfield%block(1)%Nj,1:IOfield%block(1)%Nk))
    allocate(var_tec%var   (1:IOfield%block(1)%Ni,1:IOfield%block(1)%Nj,1:IOfield%block(1)%Nk))

    var_tec%dim(1) = IOfield%block(1)%Ni
    var_tec%dim(2) = IOfield%block(1)%Nj
    var_tec%dim(3) = IOfield%block(1)%Nk

    do i = 0, var_tec%dim(1); do j = 0, var_tec%dim(2); do k = 0, var_tec%dim(3)
      var_tec%node(i,j,k)%c(1:3) = IOfield%block(1)%mesh(:,i,j,k)
    enddo; enddo; enddo
   
    !> Compute the cells center coords
    do k = 1, var_tec%dim(3); do j = 1, var_tec%dim(2); do i = 1, var_tec%dim(1)
      do d = 1, 3
        var_tec%center(i,j,k)%c(d)=0.125d0*(var_tec%node(i-1,j-1,k-1)%c(d)+var_tec%node(i,j-1,k-1)%c(d)+ &
                                             var_tec%node(i-1,j,k-1)%c(d)+var_tec%node(i-1,j-1,k)%c(d)+ &
                                             var_tec%node(i,j,k)%c(d)+var_tec%node(i,j,k-1)%c(d)+ &
                                             var_tec%node(i,j-1,k)%c(d)+var_tec%node(i-1,j,k)%c(d))
      enddo
    enddo; enddo; enddo

    do i = 1, var_tec%dim(1); do j = 1, var_tec%dim(2); do k = 1, var_tec%dim(3)
      var_tec%var(i,j,k) = IOfield%block(1)%vars(1,i,j,k)
    enddo; enddo; enddo

    ! Cell centers minimum distance algorithm
    do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)
      
      inside = .false.
      do ii = 1, var_tec%dim(1); do jj = 1, var_tec%dim(2); do kk = 1, var_tec%dim(3)
        
        cell(:,1) = var_tec%node(ii-1,jj-1,kk-1)%c(1:3)*fs
        cell(:,2) = var_tec%node(ii-1,jj  ,kk-1)%c(1:3)*fs
        cell(:,3) = var_tec%node(ii-1,jj-1,kk  )%c(1:3)*fs
        cell(:,4) = var_tec%node(ii-1,jj  ,kk  )%c(1:3)*fs
        cell(:,5) = var_tec%node(ii  ,jj-1,kk-1)%c(1:3)*fs
        cell(:,6) = var_tec%node(ii  ,jj  ,kk-1)%c(1:3)*fs
        cell(:,7) = var_tec%node(ii  ,jj-1,kk  )%c(1:3)*fs
        cell(:,8) = var_tec%node(ii  ,jj  ,kk  )%c(1:3)*fs
       
        inside_loc = .false.
        call pointInsideHexahedron(block%center(i,j,k)%c(1:3)*fs, cell, inside_loc)

        if (inside_loc .eqv. .true.) inside = .true.
      
      enddo; enddo; enddo

      if (inside .eqv. .true.) then
  
        allocate(dx(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3)))
        allocate(dy(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3)))
        allocate(dz(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3)))
        allocate(dist(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3)))
              
        dx(:,:,:) = (block%center(i,j,k)%c(1)-var_tec%center(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3))%c(1))**2
        dy(:,:,:) = (block%center(i,j,k)%c(2)-var_tec%center(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3))%c(2))**2
        dz(:,:,:) = (block%center(i,j,k)%c(3)-var_tec%center(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3))%c(3))**2
        dist(:,:,:) = sqrt(dx(:,:,:)+dy(:,:,:)+dz(:,:,:))

        ind = minloc(dist(:,:,:), MASK=.true.)
        mindist = dist(ind(1),ind(2),ind(3))

        deallocate(dx);deallocate(dy);deallocate(dz);deallocate(dist)

        var(i,j,k) = var_tec%var(ind(1),ind(2),ind(3))

      endif
          
    enddo; enddo; enddo

  end subroutine read_file_tec
  

end module IC_lib_IG