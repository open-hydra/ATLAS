submodule (bc_mod) dp_inflow_outflow_mod
  use bcb_config_mod, only: bcb_dp_boundary_config_t, load_bcb_dp_boundary_config
  use phase_mod, only: phase_t
  implicit none

contains

  !> Inlet/outlet of ONE dispersed phase into its own slot self % dp(k) (k from bc_t % dp_slot).
  !> The payload arrays are sized from THIS phase (materials x populations), so two phases with
  !> different population counts no longer share one allocation. The id is still assigned per
  !> material in turn (last material wins) - pre-existing, documented limitation.
  module procedure build_inflow_outflow_dp
    implicit none
    integer :: m, npCP
    type(bcb_dp_boundary_config_t) :: cfg

    self % dp(k) % n = 7
    if (allocated(self % dp(k) % properties))   deallocate(self % dp(k) % properties)
    if (allocated(self % dp(k) % distribution)) deallocate(self % dp(k) % distribution)
    if (allocated(self % dp(k) % ds))           deallocate(self % dp(k) % ds)
    allocate(self % dp(k) % properties(1:phase % material % n,1:maxval(phase % material % npCP(:)),1:self % dp(k) % n))
    allocate(self % dp(k) % distribution(1:phase % material % n,1:maxval(phase % material % npCP(:))))
    allocate(self % dp(k) % ds(1:phase % material % n,1:maxval(phase % material % npCP(:))))

    self % dp(k) % properties   = 1.0_R8
    self % dp(k) % distribution = 'none'
    self % dp(k) % ds           = 0.0_R8

    call load_bcb_dp_boundary_config(sourceini, section, phase, cfg)

    do m = 1, phase % material % n
      npCP = phase % material % npCP(m)

      if (.not. cfg%materials(m)%has_gp) then
        self % dp(k) % id = 401
      elseif (all(cfg%materials(m)%velocity_magnitude /= 0.0_R8)) then
        self % dp(k) % id = 402
      else
        self % dp(k) % id = 403
      endif
      if (self % definition == 'outlet')      self % dp(k) % id = 400

      if (self % dp(k) % id == 401) then
        self % dp(k) % properties(m,1:npCP,1) = cfg%materials(m)%krho
        self % dp(k) % properties(m,1:npCP,2) = cfg%materials(m)%kV
        self % dp(k) % properties(m,1:npCP,5) = cfg%materials(m)%kT

      elseif (self % dp(k) % id == 402) then
        self % dp(k) % properties(m,1:npCP,1) = cfg%materials(m)%gp
        self % dp(k) % properties(m,1:npCP,2) = cfg%materials(m)%velocity_magnitude
        self % dp(k) % properties(m,1:npCP,5) = cfg%materials(m)%Tp

      elseif (self % dp(k) % id == 403) then
        self % dp(k) % properties(m,1:npCP,1) = cfg%materials(m)%gp
        self % dp(k) % properties(m,1:npCP,2) = cfg%materials(m)%kV
        self % dp(k) % properties(m,1:npCP,5) = cfg%materials(m)%Tp

      else
        self % dp(k) % id = 400

      endif

      self % dp(k) % properties(m,1:npCP,3) = cfg%materials(m)%alphap
      self % dp(k) % properties(m,1:npCP,4) = cfg%materials(m)%betap
      self % dp(k) % properties(m,1:npCP,6) = cfg%materials(m)%rp
      self % dp(k) % properties(m,1:npCP,7) = cfg%materials(m)%sigmap
      self % dp(k) % distribution(m,1:npCP) = cfg%materials(m)%distribution(1:npCP)
      self % dp(k) % ds(m,1:npCP)           = cfg%materials(m)%ds

    enddo

  end procedure build_inflow_outflow_dp

end submodule dp_inflow_outflow_mod
