module lib_ic
  use ATLAS_high_level
  use finer, only: file_ini
  implicit none
  private
  public:: build_IC

  integer, parameter :: nIG=5
  real(8), parameter :: runi=8314.51d0

  character(len=2)        :: nozzle_dir
  real(8)                 :: L_threshold
  integer                 :: L_threshold_cell

  contains

  subroutine build_IC(phase,sini,blocks)
    use species, only: obj_species
    use ATLAS_IO, only: read_idealgas_properties
    use strings, only: parse
    implicit none
    type(phase_type), intent(in)     :: phase(:)
    type(ATLAS_block), intent(inout) :: blocks(:)
    type(file_ini), intent(in)       :: sini

    character(len=30)             :: zonename, section_name
    character(len=:), allocatable :: option_pairs(:)
    type(file_ini)                :: zoneini
    integer                       :: b, p, error, error_zone
    character(len=4)              :: indb, ind
    character(len=4)              :: zonedirection
    real(8)                       :: zonerange(4)
    character(len=20)             :: wholestring, args(3), phase_name

    do b = 1, size(blocks)
      write(indb,'(I4)') b
      section_name = 'ICB-Block'//adjustl(indb)   
      associate(block => blocks(b))

      ! Look for phases solved in block b
      call sini%get(section_name=section_name, option_name='phase', val=wholestring, error=error)
      if (error/=0) then
        allocate(block%associated_phase(1:size(phase)))
        block%associated_phase = phase
      else
        allocate(block%associated_phase(1))
        do p = 1, size(phase)
          if (phase(p)%name==trim(wholestring)) then
            block%associated_phase(1) = phase(p)
            exit
          endif
        enddo
      endif

      ! Check phase name
      if (block%associated_phase(1)%name=='') then
        phase_name = ''
      else
        phase_name = trim(block%associated_phase(1)%name)//'-'
      endif

      ! Read phase properties (if any)
      if (block%associated_phase(1)%type=='IG') then
        call read_idealgas_properties(trim(phase_name),block%species)
        if (.not.allocated(block%species%massf)) allocate(block%species%massf(1:block%species%n))
        block%species%massf = 1d-20
      endif

      call sini%get(section_name=section_name, option_name='type', val=block%type, error=error)
      if (error/=0) block%type = 'homogeneous'
      ! Multizone
      call sini%get(section_name=section_name, option_name='direction',  val=zonedirection, error=error)
      if (error==0) block%type = 'multizone'

      if (block%type=='multizone') then
        p = 0
        do
          p = p+1; write(ind,'(I4)') p
          call sini%get(section_name=section_name, option_name='zone'//adjustl(ind), &
                                            val=zonename, error=error_zone)
          if (error_zone/=0) exit
          call sini%get(section_name=section_name, option_name='range'//adjustl(ind), &
                                            val=zonerange, error=error)
          call zoneini%free
          call zoneini%add(section_name='zone')
          do while (sini%loop(section_name=zonename, option_pairs=option_pairs))
            call zoneini%add(section_name='zone', option_name=option_pairs(1), val=option_pairs(2))
          enddo
          call zoneini%add(section_name='zone', option_name='range', val=zonerange)
          call zoneini%add(section_name='zone', option_name='direction', val=zonedirection)
          call build_field(b,block,zoneini,block%associated_phase(1)%type)
        enddo
      else
        call zoneini%free
        call zoneini%add(section_name='zone')
        do while (sini%loop(section_name=section_name, option_pairs=option_pairs))
          call zoneini%add(section_name='zone', option_name=option_pairs(1), val=option_pairs(2))
        enddo
        call build_field(b,block,zoneini,block%associated_phase(1)%type)
      endif

      write(*,*)' Block n. = ', b, ' -> ', block%type
      endassociate
    enddo

  end subroutine build_IC


  !> Builds the field for a given block based on the provided zone initialization and phase type.
  !! @param self The block object to be initialized.
  !! @param zoneini The zone initialization object containing configuration data.
  !! @param phase The type of phase (e.g., 'IG' for ideal gas).
  subroutine build_field(b,self,zoneini,phase)
    use variables, only: nrans
    use Interpolator
    use species, only: define_composition
    implicit none
    integer, intent(in)               :: b
    class(ATLAS_block), intent(inout) :: self
    type(file_ini), intent(in)        :: zoneini
    character(len=2), intent(in)      :: phase
    logical                       :: found(5)
    integer                       :: throat_cell, i, ib1, ib2, ip, j, s, k, error
    real(8)                       :: Rgas, gamma, rho, vel, del, a, cp_
    real(8)                       :: M0, mach
    real(8)                       :: alpha, beta, M, p0, T0, p, T, ux, uy, uz, mit, kappa, omega, rhoRij
    real(8)                       :: throat_area, dx, dy, dz, zeta, phi
    real(8), allocatable          :: radius_ext(:), radius_int(:), area(:)
    character(len=llen)           :: OMF, OFF, OSF
    integer                       :: oldid
    character(len=20)             :: type
    real(8)                       :: ytot=0.0, range(6)
    character(len=3)              :: dirID
    integer                       :: dirSize
    integer, allocatable          :: dir(:)
    real(8)                       :: here(3)
    real(8)                       :: R1, uTF

    call zoneini%get(section_name='zone', option_name='type', val=type, error=error)
    if (error/=0) type='homogeneous'

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
    onemesh = .true.; onespecies = .true.
    call zoneini%get(section_name='zone', option_name='oldmesh', val=OMF, error=error)
    if (error==0) onemesh = .false.
    call zoneini%get(section_name='zone', option_name='oldspecies', val=OSF, error=error)
    if (error==0) onespecies = .false.
    call zoneini%get(section_name='zone', option_name='oldsolution', val=OFF, error=error)
    if (error==0) type = 'interpolation'
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

    self%type = type

    select case (phase)
    case('IG')

      self%species%massf = 1d-20

      ! Assign species mass fractions and temperature (if equilibrium)
      if (self%species%n==1) then
        ! Look for single-species case
        self%species%massf = 1.0
      else
        ! Chemical equilibrium input
        call define_composition(zoneini, self%species, ytot, T0, p0)
        ! Look for inertMix presence
        do j = 1, self%species%n
          if (self%species%name(j)=='inertMix') then
            self%species%massf(j) = 1.0-ytot
          else
            self%species%massf(j) = self%species%massf(j) / ytot
          endif
        enddo
      endif

      if (.not.allocated(self%density)) then
        allocate(self%density(self%species%n,1:self%dim(1),1:self%dim(2),1:self%dim(3)))
        allocate(self%velocity(3,1:self%dim(1),1:self%dim(2),1:self%dim(3)))
        allocate(self%pressure(1:self%dim(1),1:self%dim(2),1:self%dim(3)))
        if (nrans>0) allocate(self%turbprop(nrans,1:self%dim(1),1:self%dim(2),1:self%dim(3)))
      endif

    case ('SP')

      if (.not.allocated(self%temperature)) then
        allocate(self%temperature(1:self%dim(1),1:self%dim(2),1:self%dim(3)))
      endif

    end select

    ! Check direction
    dirSize = 0
    call zoneini%get(section_name='zone', option_name='direction', val=dirID, error=error)
    if (error==0) then
      found = .false.
      dirSize = len_trim(dirID)
      allocate(dir(1:dirSize))
      do i = 1, dirSize
        if (index(dirID,'x')/=0 .and. .not.found(1)) then
          dir(i) = 1; found(1)=.true.
        elseif (index(dirID,'y')/=0 .and. .not.found(2)) then
          dir(i) = 2; found(2)=.true.
        elseif (index(dirID,'z')/=0 .and. .not.found(3)) then
          dir(i) = 3; found(3)=.true.
        elseif (index(dirID,'r')/=0 .and. .not.found(4)) then
          dir(i) = 4; found(4)=.true.
        elseif (index(dirID,'t')/=0 .and. .not.found(5)) then
          dir(i) = 5; found(5)=.true.
        endif
      enddo
    endif

    ! Check range for multizone
    call zoneini%get(section_name='zone',option_name='range',val=range, error=error)
    if (error/=0) then
      do i = 1, 6 ; range(i) = (-1.0)**i*huge(range(i)) ; enddo
    else
      do i = dirSize*2+1, 6 ; range(i) = (-1.0)**i*huge(range(i)) ; enddo
    endif

    select case (type)

    case ('interpolation')

      select case (phase)
      case('IG')
        call intersol(self,OMF,OFF,OSF,oldid,b)
      case('SP')
        error stop ('--- Interpolation not implemented for SP ---')
      end select

    case ('homogeneous')

      select case (phase)
      case('IG')

        ! R
        Rgas = sum(Runi*self%species%massf/self%species%w)

        ! Temperature
        if (T0==0 .and. T==0) T = p/(Rgas*rho)
        if (T0/=0 .and. T==0) T = T02T(T0,self%species%massf,self%species%cp,self%species%dcp,self%species%h,M,Rgas)
        cp_ = sum(self%species%massf*self%species%cp(:,nint(T)))
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
        do k = 1, self%dim(3); do j = 1, self%dim(2); do i = 1, self%dim(1)
              if (dirSize>=1) here(1) = self%center(i,j,k)%c(dir(1))
              if (dirSize>=2) here(2) = self%center(i,j,k)%c(dir(2))
              if (dirSize>=3) here(3) = self%center(i,j,k)%c(dir(3))
              if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
                  here(2)>=range(3) .and. here(2)<=range(4) .and. &
                  here(3)>=range(5) .and. here(3)<=range(6)) then
                do s = 1, self%species%n
                  self%density(s,i,j,k) = rho*self%species%massf(s)
                enddo
                a = sqrt(gamma*Rgas*T)
                vel = M*a
                if (ux==0) then
                  self%velocity(1,i,j,k) = vel*cos(alpha)*cos(beta)
                else
                  self%velocity(1,i,j,k) = ux
                endif
                if (uy==0) then
                  self%velocity(2,i,j,k) = vel*cos(alpha)*sin(beta)
                else
                  self%velocity(2,i,j,k) = uy
                endif
                if (uz==0) then
                  self%velocity(3,i,j,k) = vel*sin(beta)
                else
                  self%velocity(3,i,j,k) = uz
                endif
                self%pressure(i,j,k) = p
              endif
        enddo; enddo; enddo

      case('SP')

        self%temperature = T

      end select

    case ('1D-centcomp' , '1D-cubcomp')

      Rgas = sum(Runi*self%species%massf/self%species%w)
      cp_ = sum(self%species%massf*self%species%cp(:,1))
      gamma = cp_/(cp_-Rgas)
      del = 0.5*(gamma-1)

      here = 1.0
      do k = 1, self%dim(3); do j = 1, self%dim(2); do i = 1, self%dim(1)
            if (dirSize>=1) here(1) = self%center(i,j,k)%c(dir(1))
            if (dirSize>=2) here(2) = self%center(i,j,k)%c(dir(2))
            if (dirSize>=3) here(3) = self%center(i,j,k)%c(dir(3))
            if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
                here(2)>=range(3) .and. here(2)<=range(4) .and. &
                here(3)>=range(5) .and. here(3)<=range(6)) then
              select case(type)
                case('1D-centcomp'); call centered_compression()
                case('1D-cubcomp');  call cubic_compression()
              end select
              self%velocity(2,i,j,k) = 0.0
              self%velocity(3,i,j,k) = 0.0
            endif
      enddo; enddo; enddo

    case ('nozzle')

      allocate(radius_ext(1:self%dim(1)))
      allocate(radius_int(1:self%dim(1)))
      allocate(area(1:self%dim(1)))

      Rgas = sum(Runi*self%species%massf/self%species%w)
      cp_ = sum(self%species%massf*self%species%cp(:,nint(T0)))
      gamma = cp_/(cp_-Rgas)
      del = 0.5*(gamma-1)

      do i = 1, self%dim(1)
        radius_ext(i) = sqrt( 0.25*(self%node(i-1,self%dim(2),0)%c(2)+self%node(i,self%dim(2),0)%c(2))**2 + &
                              0.25*(self%node(i-1,self%dim(2),0)%c(3)+self%node(i,self%dim(2),0)%c(3))**2 )
        radius_int(i) = sqrt( 0.25*(self%node(i-1,0,0)%c(2)+self%node(i,0,0)%c(2))**2 + &
                              0.25*(self%node(i-1,0,0)%c(3)+self%node(i,0,0)%c(3))**2 )
      enddo
      area = acos(-1d0)*abs(radius_ext*radius_ext-radius_int*radius_int)
      throat_cell = minloc(area,1)
      throat_area = area(throat_cell)

      ib1 = 1; ib2 = self%dim(1); ip = 1
      do i = ib1, ib2
        if (self%center(i,1,1)%c(1)>L_threshold) then
          L_threshold_cell = i
          exit
        endif
      enddo

      if (nozzle_dir=='dx') then
        ip = 1
        ib1 = L_threshold_cell+1
        ib2 = self%dim(1)
      elseif (nozzle_dir=='sx') then
        ip = -1
        ib1 = L_threshold_cell-1
        ib2 = 0
      endif

      do i = 1, ib1-1, ip
        do s = 1, self%species%n
          self%density(s,i,:,:) = self%species%massf(s)*p0/(Rgas*T0)
        enddo
        self%pressure(i,:,:) = p0
        self%velocity(:,i,:,:) = 0.0
      enddo

      do i = ib1, ib2, ip
        M0 = 0.001
        if (i>throat_cell) M0 = 1.30
        call legge_aree(area(i),M0,Mach,throat_area,gamma)
        here = 1.0
        do k = 1, self%dim(3)
          do j = 1, self%dim(2)
            if (dirSize>=1) here(1) = self%center(i,j,k)%c(dir(1))
            if (dirSize>=2) here(2) = self%center(i,j,k)%c(dir(2))
            if (dirSize>=3) here(3) = self%center(i,j,k)%c(dir(3))
            if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
                here(2)>=range(3) .and. here(2)<=range(4) .and. &
                here(3)>=range(5) .and. here(3)<=range(6)) then
              dx = self%center(i,j,k)%c(1)-self%center(i-1,j,k)%c(1)
              dy = self%center(i,j,k)%c(2)-self%center(i-1,j,k)%c(2)
              dz = self%center(i,j,k)%c(3)-self%center(i-1,j,k)%c(3)
              zeta = atan(dy/sqrt(dx*dx+dz*dz))
              phi = atan(dz/dx)
              do s = 1, self%species%n
                self%density(s,i,j,k) = self%species%massf(s)*p0/(Rgas*T0)/((1+del*(Mach**2))**(0.5/del))
              enddo
              self%pressure(i,j,k) = p0/((1+del*(Mach**2))**(gamma/(2*del)))
              self%velocity(1,i,j,k) = Mach*sqrt(gamma*Rgas*T0/(1+del*(Mach**2)))*cos(zeta)*cos(phi)
              self%velocity(2,i,j,k) = Mach*sqrt(gamma*Rgas*T0/(1+del*(Mach**2)))*sin(zeta)
              self%velocity(3,i,j,k) = Mach*sqrt(gamma*Rgas*T0/(1+del*(Mach**2)))*cos(zeta)*sin(phi)
            endif
          end do 
        end do
      end do

    end select

    ! Turbulence specific parameters
    select case (phase)
    case('IG')
      if (nrans==1) then
        self%turbprop(1,:,:,:) = mit
        if(mit/=0.0) self%turbprop(1,:,:,:) = mit
      elseif (nrans==2) then
        if(kappa/=0.0) self%turbprop(1,:,:,:) = kappa
        if(omega/=0.0) self%turbprop(2,:,:,:) = omega
      elseif (nrans==7) then
        if(rhoRij/=0.0) self%turbprop(1:3,:,:,:) = rhoRij
        self%turbprop(4:6,:,:,:) = 1d-8
        if(omega/=0.0) self%turbprop(7,:,:,:) = omega
      endif
    end select
  
  contains
  ! 1D specific ICs

    ! Centered compression assuming rest for the state ahead of the compression wave
    subroutine centered_compression()
      implicit none
      real(8) :: alpha(2), pol
      alpha(1) = uTF; alpha(2) = -1/(range(2)-range(1))
      pol = alpha(1)+alpha(2)*(here(1)-range(1))
      self%velocity(1,i,j,k) = (pol-R1)/(1.d0+del)
      a = R1+del*self%velocity(1,i,j,k)
      self%pressure(i,j,k) = (a/R1)**(gamma/del)
      do s = 1, self%species%n
        self%density(s,i,j,k) = gamma*self%pressure(i,j,k)/(a*a)*self%species%massf(s)
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
      self%velocity(1,i,j,k) = (pol-R1)/(1.d0+del)
      a = R1+del*self%velocity(1,i,j,k)
      self%pressure(i,j,k) = (a/R1)**(gamma/del)
      do s = 1, self%species%n
        self%density(s,i,j,k) = gamma*self%pressure(i,j,k)/(a*a)*self%species%massf(s)
      enddo
    end subroutine cubic_compression

  end subroutine build_field

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


end module lib_ic
