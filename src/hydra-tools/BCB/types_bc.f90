module bc_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use global_mod
  use bc_names_mod
  use phase_mod
  use finer,        only: file_ini
  implicit none
  private

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
    ! Dispersed particles
    integer                    :: dp_id=0
    integer                    :: dp_n=0
    real(8),       allocatable :: dp_properties(:,:,:)
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
    procedure, pass(self)      :: build_wall_fluid
    procedure, pass(self)      :: build_wall_solid
    procedure, pass(self)      :: build_periodic
    procedure, pass(self)      :: build_manifold
    procedure, pass(self)      :: build_srm_ig

  end type bc_t

  interface
    module subroutine build_inflow_outflow_ig(self, sourceini, section, phase)
      class(bc_t),          intent(inout) :: self
      type(file_ini),       intent(in)    :: sourceini
      character(len=*),     intent(in)    :: section
      type(phase_t),        intent(in)    :: phase
    end subroutine

    module subroutine build_inflow_outflow_dp(self, sourceini, section, phase)
      class(bc_t),          intent(inout) :: self
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

    module subroutine build_srm_ig(self, sourceini, section, phase)
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
    select case(phase%type)

    ! Ideal gas
    case('IG', 'RF')

      select case(trim(self % definition))
      case(trim(MARKER_WALL))
        call build_wall_fluid(self, sourceini, section, phase)

      case(trim(MARKER_INLET), trim(MARKER_OUTLET))
        call build_inflow_outflow_ig(self, sourceini, section, phase)

      case(trim(MARKER_SRM))
        call build_srm_ig(self, sourceini, section, phase)

      ! case default
      !   write(*,*) '[ERROR] BC definition ', trim(self % definition), ' not implemented for ideal gas or real fluid phase'
      !   stop

      end select


    ! Dispersed phase
    case('DP')

      select case(trim(self % definition))
      case(trim(MARKER_SYM))
        self % dp_id = 300
        self % dp_n = 0

      case (trim(MARKER_WALL))
        self % dp_id = 301
        self % dp_n = 0

      case (trim(MARKER_INLET), trim(MARKER_OUTLET))
        call build_inflow_outflow_dp(self, sourceini, section, phase)

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
      stop
  
    end select

  end subroutine build

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
