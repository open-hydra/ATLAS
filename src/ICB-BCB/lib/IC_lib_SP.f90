module IC_lib_SP
  implicit none

contains

  subroutine build_SP_field(block,zoneini,IC_type,mat,range,dirSize,dir)
    use ATLAS_high_level
    use finer, only: file_ini
    use material_module
    implicit none
    type(ATLAS_block), intent(inout)  :: block
    type(file_ini), intent(in)        :: zoneini
    character(len=*), intent(inout)   :: IC_type
    type(obj_material), intent(in)    :: mat
    real(8), intent(in)               :: range(6)
    integer, intent(in)               :: dirSize
    integer                       :: dir(:)
    integer                       :: i, j, k, error, mID
    real(8)                       :: T
    character(len=16)             :: material_name
    real(8)                       :: here(3)
    ! character(len=128)            :: OMF, OFF, OSF
    ! integer                       :: oldid

    if (.not.allocated(block%temperature)) then
        allocate(block%temperature(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
        allocate(block%mID(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
    endif

    mID = 0
    call zoneini%get(section_name='zone', option_name='material', val=material_name, error=error)
    do i = 1, mat%n
        if (trim(mat%name(i))==trim(material_name)) &
        mID = i
    enddo
    mID = max(mID,1)

    call zoneini%get(section_name='zone', option_name='T', val=T, error=error)

    write(*,*) ' -- SP type = ',trim(IC_type)

    select case (IC_type)
    case ('interpolation')

        error stop ("Interopilation procedure not available for SP")

    case ('homogeneous')

        here = 1.0
        do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)
            if (dirSize>=1) here(1) = block%center(i,j,k)%c(dir(1))
            if (dirSize>=2) here(2) = block%center(i,j,k)%c(dir(2))
            if (dirSize>=3) here(3) = block%center(i,j,k)%c(dir(3))
            if (here(1)>=range(1) .and. here(1)<=range(2) .and. &
                here(2)>=range(3) .and. here(2)<=range(4) .and. &
                here(3)>=range(5) .and. here(3)<=range(6)) then
                block%temperature(i,j,k) = T
                block%mID(i,j,k) = mID
            endif
        enddo; enddo; enddo

    end select

  end subroutine build_SP_field

end module IC_lib_SP