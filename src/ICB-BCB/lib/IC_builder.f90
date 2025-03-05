module build_IC_mod
  use ATLAS_high_level
  use finer, only: file_ini
  implicit none
  private
  public:: build_IC

  integer, parameter :: nIG=5

  contains

  subroutine build_IC(phase,sini,blocks)
    use phase_module, only: phase_type
    use ATLAS_IO, only: read_idealgas_properties, read_cdp_properties
    use strings, only: parse
    implicit none
    type(phase_type), intent(in)     :: phase(:)
    type(ATLAS_block), intent(inout) :: blocks(:)
    type(file_ini), intent(in)       :: sini

    character(len=30)             :: zonename, section_name
    character(len=:), allocatable :: option_pairs(:)
    type(file_ini)                :: zoneini
    integer                       :: i, j, b, p, error, error_zone
    character(len=4)              :: indb, ind
    character(len=4)              :: zonedirection
    real(8)                       :: zonerange(6)
    character(len=20)             :: wholestring, args(3), phase_name

    do b = 1, size(blocks)
      write(indb,'(I4)') b
      section_name = 'ICB-Block'//adjustl(indb)
      blocks(b)%id = b
      associate(block => blocks(b))

      write(*,*)' - Initialization block n. = ', b

      ! Look for phases solved in block b
      call sini%get(section_name=section_name, option_name='phase', val=wholestring, error=error)
      if (error/=0) then
        allocate(block%associated_phase(1:size(phase)))
        block%associated_phase = phase
      else
        call parse(wholestring,' ',args)
        p = count(args /= '')
        allocate(block%associated_phase(1:p))
        block%associated_phase%name = args(1:p)
        do j = 1, p
          do i = 1, size(phase)
            if (block%associated_phase(j)%name==phase(i)%name) &
              block%associated_phase(j) = phase(i)
          enddo
        enddo
      endif

      ! Read phase properties (if any)
      do p = 1, size(block%associated_phase)
        if (block%associated_phase(p)%name=='') then
          phase_name = ''
        else
          phase_name = trim(block%associated_phase(p)%name)//'-'
        endif
        if (block%associated_phase(p)%type=='IG') then
          call read_idealgas_properties(trim(phase_name),block%associated_phase(p)%species)
        elseif (block%associated_phase(p)%type=='CD') then
          call read_cdp_properties(trim(phase_name),block%associated_phase(p)%material)
        elseif (block%associated_phase(p)%type=='SP') then
          call read_cdp_properties(trim(phase_name),block%associated_phase(p)%material)
        endif
        if (.not.allocated(block%associated_phase(p)%species%massf)) &
        allocate(block%associated_phase(p)%species%massf(1:block%associated_phase(p)%species%n))
        block%associated_phase(p)%species%massf = 1d-20
      enddo

      call sini%get(section_name=section_name, option_name='type', val=block%type, error=error)
      if (error/=0) block%type = 'homogeneous'
      ! Multizone
      call sini%get(section_name=section_name, option_name='direction',  val=zonedirection, error=error)
      if (error==0) block%type = 'multizone'

      if (block%type=='multizone') then
        p = 0
        do
          p = p+1; write(ind,'(I4)') p
          call sini%get(section_name=section_name, option_name='zone'//adjustl(ind), &
                                            val=zonename, error=error_zone)
          if (error_zone/=0) exit
          call sini%get(section_name=section_name, option_name='range'//adjustl(ind), &
                                            val=zonerange, error=error)
          call zoneini%free
          call zoneini%add(section_name='zone')
          do while (sini%loop(section_name=zonename, option_pairs=option_pairs))
            call zoneini%add(section_name='zone', option_name=option_pairs(1), val=option_pairs(2))
          enddo
          call zoneini%add(section_name='zone', option_name='range', val=zonerange)
          call zoneini%add(section_name='zone', option_name='direction', val=zonedirection)
          call build_field(block,zoneini)
        enddo
      else
        call zoneini%free
        call zoneini%add(section_name='zone')
        do while (sini%loop(section_name=section_name, option_pairs=option_pairs))
          call zoneini%add(section_name='zone', option_name=option_pairs(1), val=option_pairs(2))
        enddo
        call build_field(block,zoneini)
      endif

      write(*,*)

      endassociate
    enddo

  end subroutine build_IC


  subroutine build_field(self,zoneini)
    use IC_lib_IG
    use IC_lib_SP
    use IC_lib_CD
    implicit none
    type(ATLAS_block), intent(inout) :: self
    type(file_ini), intent(in)       :: zoneini
    character(len=2)              :: phase_type
    logical                       :: found(8), index_based
    integer                       :: pi, i, error
    character(len=20)             :: IC_type
    real(8)                       :: range(6)
    character(len=3)              :: dirID
    integer                       :: dirSize
    integer, allocatable          :: dir(:)
    
    call zoneini%get(section_name='zone', option_name='type', val=IC_type, error=error)
    if (error/=0) IC_type='homogeneous'
    
    ! Check direction
    index_based=.false.
    dirSize = 0
    call zoneini%get(section_name='zone', option_name='direction', val=dirID, error=error)
    if (error==0) then
      found = .false.
      dirSize = len_trim(dirID)
      allocate(dir(1:dirSize))
      do i = 1, dirSize
        if (index(dirID,'x')/=0 .and. .not.found(1)) then
          dir(i) = 1; found(1)=.true.
        elseif (index(dirID,'y')/=0 .and. .not.found(2)) then
          dir(i) = 2; found(2)=.true.
        elseif (index(dirID,'z')/=0 .and. .not.found(3)) then
          dir(i) = 3; found(3)=.true.
        elseif (index(dirID,'r')/=0 .and. .not.found(4)) then
          dir(i) = 4; found(4)=.true.
        elseif (index(dirID,'t')/=0 .and. .not.found(5)) then
          dir(i) = 5; found(5)=.true.
        elseif (index(dirID,'i')/=0 .and. .not.found(6)) then
          dir(i) = 6; found(6)=.true.; index_based=.true.
        elseif (index(dirID,'j')/=0 .and. .not.found(7)) then
          dir(i) = 7; found(7)=.true.; index_based=.true.
        elseif (index(dirID,'k')/=0 .and. .not.found(8)) then
          dir(i) = 8; found(8)=.true.; index_based=.true.
        endif
      enddo
    endif

    ! Check range for multizone
    call zoneini%get(section_name='zone',option_name='range',val=range, error=error)
    if (error/=0) then
      do i = 1, 6 ; range(i) = (-1.0)**i*huge(range(i)) ; enddo
    else
      do i = dirSize*2+1, 6 ; range(i) = (-1.0)**i*huge(range(i)) ; enddo
    endif

    do pi = 1, size(self%associated_phase)
      phase_type = self%associated_phase(pi)%type

      select case (phase_type)

      case('IG')

        call build_IG_field(self,zoneini,IC_type,self%associated_phase(pi)%species,range,dirSize,dir)

      case ('CD')

        call build_CD_field(self,zoneini,self%associated_phase(pi)%material)

      case ('SP')
        
        call build_SP_field(self,zoneini,IC_type,self%associated_phase(pi)%material,range,dirSize,dir,index_based)

      end select

    enddo

  end subroutine build_field

end module build_IC_mod
