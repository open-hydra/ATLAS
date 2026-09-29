module ic_builder_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use finer,         only: file_ini
  use direction_mod, only: parse_direction
  use ic_block_mod
  implicit none
  private
  public:: build_IC

  ! after each zone, the cells written so far per phase (for the message of refuse_unwritten_cells)
  character(len=:), allocatable :: zone_log

  contains

  subroutine build_IC(phase,sini,blocks)
    use phase_mod,                 only: phase_t
    use io_phase_mod,              only: read_idealgas_properties, read_dp_properties, read_realfluid_properties
    use strings,                   only: parse
    use ir_precision,              only: str
    use input_keys_mod,            only: input_keys_check_section
    implicit none
    type(phase_t), allocatable, intent(in)     :: phase(:)
    type(IC_block), intent(inout), target :: blocks(:)
    type(file_ini), intent(in)       :: sini
    ! Local
    character(len=30)             :: zonename, section_name
    character(len=:), allocatable :: option_pairs(:)
    type(file_ini)                :: zoneini
    integer                       :: i, j, b, p
    integer                       :: error, error_zone
    character(len=4)              :: zonedirection
    real(R8)                      :: zonerange(6)
    character(len=20)             :: wholestring, args(3), phase_name
    logical                       :: has_direction, found_phase
    integer                       :: nopt
    character(len=:), allocatable :: declared

    do b = 1, size(blocks)
      section_name = 'ICB-Block'//str(.true.,b)
      blocks(b)%id = b
      associate(blk => blocks(b))

      write(*,*)' - Initialization block n. = ', b

      ! Look for phases solved in block b
      call sini%get(section_name=section_name, option_name='phase', val=wholestring, error=error)
      if (error/=0) then
        allocate(blk%associated_phase, source=phase)
      else
        call parse(wholestring,' ',args)
        p = count(args /= '')
        allocate(blk%associated_phase(1:p))
        blk%associated_phase%name = args(1:p)
        do j = 1, p
          found_phase = .false.
          do i = 1, size(phase)
            if (blk%associated_phase(j)%name==phase(i)%name) then
              blk%associated_phase(j) = phase(i)
              found_phase = .true.
            endif
          enddo
          if (.not. found_phase) then
            declared = ''
            do i = 1, size(phase)
              if (i > 1) declared = declared//', '
              declared = declared//trim(phase(i)%name)
            enddo
            write(*,'(A)') '[ERROR] key phase of section ['//trim(section_name)//']: phase '// &
              trim(blk%associated_phase(j)%name)//' is declared by no <name>-phase.txt (declared: '//declared//')'
            stop 1
          endif
        enddo
      endif

      ! Read phase properties (if any)
      do p = 1, size(blk%associated_phase)
        if (blk%associated_phase(p)%name=='') then
          phase_name = ''
        else
          phase_name = trim(blk%associated_phase(p)%name)//'-'
        endif
        if (blk%associated_phase(p)%type=='IG') then
          call read_idealgas_properties(trim(phase_name),blk%associated_phase(p)%species)
        elseif (blk%associated_phase(p)%type=='RF') then
          call read_realfluid_properties(trim(phase_name),blk%associated_phase(p)%fluid)
        elseif (blk%associated_phase(p)%type=='DP') then
          call read_dp_properties(trim(phase_name),blk%associated_phase(p)%material)
        elseif (blk%associated_phase(p)%type=='SP') then
          call read_dp_properties(trim(phase_name),blk%associated_phase(p)%material)
        endif
        if (.not.allocated(blk%associated_phase(p)%species%massf)) &
        allocate(blk%associated_phase(p)%species%massf(1:blk%associated_phase(p)%species%n))
        blk%associated_phase(p)%species%massf = 1d-20
      enddo

      call input_keys_check_section(sini, section_name, 'block')
      ! a block that no section describes would be written from a zero state
      nopt = 0
      do while (sini%loop(section_name=section_name, option_pairs=option_pairs))
        nopt = nopt + 1
      enddo
      if (nopt == 0) then
        write(*,'(A,I0,A)') '[ERROR] build_IC: block ', b, ' has no initial state: give a section ['//trim(section_name)// &
          '] (or [ICB-Block*]) with its keys'
        stop 1
      endif
      call sini%get(section_name=section_name, option_name='type', val=blk%type, error=error)
      if (error/=0) blk%type = 'homogeneous'
      ! Multizone
      call sini%get(section_name=section_name, option_name='direction',  val=zonedirection, error=error)
      has_direction = error==0
      if (blk%type=='multizone' .and. .not.has_direction) then
        write(*,'(A)') '[ERROR] build_IC: type = multizone in section ['//trim(section_name)//'] needs the key direction'// &
          ' (the letters along which range<n> of each zone<n> is given)'
        stop 1
      endif
      if (has_direction) blk%type = 'multizone'

      ! written masks of this block, one per phase (set by the writers, checked by refuse_unwritten_cells)
      call new_written_masks(blk)
      zone_log = ''

      if (blk%type=='multizone') then
        call check_block_keys_with_zones(sini, section_name)
        call check_direction_letters(section_name, zonedirection)
        p = 0
        do
          p = p+1
          call sini%get(section_name=section_name, option_name='zone'//str(.true.,p), &
                                            val=zonename, error=error_zone)
          if (error_zone/=0) exit
          call check_zone_section(sini, section_name, p, zonename, zonedirection)
          zonerange = 0.0_R8   ! the range<n> get fills only the values given in the key: the rest must be defined (build_field overwrites only the values beyond 2 x the letters of direction)
          call sini%get(section_name=section_name, option_name='range'//str(.true.,p), &
                                            val=zonerange, error=error)
          call input_keys_check_section(sini, trim(zonename), 'section')
          call zoneini%free
          call zoneini%add(section_name='zone')
          do while (sini%loop(section_name=zonename, option_pairs=option_pairs))
            call zoneini%add(section_name='zone', option_name=option_pairs(1), val=option_pairs(2))
          enddo
          call zoneini%add(section_name='zone', option_name='range', val=zonerange)
          call zoneini%add(section_name='zone', option_name='direction', val=zonedirection)
          call zoneini%add(section_name='zone', option_name='x-section', val=trim(zonename))   ! the deck section, for messages
          call build_field(self=blk,zoneini=zoneini)
          call log_zone(blk, trim(zonename))
        enddo
        if (p == 1) then
          write(*,'(A)') '[ERROR] build_IC: section ['//trim(section_name)//'] has direction but no zone1: a multizone'// &
            ' block takes its state from zone1, zone2, ... (each with its range<n>)'
          stop 1
        endif
        call check_zone_numbering(sini, section_name, p-1)
      else
        call zoneini%free
        call zoneini%add(section_name='zone')
        do while (sini%loop(section_name=section_name, option_pairs=option_pairs))
          call zoneini%add(section_name='zone', option_name=option_pairs(1), val=option_pairs(2))
        enddo
        call zoneini%add(section_name='zone', option_name='x-section', val=trim(section_name))   ! the deck section, for messages
        call build_field(self=blk,zoneini=zoneini)
        call log_zone(blk, trim(section_name))
      endif
      call refuse_unwritten_cells(blk)

      write(*,*)

      endassociate
    enddo

  end subroutine build_IC

  subroutine new_written_masks(blk)
    type(IC_block), intent(inout) :: blk
    if (allocated(blk%set_ig)) deallocate(blk%set_ig)
    if (allocated(blk%set_rf)) deallocate(blk%set_rf)
    if (allocated(blk%set_sp)) deallocate(blk%set_sp)
    if (allocated(blk%set_dp)) deallocate(blk%set_dp)
    if (allocated(blk%plenum_ig)) deallocate(blk%plenum_ig)
    if (allocated(blk%zone_ig)) deallocate(blk%zone_ig)
    if (allocated(blk%set_turb_ig)) deallocate(blk%set_turb_ig)
    if (allocated(blk%set_turb_rf)) deallocate(blk%set_turb_rf)
    allocate(blk%set_ig(blk%dim(1), blk%dim(2), blk%dim(3)), source=.false.)
    allocate(blk%set_rf(blk%dim(1), blk%dim(2), blk%dim(3)), source=.false.)
    allocate(blk%set_sp(blk%dim(1), blk%dim(2), blk%dim(3)), source=.false.)
    allocate(blk%set_dp(blk%dim(1), blk%dim(2), blk%dim(3)), source=.false.)
    allocate(blk%plenum_ig(blk%dim(1), blk%dim(2), blk%dim(3)), source=.false.)
    allocate(blk%zone_ig(blk%dim(1), blk%dim(2), blk%dim(3)), source=.false.)
  end subroutine new_written_masks

  !> After the zones: the cells written so far by each phase of the block, for the message of refuse_unwritten_cells
  subroutine log_zone(blk, sect)
    use ir_precision, only: str
    type(IC_block),   intent(in) :: blk
    character(len=*), intent(in) :: sect
    integer :: p
    character(len=:), allocatable :: line
    line = '        after ['//sect//']:'
    do p = 1, size(blk%associated_phase)
      select case (blk%associated_phase(p)%type)
      case ('IG'); line = line//' '//trim(blk%associated_phase(p)%name)//' (IG) '//trim(str(.true., count(blk%set_ig)))
      case ('RF'); line = line//' '//trim(blk%associated_phase(p)%name)//' (RF) '//trim(str(.true., count(blk%set_rf)))
      case ('SP'); line = line//' '//trim(blk%associated_phase(p)%name)//' (SP) '//trim(str(.true., count(blk%set_sp)))
      case ('DP'); line = line//' '//trim(blk%associated_phase(p)%name)//' (DP) '//trim(str(.true., count(blk%set_dp)))
      end select
    enddo
    zone_log = zone_log//line//' of '//trim(str(.true., size(blk%set_ig)))//' cells written'//new_line('a')
  end subroutine log_zone

  !> Every cell of every block must be written by a zone, for every phase of the block: each writer
  !> records the cells it assigns (set_ig, set_rf, set_sp, set_dp) and a cell no writer assigned
  !> would reach the IC file with the content of unset memory. Refused naming the block, the phase,
  !> the count and the first such cell, then the cells written after each zone. Under an omega
  !> turbulence model (nrans 2 or 7) the bands no zone set are refused likewise (0 there divides in the
  !> solver kernels); under SA (nrans 1) they are reported.
  subroutine refuse_unwritten_cells(blk)
    type(IC_block), intent(inout) :: blk
    integer :: p
    do p = 1, size(blk%associated_phase)
      select case (blk%associated_phase(p)%type)
      case ('IG'); call refuse_mask(blk%set_ig, trim(blk%associated_phase(p)%name), 'IG')
      case ('RF'); call refuse_mask(blk%set_rf, trim(blk%associated_phase(p)%name), 'RF')
      case ('SP'); call refuse_mask(blk%set_sp, trim(blk%associated_phase(p)%name), 'SP')
      case ('DP'); call refuse_mask(blk%set_dp, trim(blk%associated_phase(p)%name), 'DP')
      end select
    enddo
    if (allocated(blk%set_turb_ig)) call refuse_turbulence(blk%set_turb_ig, 'IG')
    if (allocated(blk%set_turb_rf)) call refuse_turbulence(blk%set_turb_rf, 'RF')
    deallocate(blk%set_ig, blk%set_rf, blk%set_sp, blk%set_dp)
    if (allocated(blk%plenum_ig)) deallocate(blk%plenum_ig)
    if (allocated(blk%zone_ig)) deallocate(blk%zone_ig)
    if (allocated(blk%set_turb_ig)) deallocate(blk%set_turb_ig)
    if (allocated(blk%set_turb_rf)) deallocate(blk%set_turb_rf)
  contains
    subroutine refuse_mask(mask, pname, ptype)
      logical,          intent(in) :: mask(:,:,:)
      character(len=*), intent(in) :: pname, ptype
      integer :: n, first(3)
      n = count(.not. mask)
      if (n == 0) return
      first = findloc(mask, .false.)
      write(*,'(A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A)') '[ERROR] build_IC block ', blk%id, ', '//ptype//' phase'// &
        trim(' '//pname)//': ', n, ' of ', size(mask), ' cells are initialised by no zone (first cell (', first(1), ',', first(2), ',', &
        first(3), ')): every cell needs a zone whose range (range<n> along direction) holds it'
      write(*,'(A)') zone_log//'        (check the zone ranges, the direction letters and the type of each zone)'
      stop 1
    end subroutine refuse_mask
    subroutine refuse_turbulence(tmask, ptype)
      logical,          intent(in) :: tmask(:,:,:,:)
      character(len=*), intent(in) :: ptype
      logical, allocatable :: ok(:,:,:)
      integer :: n, first(3)
      character(len=:), allocatable :: model, keys
      select case (size(tmask, 1))
      case (1)
        n = count(.not. tmask(1,:,:,:))
        if (n > 0) write(*,'(A,I0,A,I0,A,I0,A)') '[WARNING] build_IC block ', blk%id, ' ('//ptype//'): mi_t of ', n, &
          ' of ', size(tmask(1,:,:,:)), ' cells is set by no zone (no key mit, no turbulent source there): it stays 0'
        return
      case (2)
        ok = tmask(1,:,:,:) .and. tmask(2,:,:,:)
        model = 'k-omega (nrans = 2)'; keys = 'kappa and omega'
      case (7)
        ok = tmask(1,:,:,:) .and. tmask(2,:,:,:) .and. tmask(3,:,:,:) .and. tmask(7,:,:,:)
        model = 'Reynolds-stress (nrans = 7)'; keys = 'rhoRij and omega'
      case default
        return
      end select
      n = count(.not. ok)
      if (n == 0) return
      first = findloc(ok, .false.)
      write(*,'(A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A)') '[ERROR] build_IC block ', blk%id, ' ('//ptype//'): the turbulence'// &
        ' bands of ', n, ' of ', size(ok), ' cells are set by no zone (first cell (', first(1), ',', first(2), ',', &
        first(3), ')) and would be written as 0 under the '//model//' model: the solver kernels divide by them.'
      write(*,'(A)') '        Give the keys '//keys//' in every zone (or a turbulent source covering them), or nrans = 0'
      stop 1
    end subroutine refuse_turbulence
  end subroutine refuse_unwritten_cells

  !> direction of a multizone block: letters of x, y, z, r, t, i, j, k written in this order (the range
  !> values are read in this order whatever order is written: another order took the ranges of one
  !> letter for another)
  subroutine check_direction_letters(section_name, zonedirection)
    character(len=*), intent(in) :: section_name, zonedirection
    character(len=*), parameter  :: letters = 'xyzrtijk'
    integer :: n, pos, last
    last = 0
    do n = 1, len_trim(zonedirection)
      pos = index(letters, zonedirection(n:n))
      if (pos == 0) then
        write(*,'(A)') "[ERROR] build_IC: direction = '"//trim(zonedirection)//"' in section ["//trim(section_name)// &
          "]: '"//zonedirection(n:n)//"' is not a direction letter (x, y, z, r, t, i, j, k)"
        stop 1
      endif
      if (pos <= last) then
        write(*,'(A)') "[ERROR] build_IC: direction = '"//trim(zonedirection)//"' in section ["//trim(section_name)// &
          "]: write the letters in the order x, y, z, r, t, i, j, k (the pairs of range<n> are read in that order)"
        stop 1
      endif
      last = pos
    enddo
  end subroutine check_direction_letters

  !> zone<n> of a multizone block: the section it names must be in the deck and range<n> must hold one
  !> pair (low high) per letter of direction
  subroutine check_zone_section(sini, section_name, n, zonename, zonedirection)
    use ir_precision, only: str
    type(file_ini),   intent(in) :: sini
    character(len=*), intent(in) :: section_name, zonename, zonedirection
    integer,          intent(in) :: n
    character(len=512) :: rtxt
    integer :: error, ntok, c, c1, c2
    logical :: blank
    if (.not. sini%has_section(section_name=trim(zonename))) then
      write(*,'(A)') '[ERROR] build_IC: zone'//trim(str(.true.,n))//' = '//trim(zonename)//' of section ['// &
        trim(section_name)//'] names no section of the deck'
      if (index(zonename, 'Block') > 0) write(*,'(A)') "        (a section whose name contains 'Block' is read as a"// &
        " block section, never as a zone: rename it)"
      stop 1
    endif
    call sini%get(section_name=section_name, option_name='range'//trim(str(.true.,n)), val=rtxt, error=error)
    if (error /= 0) then
      write(*,'(A)') '[ERROR] build_IC: zone'//trim(str(.true.,n))//' of section ['//trim(section_name)//'] has no range'// &
        trim(str(.true.,n))//' (one pair low high per letter of direction = '//trim(zonedirection)//')'
      stop 1
    endif
    ! the values are read on blanks: a TAB or a comma between two values would be misread (edge ones are harmless)
    c1 = verify(rtxt, ' '//char(9))
    c2 = verify(rtxt, ' '//char(9), back=.true.)
    if (c1 > 0) then
      if (scan(rtxt(c1:c2), ','//char(9)) > 0) then
        write(*,'(A)') '[ERROR] build_IC: range'//trim(str(.true.,n))//' of section ['//trim(section_name)//'] = '// &
          rtxt(c1:c2)//': separate the values with blanks (a '// &
          trim(merge('TAB  ', 'comma', index(rtxt(c1:c2), char(9)) > 0))//' is not read as a separator)'
        stop 1
      endif
    endif
    ntok = 0; blank = .true.
    do c = 1, len_trim(rtxt)
      if (rtxt(c:c) == ' ' .or. rtxt(c:c) == char(9)) then
        blank = .true.
      elseif (blank) then
        ntok = ntok + 1; blank = .false.
      endif
    enddo
    if (ntok /= 2*len_trim(zonedirection)) then
      write(*,'(A,I0,A,I0,A)') '[ERROR] build_IC: range'//trim(str(.true.,n))//' of section ['//trim(section_name)// &
        '] holds ', ntok, ' values: direction = '//trim(zonedirection)//' needs ', 2*len_trim(zonedirection), &
        ' (one pair low high per letter)'
      stop 1
    endif
  end subroutine check_zone_section

  !> zone<n> keys after a missing index are never read (the zones are read up to the first missing index)
  subroutine check_zone_numbering(sini, section_name, nread)
    use input_keys_mod, only: input_keys_strict
    use ir_precision,   only: str
    type(file_ini),   intent(in) :: sini
    character(len=*), intent(in) :: section_name
    integer,          intent(in) :: nread
    character(len=:), allocatable :: option_pairs(:), key
    integer :: q, ios
    do while (sini%loop(section_name=section_name, option_pairs=option_pairs))
      key = trim(option_pairs(1))
      if (len(key) < 5) cycle
      if (key(1:4) /= 'zone' .or. verify(key(5:), '0123456789') /= 0) cycle
      read(key(5:), *, iostat=ios) q
      if (ios /= 0 .or. q <= nread) cycle
      if (input_keys_strict()) then
        write(*,'(A)') '[ERROR] build_IC: key '//key//' of section ['//trim(section_name)//'] is never read: zone'// &
          trim(str(.true.,nread+1))//' is missing and the zones are read from zone1 up to the first missing index'
        stop 1
      endif
      write(*,'(A)') '[WARNING] build_IC: key '//key//' of section ['//trim(section_name)//'] is not read: zone'// &
        trim(str(.true.,nread+1))//' is missing and the zones are read from zone1 up to the first missing index'
    enddo
  end subroutine check_zone_numbering

  !> Block keys with zones: a block with zones takes its whole state from the zone
  !> sections. A state key left in the block section (y<species>, y<species>-file, p, T0,
  !> old-solution, ...) is not inherited by the zones and was dropped in silence: refused under
  !> strict-keys, reported otherwise. The structural keys of a multizone block (phase, type,
  !> direction, zone<n>, range<n>) and the ignore- escape pass.
  subroutine check_block_keys_with_zones(sini, section_name)
    use input_keys_mod, only: input_keys_strict
    use ir_precision,   only: str
    implicit none
    type(file_ini), intent(in)    :: sini
    character(len=*), intent(in)  :: section_name
    character(len=:), allocatable :: option_pairs(:), key, zones, msg
    character(len=30)             :: zonename
    integer                       :: p, error

    zones = ''
    p = 0
    do
      p = p + 1
      call sini%get(section_name=section_name, option_name='zone'//str(.true.,p), val=zonename, error=error)
      if (error /= 0) exit
      if (p > 1) zones = zones//', '
      zones = zones//'['//trim(zonename)//']'
    enddo
    do while (sini%loop(section_name=section_name, option_pairs=option_pairs))
      key = trim(option_pairs(1))
      if (structural_key(key)) cycle
      msg = 'key '//key//' of section ['//trim(section_name)//']: a block with zones ('//zones// &
            ') takes its state from the zone sections, the key is not inherited: move it there (or remove it)'
      if (input_keys_strict()) then
        write(*,'(A)') '[ERROR] '//msg
        stop 1
      endif
      write(*,'(A)') '[WARNING] '//msg
    enddo
  contains
    logical function structural_key(key)
      implicit none
      character(len=*), intent(in) :: key
      structural_key = .true.
      if (key == 'phase' .or. key == 'type' .or. key == 'direction') return
      if (len(key) > 7) then
        if (key(1:7) == 'ignore-') return
      endif
      if (len(key) > 4) then
        if (key(1:4) == 'zone' .and. verify(key(5:), '0123456789') == 0) return
      endif
      if (len(key) > 5) then
        if (key(1:5) == 'range' .and. verify(key(6:), '0123456789') == 0) return
      endif
      structural_key = .false.
    end function structural_key
  end subroutine check_block_keys_with_zones


  subroutine build_field(self,zoneini)
    use ic_ig_mod
    use ic_rf_mod
    use ic_sp_mod
    use ic_dp_mod
    use config_mod, only: config_zone_runtime_t, config_ig_t, config_rf_t, config_sp_t, &
                          config_dp_t, load_zone_runtime_config, load_ig_config, &
                          load_rf_config, load_sp_config, load_dp_config
    implicit none
    type(IC_block), intent(inout) :: self
    type(file_ini), intent(in)    :: zoneini
    ! Local
    character(len=2)              :: phase_type
    logical                       :: index_based
    logical                       :: ig_loaded, rf_loaded, sp_loaded, dp_loaded
    integer                       :: pi, i, j, k, nnn, pass
    character(len=32)             :: IC_type
    real(R8)                      :: range(6)
    integer                       :: dirSize
    integer, allocatable          :: dir(:)
    type(config_zone_runtime_t)   :: zone_cfg
    type(config_ig_t)             :: ig_cfg
    type(config_rf_t)             :: rf_cfg
    type(config_sp_t)             :: sp_cfg
    type(config_dp_t)             :: dp_cfg
    
    call load_zone_runtime_config(zoneini, zone_cfg)
    IC_type = zone_cfg%ic_type
    
    ! Check direction
    index_based = .false.
    dirSize = 0
    if (zone_cfg%has_direction) then
      call parse_direction(zone_cfg%direction, dir, dirSize, index_based)
    endif

    ! Check range for multizone
    if (.not. zone_cfg%has_range) then
      do i = 1, 6 ; range(i) = (-1.0)**i*huge(range(i)) ; enddo
    else
      range = zone_cfg%range
      do i = dirSize*2+1, 6 ; range(i) = (-1.0)**i*huge(range(i)) ; enddo
    endif

    ! Convert theta range (if present) from degrees to rad
    if (dirSize>0) then
      if (dir(1)==5) range(1:2) = range(1:2)*acos(-1d0)/180d0
      if (dirSize>1) then
        if (dir(2)==5) range(3:4) = range(3:4)*acos(-1d0)/180d0
      endif
      if (dirSize>2) then
        if (dir(3)==5) range(5:6) = range(5:6)*acos(-1d0)/180d0
      endif
    endif

    ! an index letter (i, j, k) takes whole cell indices, the same for every phase writer
    do i = 1, min(dirSize, 3)
      if (dir(i) >= 6) range(2*i-1:2*i) = real(nint(range(2*i-1:2*i)), R8)
    enddo

    ! the cells that the gas writer of this zone writes (read by the dispersed-phase writer of the zone)
    if (allocated(self%zone_ig)) self%zone_ig = .false.

    ig_loaded = .false.
    rf_loaded = .false.
    sp_loaded = .false.
    dp_loaded = .false.

    ! two passes: every phase but DP in the order of the phase key, then DP, whose state is derived from the
    ! gas state of the cell (a key 'particles gas' builds as 'gas particles')
    do pass = 1, 2
    do pi = 1, size(self%associated_phase)
      phase_type = self%associated_phase(pi)%type
      if ((pass == 1) .eqv. (phase_type == 'DP')) cycle

      select case (phase_type)

      case ('IG')

        if (.not. ig_loaded) then
          call load_ig_config(zoneini, ig_cfg)
          ig_loaded = .true.
        endif
        call build_IG_field(self, zoneini, ig_cfg, IC_type, self%associated_phase(pi)%species, &
                            range, dirSize, dir)

      case ('RF')

        if (.not. rf_loaded) then
          call load_rf_config(zoneini, rf_cfg)
          rf_loaded = .true.
        endif
        call build_RF_field(self, rf_cfg, IC_type, self%associated_phase(pi)%fluid, &
                            range, dirSize, dir)

      case ('DP')

        if (.not. dp_loaded) then
          nnn = 0
          do i = 1, self%associated_phase(pi)%material%n
            nnn = nnn + self%associated_phase(pi)%material%npCP(i)
          enddo
          call load_dp_config(zoneini, nnn, dp_cfg)
          dp_loaded = .true.
        endif
        call build_DP_field(self, dp_cfg, IC_type, self%associated_phase(pi)%material, range, dirSize, dir)

      case ('SP')

        if (.not. sp_loaded) then
          call load_sp_config(zoneini, sp_cfg)
          sp_loaded = .true.
        endif
        call build_SP_field(self, sp_cfg, IC_type, self%associated_phase(pi)%material, range, dirSize, dir, index_based)

      end select

    enddo
    enddo

  end subroutine build_field

end module ic_builder_mod
