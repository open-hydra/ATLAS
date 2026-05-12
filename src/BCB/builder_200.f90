submodule (bc_mod) bc_periodic_mod
  use bcb_config_mod, only: bcb_periodic_config_t, load_bcb_periodic_config

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

end submodule bc_periodic_mod
