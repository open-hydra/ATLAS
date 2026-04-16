module config_mod
  use iso_fortran_env, only: I4 => int32, R8 => real64
  use variables

  implicit none
  private

  !! ------------------------------------------------------
  !! Interpolation Configuration -------------------------
  !! ------------------------------------------------------
  type :: config_interpolation_t
    character(len=llen) :: warning_message
    character(len=llen) :: error_message
    character(len=llen) :: description
    ! USER-DEFINED INPUTS
    real(R8)            :: theta = 90_R8
    integer             :: nz = 10
    character(len=llen) :: file
    character(len=llen) :: law = 'outlaw'
    ! Useful variables
    ! ...
  end type config_interpolation_t


  !! Global instance of the interpolation configuration
  type(config_interpolation_t), public :: config_interpolation
  

end module config_mod