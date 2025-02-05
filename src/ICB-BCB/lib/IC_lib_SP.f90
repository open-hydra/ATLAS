module IC_lib_SP
  implicit none

contains

  subroutine build_SP_field(block,zoneini,IC_type,mat,range,dirSize,dir,index_based)
    use ATLAS_high_level
    use finer, only: file_ini
    use material_module
    implicit none
    type(ATLAS_block), intent(inout)  :: block
    type(file_ini), intent(in)        :: zoneini
    character(len=*), intent(inout)   :: IC_type
    type(obj_material), intent(in)    :: mat
    logical, intent(in)               :: index_based
    real(8), intent(in)               :: range(6)
    integer, intent(in)               :: dirSize
    ! Local
    integer                       :: dir(:), i, j, k, h, mID
    integer                       :: error, errorfile, errordirection
    real(8)                       :: T, qvol_const
    character(len=16)             :: material_name, qvoldirection
    real(8)                       :: here(3)
    integer                       :: imin, imax, jmin, jmax, kmin, kmax
    character(len=200)            :: qvolfile
    real(8), dimension(1:block%dim(1),1:block%dim(2),1:block%dim(3)) :: qvol
    ! character(len=128)            :: OMF, OFF, OSF
    ! integer                       :: oldid

    if (.not.allocated(block%temperature)) then
        allocate(block%temperature(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
        allocate(block%mID(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
        allocate(block%qvol(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
    endif

    mID = 0
    call zoneini%get(section_name='zone', option_name='material', val=material_name, error=error)
    do i = 1, mat%n
        if (trim(mat%name(i))==trim(material_name)) &
        mID = i
    enddo
    mID = max(mID,1)

    call zoneini%get(section_name='zone', option_name='T', val=T, error=error)
    
    call zoneini%get(section_name='zone', option_name='qvol', val=qvol_const, error=error)
    if (error/=0) then
      qvol = 0.0d0
      call zoneini%get(section_name='zone', option_name='qvol-file', val=qvolfile, error=errorfile)
      if (errorfile==0) then
        call zoneini%get(section_name='zone', option_name='direction', val=qvoldirection, error=errordirection)
        if (errordirection==0) then
          call read_qvolfile (qvol, block, qvolfile, qvoldirection)
        else
          print*, 'TODO: LEGGERE FILE QVOL.TEC'
          call read_qvolfile (qvol, block, qvolfile)
        endif
      endif
    else
      qvol = qvol_const
    endif

    write(*,*) ' -- SP type = ',trim(IC_type)

    select case (IC_type)
    
    case ('interpolation')

      error stop 'Interpolation procedure not available for SP'

    case ('homogeneous')

        if (.not.index_based) then
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
                block%qvol(i,j,k) = qvol(i,j,k)

              endif
          enddo; enddo; enddo
      
        
        elseif (index_based) then
          
          imin = -huge(imin); jmin = -huge(jmin); kmin = -huge(kmin)
          imax = huge(imax); jmax = huge(jmax); kmax = huge(kmax)

          do h = 1, dirSize

            select case(dir(h))
            
            case(6)
              imin = range(2*h-1)
              imax = range(2*h)
              
            case(7)
              jmin = range(2*h-1)
              jmax = range(2*h)

            case(8)
              kmin = range(2*h-1)
              kmax = range(2*h)

            end select

          enddo

          do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)
            if (i>=imin .and. i<=imax .and. &
                j>=jmin .and. j<=jmax .and. &
                k>=kmin .and. k<=kmax) then

              block%temperature(i,j,k) = T
              block%mID(i,j,k) = mID
              block%qvol(i,j,k) = qvol(i,j,k)

            endif
          enddo; enddo; enddo            
        
        endif

    end select


  end subroutine build_SP_field




  subroutine read_qvolfile (qvol, block, qvolfile, qvoldirection)
    use ATLAS_high_level
    implicit none
    type(ATLAS_block), intent(inout)  :: block
    character(len=200), intent(in)    :: qvolfile
    character(len=16), intent(in), optional  :: qvoldirection
    real(8), dimension(1:block%dim(1),1:block%dim(2),1:block%dim(3)), intent(inout) :: qvol
    ! Local
    integer :: dir

    if (index(qvoldirection,'x')/=0) dir = 1
    if (index(qvoldirection,'y')/=0) dir = 2
    if (index(qvoldirection,'z')/=0) dir = 3

    ! TODO: interpolazione lineare di un file


  end subroutine read_qvolfile

end module IC_lib_SP