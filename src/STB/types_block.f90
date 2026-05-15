module st_block_mod
  use, intrinsic :: iso_fortran_env, only: R8 => real64
  use grid_mod, only: block_type
  implicit none
  private
  public :: st_block

  !>
  !> Type to hold volumetric heat source qvol in a block
  !> Can be uniform (single value) or spatially distributed (3D array)
  !>
  type :: st_block
    integer :: id = 0
    logical :: is_uniform = .false.
    real(R8) :: uniform_value = 0.0_R8
    real(R8), allocatable :: var(:,:,:)
  contains
    procedure :: allocate
    procedure :: free
  end type st_block

contains

  subroutine allocate(self, dim1, dim2, dim3)
    class(st_block), intent(inout) :: self
    integer, intent(in) :: dim1, dim2, dim3
    
    if (allocated(self%var)) deallocate(self%var)
    allocate(self%var(1:dim1, 1:dim2, 1:dim3))
    self%var = 0.0_R8
    self%is_uniform = .false.
  end subroutine allocate

  subroutine free(self)
    class(st_block), intent(inout) :: self
    if (allocated(self%var)) deallocate(self%var)
  end subroutine free

end module st_block_mod
