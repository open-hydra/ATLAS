submodule (bc_mod) bc_periodic_mod
  use bcb_config_mod, only: bcb_periodic_config_t, bcb_manifold_config_t, &
                            load_bcb_periodic_config, load_bcb_manifold_config

  implicit none

contains

  module procedure build_periodic
    implicit none
    type(bcb_periodic_config_t) :: cfg

    call load_bcb_periodic_config(sourceini, section, cfg)
    if (.not. cfg%has_connection) return

    self%gp_id = 201
    self%connection = 0
    ! Periodic information are temporarily stored into connection integers
    self%connection(1:2) = cfg%blocks
    self%connection(3:4) = cfg%faces

  end procedure build_periodic


  module procedure build_manifold
    implicit none
    type(bcb_manifold_config_t) :: cfg

    self%gp_id = 202
    call load_bcb_manifold_config(sourceini, section, cfg)
    self%ci_properties(1) = cfg%block
    self%ci_properties(4) = cfg%face

  end procedure build_manifold

end submodule bc_periodic_mod
