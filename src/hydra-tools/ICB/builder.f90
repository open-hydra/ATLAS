module ic_builder_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use finer,         only: file_ini
  use direction_mod, only: parse_direction
  use ic_block_mod
  implicit none
  private
  public:: build_IC

  contains

  subroutine build_IC(phase,sini,blocks)
    use phase_mod,                 only: phase_t
    use io_phase_mod,              only: read_idealgas_properties, read_dp_properties, read_realfluid_properties
    use ic_interpolation_cons_mod, only: set_conservative_receiver_blocks
    use strings,                   only: parse
    use ir_precision,              only: str
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

    call set_conservative_receiver_blocks(blocks)

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
          do i = 1, size(phase)
            if (blk%associated_phase(j)%name==phase(i)%name) &
              blk%associated_phase(j) = phase(i)
          enddo
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

      call sini%get(section_name=section_name, option_name='type', val=blk%type, error=error)
      if (error/=0) blk%type = 'homogeneous'
      ! Multizone
      call sini%get(section_name=section_name, option_name='direction',  val=zonedirection, error=error)
      if (error==0) blk%type = 'multizone'

      if (blk%type=='multizone') then
        p = 0
        do
          p = p+1
          call sini%get(section_name=section_name, option_name='zone'//str(.true.,p), &
                                            val=zonename, error=error_zone)
          if (error_zone/=0) exit
          call sini%get(section_name=section_name, option_name='range'//str(.true.,p), &
                                            val=zonerange, error=error)
          call zoneini%free
          call zoneini%add(section_name='zone')
          do while (sini%loop(section_name=zonename, option_pairs=option_pairs))
            call zoneini%add(section_name='zone', option_name=option_pairs(1), val=option_pairs(2))
          enddo
          call zoneini%add(section_name='zone', option_name='range', val=zonerange)
          call zoneini%add(section_name='zone', option_name='direction', val=zonedirection)
          call build_field(self=blk,zoneini=zoneini)
        enddo
      else
        call zoneini%free
        call zoneini%add(section_name='zone')
        do while (sini%loop(section_name=section_name, option_pairs=option_pairs))
          call zoneini%add(section_name='zone', option_name=option_pairs(1), val=option_pairs(2))
        enddo
        call build_field(self=blk,zoneini=zoneini)
      endif

      write(*,*)

      endassociate
    enddo

  end subroutine build_IC


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
    integer                       :: pi, i, nnn
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

    ig_loaded = .false.
    rf_loaded = .false.
    sp_loaded = .false.
    dp_loaded = .false.

    do pi = 1, size(self%associated_phase)
      phase_type = self%associated_phase(pi)%type

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
        call build_DP_field(self, dp_cfg, IC_type, self%associated_phase(pi)%material)

      case ('SP')

        if (.not. sp_loaded) then
          call load_sp_config(zoneini, sp_cfg)
          sp_loaded = .true.
        endif
        print *, 'Building SP field for material: ', self%associated_phase(pi)%material%name
        call build_SP_field(self, sp_cfg, IC_type, self%associated_phase(pi)%material, range, dirSize, dir, index_based)

      end select

    enddo

  end subroutine build_field

end module ic_builder_mod
