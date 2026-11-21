!> The manifold groups of a BCB run (BC 501). One group per `manifold` section of the deck, numbered in the
!> order the sections are first met as the faces are built (block, then face order; the same on every multigrid
!> level, the registry lives for the whole run). A group holds the faces the section lists with their roles --
!> outlet, where the gas leaves the domain into the manifold; inlet, where it comes back -- as the deck's block
!> and face numbers, and the parameters written into every record of the group: the loss coefficient K on the
!> dynamic head of the outlet faces, the relaxation factor rf, and the three ratios of a lumped link (mass flow,
!> total pressure, total-enthalpy drop) from the outlet to the inlet faces. The solvers group the records by id
!> and apply the roles as given: no sign of the flow decides them.
module manifold_groups_mod
  use iso_fortran_env, only: R8 => real64
  implicit none
  private

  public :: manifold_group_t, manifold_register, manifold_role, manifold_ngroups, manifold_group

  integer, parameter, public :: MANIFOLD_OUTLET = 1   !< role of a face where the gas leaves the domain
  integer, parameter, public :: MANIFOLD_INLET  = 2   !< role of a face where the gas comes back in

  type :: manifold_group_t
    character(len=20)    :: name = ''                       !< the section
    integer              :: n_out = 0, n_in = 0
    integer, allocatable :: out_bf(:,:), in_bf(:,:)          !< (2, n): block and face of the deck
    real(R8)             :: K          = 0.0_R8             !< loss on the dynamic head of the outlet faces
    real(R8)             :: rf         = 1.0_R8             !< relaxation factor of the inlet and outlet faces
    real(R8)             :: mdot_ratio = 1.0_R8             !< mass flow in over mass flow out
    real(R8)             :: p0_ratio   = 1.0_R8             !< total pressure in over total pressure out
    real(R8)             :: dh0        = 0.0_R8             !< total enthalpy taken out between the two [J/kg]
  end type manifold_group_t

  type(manifold_group_t), allocatable, save :: groups(:)

contains

  !> The id of the group of section g%name: registered on first sight, found by name afterwards (the builder
  !> runs once per face, per phase, per level; the section's keys are the same every time).
  function manifold_register(g) result(gid)
    type(manifold_group_t), intent(in) :: g
    integer :: gid
    type(manifold_group_t), allocatable :: tmp(:)

    if (.not. allocated(groups)) allocate(groups(0))
    do gid = 1, size(groups)
      if (trim(groups(gid)%name) == trim(g%name)) return
    enddo
    allocate(tmp(size(groups)+1))
    tmp(1:size(groups)) = groups
    tmp(size(groups)+1) = g
    call move_alloc(tmp, groups)
    gid = size(groups)
  end function manifold_register

  !> The role of face f of block b (deck numbers) in group gid: MANIFOLD_OUTLET, MANIFOLD_INLET, or 0 when the
  !> section lists it in neither.
  pure function manifold_role(gid, b, f) result(role)
    integer, intent(in) :: gid, b, f
    integer :: role, i

    role = 0
    if (.not. allocated(groups)) return
    if (gid < 1 .or. gid > size(groups)) return
    do i = 1, groups(gid)%n_out
      if (groups(gid)%out_bf(1,i) == b .and. groups(gid)%out_bf(2,i) == f) role = MANIFOLD_OUTLET
    enddo
    do i = 1, groups(gid)%n_in
      if (groups(gid)%in_bf(1,i) == b .and. groups(gid)%in_bf(2,i) == f) role = MANIFOLD_INLET
    enddo
  end function manifold_role

  pure function manifold_ngroups() result(n)
    integer :: n
    n = 0
    if (allocated(groups)) n = size(groups)
  end function manifold_ngroups

  function manifold_group(gid) result(g)
    integer, intent(in) :: gid
    type(manifold_group_t) :: g
    g = groups(gid)
  end function manifold_group

end module manifold_groups_mod
