!> L6 (composition-sum check): the composition of a boundary or initial state given by
!> y<species> keys must sum to 1. The deviation |1 - sum y| is measured against
!> ONE pair of constants shared with the ICB species profiles:
!> <= YSUM_EPS: renormalised in silence;
!>   <= YSUM_TOL + YSUM_EPS (1e-3 with the same slack on the limit, so that 0.249 + 0.75 is
!>      accepted like 0.25 + 0.75): renormalised with a WARNING that names the keys;
!>   beyond: the section is refused (the solver would start from an inconsistent state: R and
!>   rho off by the same factor, silently).
!> A composition taken from a CEA file whose gas products are not all species of the run
!> (dropped species) follows the same rule on the missing mass: renormalised with a
!> WARNING within the tolerance, refused beyond it (dropped species are treated like the keys).
!> A declared CEA-mixture species absorbs the missing mass (define_composition), so such a
!> deck never reaches the deficit branch. A multi-species state that gives neither y<species>
!> keys nor eq-CEA-file is refused when the caller marks the composition as required (
!> the 4xx inlets and the ICB deck compositions; every mass fraction would be written as 1e-20);
!> nothing is checked otherwise (the decomposition of an interpolated source has no keys).
module composition_check_mod
  use iso_fortran_env, only: R8 => real64
  use finer, only: file_ini
  use phase_mod, only: species_t
  implicit none
  private
  public :: check_composition, COMPOSITION_TOL, YSUM_TOL, YSUM_EPS
  real(R8), parameter :: YSUM_TOL = 1.0e-3_R8    ! |1 - sum y| renormalised with a WARNING; ERROR beyond (+ YSUM_EPS)
  real(R8), parameter :: YSUM_EPS = 1.0e-12_R8   ! rounding of decimal constants: renormalised in silence; slack on both limits
  real(R8), parameter :: COMPOSITION_TOL = YSUM_TOL

contains

  subroutine check_composition(sini, section, sp, label, report, required)
    implicit none
    type(file_ini), intent(in)     :: sini
    character(len=*), intent(in)   :: section, label
    type(species_t), intent(inout) :: sp
    logical, intent(in), optional  :: report   ! .false.: renormalise without the WARNING (a caller that
                                               ! checks the same keys cell by cell prints it once)
    logical, intent(in), optional  :: required ! .true.: the state carries this composition (a missing one is refused)
    character(len=:), allocatable  :: suffix   ! " (section [<deck section>])" when the caller renamed the section
    character(len=64)              :: xsect
    integer                        :: ierr
    character(len=:), allocatable :: option_pairs(:), keys_txt
    integer  :: j, nkeys
    real(R8) :: total, dev
    logical  :: cea, say

    say = .true.
    if (present(report)) say = report
    if (.not. allocated(sp%massf)) return
    if (sp%n <= 1) return
    nkeys = 0; cea = .false.; keys_txt = ''
    do while (sini%loop(section_name=section, option_pairs=option_pairs))
      if (trim(option_pairs(1)) == 'eq-CEA-file') cea = .true.
      do j = 1, sp%n
        if (trim(option_pairs(1)) == 'y'//trim(adjustl(sp%name(j)))) then
          nkeys = nkeys + 1
          keys_txt = keys_txt//' '//trim(option_pairs(1))
        endif
      enddo
    enddo
    total = sum(sp%massf)
    dev = abs(1.0_R8 - total)
    ! ICB copies every zone section into a section named 'zone' (the deck name is kept as x-section)
    suffix = ''
    call sini%get(section_name=section, option_name='x-section', val=xsect, error=ierr)
    if (ierr == 0) suffix = ' (section ['//trim(xsect)//'])'
    if (nkeys > 0) then
      if (dev > YSUM_TOL + YSUM_EPS) then
        write(*,'(A,ES12.5,A)') '[ERROR] composition of '//label//' (keys'//keys_txt//'): the mass fractions sum to ', &
                                total, ', they must sum to 1 within 1e-3'//suffix
        stop 1
      elseif (dev > YSUM_EPS) then
        if (say) write(*,'(A,ES12.5,A)') '[WARNING] composition of '//label//' (keys'//keys_txt//'): the mass fractions sum to ', &
                                total, ', renormalised to 1'//suffix
        sp%massf = sp%massf / total
      elseif (dev > 0.0_R8) then
        sp%massf = sp%massf / total   ! representation noise of the deck values: silent
      endif
    elseif (cea) then
      if (total < 1.0_R8 - (YSUM_TOL + YSUM_EPS)) then
        write(*,'(A,ES12.5,A)') '[ERROR] composition of '//label//' from the CEA file: the products declared as species'// &
                                ' of the run sum to ', total, ', they must sum to 1 within 1e-3 (the rest are CEA products'// &
                                ' absent from the phases: declare them, or add a CEA-mixture species to absorb them)'//suffix
        stop 1
      elseif (dev > YSUM_EPS) then
        if (say) write(*,'(A,ES12.5,A)') '[WARNING] composition of '//label//' from the CEA file: the products declared as species'// &
                                ' of the run sum to ', total, ', renormalised to 1 (the rest are CEA products absent'// &
                                ' from the phases)'//suffix
        sp%massf = sp%massf / total
      elseif (dev > 0.0_R8) then
        sp%massf = sp%massf / total
      endif
    elseif (present(required)) then
      if (required) then
        write(*,'(A,I0,A)') '[ERROR] composition of '//label//': no y<species> key and no eq-CEA-file for a phase of ', sp%n, &
                            ' species (every mass fraction would be 1e-20): give the y<species> keys'//suffix
        stop 1
      endif
    endif
  end subroutine check_composition

end module composition_check_mod
