module lib_bc
  use phase_module
  use intersection_module
  use variables
  implicit none
  private

  integer, parameter :: nIG=7
  integer, public, parameter :: nCP=7

  type, public:: obj_bc_cellface_properties
    ! General
    integer:: definition
    character(len=20):: name
    integer:: connection(4)
    logical:: adj_assigned
    ! Ideal gas
    integer:: nproperties
    logical, dimension(:), allocatable       :: IG_time_BC
    character(32), dimension(:), allocatable :: IG_time_properties
    real(8), dimension(:), allocatable       :: properties
    type(obj_species):: species
    ! Condensed phase
    integer:: cp_nproperties
    real(8), dimension(:,:,:), allocatable:: cp_properties
  contains
    procedure,  pass(self):: build
  end type obj_bc_cellface_properties

  type, public:: obj_bc_cell_properties
    real(8), dimension(:,:), allocatable:: chimerainfo
  end type obj_bc_cell_properties


  contains


  !> obj_bc : define n properties depending on bc type
  subroutine build(self,nrans,sourceini,section,phase)
    use finer, only: file_ini
    implicit none
    class(obj_bc_cellface_properties), intent(inout) :: self
    type(phase_type), intent(in)                     :: phase
    type(file_ini), intent(in)                       :: sourceini
    integer, intent(in)                              :: nrans
    character(len=4)                                 :: section

    !% General
    self%connection = 0
    self%adj_assigned = .false.
    self%nproperties = nIG+nrans
    if (self%definition==14) self%nproperties = 8
    if (.not.allocated(self%properties)) allocate(self%properties(1:self%nproperties))
    if (.not.allocated(self%IG_time_BC)) allocate(self%IG_time_BC(1:self%nproperties))
    if (.not.allocated(self%IG_time_properties)) allocate(self%IG_time_properties(1:self%nproperties))

    select case(phase%type)
    !% Ideal gas
    case('IG')
      self%species = phase%species
      self%properties = 0.d0
      if (.not.allocated(self%species%massf)) allocate(self%species%massf(1:self%species%n))
      self%species%massf = 1d-20

    !% Condensed phase
    case('CD')
      self%cp_nproperties = nCP
      if (.not.allocated(self%cp_properties)) &
        allocate(self%cp_properties(1:phase%material%n,1:maxval(phase%material%npCP(:)),1:nCP))
      self%cp_properties = 1d0
    end select

    select case(self%definition)
    case(1);    self%properties = 0.
    case(2);    call assigne_halfPeriodicInfo
    case(3);    self%properties = 0.
    case(4,22); call assemble_the_monster()
    case(5);    call assigne_q;        call assigne_roughness(2)
    case(6);    call assigne_T;        call assigne_roughness(2)
    case(7);    call assigne_hconv;    call assigne_qrad;         call assigne_Tref
    case(8);    call assigne_T;        call assigne_qrad
    case(9);    call assigne_qrad;     call assigne_roughness(2)
    case(10);   call assigne_SF;       call assigne_roughness(2)
    case(11);   self%properties = 0.
    case(12);   call assigne_ablation; call assigne_roughness(6)
    case(13);   call assigne_qrad;     call assigne_roughness(2)
    case(14);   call assigne_SF;       call assigne_SRMgrain(2);  call assemble_the_monster(.true.)
    case(1001); call assigne_manifold;
    end select

    contains

    subroutine assigne_manifold
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='bs', val=self%properties(1), error=error)
      call sourceini%get(section_name=section, option_name='fs', val=self%properties(2), error=error)

    end subroutine assigne_manifold


    subroutine assigne_roughness(pos)
      implicit none
      integer, intent(in) :: pos
      integer:: error

      call sourceini%get(section_name=section, option_name='ks', val=self%properties(pos), error=error)
      if (error/=0) self%properties(pos) = 0.
      !if (error==0) print *, ' rugosity: ', self%properties(1)

    end subroutine assigne_roughness

    subroutine assigne_q
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='q', val=self%properties(1), error=error)
      !if (error==0) print *, ' q: ', self%properties(1)

    end subroutine assigne_q

    subroutine assigne_hconv
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='hconv', val=self%properties(1), error=error)
      if (error/=0) self%properties(1) = 0.

    end subroutine assigne_hconv

    subroutine assigne_Tref
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='Tref', val=self%properties(3), error=error)
      if (error/=0) self%properties(3) = 0.

    end subroutine assigne_Tref

    subroutine assigne_qrad
      implicit none
      integer:: error
      integer:: pos

      pos = 1
      if (self%properties(1)/=0.) pos = 2
      call sourceini%get(section_name=section, option_name='qrad', val=self%properties(pos), error=error)
      if (error/=0) self%properties(pos) = 0.
      !if (error==0) print *, ' qrad: ', self%properties(pos)

    end subroutine assigne_qrad

    subroutine assigne_T
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='T', val=self%properties(1), error=error)
      !if (error==0) print *, ' T: ', self%properties(1)

    end subroutine assigne_T

    subroutine assigne_SF
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='SF', val=self%properties(1), error=error)
      !if (error==0) print *, ' SF: ', self%properties(1)
      if (self%cp_nproperties==nCP) self%cp_properties(:,:,1) = self%properties(1)

    end subroutine assigne_SF

    subroutine assigne_SRMgrain(pos)
      implicit none
      integer, intent(in) :: pos
      integer:: error

      ! |  pos  | pos+1 | pos+2 | pos+3 | pos+4 | pos+5 | pos+6 |
      ! |   a   |   n   | pRef  |  Taf  |  haf  | rhoGr | SFgeo |
      ! |  m-6  |  m-5  |  m-4  |  m-3  |  m-2  |  m-1  |   m   |

      call sourceini%get(section_name=section, option_name='a',        val=self%properties(pos),   error=error)
      if (error/=0) write(*,*) ' ERROR: a coefficient required for SRM grain BC (14)'
      call sourceini%get(section_name=section, option_name='n',        val=self%properties(pos+1), error=error)
      if (error/=0) write(*,*) ' ERROR: n exponent required for SRM grain BC (14)'
      call sourceini%get(section_name=section, option_name='pRef',     val=self%properties(pos+2), error=error)
      if (error/=0) self%properties(pos+2) = 1.d0; self%properties(pos+2) = self%properties(pos+2)*1.d+5
      call sourceini%get(section_name=section, option_name='Taf',      val=self%properties(pos+3), error=error)
      if (error/=0) self%properties(pos+3) = 0.
      call sourceini%get(section_name=section, option_name='rhoGrain', val=self%properties(pos+5), error=error)
      if (error/=0) write(*,*) ' ERROR: grain density (rhoGrain) required for SRM grain BC (14)'
      call sourceini%get(section_name=section, option_name='SFgeo',    val=self%properties(pos+6), error=error)
      if (error/=0) self%properties(pos+6) = 1.d0

    end subroutine assigne_SRMgrain

    subroutine assigne_ablation
      implicit none
      integer:: error
      integer, dimension(2) :: switch

      switch = 5000
      call sourceini%get(section_name=section, option_name='phi', val=self%properties(1), error=error)
      call sourceini%get(section_name=section, option_name='T', val=self%properties(2), error=error)
      call sourceini%get(section_name=section, option_name='q', val=self%properties(3), error=error)
      call sourceini%get(section_name=section, option_name='switch', val=switch, error=error)
      self%properties(4:5) = switch

    end subroutine assigne_ablation

    subroutine assigne_halfPeriodicInfo
      implicit none
      integer:: error
      integer:: wb(2)=0, wf(2)=0

      call sourceini%get(section_name=section, option_name='blocks', val=wb, error=error)
      call sourceini%get(section_name=section, option_name='faces', val=wf, error=error)
      if (error/=0) return
      self%definition = 77
      self%connection = 0
      ! Period information are temporarily stored into connection integers
      self%connection(1:2) = wb
      self%connection(3:4) = wf

    end subroutine assigne_halfPeriodicInfo

    subroutine assemble_the_monster(SRMswitch)
      use species, only: define_composition
      implicit none
      logical, intent(in), optional  :: SRMswitch
      logical                        :: found_CEA, force_inflow
      integer                        :: error, m, npCP, i
      ! Ideal gas
      real(8) :: mach, massflux, p0, T0, h0, CEAh0, T, pstatic, rel_fac, alpha, beta, nmach, mit, kappa, omega, rhoRij, psub, psup, rt, krho
      ! Condensed-phase
      integer :: cp_scaling, error_gp
      real(8), allocatable :: kr(:), ku(:), kt(:), rp(:), dp(:), rRes(:), Tsat(:), volRatio(:)
      real(8), allocatable :: gp(:), up(:), vp(:), wp(:), mvp(:), alphap(:), betap(:), Tp(:)
      real(8), parameter   :: Qal  = 9.53d6      !< Aluminum combustion reaction energy
      real(8), parameter   :: csAl = 1597.6654d0 !< Alumina thermic capacity (CEA thermo lib)

      ! Ideal gas bc
      if (phase%type=='IG'.or.present(SRMswitch)) then
        self%IG_time_BC = .false.
        self%IG_time_properties = 'None'
        found_cea = .false.
        nmach = 0.0; p0 = 0.0; force_inflow = .false.
        call sourceini%get(section_name=section, option_name='force-inflow', val=force_inflow,    error=error)
        call sourceini%get(section_name=section, option_name='mach', val=mach,    error=error)
        if (error==0) nmach = mach
        call sourceini%get(section_name=section, option_name='p0',   val=p0,      error=error)
        if (error==0) p0 = p0*1d+5
        call sourceini%get(section_name=section, option_name='T0',   val=T0,      error=error)
        if (error/=0) T0 = 0.0
        call sourceini%get(section_name=section, option_name='h0',   val=h0,      error=error)
        if (error/=0) h0 = 0.0
        call sourceini%get(section_name=section, option_name='T',    val=T,       error=error)
        if (error/=0) T = 0.0
        call sourceini%get(section_name=section, option_name='g', val=massflux,    error=error)
        if (error==0 .and. nmach==0.0) nmach = -10.0
        call sourceini%get(section_name=section, option_name='alpha',val=alpha,   error=error)
        if (error/=0) alpha = 0.0
        call sourceini%get(section_name=section, option_name='beta', val=beta,    error=error)
        if (error/=0) beta = 0.0
        call sourceini%get(section_name=section, option_name='p',    val=pstatic, error=error)
        if (error/=0) pstatic = 0.0
        call sourceini%get(section_name=section, option_name='rf',   val=rel_fac, error=error)
        if (error/=0) rel_fac = 1.0
        call sourceini%get(section_name=section, option_name='mit',  val=mit,     error=error)
        if (error/=0) mit = 0.0
        call sourceini%get(section_name=section, option_name='kappa',val=kappa,   error=error)
        if (error/=0) kappa = 0.0
        call sourceini%get(section_name=section, option_name='omega',val=omega,   error=error)
        if (error/=0) omega = 0.0
        call sourceini%get(section_name=section, option_name='rhoRij',val=rhoRij, error=error)
        if (error/=0) rhoRij = 0.0

        ! Injector
        call sourceini%get(section_name=section, option_name='psub',val=psub,   error=error)
        if (error==0) alpha = psub
        call sourceini%get(section_name=section, option_name='psup',val=psup,    error=error)
        if (error==0) beta = psup
        rt = 0.0
        call sourceini%get(section_name=section, option_name='rt',  val=rt, error=error)
        if (error==0) pstatic = rt

        ! Assign species mass fractions (if equilibrium also pressure and temperature may be assigned)
        call define_composition(sourceini, self%species, T0, p0, CEAh0)

        if (h0/=0 .and. self%species%n==1) then
          T0 = h02T0(h0,self%species%h,lbound(self%species%h,dim=2))
        else
          h0 = CEAh0
        endif

        ! Time bc
        ! Only total pressure is currently allowed
        call sourceini%get(section_name=section,option_name='p0-time-file',val=self%IG_time_properties(3),error=error)
        if (error==0) self%IG_time_BC(3) = .true.

        ! Force inflow
        if (force_inflow) pstatic = -3.14d-5

        ! Choose between total temperature and static one
        if (nmach<0.0 .and. T>0) nmach = -5.0

        if (.not.present(SRMswitch)) then
          self%properties(1) = nmach
          self%properties(2) = T0
          if (T>0) self%properties(2) = T
          if (nmach>=0) self%properties(3) = p0
          if (nmach<0) self%properties(3) = massflux
          self%properties(4) = alpha
          self%properties(5) = beta
          if (rt/=0.0) then
            self%properties(6) = rt
          else
            self%properties(6) = pstatic*1e+5
          endif
          self%properties(7) = rel_fac
          if (nrans==1) then
            self%properties(nIG+1) = mit
          elseif (nrans==2) then
            self%properties(nIG+1) = kappa
            self%properties(nIG+2) = omega
          elseif (nrans==7) then
            self%properties(nIG+1:nIG+3) = rhoRij
            self%properties(nIG+4:nIG+6) = 1d-8
            self%properties(nIG+7) = omega
          endif
        else
          m = size(self%properties)
          if (self%properties(m-3)>0.5d0) then
            T0 = self%properties(m-3)
            write(*,*) ' Override CEA mixture temperature given adiabatic flame temperature Taf'
            do i = 1, self%species%n
              self%properties(m-2) = self%properties(m-2) + self%species%massf(i)*T02h0(T0,self%species%h,i) 
            enddo
          else
            self%properties(m-3) = T0
            self%properties(m-2) = h0
          endif         
          self%properties(m-6) = self%properties(1)*self%properties(m)*self%properties(m-1)*self%properties(m-6)
        endif

      endif

      if (phase%type/='IG') then

        ! Condensed-phase bc
        do m = 1, phase%material%n
          npCP = phase%material%npCP(m)
          allocate(kr(1:npCP)); kr = 0d0; call sourceini%get(section_name=section, option_name='krho',val=kr,error=error)
          allocate(ku(1:npCP)); ku = 1d0; call sourceini%get(section_name=section, option_name='kV',val=ku,error=error)
          allocate(kt(1:npCP)); kt = 1d0; call sourceini%get(section_name=section, option_name='kT',val=kt,error=error)

          allocate(gp(1:npCP)); gp = 0d0; call sourceini%get(section_name=section, option_name='gp',val=gp,error=error_gp)
          allocate(up(1:npCP)); up = 0d0; call sourceini%get(section_name=section, option_name='up',val=up,error=error)
          allocate(vp(1:npCP)); vp = 0d0; call sourceini%get(section_name=section, option_name='vp',val=vp,error=error)
          allocate(wp(1:npCP)); wp = 0d0; call sourceini%get(section_name=section, option_name='wp',val=wp,error=error)
          allocate(mvp(1:npCP)); mvp = 0d0; call sourceini%get(section_name=section, option_name='|up|',val=mvp,error=error)
          if (error/=0) mvp = sqrt(up**2+vp**2+wp**2)
          allocate(Tp(1:npCP)); Tp = 0d0; call sourceini%get(section_name=section, option_name='Tp',val=Tp,error=error)

          allocate(rp(1:npCP)); call sourceini%get(section_name=section, option_name='rp',val=rp,error=error)
          allocate(dp(1:npCP)); call sourceini%get(section_name=section, option_name='dp',val=dp,error=error)
          if (error==0) rp = 0.5*dp

          allocate(alphap(1:npCP)); alphap = 0d0
          call sourceini%get(section_name=section, option_name='alphap',val=alphap,error=error)
          allocate(betap(1:npCP)); betap = 0d0
          call sourceini%get(section_name=section, option_name='betap',val=betap,error=error)
          allocate(rRes(1:npCP)); rRes = rp
          call sourceini%get(section_name=section, option_name='rRes',val=rRes,error=error)
          allocate(volRatio(1:npCP)); volRatio = (rRes/rp)**3.d0
          
          allocate(Tsat(1:npCP)); Tsat = T0
          call sourceini%get(section_name=section, option_name='Tsat',val=Tsat,error=error)

          if (error_gp/=0) cp_scaling = 0
          if (error_gp==0 .and. all(mvp/=0.d0)) cp_scaling = 1
          if (error_gp==0 .and. all(mvp==0.d0)) cp_scaling = 2

          self%cp_properties(m,1:npCP,1) = dble(cp_scaling)
          if (cp_scaling==0) then
            self%cp_properties(m,1:npCP,2) = kr
            self%cp_properties(m,1:npCP,3) = ku
            self%cp_properties(m,1:npCP,6) = kt
          elseif (cp_scaling==1) then
            self%cp_properties(m,1:npCP,2) = gp
            self%cp_properties(m,1:npCP,3) = mvp
            self%cp_properties(m,1:npCP,6) = Tp
          elseif (cp_scaling==2) then
            self%cp_properties(m,1:npCP,2) = gp
            self%cp_properties(m,1:npCP,3) = ku
            self%cp_properties(m,1:npCP,6) = Tp
          endif
          self%cp_properties(m,1:npCP,4) = alphap
          self%cp_properties(m,1:npCP,5) = betap
          self%cp_properties(m,1:npCP,7) = rp
        enddo

        if (present(SRMswitch)) then
          m = size(self%properties)
          self%properties(m-2) = (csAl*sum(self%cp_properties(m,1:npCP,2)*(volRatio*T0-Tsat))                &
                                  + sum((1d0-self%cp_properties(m,1:npCP,2)*volRatio))*self%properties(m-2)  &
                                  - sum(self%cp_properties(m,1:npCP,2)*(1d0-volRatio))*Qal)                 &
                                  /(1d0-sum(self%cp_properties(m,1:npCP,2)))
          if (all(self%cp_properties(:,:,1)==0.d0)) then
            krho = sum( self%cp_properties(:,:,2) )
          else
            write(*,*) 'ERROR: you should not fix the condensed-phase mass flux when using the SRM grain BC (14)'
            stop
          endif
          self%properties(m-6) = self%properties(m-6)*(1.d0-krho)
        endif
      endif

    end subroutine assemble_the_monster

  end subroutine build


  !> compute T starting from h using tabellams
  function h02T0(h0,h,start) result(T0)
    implicit none
    real(8), intent(in) :: h0
    integer, intent(in) :: start
    real(8), intent(in) :: h(:,start:)
    real(8) :: T0
    integer :: i

    do i = lbound(h, dim=2), ubound(h, dim=2)
      if (h0<=h(1,i) .and. h0>h(1,i-1)) then
        T0 = 1d0/(h(1,i)-(h(1,i-1))*(h0-(h(1,i-1))))+dble(i-1)
        exit
      endif
    enddo

  end function h02T0

  function T02h0(T0,h,s) result(h0)
    implicit none
    real(8), intent(in) :: T0
    real(8), intent(in) :: h(:,:)
    integer, intent(in) :: s
    real(8) :: h0
    integer :: i

    do i = lbound(h, dim=2), ubound(h, dim=2)
      if (T0<=i .and. T0>i-1) then
        h0 = (T0-dble(i-1))*(h(s,i)-(h(s,i-1))) + (h(s,i-1))
        exit
      endif
    enddo

  end function T02h0

end module lib_bc
