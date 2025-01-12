module bc
  use species
  use intersection_module
  use variables
  implicit none
  private

  integer, parameter :: nIG=6
  integer, public, parameter :: nCP=7

  type, public:: obj_bc_cellface_properties
    ! General
    integer:: definition
    character(len=20):: name
    integer:: connection(4)
    logical:: adj_assigned
    ! Ideal gas
    integer:: nproperties
    real(8), dimension(:), allocatable:: properties
    type(obj_species):: species
    ! Condensed phase
    integer:: cp_nproperties
    real(8), dimension(:,:), allocatable:: cp_properties
  contains
    procedure,  pass(self):: build
  end type obj_bc_cellface_properties

  type, public:: obj_bc_cell_properties
    real(8), dimension(:,:), allocatable:: chimerainfo
  end type obj_bc_cell_properties


  contains


  !> obj_bc : define n properties depending on bc type
  subroutine build(self,nrans,sourceini,section,species)
    use finer, only: file_ini
    implicit none
    class(obj_bc_cellface_properties), intent(inout)  :: self
    type(obj_species), intent(in)                     :: species
    type(file_ini), intent(in)                        :: sourceini
    integer, intent(in)                               :: nrans
    character(len=4)                                  :: section

    !% General
    self%connection = 0
    self%adj_assigned = .false.

    !% Ideal gas
    self%nproperties = nIG+nrans
    if (.not.allocated(self%properties) )allocate(self%properties(1:self%nproperties))
    self%properties = 0.d0
    self%species = species
    if (.not.allocated(self%species%massf)) allocate(self%species%massf(1:self%species%n))
    self%species%massf = 1d-20

    !% Condensed phase
    self%cp_nproperties = nCP
    if (.not.allocated(self%cp_properties)) allocate(self%cp_properties(1:npCP,1:nCP))
    self%cp_properties = 1d0

    select case(self%definition)
    case(1);  self%properties = 0.
    case(2);  call assigne_halfPeriodicInfo
    case(3);  self%properties = 0.
    case(4);  call assemble_the_monster
    case(5);  call assigne_q
    case(6);  call assigne_T
    case(8);  call assigne_T; call assigne_qrad
    case(9);  call assigne_qrad
    case(10); call assigne_SF
    case(11); self%properties = 0.
    case(12); call assigne_ablation
    end select

    contains

    subroutine assigne_q
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='q', val=self%properties(1), error=error)
      !if (error==0) print *, ' q: ', self%properties(1)

    end subroutine assigne_q

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
      if (nCP>0) self%cp_properties(1:npCP,1) = self%properties(1)

    end subroutine assigne_SF

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
      self%definition = 1
      self%connection = 0
      ! Period information are temporarily stored into connection integers
      self%connection(1:2) = wb
      self%connection(3:4) = wf

    end subroutine assigne_halfPeriodicInfo

    subroutine assemble_the_monster
      use species
      implicit none
      logical                        :: found_CEA
      integer                        :: error, j
      character(len=200)             :: chardummy
      ! Ideal gas
      real(8) :: mach, massflux, p0, T0, h0, T, pstatic, alpha, beta, nmach, ytot, mit, kappa, omega, rhoRij
      ! Condensed-phase
      integer :: cp_scaling
      real(8), allocatable :: kr(:), ku(:), kt(:), rp(:), dp(:)
      real(8), allocatable :: rhop(:), up(:), vp(:), wp(:), mvp(:), alphap(:), betap(:), Tp(:)

      ! Ideal gas bc
      found_cea = .false.
      nmach = 0.0; ytot = 0.0; p0 = 0.0
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
      call sourceini%get(section_name=section, option_name='mit',  val=mit,     error=error)
      if (error/=0) mit = 0.0
      call sourceini%get(section_name=section, option_name='kappa',val=kappa,   error=error)
      if (error/=0) kappa = 0.0
      call sourceini%get(section_name=section, option_name='omega',val=omega,   error=error)
      if (error/=0) omega = 0.0
      call sourceini%get(section_name=section, option_name='rhoRij',val=rhoRij, error=error)
      if (error/=0) rhoRij = 0.0

      ! Assign species mass fractions (if equilibrium also pressure and temperature may be assigned)
      call define_composition(sourceini, self%species, ytot, T0, p0)

      if (h0/=0 .and. self%species%n>1) then
        error stop ("Not possible to assign h0 to a multispecies flow!")
      elseif (h0/=0 .and. self%species%n==1) then
        T0 = h02T0(h0,self%species%h)
      endif

      ! Time bc
      call sourceini%get(section_name=section,option_name='p0-time-file',val=chardummy,error=error)
      if (error==0) p0 = 1732

      !> Choose between total temperature and static one
      if (nmach<0.0 .and. T>0) nmach = -5.0

      self%properties(1) = nmach
      self%properties(2) = T0
      if (T>0) self%properties(2) = T
      if (nmach>=0) self%properties(3) = p0
      if (nmach<0) self%properties(3) = massflux
      self%properties(4) = alpha
      self%properties(5) = beta
      self%properties(6) = pstatic*1d+5
      if (nrans==1) then
        self%properties(7) = mit
      elseif (nrans==2) then
        self%properties(7) = kappa
        self%properties(8) = omega
      elseif (nrans==7) then
        self%properties(7:9) = rhoRij
        self%properties(10:12) = 1d-8
        self%properties(13) = omega
      endif

      ! Condensed-phase bc
      if (npCP>0) then
        cp_scaling = 1
        allocate(kr(1:npCP)); kr = 0d0; call sourceini%get(section_name=section, option_name='krho',val=kr,error=error)
        if (error==0) cp_scaling = 0
        allocate(ku(1:npCP)); ku = 1d0; call sourceini%get(section_name=section, option_name='kV',val=ku,error=error)
        allocate(kt(1:npCP)); kt = 1d0; call sourceini%get(section_name=section, option_name='kT',val=kt,error=error)

        allocate(rhop(1:npCP)); rhop = 0d0; call sourceini%get(section_name=section, option_name='rhop',val=rhop,error=error)
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

        self%cp_properties(:,1) = dble(cp_scaling)
        if (cp_scaling==0) then
          self%cp_properties(:,2) = kr
          self%cp_properties(:,3) = ku
          self%cp_properties(:,6) = kt
        else
          self%cp_properties(:,2) = rhop
          self%cp_properties(:,3) = mvp
          self%cp_properties(:,6) = Tp
        endif
        self%cp_properties(:,4) = alphap
        self%cp_properties(:,5) = betap
        self%cp_properties(:,7) = rp
      endif

    end subroutine assemble_the_monster

  end subroutine build


  !> compute T starting from h using tabellams
  function h02T0(h0,h) result(T0)
    implicit none
    real(8), intent(in) :: h0
    real(8), intent(in) :: h(:,:)
    real(8) :: T0
    integer :: n(2)
    integer :: i

    do i = lbound(h, dim=2), ubound(h, dim=2)
      if (h0<=h(1,i) .and. h0>h(1,i-1)) then
        T0 = 1d0/(h(1,i)-(h(1,i-1))*(h0-(h(1,i-1))))+dble(i-1)
        exit
      endif
    enddo

  end function h02T0

end module bc
