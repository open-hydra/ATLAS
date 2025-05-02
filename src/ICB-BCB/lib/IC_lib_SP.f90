module IC_lib_SP
  implicit none

contains

  subroutine build_SP_field(block,zoneini,IC_type,mat,range,dirSize,dir,index_based)
    use ATLAS_high_level
    use finer, only: file_ini
    use Interpolator_SP
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
    real(8)                       :: val_const
    character(len=16)             :: material_name, val_direction
    real(8)                       :: here(3)
    integer                       :: imin, imax, jmin, jmax, kmin, kmax
    character(len=200)            :: val_file
    real(8), dimension(1:block%dim(1),1:block%dim(2),1:block%dim(3)) :: qvol, T
    character(len=llen)           :: OMF, OFF
    integer                       :: oldid

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

    call zoneini%get(section_name='zone', option_name='T', val=val_const, error=error)
    if (error/=0) then
      T = 0.0d0
      call zoneini%get(section_name='zone', option_name='T-file', val=val_file, error=errorfile)      
      if (errorfile==0) then
        call zoneini%get(section_name='zone', option_name='T-direction', val=val_direction, error=errordirection)
        if (errordirection==0) then
          call read_file_direction (T, block, val_file, val_direction)
        else
          call read_file_tec (T, block, val_file)
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
          call read_file_tec (qvol, block, val_file)
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



  subroutine read_file_tec ( var, block, varfile )
    use ATLAS_high_level
    use chimera, only: fs
    use intersection_module
    use Lib_ORION_data
    use Lib_Tecplot
    use TOM
    implicit none
    type(ATLAS_block), intent(inout)  :: block
    character(len=200), intent(in)    :: varfile
    real(8), dimension(1:block%dim(1),1:block%dim(2),1:block%dim(3)), intent(inout) :: var
    !Local
    type(Orion_Data) :: IOfield
    integer          :: error, i, j, k, d, ii, jj, kk
    type(var_block)  :: var_tec
    real(8)                                  :: mindist
    real(8), dimension(:,:,:), allocatable   :: dx, dy, dz, dist
    integer, dimension(3)                    :: ind
    real*8, dimension(3,8)                   :: cell
    logical                                  :: inside_loc, inside

    
    IOfield%tec%format = 'ascii'
    error = tec_read_structured_multiblock( orion=IOfield, filename=trim(varfile) )

    allocate(var_tec%node   (0:IOfield%block(1)%Ni,0:IOfield%block(1)%Nj,0:IOfield%block(1)%Nk))
    allocate(var_tec%center (1:IOfield%block(1)%Ni,1:IOfield%block(1)%Nj,1:IOfield%block(1)%Nk))
    allocate(var_tec%var   (1:IOfield%block(1)%Ni,1:IOfield%block(1)%Nj,1:IOfield%block(1)%Nk))

    var_tec%dim(1) = IOfield%block(1)%Ni
    var_tec%dim(2) = IOfield%block(1)%Nj
    var_tec%dim(3) = IOfield%block(1)%Nk

    do i = 0, var_tec%dim(1); do j = 0, var_tec%dim(2); do k = 0, var_tec%dim(3)
      var_tec%node(i,j,k)%c(1:3) = IOfield%block(1)%mesh(:,i,j,k)
    enddo; enddo; enddo
   
    !> Compute the cells center coords
    do k = 1, var_tec%dim(3); do j = 1, var_tec%dim(2); do i = 1, var_tec%dim(1)
      do d = 1, 3
        var_tec%center(i,j,k)%c(d)=0.125d0*(var_tec%node(i-1,j-1,k-1)%c(d)+var_tec%node(i,j-1,k-1)%c(d)+ &
                                             var_tec%node(i-1,j,k-1)%c(d)+var_tec%node(i-1,j-1,k)%c(d)+ &
                                             var_tec%node(i,j,k)%c(d)+var_tec%node(i,j,k-1)%c(d)+ &
                                             var_tec%node(i,j-1,k)%c(d)+var_tec%node(i-1,j,k)%c(d))
      enddo
    enddo; enddo; enddo

    do i = 1, var_tec%dim(1); do j = 1, var_tec%dim(2); do k = 1, var_tec%dim(3)
      var_tec%var(i,j,k) = IOfield%block(1)%vars(1,i,j,k)
    enddo; enddo; enddo

    ! Cell centers minimum distance algorithm
    do k = 1, block%dim(3); do j = 1, block%dim(2); do i = 1, block%dim(1)
      
      inside = .false.
      do ii = 1, var_tec%dim(1); do jj = 1, var_tec%dim(2); do kk = 1, var_tec%dim(3)
        
        cell(:,1) = var_tec%node(ii-1,jj-1,kk-1)%c(1:3)*fs
        cell(:,2) = var_tec%node(ii-1,jj  ,kk-1)%c(1:3)*fs
        cell(:,3) = var_tec%node(ii-1,jj-1,kk  )%c(1:3)*fs
        cell(:,4) = var_tec%node(ii-1,jj  ,kk  )%c(1:3)*fs
        cell(:,5) = var_tec%node(ii  ,jj-1,kk-1)%c(1:3)*fs
        cell(:,6) = var_tec%node(ii  ,jj  ,kk-1)%c(1:3)*fs
        cell(:,7) = var_tec%node(ii  ,jj-1,kk  )%c(1:3)*fs
        cell(:,8) = var_tec%node(ii  ,jj  ,kk  )%c(1:3)*fs
       
        inside_loc = .false.
        call pointInsideHexahedron(block%center(i,j,k)%c(1:3)*fs, cell, inside_loc)

        if (inside_loc .eqv. .true.) inside = .true.
      
      enddo; enddo; enddo

      if (inside .eqv. .true.) then
  
        allocate(dx(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3)))
        allocate(dy(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3)))
        allocate(dz(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3)))
        allocate(dist(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3)))
              
        dx(:,:,:) = (block%center(i,j,k)%c(1)-var_tec%center(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3))%c(1))**2
        dy(:,:,:) = (block%center(i,j,k)%c(2)-var_tec%center(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3))%c(2))**2
        dz(:,:,:) = (block%center(i,j,k)%c(3)-var_tec%center(1:var_tec%dim(1),1:var_tec%dim(2),1:var_tec%dim(3))%c(3))**2
        dist(:,:,:) = sqrt(dx(:,:,:)+dy(:,:,:)+dz(:,:,:))

        ind = minloc(dist(:,:,:), MASK=.true.)
        mindist = dist(ind(1),ind(2),ind(3))

        deallocate(dx);deallocate(dy);deallocate(dz);deallocate(dist)

        var(i,j,k) = var_tec%var(ind(1),ind(2),ind(3))

      endif
          
    enddo; enddo; enddo

  end subroutine read_file_tec



end module IC_lib_SP