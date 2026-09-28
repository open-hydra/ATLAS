module ini_values_mod
  !< Per-population values of a dispersed-phase key: one value for every (material, population) pair,
  !< or one value per pair in phase-file order (material-major), any other count refused.
  use iso_fortran_env, only: R8 => real64
  use finer,           only: file_ini
  use global_mod,      only: llen
  implicit none
  private

  public :: get_population_reals, get_population_words

contains

  !> Values of `key` for the `size(val)` populations that sit after the first `off` of `nall`.
  !> Absent key: `val` untouched and error /= 0 (FiNeR's code). One value: every population.
  !> `nall` values: element-wise. Any other count, or a token that is not a number: stop 1.
  subroutine get_population_reals(ini, section, key, off, nall, val, error)
    type(file_ini), intent(in)    :: ini
    character(*),   intent(in)    :: section, key
    integer,        intent(in)    :: off, nall
    real(R8),       intent(inout) :: val(:)
    integer,        intent(out)   :: error
    character(len=llen), allocatable :: tok(:)
    real(R8), allocatable :: x(:)
    integer :: i, ios

    call population_tokens(ini, section, key, nall, tok, error)
    if (error /= 0) return
    allocate(x(size(tok)))
    do i = 1, size(tok)
      read(tok(i), *, iostat=ios) x(i)
      if (ios /= 0) then
        write(*,'(A)') '[ERROR] '//trim(key)//' = "'//trim(tok(i))//'" is not a number'
        stop 1
      endif
    enddo
    if (size(x) == 1) then
      val = x(1)
    else
      val = x(off+1:off+size(val))
    endif
  end subroutine get_population_reals

  !> The same rule for a word-valued key (a distribution name or a file path).
  subroutine get_population_words(ini, section, key, off, nall, val, error)
    type(file_ini), intent(in)    :: ini
    character(*),   intent(in)    :: section, key
    integer,        intent(in)    :: off, nall
    character(*),   intent(inout) :: val(:)
    integer,        intent(out)   :: error
    character(len=llen), allocatable :: tok(:)

    call population_tokens(ini, section, key, nall, tok, error)
    if (error /= 0) return
    if (size(tok) == 1) then
      val = tok(1)
    else
      val = tok(off+1:off+size(val))
    endif
  end subroutine get_population_words

  !> Blank-separated tokens of `key` (repeated blanks collapse, as FiNeR's own split), checked
  !> against the number of (material, population) pairs `nall`.
  subroutine population_tokens(ini, section, key, nall, tok, error)
    type(file_ini), intent(in)  :: ini
    character(*),   intent(in)  :: section, key
    integer,        intent(in)  :: nall
    character(len=llen), allocatable, intent(out) :: tok(:)
    integer,        intent(out) :: error
    character(len=4096) :: raw
    integer :: pass, n, i, j, last

    raw = ''
    call ini%get(section_name=section, option_name=key, val=raw, error=error)
    if (error /= 0) return
    last = len_trim(raw)
    do pass = 1, 2
      n = 0
      i = 1
      do while (i <= last)
        if (raw(i:i) == ' ' .or. raw(i:i) == char(9)) then
          i = i + 1
          cycle
        endif
        j = i
        do while (j < last)
          if (raw(j+1:j+1) == ' ' .or. raw(j+1:j+1) == char(9)) exit
          j = j + 1
        enddo
        n = n + 1
        if (pass == 2) tok(n) = raw(i:j)
        i = j + 1
      enddo
      if (pass == 1) allocate(tok(n))
    enddo
    if (n /= 1 .and. n /= nall) then
      write(*,'(A,I0,A,I0,A)') '[ERROR] '//trim(key)//': ', n, ' value(s) for ', nall, &
        ' (material, population) pairs; give one value for all of them, or one per population in phase-file order'
      stop 1
    endif
  end subroutine population_tokens

end module ini_values_mod
