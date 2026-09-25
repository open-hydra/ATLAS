submodule (bc_mod) bc_connection_smod
  use bcb_config_mod, only: bcb_connection_config_t, load_bcb_connection_config

  implicit none

contains

  module procedure build_connection
    implicit none
    type(bcb_connection_config_t) :: cfg

    call load_bcb_connection_config(sourceini, section, cfg)

    ! Wall roughness seen by the fluid when the connection turns into a
    ! multi-solver interface (103); 0 if not given
    self % ci_ks = cfg%ks

  end procedure build_connection

end submodule bc_connection_smod
