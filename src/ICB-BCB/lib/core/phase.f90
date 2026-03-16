module phase_module
  use species
  use material_module
  implicit none

  type, public :: phase_type
    character(len=2)        :: type
    character(len=128)      :: name
    type(obj_material)      :: material
    type(obj_species)       :: species
  end type phase_type

end module phase_module