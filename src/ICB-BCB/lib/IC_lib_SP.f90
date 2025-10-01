module IC_lib_SP
  implicit none

contains

  subroutine build_SP_field(block,zoneini,IC_type,mat,range,dirSize,dir,index_based,powerblock)
    use ATLAS_high_level
    use finer, only: file_ini
    use Interpolator_SP
    use material_module
    use IC_lib_POWER

    implicit none
    type(ATLAS_block), intent(inout)  :: block
    type(file_ini), intent(in)        :: zoneini
    character(len=*), intent(inout)   :: IC_type
    type(obj_material), intent(in)    :: mat
    logical, intent(in)               :: index_based
    real(8), intent(in)               :: range(6)
    integer, intent(in)               :: dirSize
    type(var_block), intent(inout), optional :: powerblock
    ! Local
    integer                       :: dir(:), i, j, k, h
    integer                       :: error, errorfile, errordirection
    real(8)                       :: val_const
    character(len=16)             :: material_name, val_direction
    real(8)                       :: here(3)
    integer                       :: imin, imax, jmin, jmax, kmin, kmax
    character(len=200)            :: val_file
    real(8), dimension(1:block%dim(1),1:block%dim(2),1:block%dim(3)) :: qvol, T
    real(8)                       :: mID
    character(len=llen)           :: OMF, OFF
    integer                       :: oldid

    if (.not.allocated(block%temperature)) then
        allocate(block%temperature(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
    endif
    if (.not.allocated(block%mID)) then
        allocate(block%mID(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
    endif
    if (.not.allocated(block%qvol)) then
        allocate(block%qvol(1:block%dim(1),1:block%dim(2),1:block%dim(3)))
    endif

    mID = 0.0
    call zoneini%get(section_name='zone', option_name='material', val=material_name, error=error)
    do i = 1, mat%n
        if (trim(mat%name(i))==trim(material_name)) &
        mID = real(i)
    enddo
    mID = max(mID,1.0)

    call zoneini%get(section_name='zone', option_name='T', val=val_const, error=error)
    if (error/=0) then
      T = 0.0d0
      call zoneini%get(section_name='zone', option_name='T-file', val=val_file, error=errorfile)      
      if (errorfile==0) then
        call zoneini%get(section_name='zone', option_name='T-direction', val=val_direction, error=errordirection)
        if (errordirection==0) then
          call read_file_direction (T, block, val_file, val_direction)
        endif
      endif
    else
      T = val_const
    endif
    
    call zoneini%get(section_name='zone', option_name='qvol', val=val_const, error=error)
    if (error/=0) then
      qvol = 0.0d0
      call zoneini%get(section_name='zone', option_name='qvol-file', val=val_file, error=errorfile)      
      if (errorfile==0) then
        call zoneini%get(section_name='zone', option_name='qvol-direction', val=val_direction, error=errordirection)
        if (errordirection==0) then
          call read_file_direction (qvol, block, val_file, val_direction)
        else
          call assign_power (qvol, block, powerblock)
        endif
      endif
    else
      qvol = val_const
    endif

    ! Interpolation specific parameters
    call zoneini%get(section_name='zone', option_name='oldmesh', val=OMF, error=error)
    if (error/=0) OMF = 'Darwin'
    call zoneini%get(section_name='zone', option_name='oldsolution', val=OFF, error=error)
    if (error==0) IC_type = 'interpolation'
    call zoneini%get(section_name='zone', option_name='oldid', val=oldid, error=error)
    if (error/=0) oldid = 0
    call zoneini%get(section_name='zone', option_name='law', val=law, error=error)
    if (error/=0) law = 'outlaw'
    if (law=='extrude') then
      call zoneini%get(section_name='zone', option_name='theta', val=thetamax_extrude, error=error)
      if (error/=0) thetamax_extrude = float(90)
      call zoneini%get(section_name='zone', option_name='nz', val=nz_extrude, error=error)
      if (error/=0) nz_extrude = int(4)
    endif

    write(*,*) ' -- SP type = ',trim(IC_type)

    select case (IC_type)
    
    case ('interpolation')

      call intersol(block,OMF,OFF,oldid)

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

                block%temperature(i,j,k) = T(i,j,k)
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

              block%temperature(i,j,k) = T(i,j,k)
              block%mID(i,j,k) = mID
              block%qvol(i,j,k) = qvol(i,j,k)

            endif
          enddo; enddo; enddo            
        
        endif

    end select

  end subroutine build_SP_field



  subroutine read_file_direction (var, block, varfile, vardirection)
    use ATLAS_high_level
    implicit none
    type(ATLAS_block), intent(inout)  :: block
    character(len=200), intent(in)    :: varfile
    character(len=16), intent(in)     :: vardirection
    real(8), dimension(1:block%dim(1),1:block%dim(2),1:block%dim(3)), intent(inout) :: var
    ! Local
    integer :: dir, ios, file_length, i, j, k, f
    real(8), dimension(:), allocatable :: file_dir, file_var
    real(8) :: coord, coordm, coordp, varm, varp

      
    if (trim(vardirection) == 'x') dir = 1
    if (trim(vardirection) == 'y') dir = 2
    if (trim(vardirection) == 'z') dir = 3

    file_length=0; ios=0
    open(unit=1,file=trim(varfile),status='old',action='read')
    do while (ios==0)
      read(1,*,iostat=ios)
      file_length = file_length+1
    enddo
    file_length = file_length-1
    rewind(1)
    allocate(file_dir(1:file_length))
    allocate(file_var(1:file_length))
    do i = 1, file_length
      read(1,*) file_dir(i), file_var(i)
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
          varm = file_var(f-1)
          varp = file_var(f)
          var(i,j,k) = varm + (coord-coordm)/(coordp-coordm)*(varp-varm)
          exit
        endif
      enddo
        
    enddo; enddo; enddo

  end subroutine read_file_direction


end module IC_lib_SP
