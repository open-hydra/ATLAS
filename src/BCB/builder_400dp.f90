submodule (bc_mod) dp_inflow_outflow_mod
  use bcb_config_mod, only: bcb_dp_boundary_config_t, load_bcb_dp_boundary_config
  use phase_mod, only: phase_t
  implicit none

contains

  module procedure build_inflow_outflow_dp
    implicit none
    integer :: m, npCP
    type(bcb_dp_boundary_config_t) :: cfg

    self % dp_n = 7
    if (.not.allocated(self % dp_properties)) &
      allocate(self % dp_properties(1:phase % material % n,1:maxval(phase % material % npCP(:)),1:self % dp_n))
    if (.not.allocated(self % dp_distribution)) &
      allocate(self % dp_distribution(1:phase % material % n,1:maxval(phase % material % npCP(:))))
    if (.not.allocated(self % dp_ds)) &
      allocate(self % dp_ds(1:phase % material % n,1:maxval(phase % material % npCP(:))))

    self % dp_properties   = 1.0_R8
    self % dp_distribution = 'none'
    self % dp_ds           = 0.0_R8

    call load_bcb_dp_boundary_config(sourceini, section, phase, cfg)

    do m = 1, phase % material % n
      npCP = phase % material % npCP(m)

      if (.not. cfg%materials(m)%has_gp) then
        self % dp_id = 401
      elseif (all(cfg%materials(m)%velocity_magnitude /= 0.0_R8)) then
        self % dp_id = 402
      else
        self % dp_id = 403
      endif
      if (self % definition == 'outlet')      self % dp_id = 400

      if (self % dp_id == 401) then
        self % dp_properties(m,1:npCP,1) = cfg%materials(m)%krho
        self % dp_properties(m,1:npCP,2) = cfg%materials(m)%kV
        self % dp_properties(m,1:npCP,5) = cfg%materials(m)%kT

      elseif (self % dp_id == 402) then
        self % dp_properties(m,1:npCP,1) = cfg%materials(m)%gp
        self % dp_properties(m,1:npCP,2) = cfg%materials(m)%velocity_magnitude
        self % dp_properties(m,1:npCP,5) = cfg%materials(m)%Tp

      elseif (self % dp_id == 403) then
        self % dp_properties(m,1:npCP,1) = cfg%materials(m)%gp
        self % dp_properties(m,1:npCP,2) = cfg%materials(m)%kV
        self % dp_properties(m,1:npCP,5) = cfg%materials(m)%Tp

      else
        self % dp_id = 400

      endif

      self % dp_properties(m,1:npCP,3) = cfg%materials(m)%alphap
      self % dp_properties(m,1:npCP,4) = cfg%materials(m)%betap
      self % dp_properties(m,1:npCP,6) = cfg%materials(m)%rp
      self % dp_properties(m,1:npCP,7) = cfg%materials(m)%sigmap
      self % dp_distribution(m,1:npCP) = cfg%materials(m)%distribution(1:npCP)
      self % dp_ds(m,1:npCP)           = cfg%materials(m)%ds

    enddo

  end procedure build_inflow_outflow_dp

end submodule dp_inflow_outflow_mod
