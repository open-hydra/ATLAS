module bc_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use global_mod
  use bc_names_mod
  use phase_mod
  use finer,        only: file_ini
  implicit none
  private

  !> Boundary data of ONE dispersed phase on a face/cell. bc_t holds one slot per
  !> dispersed phase built on it, found by exact phase name (dp_slot).
  type, public :: dp_slot_t
    character(len=128)         :: phase_name = ''
    integer                    :: id = 0
    integer                    :: n  = 0
    real(8),       allocatable :: properties(:,:,:)     ! material x population x property
    character(32), allocatable :: distribution(:,:)    ! material x population
    real(8),       allocatable :: ds(:,:)              ! material x population (meters)
  end type dp_slot_t

  type, public:: bc_t
    ! General
    character(len=20)          :: name
    character(len=20)          :: definition
    integer                    :: gp_id=0
    logical                    :: time_varying=.false.
    ! Connection info
    integer                    :: ci_n=0
    integer, allocatable       :: ci_properties(:)
    integer                    :: connection(4)=0
    logical                    :: adj_assigned=.false.
    ! Ideal gas
    integer                    :: ig_id=0
    integer                    :: ig_n=0
    character(32), allocatable :: ig_time_file(:)
    logical,       allocatable :: ig_time(:)
    real(8),       allocatable :: ig_properties(:)
    type(species_t)            :: ig_species
    ! Dispersed particles: one slot per dispersed phase associated with the block (P4)
    type(dp_slot_t), allocatable :: dp(:)
    ! Solid phase
    integer                    :: sp_id=0
    integer                    :: sp_n=0
    character(32), allocatable :: sp_time_file(:)
    logical,       allocatable :: sp_time(:)
    real(8),       allocatable :: sp_properties(:)
  contains
    procedure, pass(self)      :: build
    procedure, pass(self)      :: build_inflow_outflow_ig
    procedure, pass(self)      :: build_inflow_outflow_dp
    procedure, pass(self)      :: dp_slot
    procedure, pass(self)      :: build_wall_fluid
    procedure, pass(self)      :: build_wall_solid
    procedure, pass(self)      :: build_periodic
    procedure, pass(self)      :: build_manifold
    procedure, pass(self)      :: build_gsi_ig

  end type bc_t

  interface
    module subroutine build_inflow_outflow_ig(self, sourceini, section, phase)
      class(bc_t),          intent(inout) :: self
      type(file_ini),       intent(in)    :: sourceini
      character(len=*),     intent(in)    :: section
      type(phase_t),        intent(in)    :: phase
    end subroutine

    module subroutine build_inflow_outflow_dp(self, k, sourceini, section, phase)
      class(bc_t),          intent(inout) :: self
      integer,              intent(in)    :: k
      type(file_ini),       intent(in)    :: sourceini
      character(len=*),     intent(in)    :: section
      type(phase_t),        intent(in)    :: phase
    end subroutine

    module subroutine build_wall_fluid(self, sourceini, section, phase)
      class(bc_t),          intent(inout) :: self
      type(file_ini),       intent(in)    :: sourceini
      character(len=*),     intent(in)    :: section
      type(phase_t),        intent(in)    :: phase
    end subroutine

    module subroutine build_wall_solid(self, sourceini, section, phase)
      class(bc_t),          intent(inout) :: self
      type(file_ini),       intent(in)    :: sourceini
      character(len=*),     intent(in)    :: section
      type(phase_t),        intent(in)    :: phase
    end subroutine

    module subroutine build_periodic(self, sourceini, section, phase)
      class(bc_t),          intent(inout) :: self
      type(file_ini),       intent(in)    :: sourceini
      character(len=*),     intent(in)    :: section
      type(phase_t),        intent(in)    :: phase
    end subroutine

    module subroutine build_manifold(self, sourceini, section, phase)
      class(bc_t),          intent(inout) :: self
      type(file_ini),       intent(in)    :: sourceini
      character(len=*),     intent(in)    :: section
      type(phase_t),        intent(in)    :: phase
    end subroutine

    module subroutine build_gsi_ig(self, sourceini, section, phase)
      class(bc_t),          intent(inout) :: self
      type(file_ini),       intent(in)    :: sourceini
      character(len=*),     intent(in)    :: section
      type(phase_t),        intent(in)    :: phase
    end subroutine
  
  end interface

  type, public:: obj_bc_cell_properties
    real(8), dimension(:,:), allocatable:: chimerainfo
  end type obj_bc_cell_properties


