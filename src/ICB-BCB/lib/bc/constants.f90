!> Shared BC constants and parameter counts.
module bc_constants
  implicit none
  private

  integer, public, parameter :: nIG_bc = 7   !< Number of ideal-gas BC properties
  integer, public, parameter :: nCP    = 8   !< Number of condensed-phase BC properties
  real(8), public, parameter :: Qal    = 9.53d6      !< Aluminum combustion reaction energy [J/kg]
  real(8), public, parameter :: csAl   = 1597.6654d0 !< Alumina thermal capacity [J/(kg K)]

end module bc_constants
