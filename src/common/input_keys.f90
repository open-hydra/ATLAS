!> Validation of the INI keys of a run against the option registry of the tool:
!> the ONE validation layer of BCB, ICB and STB decks (MDB has no registry and
!> nothing is checked for it). The bcb/icb/stb registry rows (section label,
!> name, type, allowed set or range) are the single source of the keys a tool
!> reads, of their types and of their admitted values. The tool snapshots its
!> registry at start-up (write_<tool>_registry_markdown(keys_only=.true.)) and
!> every section it reads passes through input_keys_check_section before its
!> loader runs. Layers, in the order they fire on a section:
!>   L1  a key the tool does not read: ERROR, or WARNING with strict-keys =
!>       false in [ATLAS-Parameters]; the hint names the current key of a key
!>       renamed since earlier decks (rt, force-connect), otherwise the closest
!>       known key; keys with the prefix ignore- are skipped
!>       by design (an annotation, never read); y<species> of a species no phase
!>       of the run declares is an error of the same class (the value would be
!>       dropped silently by define_composition); y<species>-file and
!>       y<species>-direction of a DECLARED species are known keys: the species
!>       profile of the initial field (ICB, handled by the species-profile
!>       reader, not here).
!>   L2  the value of a numeric key must read as a number of its kind (FiNeR's
!>       get converts "abc" or "8,5" silently), the value of a logical key must
!>       be T/F (FiNeR's get would stop with a runtime error instead).
!>   L3  the allowed column of the registry row is executable: an enumeration
!>       (axis, nozzle-direction, interpolation-law, *-direction, type, IC-format
!>       with the substring grammar of the legacy decks) or a numeric range
!>       (>=1, (0,1], ...); a value outside it is an error.
!> The per-type check of the keys a boundary record cannot carry (L4) lives in
!> the BCB builder after the dispatch; the physical ranges (L5) and the semantic
!> conflicts (L6) in the builders; the report of the known keys left unread in
!> the ATLAS-/<PROG>- sections (L7) is input_keys_warn_unused.
!> Message style: [ERROR] key <k> of section [<s>]: <why> (<hint>), one line,
!> written with (A) so that the fragment a fixture greps sits in the first 60
!> characters.
module input_keys_mod
  use iso_fortran_env, only: R8 => real64
  use finer, only: file_ini
  use registry_mod, only: registry_t, lowercase
  use phase_mod, only: phase_t
  implicit none
  private
  public :: input_keys_snapshot, input_keys_set_phases, input_keys_check_section, &
            input_keys_set_strict, input_keys_strict, input_keys_warn_unused, &
            input_keys_format_ok, input_keys_refuse_or_warn, input_keys_check_duplicate_sections, &
            input_keys_phase_key, input_keys_check_logical

  integer, parameter :: KLEN = 64, ALEN = 200
  type :: key_t
    character(len=KLEN) :: section = ''   ! registry label: 'ATLAS-Parameters', '<PROG>-Block*', 'bc-section', 'ICB-IG', ...
    character(len=KLEN) :: name = ''      ! may end with '<n>' (face<n>, patch<n>, range<n>, zone<n>)
    integer             :: type_id = 0    ! registry_mod: 1 integer, 2 real, 3 logical, 4 string
    character(len=ALEN) :: allowed = ''   ! registry 'allowed' column: enumeration (a<br>b or a,b) or numeric range
    logical             :: is_array = .false. ! registered as a list (center = 0 0 0): more than one number allowed
    logical             :: per_population = .false. ! read by get_population_reals: its token grammar applies
  end type key_t
  type(key_t), allocatable :: keys(:)
  character(len=3) :: prog = ''
  ! run-time names the registry cannot list: the 'y<species>' mass fractions
  ! and the '<phase>-' prefix of the dispersed-phase inlet keys
  character(len=KLEN), allocatable :: species_keys(:), species_names(:), phase_prefixes(:)
  character(len=KLEN), allocatable :: phase_types(:)   ! type of the phase of each prefix (IG, RF, DP, SP, ...)
  logical :: strict = .true.                       ! [ATLAS-Parameters] strict-keys
  character(len=KLEN), allocatable :: checked(:)   ! sections already checked (no duplicate diagnostics)
  integer :: nchecked = 0
  character(len=:), allocatable :: scanned          ! deck already scanned for duplicate section headers
  ! escape prefix: a key the tool never reads and never reports (an annotation)
  character(len=*), parameter :: ESCAPE = 'ignore-'
  ! keys of earlier decks that are not read any more: an unknown key like any other
  ! (ERROR, or WARNING with strict-keys = false), whose hint names the current key.
  integer, parameter :: NHINTS = 2
  character(len=KLEN), parameter :: hint_key(NHINTS) = [character(len=KLEN) :: 'rt', 'force-connect']
  character(len=80), parameter :: hint_text(NHINTS) = [character(len=80) :: &
    "key 'rt' was renamed 'g' (nozzle mass flux, kg m-2 s-1)", &
    "the option is BC-force-connect in [ATLAS-Parameters]"]

contains

  subroutine input_keys_set_strict(flag)
    implicit none
    logical, intent(in) :: flag
    strict = flag
  end subroutine input_keys_set_strict

  !> [ATLAS-Parameters] strict-keys as parsed by load_atlas_parameters (the
  !> builders' own class-of-key checks follow the same switch).
  logical function input_keys_strict()
    implicit none
    input_keys_strict = strict
  end function input_keys_strict

  !> ERROR (stop 1) under strict-keys, WARNING otherwise: the diagnostic of a
  !> key of a class the deck may carry by mistake (unknown, not honoured by the
  !> resolved type, y of an undeclared species). The value refusals (L2, L3)
  !> never go through here: they stop whatever the switch.
  subroutine input_keys_refuse_or_warn(msg)
    implicit none
    character(len=*), intent(in) :: msg
    if (strict) then
      write(*,'(A)') '[ERROR] '//msg
      stop 1
    else
      write(*,'(A)') '[WARNING] '//msg
    endif
  end subroutine input_keys_refuse_or_warn

  !> L0: a section header written twice in a deck.
  !> FiNeR keeps the first [section] and drops the second in silence (a user
  !> deck had two [ICB-Block4]). Two copies with the same keys and the same
  !> values (as FiNeR reads each copy: blank lines, comments and the order of
  !> the keys do not count; values are compared as written) give the products
  !> of the deck written with one copy: a WARNING whatever strict-keys. Copies
  !> that differ in a section the tool reads (the ATLAS-/<PROG>- prefix, or a
  !> section named by the value of a key such as face<n> or zone<n>) are
  !> refused under strict-keys and reported otherwise; a duplicated section
  !> nobody reads (a disabled block) only gets a WARNING, as the rest of the
  !> layer ignores such sections. Each file is scanned once (the
  !> [ATLAS-Parameters] file and the <PROG>-file deck are the same file unless
  !> the deck redirects).
  subroutine input_keys_check_duplicate_sections(filename, ini)
    implicit none
    character(len=*), intent(in) :: filename
    type(file_ini), intent(inout) :: ini
    character(len=1024)              :: buf
    character(len=:), allocatable    :: src, line, head, msg
    character(len=KLEN), allocatable :: hname(:)
    integer, allocatable             :: hline(:), hfrom(:), hupto(:)
    character(len=12)                :: n1, n2
    integer                          :: u, ios, sz, c, k, i, h, n, lineno

    if (allocated(scanned)) then
      if (scanned == filename) return
    endif
    scanned = filename
    open(newunit=u, file=filename, status='old', action='read', iostat=ios)
    if (ios /= 0) return
    ! The deck as the tool reads it (comment lines left out, as load_ini_file does) and, for each
    ! section header, its name, its line and the span of its copy in that text: a copy ends where
    ! the next line that starts with '[' begins, as in FiNeR.
    src = ''
    allocate(hname(0), hline(0), hfrom(0), hupto(0))
    n = 0; lineno = 0
    do
      line = ''
      do
        read(u, '(A)', advance='no', iostat=ios, size=sz) buf
        line = line//buf(1:sz)
        if (ios /= 0) exit
      enddo
      if (.not. (is_iostat_eor(ios) .or. (is_iostat_end(ios) .and. len(line) > 0))) exit
      lineno = lineno + 1
      c = verify(line, ' '//char(9))
      if (c > 0) then
        if (index('#;!', line(c:c)) > 0) line = ''
      endif
      head = adjustl(line)
      if (index(head, '[') == 1) then
        if (n > 0) then
          if (hupto(n) < 0) hupto(n) = len(src)
        endif
        k = index(head, ']')
        if (k >= 3) then
          hname = [character(len=KLEN) :: hname, adjustl(head(2:k-1))]
          hline = [hline, lineno]; hfrom = [hfrom, len(src) + 1]; hupto = [hupto, -1]
          n = n + 1
        endif
      endif
      src = src//line//new_line('a')
      if (is_iostat_end(ios)) exit
    enddo
    close(u)
    if (n > 0) then
      if (hupto(n) < 0) hupto(n) = len(src)
    endif
    do h = 2, n
      do i = 1, h - 1
        if (trim(hname(i)) == trim(hname(h))) exit
      enddo
      if (i == h) cycle                                ! the first copy of its section
      write(n1, '(I0)') hline(i); write(n2, '(I0)') hline(h)
      msg = 'section ['//trim(hname(h))//'] of '//trim(filename)//': declared twice (lines '// &
            trim(n1)//' and '//trim(n2)//'), the second is ignored: merge them'
      if (.not. section_is_read(trim(hname(h)), ini)) then
        write(*,'(A)') '[WARNING] '//msg//' (a section the tool does not read)'
      elseif (same_keys_and_values(src(hfrom(i):hupto(i)), src(hfrom(h):hupto(h)))) then
        write(*,'(A)') '[WARNING] '//msg//' (the two copies hold the same keys and values)'
      else
        call input_keys_refuse_or_warn(msg)
      endif
    enddo
  end subroutine input_keys_check_duplicate_sections

  !> Two copies of a section (the text of each, its header line first) hold the
  !> same keys with the same values as FiNeR reads them. The order of the keys
  !> does not count; a key written twice in one copy keeps its order (FiNeR
  !> returns the first).
  logical function same_keys_and_values(copy1, copy2)
    implicit none
    character(len=*), intent(in) :: copy1, copy2
    character(len=:), allocatable :: o1(:,:), o2(:,:)
    integer, allocatable :: r1(:), r2(:)
    integer :: i

    call copy_options(copy1, o1); call copy_options(copy2, o2)
    same_keys_and_values = .false.
    if (size(o1, 1) /= size(o2, 1)) return
    call order_by_name(o1, r1); call order_by_name(o2, r2)
    do i = 1, size(r1)
      if (o1(r1(i),1) /= o2(r2(i),1) .or. o1(r1(i),2) /= o2(r2(i),2)) return
    enddo
    same_keys_and_values = .true.
  end function same_keys_and_values

  !> The options (name, value) of the one section written in text, as FiNeR
  !> reads them; an option slot FiNeR leaves without a name (a line with a
  !> second '=') holds nothing and is skipped. FiNeR's loop runs to completion
  !> (see section_is_read).
  subroutine copy_options(text, opts)
    implicit none
    character(len=*), intent(in)               :: text
    character(len=:), allocatable, intent(out) :: opts(:,:)
    type(file_ini)                :: one
    character(len=:), allocatable :: sections(:), pairs(:)
    integer                       :: n, l, pass

    call one%load(source=text)
    call one%get_sections_list(sections)
    l = 1
    do pass = 1, 2
      n = 0
      if (allocated(sections)) then
        if (size(sections) > 0) then
          do while (one%loop(section_name=trim(sections(1)), option_pairs=pairs))
            if (.not. allocated(pairs)) cycle
            n = n + 1
            if (pass == 1) then
              l = max(l, len(pairs))
            else
              opts(n,1) = pairs(1); opts(n,2) = pairs(2)
            endif
          enddo
        endif
      endif
      if (pass == 1) allocate(character(len=l) :: opts(n,2))
    enddo
  end subroutine copy_options

  !> Rows of opts in the order of their names (insertion sort, stable: the rows
  !> of one name keep their order).
  subroutine order_by_name(opts, ord)
    implicit none
    character(len=*), intent(in)      :: opts(:,:)
    integer, allocatable, intent(out) :: ord(:)
    integer :: i, j, t

    ord = [(i, i = 1, size(opts, 1))]
    do i = 2, size(ord)
      t = ord(i); j = i - 1
      do while (j >= 1)
        if (.not. lgt(opts(ord(j),1), opts(t,1))) exit
        ord(j+1) = ord(j); j = j - 1
      enddo
      ord(j+1) = t
    enddo
  end subroutine order_by_name

  !> A section the tool reads: [ATLAS-*], [<PROG>-*] (BCB, ICB, STB, MDB) or a
  !> section named by the value of a key of any section (face<n>, zone<n>, ...).
  logical function section_is_read(name, ini)
    implicit none
    character(len=*), intent(in) :: name
    type(file_ini), intent(inout) :: ini
    character(len=:), allocatable :: sections(:), option_pairs(:)
    character(len=KLEN) :: sec
    integer :: s
    logical :: named

    section_is_read = .true.
    if (index(name, 'ATLAS-') == 1 .or. index(name, 'BCB-') == 1 .or. index(name, 'ICB-') == 1 .or. &
        index(name, 'STB-') == 1 .or. index(name, 'MDB-') == 1) return
    named = .false.
    call ini%get_sections_list(sections)
    if (allocated(sections)) then
      do s = 1, size(sections)
        sec = sections(s)
        ! FiNeR's loop keeps its position in a saved counter shared by every section: it runs to
        ! completion (a return from inside it made the next loop over any section skip options)
        do while (ini%loop(section_name=trim(sec), option_pairs=option_pairs))
          if (trim(adjustl(option_pairs(2))) == name) named = .true.
        enddo
      enddo
    endif
    section_is_read = named
  end function section_is_read

  !> Copy (section label, name, type, allowed) of every registry row.
  subroutine input_keys_snapshot(registry, tool)
    implicit none
    type(registry_t), intent(in) :: registry
    character(len=*), intent(in) :: tool
    integer :: i

    prog = tool
    if (allocated(keys)) deallocate(keys)
    allocate(keys(registry%size))
    do i = 1, registry%size
      keys(i)%section = registry%params(i)%section
      keys(i)%name    = registry%params(i)%name
      keys(i)%type_id = registry%params(i)%type_id
      keys(i)%is_array = registry%params(i)%is_array
      keys(i)%per_population = registry%params(i)%per_population
      keys(i)%allowed = ''
      if (allocated(registry%params(i)%allowed)) keys(i)%allowed = registry%params(i)%allowed
    enddo
  end subroutine input_keys_snapshot

  !> Names that depend on the phases of the run (called after read_phase). The
  !> species of an ideal-gas phase are read from its <phase>phase.txt (one
  !> species per line after the header, name = first token: the layout
  !> read_idealgas_properties reads) when the caller has not loaded them yet
  !> (BCB loads them per block, after the deck is checked).
  subroutine input_keys_set_phases(phase)
    implicit none
    type(phase_t), intent(in) :: phase(:)
    character(len=KLEN), allocatable :: names(:)
    integer :: p, j, n

    if (allocated(species_keys)) deallocate(species_keys)
    if (allocated(species_names)) deallocate(species_names)
    if (allocated(phase_prefixes)) deallocate(phase_prefixes)
    if (allocated(phase_types)) deallocate(phase_types)
    allocate(species_keys(0), species_names(0), phase_prefixes(size(phase)), phase_types(size(phase)))
    do p = 1, size(phase)
      phase_prefixes(p) = ''
      phase_types(p) = trim(adjustl(phase(p)%type))
      if (len_trim(phase(p)%name) > 0) phase_prefixes(p) = trim(adjustl(phase(p)%name))//'-'
      if (allocated(phase(p)%species%name)) then
        do j = 1, size(phase(p)%species%name)
          species_names = [character(len=KLEN) :: species_names, trim(adjustl(phase(p)%species%name(j)))]
        enddo
      elseif (phase(p)%type == 'IG') then
        call phase_file_species(trim(phase_prefixes(p))//'phase.txt', names)
        if (allocated(names)) species_names = [character(len=KLEN) :: species_names, names]
      endif
    enddo
    n = size(species_names)
    deallocate(species_keys); allocate(species_keys(n))
    do j = 1, n
      species_keys(j) = 'y'//trim(species_names(j))
    enddo
  end subroutine input_keys_set_phases

  !> Species names of an ideal-gas phase file: header line, then one species
  !> per line (name, molar mass, ...); a missing file gives no names (the
  !> builders report it later with their own message).
  subroutine phase_file_species(filename, names)
    implicit none
    character(len=*), intent(in)                  :: filename
    character(len=KLEN), allocatable, intent(out) :: names(:)
    character(len=256) :: line
    character(len=KLEN) :: token
    integer :: u, ios
    logical :: exists

    allocate(names(0))
    inquire(file=filename, exist=exists)
    if (.not. exists) return
    open(newunit=u, file=filename, status='old', action='read', iostat=ios)
    if (ios /= 0) return
    read(u, '(A)', iostat=ios) line
    do
      read(u, '(A)', iostat=ios) line
      if (ios /= 0) exit
      if (len_trim(line) == 0) cycle
      read(line, *, iostat=ios) token
      if (ios /= 0) cycle
      names = [character(len=KLEN) :: names, trim(adjustl(token))]
    enddo
    close(u)
  end subroutine phase_file_species

  !> Check the options of section `section_name` of `ini`, a section of the
  !> registered kind `kind`: 'atlas' = [ATLAS-Parameters], 'block' =
  !> [<PROG>-Block<n>] (copied from [<PROG>-Block<n>] or [<PROG>-Block*]),
  !> 'section' = a user-named section the tool reads (bc section, patch, zone).
  !> `extra` = further names the caller accepts. Stops with status 1 on the
  !> first key the tool does not read (WARNING with strict-keys = false; the
  !> prefix ignore- is skipped), on the first numeric or logical key whose value
  !> is not one, and on the first value outside the allowed set / range of its row.
  subroutine input_keys_check_section(ini, section_name, kind, extra)
    implicit none
    type(file_ini), intent(inout)          :: ini
    character(len=*), intent(in)           :: section_name, kind
    character(len=*), intent(in), optional :: extra(:)
    character(len=:), allocatable :: option_pairs(:)
    character(len=ALEN) :: allowed
    integer :: type_id
    logical :: is_list, per_pop

    if (.not. allocated(keys)) return
    if (.not. ini%has_section(trim(section_name))) return
    if (is_checked(trim(section_name))) return
    ! FiNeR's loop keeps its position in a saved counter: it runs to completion
    do while (ini%loop(section_name=trim(section_name), option_pairs=option_pairs))
      if (is_escaped(trim(option_pairs(1)))) cycle
      type_id = key_type(trim(option_pairs(1)), kind, extra, allowed, is_list, per_pop)
      if (type_id < 0) then
        ! y<name>, y<name>-file, y<name>-direction of a species that no phase of
        ! the run declares (registry row 'yspecies' of this kind): the value
        ! would be dropped silently (define_composition matches by name)
        if (species_shaped(trim(option_pairs(1))) .and. registry_type('yspecies', kind, allowed) >= 0 .and. &
            .not. species_declared(species_of(trim(option_pairs(1))))) then
          call absent_species(trim(option_pairs(1)), trim(section_name), kind)
          cycle
        endif
        call unknown_key(trim(option_pairs(1)), trim(section_name), kind, extra)
      elseif (type_id == 1 .or. type_id == 2) then
        call check_numeric(trim(option_pairs(1)), trim(option_pairs(2)), type_id, trim(section_name), kind, is_list, per_pop)
        if (len_trim(allowed) > 0) call check_range(trim(option_pairs(1)), trim(option_pairs(2)), &
                                                    trim(allowed), trim(section_name), kind)
      elseif (type_id == 3) then
        call check_logical(trim(option_pairs(1)), trim(option_pairs(2)), trim(section_name), kind)
      elseif (type_id == 4) then
        if (len_trim(allowed) > 0) call check_enum(trim(option_pairs(1)), trim(option_pairs(2)), &
                                                   trim(allowed), trim(section_name), kind)
      endif
    enddo
    call mark_checked(trim(section_name))
  end subroutine input_keys_check_section

  !> A known key inside a section the tool never read (a section of the
  !> global or of the tool's namespace: [ATLAS-*], [<PROG>-*]; a user-named
  !> section may belong to another tool of a combined input.ini).
  subroutine input_keys_warn_unused(ini)
    implicit none
    type(file_ini), intent(inout) :: ini
    character(len=:), allocatable :: sections(:), option_pairs(:)
    character(len=KLEN) :: sec
    integer :: s

    if (.not. allocated(keys)) return
    call ini%get_sections_list(sections)
    if (.not. allocated(sections)) return
    do s = 1, size(sections)
      sec = sections(s)
      if (is_checked(trim(sec))) cycle
      if (index(sec, 'ATLAS-') /= 1 .and. index(sec, prog//'-') /= 1) cycle
      do while (ini%loop(section_name=trim(sec), option_pairs=option_pairs))
        if (key_type(trim(option_pairs(1)), 'any') >= 0) &
          write(*,'(A)') '[WARNING] key '//trim(option_pairs(1))//' is ignored in section ['//trim(sec)//']'
      enddo
    enddo
  end subroutine input_keys_warn_unused

  !> The escape prefix: a key the tool never reads and never reports.
  logical function is_escaped(name)
    implicit none
    character(len=*), intent(in) :: name
    is_escaped = .false.
    if (len(name) > len(ESCAPE)) is_escaped = name(1:len(ESCAPE)) == ESCAPE
  end function is_escaped

  logical function is_checked(section_name)
    implicit none
    character(len=*), intent(in) :: section_name
    integer :: i
    is_checked = .false.
    do i = 1, nchecked
      if (section_name == trim(checked(i))) is_checked = .true.
    enddo
  end function is_checked

  subroutine mark_checked(section_name)
    implicit none
    character(len=*), intent(in) :: section_name
    character(len=KLEN), allocatable :: tmp(:)
    if (.not. allocated(checked)) allocate(checked(16))
    if (nchecked == size(checked)) then
      allocate(tmp(2 * size(checked)))
      tmp(1:nchecked) = checked(1:nchecked)
      call move_alloc(tmp, checked)
    endif
    nchecked = nchecked + 1
    checked(nchecked) = section_name
  end subroutine mark_checked

  !> Diagnostic of a key the tool does not read (ERROR, or WARNING with
  !> strict-keys = false). The hint: the current name of a renamed key, else
  !> the closest key of the section kind (edit distance 1, or 2 from 4
  !> characters on, case-insensitive).
  subroutine unknown_key(name, section_name, kind, extra)
    implicit none
    character(len=*), intent(in)           :: name, section_name, kind
    character(len=*), intent(in), optional :: extra(:)
    character(len=:), allocatable :: msg, best
    integer :: i

    msg = 'key '//name//' of section ['//section_name//']'//block_hint(kind)//': '
    do i = 1, NHINTS
      if (name == trim(hint_key(i))) then
        call input_keys_refuse_or_warn(msg//'unknown key ('//trim(hint_text(i))//')')
        return
      endif
    enddo
    best = closest_key(name, kind, extra)
    if (best /= '') best = ' (did you mean '//best//'?)'
    call input_keys_refuse_or_warn(msg//'unknown key'//best)
  end subroutine unknown_key

  !> y<name>[-file|-direction] with a non-empty <name>: the shape of a
  !> mass-fraction key (the registry row 'yspecies' and the species-profile keys).
  logical function species_shaped(name)
    implicit none
    character(len=*), intent(in) :: name
    species_shaped = .false.
    if (len(name) < 2) return
    if (name(1:1) /= 'y') return
    species_shaped = len_trim(species_of(name)) > 0
  end function species_shaped

  !> The species name of a species-shaped key (y<sp>, y<sp>-file, y<sp>-direction).
  function species_of(name) result(sp)
    implicit none
    character(len=*), intent(in)  :: name
    character(len=:), allocatable :: sp
    integer :: n
    sp = name(2:)
    n = len(sp)
    if (n > 5) then
      if (sp(n-4:n) == '-file') sp = sp(1:n-5)
    endif
    n = len(sp)
    if (n > 10) then
      if (sp(n-9:n) == '-direction') sp = sp(1:n-10)
    endif
  end function species_of

  !> True when a phase of the run declares the species `sp`: a declared species with a suffix
  !> this tool does not read (y<sp>-file in BCB) is an unknown key, not an absent species.
  logical function species_declared(sp)
    implicit none
    character(len=*), intent(in) :: sp
    integer :: i
    species_declared = .false.
    if (.not. allocated(species_names)) return
    do i = 1, size(species_names)
      if (sp == trim(species_names(i))) species_declared = .true.
    enddo
  end function species_declared

  !> Type of a species-shaped key when its species is declared by a phase of
  !> the run: y<sp> = the 'yspecies' row (real; the range [0, 1] is checked by the
  !> y-key reader of phase.f90, the only check of the value); y<sp>-file and
  !> y<sp>-direction = the species-profile keys, registered by the species-profile
  !> reader of ICB ('yspecies-file' / 'yspecies-direction' rows when present,
  !> otherwise known strings): they are handled by that reader, not read here.
  integer function species_key_type(name, kind, allowed) result(t)
    implicit none
    character(len=*), intent(in)     :: name, kind
    character(len=ALEN), intent(out) :: allowed
    character(len=:), allocatable :: sp, suffix
    integer :: i
    logical :: declared

    t = -1
    allowed = ''
    if (.not. species_shaped(name)) return
    sp = species_of(name)
    declared = .false.
    if (allocated(species_names)) then
      do i = 1, size(species_names)
        if (sp == trim(species_names(i))) declared = .true.
      enddo
    endif
    if (.not. declared) return
    suffix = name(len(sp)+2:)
    if (suffix == '') then
      t = registry_type('yspecies', kind, allowed)
    elseif (prog == 'ICB') then
      t = registry_type('yspecies'//suffix, kind, allowed)
      if (t < 0) then
        t = 4       ! registered by (species-profile reader): known key, read there
        allowed = ''
      endif
    endif
  end function species_key_type

  !> the species of y<sp> (or y<sp>-file, y<sp>-direction) is not declared
  !> by any phase of the run: an error under strict-keys, a WARNING otherwise
  !> (the mass fraction is then dropped, as define_composition matches by name).
  subroutine absent_species(name, section_name, kind)
    implicit none
    character(len=*), intent(in) :: name, section_name, kind
    character(len=:), allocatable :: declared
    integer :: i

    declared = ''
    if (allocated(species_names)) then
      do i = 1, size(species_names)
        declared = declared//' '//trim(species_names(i))
      enddo
    endif
    if (declared == '') declared = ' none'
    call input_keys_refuse_or_warn('key '//name//' of section ['//section_name//']'//block_hint(kind)// &
                                   ': no species '//species_of(name)//' in the phases of the run (declared:'// &
                                   declared//'), the mass fraction would be ignored')
  end subroutine absent_species

  function closest_key(name, kind, extra) result(best)
    implicit none
    character(len=*), intent(in)           :: name, kind
    character(len=*), intent(in), optional :: extra(:)
    character(len=:), allocatable :: best
    integer :: i, d, dbest, dmax

    best = ''
    dmax = 1
    if (len(name) >= 4) dmax = 2
    dbest = dmax + 1
    do i = 1, size(keys)
      if (.not. label_allowed(trim(keys(i)%section), kind)) cycle
      if (index(keys(i)%name, '<n>') > 0) cycle
      call consider(trim(keys(i)%name))
    enddo
    if (allocated(species_keys)) then
      do i = 1, size(species_keys)
        call consider(trim(species_keys(i)))
      enddo
    endif
    if (present(extra)) then
      do i = 1, size(extra)
        call consider(trim(extra(i)))
      enddo
    endif

  contains

    subroutine consider(candidate)
      character(len=*), intent(in) :: candidate
      d = levenshtein(lowercase(name), lowercase(candidate))
      if (d > dmax) return   ! outside the bound: never a hint (the same-length tie-break below would admit dmax+1)
      if (d < dbest .or. (d == dbest .and. len(candidate) == len(name) .and. len(best) /= len(name))) then
        dbest = d
        best = candidate
      endif
    end subroutine consider

  end function closest_key

  pure integer function levenshtein(a, b) result(d)
    implicit none
    character(len=*), intent(in) :: a, b
    integer :: i, j, cost
    integer :: prev(0:len(b)), cur(0:len(b))

    prev = [(j, j = 0, len(b))]
    do i = 1, len(a)
      cur(0) = i
      do j = 1, len(b)
        cost = 1
        if (a(i:i) == b(j:j)) cost = 0
        cur(j) = min(prev(j) + 1, cur(j-1) + 1, prev(j-1) + cost)
      enddo
      prev = cur
    enddo
    d = prev(len(b))
  end function levenshtein

  !> Registry type of `name` for a section of kind `kind` (and the allowed
  !> column of its row); 0 for a run-time or caller-listed name (untyped),
  !> -1 when the name is not read by the tool.
  integer function key_type(name, kind, extra, allowed, is_array, per_population) result(t)
    implicit none
    character(len=*), intent(in)              :: name, kind
    character(len=*), intent(in), optional    :: extra(:)
    character(len=ALEN), intent(out), optional :: allowed
    logical, intent(out), optional :: is_array, per_population
    character(len=ALEN) :: allowed_
    integer :: i, lp
    logical :: arr_, pop_

    allowed_ = ''
    arr_ = .false.
    pop_ = .false.
    t = registry_type(name, kind, allowed_, arr_, pop_)
    if (t < 0) then
      t = species_key_type(name, kind, allowed_)
      ! y<species> values are parsed by the y-key reader (phase.f90: one number in [0, 1], its own message);
      ! the registry row has no range, so a value outside [0, 1] gets that one message only
      if (t >= 0) arr_ = .true.
    endif
    if (t < 0 .and. present(extra)) then
      do i = 1, size(extra)
        if (name == trim(extra(i))) then
          t = 0
          exit
        endif
      enddo
    endif
    if (t < 0 .and. allocated(phase_prefixes)) then
      do i = 1, size(phase_prefixes)
        lp = len_trim(phase_prefixes(i))
        if (lp == 0 .or. len(name) <= lp) cycle
        if (name(1:lp) == phase_prefixes(i)(1:lp)) then
          ! a key registered with its prefix (<phase>-type) has its own row; the
          ! others (<phase>-krho, <phase>-gp, ...) take the row of the bare key
          t = registry_type('<phase>-'//name(lp+1:), kind, allowed_, arr_, pop_)
          if (t < 0) t = registry_type(name(lp+1:), kind, allowed_, arr_, pop_)
          if (t >= 0) exit
        endif
      enddo
    endif
    if (present(allowed)) allowed = allowed_
    if (present(is_array)) is_array = arr_
    if (present(per_population)) per_population = pop_
  end function key_type

  !> True when `key` is `<phase>-<suffix>` for a phase of the deck (names set by
  !> input_keys_set_phases); `pname` and `ptype` are that phase's name and type.
  logical function input_keys_phase_key(key, suffix, pname, ptype) result(yes)
    implicit none
    character(len=*), intent(in)  :: key, suffix
    character(len=*), intent(out) :: pname, ptype
    integer :: i, lp

    yes = .false.
    pname = ''
    ptype = ''
    if (.not. allocated(phase_prefixes)) return
    do i = 1, size(phase_prefixes)
      lp = len_trim(phase_prefixes(i))
      if (lp == 0) cycle
      if (key == phase_prefixes(i)(1:lp)//suffix) then
        yes = .true.
        pname = phase_prefixes(i)(1:lp-1)
        ptype = phase_types(i)
        return
      endif
    enddo
  end function input_keys_phase_key

  integer function registry_type(name, kind, allowed, is_array, per_population) result(t)
    implicit none
    character(len=*), intent(in)               :: name, kind
    character(len=ALEN), intent(out), optional :: allowed
    logical, intent(out), optional             :: is_array, per_population
    integer :: i

    t = -1
    if (present(allowed)) allowed = ''
    if (present(is_array)) is_array = .false.
    if (present(per_population)) per_population = .false.
    do i = 1, size(keys)
      if (.not. label_allowed(trim(keys(i)%section), kind)) cycle
      if (name_matches(name, trim(keys(i)%name))) then
        t = keys(i)%type_id
        if (present(allowed)) allowed = keys(i)%allowed
        if (present(is_array)) is_array = keys(i)%is_array
        if (present(per_population)) per_population = keys(i)%per_population
        return
      endif
    enddo
  end function registry_type

  !> Which registry labels a section of kind `kind` may draw its keys from.
  !> BCB separates the block sections (face<n>, phase) from the bc sections;
  !> an ICB block or zone section and an STB block section carry every key of
  !> the tool (type, direction, range and the state keys live in the same section).
  logical function label_allowed(label, kind)
    implicit none
    character(len=*), intent(in) :: label, kind

    select case (kind)
    case ('any')
      label_allowed = .true.
    case ('atlas')
      label_allowed = label == 'ATLAS-Parameters'
    case ('block')
      if (prog == 'BCB') then
        label_allowed = label == 'BCB-Block*'
      else
        label_allowed = label /= 'ATLAS-Parameters'
      endif
    case default
      if (prog == 'BCB') then
        label_allowed = label /= 'ATLAS-Parameters' .and. label /= 'BCB-Block*'
      else
        label_allowed = label /= 'ATLAS-Parameters'
      endif
    end select
  end function label_allowed

  !> Exact match, or `<prefix><digits>` for a registry name `<prefix><n>`.
  logical function name_matches(name, pattern)
    implicit none
    character(len=*), intent(in) :: name, pattern
    integer :: p

    p = index(pattern, '<n>')
    if (p == 0) then
      name_matches = name == pattern
    else
      name_matches = .false.
      if (len(name) > p - 1) then
        if (name(1:p-1) == pattern(1:p-1)) name_matches = verify(name(p:), '0123456789') == 0
      endif
    endif
  end function name_matches

  !> Every blank-separated token of the value must read as a number of the
  !> registered kind (several keys carry lists: center = 0 0 0, krho = 0.5 0.1).
  !> A per-population key is read by get_population_reals (ini_values.f90),
  !> which reads each token with list-directed input: its tokens follow that
  !> grammar instead of FiNeR's. A token may end with the separators ',' and
  !> '/' ("450, 460, 470" reads 450 460 470) and carry a repeat count ("1*450";
  !> "3*450" as the whole value: 450 for every population). Refused as there
  !> they are read wrong: a comma between two numbers ("450,460": 450 only), a
  !> token of separators alone (no value), a repeat count above 1 among other
  !> values (read as one value), and inf or NaN.
  subroutine check_numeric(key, value, type_id, section_name, kind, list, per_population)
    use stringifor, only: string
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    implicit none
    character(len=*), intent(in) :: key, value, section_name, kind
    integer, intent(in)          :: type_id
    logical, intent(in)          :: list
    logical, intent(in), optional :: per_population
    integer  :: i, j, n, ios, ival, ntok, first, last, star
    real(R8) :: rval
    type(string) :: token
    logical  :: pop, repeat_many

    pop = .false.
    if (present(per_population)) pop = per_population .and. type_id == 2
    repeat_many = .false.
    n = len_trim(value)
    ! an empty value is not a number either (FiNeR returns error 0 and an undefined value)
    if (n == 0) then
      write(*,'(A)') '[ERROR] key '//key//' of section ['//section_name//']'//block_hint(kind)// &
                     ': empty value, not a number'
      stop 1
    endif
    i = 1
    ntok = 0
    do while (i <= n)
      if (value(i:i) == ' ' .or. value(i:i) == achar(9)) then
        i = i + 1
        cycle
      endif
      j = i
      do while (j < n)
        if (value(j+1:j+1) == ' ' .or. value(j+1:j+1) == achar(9)) exit
        j = j + 1
      enddo
      ntok = ntok + 1
      ios = 0
      if (pop) then
        ! the reader's list-directed syntax: separators after the value, a repeat count r*
        first = i
        last = j
        do while (last >= first)
          if (index(',/', value(last:last)) == 0) exit
          last = last - 1
        enddo
        star = 0
        if (last >= first) star = index(value(first:last), '*')
        if (star > 1) then
          if (verify(value(first:first+star-2), '0123456789') /= 0) then
            ios = 1
          else
            read(value(first:first+star-2), *, iostat=ios) ival
            if (ios == 0 .and. ival < 1) ios = 1
            if (ios == 0 .and. ival > 1) repeat_many = .true.
          endif
          first = first + star
        elseif (star == 1) then
          ios = 1
        endif
        if (last < first) then
          ios = 1
        elseif (scan(value(first:last), ',/*') > 0) then
          ios = 1
        endif
        if (ios == 0) read(value(first:last), *, iostat=ios) rval
        if (ios == 0) then
          if (.not. ieee_is_finite(rval)) ios = 1
        endif
      else
        ! a number starts with a sign, a digit or the decimal point (no inf/nan)
        ! and holds no list-directed separator: "8,5" would silently read as 8
        ! FiNeR's get converts a value only when StringiFor's is_integer / is_real accepts it
        ! (otherwise it returns error 0 and an undefined number, e.g. g = 2*500, 1+3, 1.0e):
        ! the same lexical test here, token by token, independent of the compiler's read(*)
        token = value(i:j)
        if (type_id == 1) then
          ! integers: digits and sign only as well (is_integer also takes 1e0, which gfortran's read
          ! refuses and ifx's accepts: the refusal must not depend on the compiler)
          if (.not. token%is_integer(allow_spaces=.false.) .or. verify(value(i:j), '+-0123456789') /= 0) ios = 1
        else
          ! reals: is_number, as is_real refuses an integer-looking value (T = 2000) since StringiFor v1.3.0
          if (.not. token%is_number(allow_spaces=.false.)) ios = 1
        endif
        if (ios == 0) then
          if (type_id == 1) then
            read(value(i:j), *, iostat=ios) ival
          else
            read(value(i:j), *, iostat=ios) rval
          endif
        endif
      endif
      if (ios /= 0) then
        write(*,'(A)') '[ERROR] key '//key//' of section ['//section_name//']'//block_hint(kind)// &
                       ': value '//value//' is not a number'
        stop 1
      endif
      i = j + 1
    enddo
    ! the reader takes r*c as one value, not r of them
    if (repeat_many .and. ntok > 1) then
      write(*,'(A)') '[ERROR] key '//key//' of section ['//section_name//']'//block_hint(kind)// &
                     ': value '//value//' has a repeat count r*c among other values (read as one value): write the values out'
      stop 1
    endif
    ! a scalar key with two numbers: FiNeR's scalar get leaves an undefined value (T0 = 300 400 wrote 1e6)
    if (.not. list .and. ntok > 1) then
      write(*,'(A)') '[ERROR] key '//key//' of section ['//section_name//']'//block_hint(kind)// &
                     ': value '//value//' is not one number (the key takes a single value)'
      stop 1
    endif
  end subroutine check_numeric

  !> A logical key takes T, F, true, false, .true., .false. (case-insensitive,
  !> a dot on one side only as well: .t, true.). FiNeR's typed get reads it with
  !> list-directed input, which takes the first item of the value and ignores
  !> what follows a separator: a TAB or a blank, ',' or '/' after the value and
  !> a comment that starts with '#' or '!', after a blank or attached to the
  !> value ("T # note", "T#note"), are read as the value.
  !> A value that starts otherwise ends in a Fortran runtime error there (yes,
  !> 1); a word that is not true or false (Tomato) and a second value (T F) are
  !> refused as well.
  subroutine check_logical(key, value, section_name, kind)
    implicit none
    character(len=*), intent(in) :: key, value, section_name, kind
    character(len=:), allocatable :: v
    integer :: i, j, k
    logical :: ok

    ok = .false.
    i = verify(value, ' '//achar(9))
    j = len(value)
    if (i > 0) then
      k = scan(value(i:), ' '//achar(9)//',/#!')
      if (k > 0) j = i + k - 2
      v = lowercase(value(i:j))
      ! Fortran logical literals (.true., .F.) are read by FiNeR as logicals: strip the dots
      if (len(v) > 1) then
        if (v(1:1) == '.') v = v(2:)
      endif
      if (len(v) > 1) then
        if (v(len(v):len(v)) == '.') v = v(1:len(v)-1)
      endif
      select case (v)
      case ('t', 'true', 'f', 'false')
        ok = .true.
      end select
    endif
    ! after the value: separators only, then nothing or a comment
    if (ok .and. j < len(value)) then
      k = verify(value(j+1:), ' '//achar(9)//',/')
      if (k > 0) ok = index('#!', value(j+k:j+k)) > 0
    endif
    if (ok) return
    write(*,'(A)') '[ERROR] key '//key//' of section ['//section_name//']'//block_hint(kind)// &
                   ': value '//trim(adjustl(value))//' is not a logical (T or F)'
    stop 1
  end subroutine check_logical

  !> check_logical for a key read before the key table of the tool (strict-keys, which selects the mode
  !> of that check): the same rule and the same message
  subroutine input_keys_check_logical(key, value, section_name)
    implicit none
    character(len=*), intent(in) :: key, value, section_name
    call check_logical(key, value, section_name, 'atlas')
  end subroutine input_keys_check_logical

  !> L3 for a numeric row: every token of the value inside the registry range
  !> ('>=1', '>0', '<=1', '<1', '(0,1]', '[0,1)', ...); the tokens were
  !> validated as numbers by check_numeric. '0 or <range>': 0 is admitted as
  !> well (the default of a key whose 0 means "not given", e.g. Ae_At).
  recursive subroutine check_range(key, value, allowed, section_name, kind)
    implicit none
    character(len=*), intent(in) :: key, value, allowed, section_name, kind
    real(R8) :: lo, hi, x
    logical  :: has_lo, has_hi, lo_incl, hi_incl, ok
    integer  :: i, j, n, ios, c

    has_lo = .false.; has_hi = .false.; lo_incl = .true.; hi_incl = .true.; lo = 0.0_R8; hi = 0.0_R8
    ios = 0
    if (len(allowed) > 5) then
      if (allowed(1:5) == '0 or ') then
        read(value, *, iostat=ios) x
        if (ios == 0 .and. len_trim(value) > 0) then
          if (x == 0.0_R8 .and. verify(trim(adjustl(value)), '+-0.eEdD') == 0) return
        endif
        call check_range(key, value, allowed(6:), section_name, kind)
        return
      endif
    endif
    ios = 0
    if (allowed(1:1) == '(' .or. allowed(1:1) == '[') then
      c = index(allowed, ',')
      n = len(allowed)
      if (c == 0 .or. n < 5) return
      if (scan(allowed(n:n), ')]') == 0) return
      lo_incl = allowed(1:1) == '['
      hi_incl = allowed(n:n) == ']'
      read(allowed(2:c-1), *, iostat=ios) lo
      if (ios == 0) read(allowed(c+1:n-1), *, iostat=ios) hi
      has_lo = .true.; has_hi = .true.
    elseif (allowed(1:2) == '>=') then
      read(allowed(3:), *, iostat=ios) lo; has_lo = .true.
    elseif (allowed(1:2) == '<=') then
      read(allowed(3:), *, iostat=ios) hi; has_hi = .true.
    elseif (allowed(1:1) == '>') then
      read(allowed(2:), *, iostat=ios) lo; has_lo = .true.; lo_incl = .false.
    elseif (allowed(1:1) == '<') then
      read(allowed(2:), *, iostat=ios) hi; has_hi = .true.; hi_incl = .false.
    else
      return   ! not a range (an enumeration of a numeric row is not checked)
    endif
    if (ios /= 0) return
    n = len_trim(value)
    i = 1
    do while (i <= n)
      if (value(i:i) == ' ' .or. value(i:i) == achar(9)) then
        i = i + 1
        cycle
      endif
      j = i
      do while (j < n)
        if (value(j+1:j+1) == ' ' .or. value(j+1:j+1) == achar(9)) exit
        j = j + 1
      enddo
      read(value(i:j), *, iostat=ios) x
      if (ios /= 0) return
      ok = .true.
      if (has_lo) then
        if (lo_incl) then
          ok = ok .and. x >= lo
        else
          ok = ok .and. x > lo
        endif
      endif
      if (has_hi) then
        if (hi_incl) then
          ok = ok .and. x <= hi
        else
          ok = ok .and. x < hi
        endif
      endif
      if (.not. ok) then
        write(*,'(A)') '[ERROR] key '//key//' of section ['//section_name//']'//block_hint(kind)// &
                       ': value '//value(i:j)//' outside the allowed range '//allowed
        stop 1
      endif
      i = j + 1
    enddo
  end subroutine check_range

  !> L3 for a string row: the value is one of the enumeration of the registry
  !> row (separators '<br>' or ','; case-sensitive: nozzle-direction = SX passed a case-insensitive
  !> check and crashed the builder, which compares exactly). IC-format is checked
  !> with the substring grammar of the writer instead (input_keys_format_ok).
  subroutine check_enum(key, value, allowed, section_name, kind)
    implicit none
    character(len=*), intent(in) :: key, value, allowed, section_name, kind
    character(len=:), allocatable :: v, list, token
    integer :: p, q
    logical :: found, binary_tec

    v = trim(adjustl(value))
    if (key == 'IC-format') then
      if (input_keys_format_ok(v, binary_tec)) return
      write(*,'(A)') '[ERROR] key '//key//' of section ['//section_name//']: value '//trim(adjustl(value))// &
                     ' is not a format (allowed: '//readable(allowed)//'; the legacy spellings tecplot binary,'// &
                     ' vtk binary, tecplot-ascii are accepted)'
      stop 1
    endif
    found = .false.
    list = allowed
    do
      p = index(list, '<br>')
      q = index(list, ',')
      if (p == 0 .or. (q > 0 .and. q < p)) p = q
      if (p == 0) then
        token = list
      else
        token = list(1:p-1)
      endif
      if (trim(adjustl(token)) == trim(adjustl(value))) found = .true.   ! exact: the consumers compare exactly
      if (p == 0) exit
      if (list(p:p) == ',') then
        list = list(p+1:)
      else
        list = list(p+4:)
      endif
      if (len_trim(list) == 0) exit
    enddo
    if (found) return
    write(*,'(A)') '[ERROR] key '//key//' of section ['//section_name//']'//block_hint(kind)// &
                   ': value '//trim(adjustl(value))//' not allowed (allowed: '//readable(allowed)//')'
    stop 1
  end subroutine check_enum

  !> The allowed column as a comma-separated list for a message.
  function readable(allowed) result(txt)
    implicit none
    character(len=*), intent(in)  :: allowed
    character(len=:), allocatable :: txt
    integer :: p
    txt = allowed
    do
      p = index(txt, '<br>')
      if (p == 0) exit
      txt = txt(1:p-1)//', '//txt(p+4:)
    enddo
  end function readable

  !> The IC-format grammar of the ICB writer (io_fields.f90): a family token
  !> tec | tecplot | vtk, optionally followed by one of binary | ascii | raw,
  !> joined by '-', ' ' or '_' (the registered and the legacy decks write
  !> tec, tec-binary, vtk-binary, tecplot binary, vtk binary, tecplot-ascii).
  !> binary_tec = the value asks for a binary Tecplot file (.szplt: TecIO).
  logical function input_keys_format_ok(value, binary_tec) result(ok)
    implicit none
    character(len=*), intent(in) :: value
    logical, intent(out)         :: binary_tec
    character(len=:), allocatable :: v, fam, mode
    integer :: p

    v = trim(adjustl(value))   ! exact spelling: the writer picks the family and the mode by index() on the raw value
    binary_tec = .false.
    ok = .false.
    p = scan(v, '- _')
    if (p == 0) then
      fam = v; mode = ''
    else
      fam = v(1:p-1); mode = trim(adjustl(v(p+1:)))
    endif
    select case (fam)
    case ('tec', 'tecplot', 'vtk')
    case default
      return
    end select
    select case (mode)
    case ('', 'binary', 'ascii', 'raw')
    case default
      return
    end select
    ok = .true.
    binary_tec = (fam /= 'vtk') .and. (mode == 'binary')
  end function input_keys_format_ok

  !> The block sections of the run are copies named [<PROG>-Block<n>]; the deck
  !> may have written [<PROG>-Block*] instead.
  function block_hint(kind) result(hint)
    implicit none
    character(len=*), intent(in)  :: kind
    character(len=:), allocatable :: hint

    hint = ''
    if (kind == 'block') hint = ' (or ['//prog//'-Block*])'
  end function block_hint

end module input_keys_mod
