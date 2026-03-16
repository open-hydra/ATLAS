module lib_bc
  use phase_module
  use intersection_module
  use variables
  use bc_constants, only: nIG_bc, nCP
  use bc_inlet, only: build_inlet
  implicit none
  private

  type, public:: obj_bc_cellface_properties
    ! General
    integer:: definition
    character(len=20):: name
    integer:: connection(4)
    logical:: adj_assigned
    ! Ideal gas
    integer:: nproperties
    logical, dimension(:), allocatable       :: IG_time_BC
    character(32), dimension(:), allocatable :: IG_time_properties
    real(8), dimension(:), allocatable       :: properties
    type(obj_species):: species
    ! Condensed phase
    integer:: cp_nproperties
    real(8), dimension(:,:,:), allocatable:: cp_properties
  contains
    procedure,  pass(self):: build
  end type obj_bc_cellface_properties

  type, public:: obj_bc_cell_properties
    real(8), dimension(:,:), allocatable:: chimerainfo
  end type obj_bc_cell_properties


  contains


  !> obj_bc : define n properties depending on bc type
  subroutine build(self,nrans,sourceini,section,phase)
    use finer, only: file_ini
    implicit none
    class(obj_bc_cellface_properties), intent(inout) :: self
    type(phase_type), intent(in)                     :: phase
    type(file_ini), intent(in)                       :: sourceini
    integer, intent(in)                              :: nrans
    character(len=4)                                 :: section

    !% General
    self%connection = 0
    self%adj_assigned = .false.
    self%nproperties = nIG_bc+nrans
    if (self%definition==14) self%nproperties = 8
    if (.not.allocated(self%properties)) allocate(self%properties(1:self%nproperties))
    if (.not.allocated(self%IG_time_BC)) allocate(self%IG_time_BC(1:self%nproperties))
    if (.not.allocated(self%IG_time_properties)) allocate(self%IG_time_properties(1:self%nproperties))

    select case(phase%type)
    !% Ideal gas
    case('IG')
      self%species = phase%species
      self%properties = 0.d0
      if (.not.allocated(self%species%massf)) allocate(self%species%massf(1:self%species%n))
      self%species%massf = 1d-20

    !% Condensed phase
    case('CD')
      self%cp_nproperties = nCP
      if (.not.allocated(self%cp_properties)) &
        allocate(self%cp_properties(1:phase%material%n,1:maxval(phase%material%npCP(:)),1:nCP))
      self%cp_properties = 1d0
    end select

    select case(self%definition)
    case(1);    self%properties = 0.
    case(2);    call assigne_halfPeriodicInfo
    case(3);    self%properties = 0.
    case(4,22); call build_inlet(self%properties, self%species, &
                    self%IG_time_BC, self%IG_time_properties, &
                    self%cp_properties, self%cp_nproperties, &
                    nrans, sourceini, section, phase)
    case(5);    call assigne_q;        call assigne_roughness(2)
    case(6);    call assigne_T;        call assigne_roughness(2)
    case(7);    call assigne_hconv;    call assigne_qrad;         call assigne_Tref
    case(8);    call assigne_T;        call assigne_qrad
    case(9);    call assigne_qrad;     call assigne_roughness(2)
    case(10);   call assigne_SF;       call assigne_roughness(2)
    case(11);   self%properties = 0.
    case(12);   call assigne_ablation; call assigne_roughness(6)
    case(13);   call assigne_qrad;     call assigne_roughness(2)
    case(14);   call assigne_SF;       call assigne_SRMgrain(2)
                call build_inlet(self%properties, self%species, &
                    self%IG_time_BC, self%IG_time_properties, &
                    self%cp_properties, self%cp_nproperties, &
                    nrans, sourceini, section, phase, &
                    SRMswitch=.true.)
    case(667);  call assigne_TimeVarying
    case(1001); call assigne_manifold;
    case(999);  call MOSKA_connection
    end select

    contains

    subroutine MOSKA_connection
      implicit none
      integer :: error

      ! Assegno come prima info di stampa l'iniettore a cui sono connesso, se la condizione al contorno è girata dal 2D o dal 3D
      call sourceini%get(section_name=section, option_name='id_inj', val=self%properties(1), error=error)
      call sourceini%get(section_name=section, option_name='face_inj', val=self%properties(2), error=error)

    end subroutine MOSKA_connection

    subroutine assigne_manifold
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='bs', val=self%properties(1), error=error)
      call sourceini%get(section_name=section, option_name='fs', val=self%properties(2), error=error)

    end subroutine assigne_manifold


    subroutine assigne_roughness(pos)
      implicit none
      integer, intent(in) :: pos
      integer:: error

      call sourceini%get(section_name=section, option_name='ks', val=self%properties(pos), error=error)
      if (error/=0) self%properties(pos) = 0.
      !if (error==0) print *, ' rugosity: ', self%properties(1)

    end subroutine assigne_roughness

    subroutine assigne_q
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='q', val=self%properties(1), error=error)
      !if (error==0) print *, ' q: ', self%properties(1)

    end subroutine assigne_q

    subroutine assigne_hconv
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='hconv', val=self%properties(1), error=error)
      if (error/=0) self%properties(1) = 0.

    end subroutine assigne_hconv

    subroutine assigne_Tref
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='Tref', val=self%properties(3), error=error)
      if (error/=0) self%properties(3) = 0.

    end subroutine assigne_Tref

    subroutine assigne_qrad
      implicit none
      integer:: error
      integer:: pos

      pos = 1
      if (self%properties(1)/=0.) pos = 2
      call sourceini%get(section_name=section, option_name='qrad', val=self%properties(pos), error=error)
      if (error/=0) self%properties(pos) = 0.
      !if (error==0) print *, ' qrad: ', self%properties(pos)

    end subroutine assigne_qrad

    subroutine assigne_T
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='T', val=self%properties(1), error=error)
      !if (error==0) print *, ' T: ', self%properties(1)

    end subroutine assigne_T

    subroutine assigne_SF
      implicit none
      integer:: error

      call sourceini%get(section_name=section, option_name='SF', val=self%properties(1), error=error)
      !if (error==0) print *, ' SF: ', self%properties(1)
      if (self%cp_nproperties==nCP) self%cp_properties(:,:,1) = self%properties(1)

    end subroutine assigne_SF

    subroutine assigne_SRMgrain(pos)
      implicit none
      integer, intent(in) :: pos
      integer:: error

      ! |  pos  | pos+1 | pos+2 | pos+3 | pos+4 | pos+5 | pos+6 |
      ! |   a   |   n   | pRef  |  Taf  |  haf  | rhoGr | SFgeo |
      ! |  m-6  |  m-5  |  m-4  |  m-3  |  m-2  |  m-1  |   m   |

      call sourceini%get(section_name=section, option_name='a',        val=self%properties(pos),   error=error)
      if (error/=0) write(*,*) ' ERROR: a coefficient required for SRM grain BC (14)'
      call sourceini%get(section_name=section, option_name='n',        val=self%properties(pos+1), error=error)
      if (error/=0) write(*,*) ' ERROR: n exponent required for SRM grain BC (14)'
      call sourceini%get(section_name=section, option_name='pRef',     val=self%properties(pos+2), error=error)
      if (error/=0) self%properties(pos+2) = 1.d0; self%properties(pos+2) = self%properties(pos+2)*1.d+5
      call sourceini%get(section_name=section, option_name='Taf',      val=self%properties(pos+3), error=error)
      if (error/=0) self%properties(pos+3) = 0.
      call sourceini%get(section_name=section, option_name='rhoGrain', val=self%properties(pos+5), error=error)
      if (error/=0) write(*,*) ' ERROR: grain density (rhoGrain) required for SRM grain BC (14)'
      call sourceini%get(section_name=section, option_name='SFgeo',    val=self%properties(pos+6), error=error)
      if (error/=0) self%properties(pos+6) = 1.d0

    end subroutine assigne_SRMgrain

    subroutine assigne_ablation
      implicit none
      integer:: error
      integer, dimension(2) :: switch

      switch = 5000
      call sourceini%get(section_name=section, option_name='phi', val=self%properties(1), error=error)
      call sourceini%get(section_name=section, option_name='T', val=self%properties(2), error=error)
      call sourceini%get(section_name=section, option_name='q', val=self%properties(3), error=error)
      call sourceini%get(section_name=section, option_name='switch', val=switch, error=error)
      self%properties(4:5) = switch

    end subroutine assigne_ablation

    subroutine assigne_halfPeriodicInfo
      implicit none
      integer:: error
      integer:: wb(2)=0, wf(2)=0

      call sourceini%get(section_name=section, option_name='blocks', val=wb, error=error)
      call sourceini%get(section_name=section, option_name='faces', val=wf, error=error)
      if (error/=0) return
      self%definition = 77
      self%connection = 0
      ! Period information are temporarily stored into connection integers
      self%connection(1:2) = wb
      self%connection(3:4) = wf

    end subroutine assigne_halfPeriodicInfo

    subroutine assigne_TimeVarying
      implicit none
      integer :: error

      call sourceini%get(section_name=section, option_name='time-file', val=self%IG_time_properties(1), error=error)
      call sourceini%get(section_name=section, option_name='periodic', val=self%IG_time_BC(1), error=error)

    end subroutine assigne_TimeVarying

  end subroutine build

end module lib_bc
