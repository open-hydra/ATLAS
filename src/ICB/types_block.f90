!> IC block type: extends block_type with initial-condition fields.
module ic_block_mod
  use grid_mod
  use phase_mod
  implicit none
  private
  public :: import_nodes

  type, public :: IC_block_ig
    real(8), dimension(:,:,:,:), allocatable   :: density
    real(8), dimension(:,:,:), allocatable     :: temperature
    real(8), dimension(:,:,:), allocatable     :: pressure
    real(8), dimension(:,:,:), allocatable     :: mil, kl
    real(8), dimension(:,:,:,:), allocatable   :: turbprop
    real(8), dimension(:,:,:,:), allocatable   :: velocity
    real(8)                                    :: gamma = 0.d0
    real(8)                                    :: R = 0.d0
  end type IC_block_ig

  type, public :: IC_block_rf
    real(8), dimension(:,:,:), allocatable     :: temperature
    real(8), dimension(:,:,:), allocatable     :: enthalpy
    real(8), dimension(:,:,:), allocatable     :: pressure
    real(8), dimension(:,:,:,:), allocatable   :: turbprop
    real(8), dimension(:,:,:,:), allocatable   :: velocity
  end type IC_block_rf

  type, public :: IC_block_dp
    real(8), dimension(:,:,:,:), allocatable   :: density
    real(8), dimension(:,:,:,:,:), allocatable :: velocity
    real(8), dimension(:,:,:,:), allocatable   :: temperature
    real(8), dimension(:,:,:,:), allocatable   :: nP
    real(8), dimension(:,:,:,:), allocatable   :: pseudopressure
  end type IC_block_dp

  type, public :: IC_block_sp
    real(8), dimension(:,:,:), allocatable     :: mID
    real(8), dimension(:,:,:), allocatable     :: qvol
    real(8), dimension(:,:,:), allocatable     :: temperature
  end type IC_block_sp

  type, extends(block_type), public :: var_block
    real(8), allocatable                   :: var(:,:,:)
  end type var_block

  type, extends(block_type), public :: IC_block
    character(len=20)                          :: type = ''
    type(IC_block_ig)                          :: ig
    type(IC_block_rf)                          :: rf
    type(IC_block_dp)                          :: dp
    type(IC_block_sp)                          :: sp
    type(phase_t), dimension(:), allocatable   :: associated_phase
    integer                                    :: id = 0
    integer                                    :: nrans = 0
    integer                                    :: neuler = 0
  contains
    private
    procedure, pass(self), public :: allocate
  end type IC_block

contains

  subroutine allocate(self,rr,ss,ii,jj,kk)
    implicit none
    class(IC_block), intent(inout) :: self
    integer, intent(in)            :: ss, rr, ii, jj, kk

    allocate(self%ig%density(1:ss,1:ii,1:jj,1:kk))
    allocate(self%ig%velocity(1:3,1:ii,1:jj,1:kk))
    allocate(self%ig%pressure(1:ii,1:jj,1:kk))
    allocate(self%ig%turbprop(1:rr,1:ii,1:jj,1:kk))
    allocate(self%ig%mil(1:ii,1:jj,1:kk))
    allocate(self%ig%kl(1:ii,1:jj,1:kk))
    allocate(self%ig%temperature(1:ii,1:jj,1:kk))
    allocate(self%sp%mID(1:ii,1:jj,1:kk))
    allocate(self%sp%qvol(1:ii,1:jj,1:kk))
    allocate(self%rf%temperature(1:ii,1:jj,1:kk))
  end subroutine allocate

end module ic_block_mod
