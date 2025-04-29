module IC_lib_CD
  implicit none

contains

  subroutine build_CD_field(block,zoneini,mat)
    use ATLAS_high_level
    use finer, only: file_ini
    use material_module
    use variables, only: neuler
    implicit none
    type(ATLAS_block), intent(inout)  :: block
    type(file_ini), intent(in)        :: zoneini
    type(obj_material), intent(in)    :: mat
    character(len=32)                 :: IC_type
    integer                       :: i, j, k, error, nnn, g
    real(8)                       :: rho
    real(8), allocatable          :: krho(:), rp(:), kT(:), Pp(:)

    nnn = 0
    do k = 1, mat%n
      nnn = nnn + mat%npCP(k)
    enddo

    if (.not.allocated(block%densityP)) then
      allocate(block%densityP    ( nnn ,1:block%dim(1),1:block%dim(2),1:block%dim(3)))
      allocate(block%velocityP   (nnn,3,1:block%dim(1),1:block%dim(2),1:block%dim(3)))
      allocate(block%temperatureP( nnn ,1:block%dim(1),1:block%dim(2),1:block%dim(3)))
      allocate(block%nP          ( nnn ,1:block%dim(1),1:block%dim(2),1:block%dim(3)))
      allocate(block%PP          ( nnn ,1:block%dim(1),1:block%dim(2),1:block%dim(3)))
    endif

    allocate(krho(1:nnn)); krho = 0.0
    allocate(kT(1:nnn)); kT = 1.0
    allocate(rp(1:nnn))
    allocate(Pp(1:nnn))
    call zoneini%get(section_name='zone', option_name='krho',   val=krho, error=error)
    call zoneini%get(section_name='zone', option_name='kT',   val=kT, error=error)
    call zoneini%get(section_name='zone', option_name='dp', val=rp, error=error)
    call zoneini%get(section_name='zone', option_name='Pp', val=Pp, error=error)
    if (error==0) neuler = 1
    rp = 0.5*rp

    if (sum(krho)==0.0) then
      IC_type = 'vacuum'
    elseif (sum(krho)/=0.0 .and. product(kT)==1.0) then
      IC_type = 'thermo-mechanical equilibrium'
    elseif (sum(krho)/=0.0 .and. product(kT)/=1.0) then
      IC_type = 'mechanical equilibrium'
    endif

    write(*,*) ' -- CD type = ',trim(IC_type)

    select case (IC_type)
    case ('interpolation')

      error stop "Interopilation procedure not available for CD"

    case ('vacuum')

      block%densityP(:,:,:,:) = 1d-20
      block%velocityP(:,1:3,:,:,:) = 1d-20
      block%temperatureP(:,:,:,:) = 1d-20
      block%np(:,:,:,:) = 1d-20
      if (neuler==1) then
        block%PP(:,:,:,:) = 1D-20
      endif

    case('equilibrium', 'thermo-mechanical equilibrium', 'mechanical equilibrium')

    do g = 1, nnn
      if (krho(g)==0.0) then
        block%densityP(g,:,:,:) = 0.0
        block%velocityP(g,1:3,:,:,:) = 0.0
        block%temperatureP(g,:,:,:) = 0.0
        block%np(g,:,:,:) = 0.0
      else
        block%densityP(g,:,:,:) = sum(block%density(:,:,:,:), dim=1) * krho(g)
        block%velocityP(g,1:3,:,:,:) = block%velocity(:,:,:,:)
        block%temperatureP(g,:,:,:) = block%temperature(:,:,:)* kT(g)
        do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)
              rho = mat%rho(g,nint(block%temperature(i,j,k)))
              block%np(g,i,j,k) = block%densityP(g,i,j,k)/(4.0/3.0*3.14*rho*rp(g)**3)
        enddo; enddo; enddo
      endif
      if (neuler==1) then
        block%PP(g,:,:,:) = Pp(g)
      endif
    enddo

    end select

  end subroutine build_CD_field

end module IC_lib_CD