contains


  subroutine build(self,sourceini,section,phase)
    use grid_mod, only: mesh_cfg
    use finer,    only: file_ini
    implicit none
    class(bc_t),          intent(inout) :: self
    type(phase_t),        intent(in)    :: phase
    type(file_ini),       intent(in)    :: sourceini
    character(len=*),     intent(in)    :: section
    integer                             :: k

    ! Further initialization
    if (mesh_cfg%meshType==-1) then
      self % ci_n = 3
    elseif (mesh_cfg%meshType==-2) then
      self % ci_n = 4
    else
      self % ci_n = 5
    endif
    if (.not.allocated(self % ci_properties)) then
      allocate(self % ci_properties(1:self % ci_n))
    end if
    self % ci_properties = 0

    ! General BC properties (independent of phase type) are assigned first, based on the definition string. 
    select case(trim(self % definition))
    case(trim(MARKER_NULL))
      self % gp_id = 0
      return

    case(trim(MARKER_CONN), trim(MARKER_CHIM))
      self % gp_id = 100
      return

    case(trim(MARKER_AXIS))
      self % gp_id = 200
      ! [<face>] <phase>-type = outlet | symmetry : that dispersed phase gets 400 | 300 on the axis
      if (phase % type == 'DP') call dispersed_axis_override(self, sourceini, section, phase)
      return

    case(trim(MARKER_SYM))
      self % gp_id = 300
      return

    case(trim(MARKER_EXTRA))
      self % gp_id = 400
      return

    case(trim(MARKER_PER))
      call build_periodic(self, sourceini, section, phase)
      return

    case(trim(MARKER_MANIFOLD))
      call build_manifold(self, sourceini, section, phase)
      return

     ! case default
     !   write(*,*) '[ERROR] BC definition ', trim(self % definition), ' not implemented'
     !   stop

    end select


    ! Phase-specific properties
    select case(phase % type)

    ! Ideal-gas and real-fluid phases
    case('IG', 'RF')

      select case(trim(self % definition))
      case(trim(MARKER_WALL))
        call build_wall_fluid(self, sourceini, section, phase)

      case(trim(MARKER_INLET), trim(MARKER_OUTLET))
        call build_inflow_outflow_ig(self, sourceini, section, phase)

      case(trim(MARKER_GSI))
        call build_gsi_ig(self, sourceini, section, phase)

      ! case default
      !   write(*,*) '[ERROR] BC definition ', trim(self % definition), ' not implemented for ideal gas or real fluid phase'
      !   stop

      end select


    ! Dispersed phase
    case('DP')

      k = self % dp_slot(phase % name)

      select case(trim(self % definition))
      case(trim(MARKER_SYM))
        self % dp(k) % id = 300
        self % dp(k) % n = 0

      case (trim(MARKER_WALL))
        self % dp(k) % id = 301
        self % dp(k) % n = 0

      case (trim(MARKER_INLET), trim(MARKER_OUTLET))
        call build_inflow_outflow_dp(self, k, sourceini, section, phase)

      ! case default
      !   write(*,*) '[ERROR] BC definition ', trim(self % definition), ' not implemented for dispersed phase'
      !   stop

      end select


    ! Solid phase
    case('SP')

      select case(trim(self % definition))
      case(trim(MARKER_wall))
        call build_wall_solid(self, sourceini, section, phase)

      ! case default
      !   write(*,*) '[ERROR] BC definition ', trim(self % definition), ' not implemented for solid phase'
      !   stop
      
      end select


    case default
      write(*,*) '[ERROR] Phase type ', trim(phase % type), ' not supported'
      stop 1
  
    end select

  end subroutine build


  !> Index of the slot holding `phase_name` in self % dp, appending an empty one when
  !> absent. Exact name match, never substring. Every dispersed phase built on a
  !> face/cell therefore keeps its own id and payload arrays.
  function dp_slot(self, phase_name) result(k)
    implicit none
    class(bc_t),      intent(inout) :: self
    character(len=*), intent(in)    :: phase_name
    integer                         :: k
    type(dp_slot_t), allocatable    :: tmp(:)

    if (.not. allocated(self % dp)) allocate(self % dp(0))
    do k = 1, size(self % dp)
      if (trim(self % dp(k) % phase_name) == trim(phase_name)) return
    enddo
    allocate(tmp(1:size(self % dp)+1))
    tmp(1:size(self % dp)) = self % dp
    call move_alloc(tmp, self % dp)
    k = size(self % dp)
    self % dp(k) % phase_name = phase_name
  end function dp_slot


  !> Dispersed-phase override on an axisymmetric face:
  !>   [<face>]  type = axisymmetric  +  <phase>-type = outlet | symmetry
  !> outlet: the phase leaves through the axis (400); symmetry: the phase is mirrored at
  !> the axis (300, what an Eulerian phase wants). The gas keeps 200 either way. The
  !> auto-tagged wedge faces of a 2Daxi mesh carry no section, so the key is absent
  !> there and they keep 200.
  subroutine dispersed_axis_override(self, sourceini, section, phase)
    implicit none
    class(bc_t),          intent(inout) :: self
    type(file_ini),       intent(in)    :: sourceini
    character(len=*),     intent(in)    :: section
    type(phase_t),        intent(in)    :: phase
    character(len=64)                   :: w
    integer                             :: error, k

    if (len_trim(phase % name) == 0) return
    w = ''
    call sourceini%get(section_name=section, option_name=trim(phase % name)//'-type', val=w, error=error)
    if (error /= 0) return
    k = self % dp_slot(phase % name)
    select case (trim(adjustl(w)))
    case ('outlet')
      self % dp(k) % id = 400
      self % dp(k) % n  = 0
    case ('symmetry')
      self % dp(k) % id = 300
      self % dp(k) % n  = 0
    case default
      write(*,'(A)') '[ERROR] '//trim(phase % name)//'-type = '//trim(adjustl(w))// &
                     ': only "outlet" or "symmetry" is allowed for a dispersed phase on an axisymmetric face'
      stop 1
    end select
  end subroutine dispersed_axis_override

  ! subroutine MOSKA_connection(self, sourceini, section)
  !   use finer, only: file_ini
  !   implicit none
  !   class(obj_bc_cellface_properties), intent(inout) :: self
  !   type(file_ini), intent(in) :: sourceini
  !   character(len=*), intent(in) :: section
  !   integer :: error

  !   ! Assegno come prima info di stampa l'iniettore a cui sono connesso, se la condizione al contorno è girata dal 2D o dal 3D
  !   call sourceini%get(section_name=section, option_name='id_inj', val=self%properties(1), error=error)
  !   call sourceini%get(section_name=section, option_name='face_inj', val=self%properties(2), error=error)

  ! end subroutine MOSKA_connection

end module bc_mod
