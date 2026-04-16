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
    type(phase_t), intent(in)     :: phase(:)
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
        allocate(blk%associated_phase(1:size(phase)))
        blk%associated_phase = phase
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
    implicit none
    type(IC_block), intent(inout) :: self
    type(file_ini), intent(in)    :: zoneini
    ! Local
    character(len=2)              :: phase_type
    logical                       :: index_based
    integer                       :: pi, i, error
    character(len=20)             :: IC_type
    real(R8)                      :: range(6)
    character(len=3)              :: dirID
    integer                       :: dirSize
    integer, allocatable          :: dir(:)
    
    call zoneini%get(section_name='zone', option_name='type', val=IC_type, error=error)
    if (error/=0) IC_type='homogeneous'
    
    ! Check direction
    index_based = .false.
    dirSize = 0
    call zoneini%get(section_name='zone', option_name='direction', val=dirID, error=error)
    if (error==0) then
      call parse_direction(dirID, dir, dirSize, index_based)
    endif

    ! Check range for multizone
    call zoneini%get(section_name='zone',option_name='range',val=range, error=error)
    if (error/=0) then
      do i = 1, 6 ; range(i) = (-1.0)**i*huge(range(i)) ; enddo
    else
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

    do pi = 1, size(self%associated_phase)
      phase_type = self%associated_phase(pi)%type

      select case (phase_type)

      case ('IG')

        call build_IG_field(self,zoneini,IC_type,self%associated_phase(pi)%species,range,dirSize,dir)

      case ('RF')

        call build_RF_field(self,zoneini,IC_type,self%associated_phase(pi)%fluid,range,dirSize,dir)

      case ('DP')

        call build_DP_field(self,zoneini,self%associated_phase(pi)%material)

      case ('SP')

        call build_SP_field(self,zoneini,IC_type,self%associated_phase(pi)%material,range,dirSize,dir,index_based)

      end select

    enddo

  end subroutine build_field

end module ic_builder_mod
