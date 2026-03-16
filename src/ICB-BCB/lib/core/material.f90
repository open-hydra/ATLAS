module material_module
  implicit none

  type :: obj_material
    integer :: n
    character(len=16), allocatable       :: name(:)
    integer, allocatable                 :: npCP(:)
    real(8), dimension(:,:), allocatable :: h, rho, cp
  end type obj_material

end module material_module
