!> IC interpolation block type: holds mesh and field data for a single
!> block used during initial-condition spatial interpolation.
module var_block_mod
  use ATLAS_Mod_Grid, only: vector_3D_type, vector_nD_type
  implicit none
  private
  public :: var_block

  type :: var_block
    integer                                :: dim(3)
    type(vector_3D_type), allocatable      :: node(:,:,:)
    type(vector_3D_type), allocatable      :: center(:,:,:)
    real(8), allocatable                   :: vol(:,:,:)
    real(8), allocatable                   :: var(:,:,:)
    real(8)                                :: block_bounding_min(3)
    real(8)                                :: block_bounding_max(3)
    type(vector_nD_type), allocatable      :: bbmin(:,:,:)
    type(vector_nD_type), allocatable      :: bbmax(:,:,:)
  end type var_block

end module var_block_mod
