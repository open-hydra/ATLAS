submodule (bc_mod) bc_periodic_mod

  implicit none

contains

  module procedure build_periodic
    implicit none
    integer:: error
    integer:: wb(2), wf(2)

    wb = 0; wf = 0

    call sourceini%get(section_name=section, option_name='blocks', val=wb, error=error)
    call sourceini%get(section_name=section, option_name='faces',  val=wf, error=error)

    if (error/=0) return

    self%gp_id = 201
    self%connection = 0
    ! Periodic information are temporarily stored into connection integers
    self%connection(1:2) = wb
    self%connection(3:4) = wf

  end procedure build_periodic


  module procedure build_manifold
    implicit none
    integer:: error

    self%gp_id = 202
    call sourceini%get(section_name=section, option_name='block', val=self%ci_properties(1), error=error)
    call sourceini%get(section_name=section, option_name='face',  val=self%ci_properties(4), error=error)

  end procedure build_manifold

end submodule bc_periodic_mod
