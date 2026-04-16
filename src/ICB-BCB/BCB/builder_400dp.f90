submodule (bc_mod) dp_inflow_outflow_mod
  use variables, only: cfg
  use phase_mod, only: phase_t
  implicit none

contains

  module procedure build_inflow_outflow_dp
    implicit none
    integer :: m, npCP
    real(R8), allocatable :: kr(:), ku(:), kt(:)
    real(R8), allocatable :: gp(:), up(:), vp(:), wp(:), mvp(:), Tp(:)
    real(R8), allocatable :: rp(:), dp(:), sigmap(:)
    real(R8), allocatable :: alphap(:), betap(:), rRes(:), volRatio(:), Tsat(:)
    integer :: error, error_gp

    self % dp_n = 7
    if (.not.allocated(self % dp_properties)) &
      allocate(self % dp_properties(1:phase % material % n,1:maxval(phase % material % npCP(:)),1:self % dp_n))
    
    self % dp_properties = 1.0_R8

    do m = 1, phase % material % n
      npCP = phase % material % npCP(m)

      allocate(kr(1:npCP));  kr  = 0.0_R8
      allocate(ku(1:npCP));  ku  = 1.0_R8
      allocate(kt(1:npCP));  kt  = 1.0_R8
      call sourceini%get(section_name=section, option_name='krho',   val=kr, error=error)
      call sourceini%get(section_name=section, option_name='kV',     val=ku, error=error)
      call sourceini%get(section_name=section, option_name='kT',     val=kt, error=error)

      allocate(gp(1:npCP));  gp  = 0.0_R8
      allocate(up(1:npCP));  up  = 0.0_R8
      allocate(vp(1:npCP));  vp  = 0.0_R8
      allocate(wp(1:npCP));  wp  = 0.0_R8
      allocate(mvp(1:npCP)); mvp = 0.0_R8
      allocate(Tp(1:npCP));  Tp  = 0.0_R8
      allocate(rp(1:npCP))
      allocate(dp(1:npCP))
      allocate(sigmap(1:npCP)); sigmap = 0.0_R8
      allocate(alphap(1:npCP)); alphap = huge(1.0_R8)
      allocate(betap(1:npCP));  betap = huge(1.0_R8)
      allocate(rRes(1:npCP)); rRes = rp
      allocate(Tsat(1:npCP)); Tsat = 0.0_R8
      call sourceini%get(section_name=section, option_name='gp',     val=gp, error=error_gp)
      call sourceini%get(section_name=section, option_name='up',     val=up, error=error)
      call sourceini%get(section_name=section, option_name='vp',     val=vp, error=error)
      call sourceini%get(section_name=section, option_name='wp',     val=wp, error=error)
      call sourceini%get(section_name=section, option_name='Vp',      val=mvp, error=error)
      if (error/=0) mvp = sqrt(up**2+vp**2+wp**2)
      call sourceini%get(section_name=section, option_name='Tp',     val=Tp, error=error)
      call sourceini%get(section_name=section, option_name='rp',     val=rp, error=error)
      call sourceini%get(section_name=section, option_name='dp',     val=dp, error=error)
      if (error==0) rp = 0.5*dp
      call sourceini%get(section_name=section, option_name='sigmap', val=sigmap, error=error)
      call sourceini%get(section_name=section, option_name='alphap', val=alphap, error=error)
      call sourceini%get(section_name=section, option_name='betap',  val=betap, error=error)
      call sourceini%get(section_name=section, option_name='rRes',   val=rRes, error=error)
      allocate(volRatio(1:npCP)); volRatio = (rRes/rp)**3.0_R8
      call sourceini%get(section_name=section, option_name='Tsat',   val=Tsat, error=error)

      if (error_gp/=0)                        self % dp_id = 401
      if (error_gp==0 .and. all(mvp/=0.0_R8)) self % dp_id = 402
      if (error_gp==0 .and. all(mvp==0.0_R8)) self % dp_id = 403
      if (self % definition == 'outlet')      self % dp_id = 400

      if (self % dp_id == 401) then
        self % dp_properties(m,1:npCP,1) = kr
        self % dp_properties(m,1:npCP,2) = ku
        self % dp_properties(m,1:npCP,5) = kt

      elseif (self % dp_id == 402) then
        self % dp_properties(m,1:npCP,1) = gp
        self % dp_properties(m,1:npCP,2) = mvp
        self % dp_properties(m,1:npCP,5) = Tp

      elseif (self % dp_id == 403) then
        self % dp_properties(m,1:npCP,1) = gp
        self % dp_properties(m,1:npCP,2) = ku
        self % dp_properties(m,1:npCP,5) = Tp

      else
        self % dp_id = 400

      endif

      self % dp_properties(m,1:npCP,3) = alphap
      self % dp_properties(m,1:npCP,4) = betap
      self % dp_properties(m,1:npCP,6) = rp
      self % dp_properties(m,1:npCP,7) = sigmap

    enddo

  end procedure build_inflow_outflow_dp

end submodule dp_inflow_outflow_mod
