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
        call zoneini%get(section_name='zone', option_name='qvol-direction', val=qvoldirection, error=errordirection)
        if (errordirection==0) then
          call read_qvolfile (qvol, block, qvolfile, qvoldirection)
        else
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
    integer :: dir, ios, file_length, i, j, k, f
    real(8), dimension(:), allocatable :: file_dir, file_qvol
    real(8) :: coord, coordm, coordp, qvolm, qvolp
    
    if (present(qvoldirection)) then
      
      if (trim(qvoldirection) == 'x') dir = 1
      if (trim(qvoldirection) == 'y') dir = 2
      if (trim(qvoldirection) == 'z') dir = 3

      file_length=0; ios=0
      open(unit=1,file=trim(qvolfile),status='old',action='read')
      do while (ios==0)
        read(1,*,iostat=ios)
        file_length = file_length+1
      enddo
      file_length = file_length-1
      rewind(1)
      allocate(file_dir(1:file_length))
      allocate(file_qvol(1:file_length))
      do i = 1, file_length
        read(1,*) file_dir(i), file_qvol(i)
      enddo
      close(1)

      do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)
        coord = block%center(i,j,k)%c(dir)
        do f = 1, file_length
          if (coord < file_dir(1) .or. coord > file_dir(file_length) ) then
            exit
          elseif (coord < file_dir(f)) then
            coordm = file_dir(f-1)
            coordp = file_dir(f)
            qvolm = file_qvol(f-1)
            qvolp = file_qvol(f)
            qvol(i,j,k) = qvolm + (coord-coordm)/(coordp-coordm)*(qvolp-qvolm)
            exit
          endif
        enddo
        
      enddo; enddo; enddo

    else

      print*, 'TODO: LEGGERE FILE QVOL.TEC'

    endif


  end subroutine read_qvolfile

end module IC_lib_SP