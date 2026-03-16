module IC_lib_POWER
  use IR_Precision

  implicit none

contains

  subroutine read_power ( powerfile, powerblock )
    use ATLAS_high_level
    use Lib_ORION_data
    use Lib_Tecplot
    use ATLAS_Mod_Grid

    implicit none
    character(len=200), intent(in)    :: powerfile
    type(var_block), intent(inout)    :: powerblock
    ! Local
    type(Orion_Data) :: IOfield
    integer          :: error, i, j, k, d


    IOfield%tec%format = 'ascii'
    error = tec_read_structured_multiblock( orion=IOfield, filename=trim(powerfile) )

    allocate(powerblock%node   (0:IOfield%block(1)%Ni,0:IOfield%block(1)%Nj,0:IOfield%block(1)%Nk))
    allocate(powerblock%center (1:IOfield%block(1)%Ni,1:IOfield%block(1)%Nj,1:IOfield%block(1)%Nk))
    allocate(powerblock%vol    (1:IOfield%block(1)%Ni,1:IOfield%block(1)%Nj,1:IOfield%block(1)%Nk))
    allocate(powerblock%var    (1:IOfield%block(1)%Ni,1:IOfield%block(1)%Nj,1:IOfield%block(1)%Nk))
    allocate(powerblock%bbmin  (1:IOfield%block(1)%Ni,1:IOfield%block(1)%Nj,1:IOfield%block(1)%Nk))
    allocate(powerblock%bbmax  (1:IOfield%block(1)%Ni,1:IOfield%block(1)%Nj,1:IOfield%block(1)%Nk))

    powerblock%dim(1) = IOfield%block(1)%Ni
    powerblock%dim(2) = IOfield%block(1)%Nj
    powerblock%dim(3) = IOfield%block(1)%Nk

    ! Compute nodes
    do i = 0, powerblock%dim(1); do j = 0, powerblock%dim(2); do k = 0, powerblock%dim(3)
      powerblock%node(i,j,k)%c(1:3) = IOfield%block(1)%mesh(:,i,j,k)
    enddo; enddo; enddo

    ! Compute the cells center coords
    do k = 1, powerblock%dim(3); do j = 1, powerblock%dim(2); do i = 1, powerblock%dim(1)
      do d = 1, 3
        powerblock%center(i,j,k)%c(d)=0.125d0*(powerblock%node(i-1,j-1,k-1)%c(d)+powerblock%node(i,j-1,k-1)%c(d)+ &
                                               powerblock%node(i-1,j,k-1)%c(d)+powerblock%node(i-1,j-1,k)%c(d)+ &
                                               powerblock%node(i,j,k)%c(d)+powerblock%node(i,j,k-1)%c(d)+ &
                                               powerblock%node(i,j-1,k)%c(d)+powerblock%node(i-1,j,k)%c(d))
      enddo
    enddo; enddo; enddo

    ! Compute the cells volume
    call compute_volume_tec(powerblock)

    ! Compute bounding box
    call compute_boundingbox_tec(powerblock)

    ! Fill variables field
    do i = 1, powerblock%dim(1); do j = 1, powerblock%dim(2); do k = 1, powerblock%dim(3)
      powerblock%var(i,j,k) = IOfield%block(1)%vars(1,i,j,k)
    enddo; enddo; enddo
    
  end subroutine read_power


  
  subroutine rescale_volumes_power( powerblock, blocks )

    use ATLAS_high_level
    use chimera
    use intersection_module
    use Lib_ORION_data
    use Lib_Tecplot
    use ATLAS_Mod_Grid

    implicit none
    type(var_block), intent(inout)    :: powerblock
    type(ATLAS_block), intent(in)     :: blocks(:)

    ! Local
    integer                :: unitfile1, unitfile2, kr, jr, ir, b, kd, jd, id, d, nint, p, i
    logical                :: next
    real(8), allocatable   :: hull_points(:)
    real(8)                :: receiver(3,8), donor(3,8)
    logical, allocatable   :: nodeinside(:,:,:,:)
    character(len=18)      :: fmt
    character(len=200)     :: master_path
    type(intersection_type), allocatable :: intersection(:)
    integer                :: localID(4)
    real(8)                :: volume


    open(newunit=unitfile1,file='couples.txt')
    open(newunit=unitfile2,file='points.txt')

    nint = 0
    ir = 1
    id = 1

    allocate(nodeinside(8,1:powerblock%dim(1),1:powerblock%dim(2),1:powerblock%dim(3)))
    
    ! Volume intersection
    do kr = 1, powerblock%dim(3); do jr = 1, powerblock%dim(2)

      ! Loop over the donor block cells
      do b = 12, 15


        do kd = 1, blocks(b)%dim(3); do jd = 1,blocks(b)%dim(2)

          ! Check with bounding-box algorithm (I level)
          next = .false.
          do d = 1, 3
          if( (blocks(b)%bbmin(id,jd,kd)%c(d)>powerblock%bbmax(ir,jr,kr)%c(d)) .and. &
              (blocks(b)%bbmax(id,jd,kd)%c(d)>powerblock%bbmax(ir,jr,kr)%c(d)) ) next = .true.
          if( (blocks(b)%bbmin(id,jd,kd)%c(d)<powerblock%bbmin(ir,jr,kr)%c(d)) .and. &
              (blocks(b)%bbmax(id,jd,kd)%c(d)<powerblock%bbmin(ir,jr,kr)%c(d)) ) next = .true.
          enddo
          if (next) cycle
        
          ! Check with serious algorithm (II level)
          if (allocated(hull_points)) deallocate(hull_points)
          receiver(:,1) = powerblock%node(ir-1,jr-1,kr-1)%c(1:3)*fs
          receiver(:,2) = powerblock%node(ir-1, jr ,kr-1)%c(1:3)*fs
          receiver(:,3) = powerblock%node(ir-1,jr-1, kr )%c(1:3)*fs
          receiver(:,4) = powerblock%node(ir-1, jr , kr )%c(1:3)*fs
          receiver(:,5) = powerblock%node( ir ,jr-1,kr-1)%c(1:3)*fs
          receiver(:,6) = powerblock%node( ir , jr ,kr-1)%c(1:3)*fs
          receiver(:,7) = powerblock%node( ir ,jr-1, kr )%c(1:3)*fs
          receiver(:,8) = powerblock%node( ir , jr , kr )%c(1:3)*fs
          donor(:,1)    = blocks(b)%node(id-1,jd-1,kd-1)%c(1:3)*fs
          donor(:,2)    = blocks(b)%node(id-1, jd ,kd-1)%c(1:3)*fs
          donor(:,3)    = blocks(b)%node(id-1,jd-1, kd )%c(1:3)*fs
          donor(:,4)    = blocks(b)%node(id-1, jd , kd) %c(1:3)*fs
          donor(:,5)    = blocks(b)%node( id ,jd-1,kd-1)%c(1:3)*fs
          donor(:,6)    = blocks(b)%node( id , jd ,kd-1)%c(1:3)*fs
          donor(:,7)    = blocks(b)%node( id ,jd-1, kd )%c(1:3)*fs
          donor(:,8)    = blocks(b)%node( id , jd , kd )%c(1:3)*fs

          call HexahedronIntesectingPoints( receiver, donor, hull_points, nodeinside(:,ir,jr,kr) )

          ! If hull_points are filled, write down the intersections info in dummy file
          if (allocated(hull_points) .and. size(hull_points)>0) then
            nint = nint+1
            write(unitfile1,'(8I4)') 1,ir,jr,kr,b,id,jd,kd
            write(unitfile1,*) nodeinside(:,ir,jr,kr)
            fmt = '('//trim(str(.true.,size(hull_points)))//'E20.10)'
            write(unitfile2,fmt) (hull_points(p),p=1,size(hull_points))
          endif

        enddo; enddo
      
      enddo
    
    enddo; enddo

    close(unitfile1); close(unitfile2)
    
    call get_environment_variable('ATLASDIR',master_path)
    if (allocated(intersection)) deallocate(intersection)
    call IntersectionVolumes(trim(master_path)//'/scripts/convexHull.py',nint,intersection)

    ! Modificare il volume della griglia della neutronica
    do ir = 1, powerblock%dim(1)
      do kr = 1, powerblock%dim(3); do jr = 1, powerblock%dim(2)

        localID = [1,1,jr,kr]
        volume  = 0.d0
        do i = 1, nint
          if (all(intersection(i)%receiverID==localID)) then
            volume = volume + intersection(i)%inter_volume
          endif
        enddo
        ! if (ir==1) print*, jr,kr,powerblock%vol(ir,jr,kr),volume
        powerblock%vol(ir,jr,kr) = volume

      enddo; enddo
    enddo

  end subroutine rescale_volumes_power


  subroutine assign_power ( var, block, powerblock )
    use ATLAS_high_level
    use chimera
    use intersection_module
    use Lib_ORION_data
    use Lib_Tecplot
    use ATLAS_Mod_Grid

    implicit none
    type(ATLAS_block), intent(inout)  :: block
    real(8), dimension(1:block%dim(1),1:block%dim(2),1:block%dim(3)), intent(inout) :: var
    type(var_block), intent(inout)    :: powerblock
    !Local
    integer                :: unitfile1, unitfile2, kr, jr, ir, b, kd, jd, id, d, nint, p, i
    logical                :: next
    real(8), allocatable   :: hull_points(:)
    real(8)                :: receiver(3,8), donor(3,8)
    logical, allocatable   :: nodeinside(:,:,:,:)
    character(len=18)      :: fmt
    character(len=200)     :: master_path
    type(intersection_type), allocatable :: intersection(:)
    integer                :: localID(4)
    real(8)                :: power, vol_frac, tot_power


    open(newunit=unitfile1,file='couples.txt')
    open(newunit=unitfile2,file='points.txt')

    nint = 0
    ir = 1
    id = 1

    allocate(nodeinside(8, 1:block%dim(1), 1:block%dim(2), 1:block%dim(3)))

    ! Volume intersection
    do kr = 1, block%dim(3); do jr = 1, block%dim(2)

      ! Loop over the donor block cells
      do kd = 1, powerblock%dim(3); do jd = 1,powerblock%dim(2)

        ! Check with bounding-box algorithm (I level)
        next = .false.
        do d = 1, 3
          if( (powerblock%bbmin(id,jd,kd)%c(d)>block%bbmax(ir,jr,kr)%c(d)) .and. &
              (powerblock%bbmax(id,jd,kd)%c(d)>block%bbmax(ir,jr,kr)%c(d)) ) next = .true.
          if( (powerblock%bbmin(id,jd,kd)%c(d)<block%bbmin(ir,jr,kr)%c(d)) .and. &
              (powerblock%bbmax(id,jd,kd)%c(d)<block%bbmin(ir,jr,kr)%c(d)) ) next = .true.
        enddo
        if (next) cycle
        
        ! Check with serious algorithm (II level)
        if (allocated(hull_points)) deallocate(hull_points)
          receiver(:,1) = block%node(ir-1,jr-1,kr-1)%c(1:3)*fs
          receiver(:,2) = block%node(ir-1, jr ,kr-1)%c(1:3)*fs
          receiver(:,3) = block%node(ir-1,jr-1, kr )%c(1:3)*fs
          receiver(:,4) = block%node(ir-1, jr , kr )%c(1:3)*fs
          receiver(:,5) = block%node( ir ,jr-1,kr-1)%c(1:3)*fs
          receiver(:,6) = block%node( ir , jr ,kr-1)%c(1:3)*fs
          receiver(:,7) = block%node( ir ,jr-1, kr )%c(1:3)*fs
          receiver(:,8) = block%node( ir , jr , kr )%c(1:3)*fs
          donor(:,1)    = powerblock%node(id-1,jd-1,kd-1)%c(1:3)*fs
          donor(:,2)    = powerblock%node(id-1, jd ,kd-1)%c(1:3)*fs
          donor(:,3)    = powerblock%node(id-1,jd-1, kd )%c(1:3)*fs
          donor(:,4)    = powerblock%node(id-1, jd , kd) %c(1:3)*fs
          donor(:,5)    = powerblock%node( id ,jd-1,kd-1)%c(1:3)*fs
          donor(:,6)    = powerblock%node( id , jd ,kd-1)%c(1:3)*fs
          donor(:,7)    = powerblock%node( id ,jd-1, kd )%c(1:3)*fs
          donor(:,8)    = powerblock%node( id , jd , kd )%c(1:3)*fs

        call HexahedronIntesectingPoints( receiver, donor, hull_points, nodeinside(:,ir,jr,kr) )

        ! If hull_points are filled, write down the intersections info in dummy file
        if (allocated(hull_points) .and. size(hull_points)>0) then
          nint = nint+1
          write(unitfile1,'(8I4)') 1,ir,jr,kr,1,id,jd,kd
          write(unitfile1,*) nodeinside(:,ir,jr,kr)
          fmt = '('//trim(str(.true.,size(hull_points)))//'E20.10)'
          write(unitfile2,fmt) (hull_points(p),p=1,size(hull_points))
        endif

        enddo; enddo

      enddo; enddo

      close(unitfile1); close(unitfile2)
      
      call get_environment_variable('ATLASDIR',master_path)
      if (allocated(intersection)) deallocate(intersection)
      call IntersectionVolumes(trim(master_path)//'/scripts/convexHull.py',nint,intersection)

      tot_power = 0.d0
      do ir = 1, block%dim(1)
        do kr = 1, block%dim(3); do jr = 1, block%dim(2)

          localID = [1,1,jr,kr]
          power   = 0.d0

          do i = 1, nint
            if (all(intersection(i)%receiverID==localID)) then
              vol_frac = intersection(i)%inter_volume / powerblock%vol( ir,intersection(i)%donorID(3),intersection(i)%donorID(4) ) 
              power = power + vol_frac * powerblock%var( ir,intersection(i)%donorID(3),intersection(i)%donorID(4) )
            endif
          enddo

          if ( power == 0.d0 .or. isnan(power) ) then 
            var(ir,jr,kr) = 0.d0
            power = 0.d0
          else
            var(ir,jr,kr) = power / block%vol(ir,jr,kr)
          endif

          tot_power = tot_power + power

        enddo; enddo
      enddo

  end subroutine assign_power



  subroutine compute_volume_tec( b )
    use ATLAS_high_level

    implicit none
    type(var_block), intent(inout) :: b
    ! Local
    real(kind=8) :: vol
    integer      :: i, j, k, im, jm, km
    real(kind=8) :: vx(8), vy(8), vz(8)

    ! Peliminary operations
    Im = b % dim(1)
    Jm = b % dim(2)
    Km = b % dim(3)

    !$omp parallel private(i,j,k,vx,vy,vz,vol)
    !$omp do collapse(3)
    do k = 1, Km ; do j = 1, Jm ; do i = 1, Im

      vx(1) = b%node(i-1,j-1,k-1)%c(1)
      vy(1) = b%node(i-1,j-1,k-1)%c(2)
      vz(1) = b%node(i-1,j-1,k-1)%c(3)

      vx(2) = b%node(i  ,j-1,k-1)%c(1)
      vy(2) = b%node(i  ,j-1,k-1)%c(2)
      vz(2) = b%node(i  ,j-1,k-1)%c(3)

      vx(3) = b%node(i-1,j  ,k-1)%c(1)
      vy(3) = b%node(i-1,j  ,k-1)%c(2)
      vz(3) = b%node(i-1,j  ,k-1)%c(3)

      vx(4) = b%node(i  ,j  ,k-1)%c(1)
      vy(4) = b%node(i  ,j  ,k-1)%c(2)
      vz(4) = b%node(i  ,j  ,k-1)%c(3)

      vx(5) = b%node(i-1,j-1,k  )%c(1)
      vy(5) = b%node(i-1,j-1,k  )%c(2)
      vz(5) = b%node(i-1,j-1,k  )%c(3)

      vx(6) = b%node(i  ,j-1,k  )%c(1)
      vy(6) = b%node(i  ,j-1,k  )%c(2)
      vz(6) = b%node(i  ,j-1,k  )%c(3)

      vx(7) = b%node(i-1,j  ,k  )%c(1)
      vy(7) = b%node(i-1,j  ,k  )%c(2)
      vz(7) = b%node(i-1,j  ,k  )%c(3)

      vx(8) = b%node(i  ,j  ,k  )%c(1)
      vy(8) = b%node(i  ,j  ,k  )%c(2)
      vz(8) = b%node(i  ,j  ,k  )%c(3)


      vol = tvol(vx,vy,vz,1,2,3,5) + tvol(vx,vy,vz,2,4,3,8) &
          + tvol(vx,vy,vz,5,8,6,2) + tvol(vx,vy,vz,5,7,8,3) &
          + tvol(vx,vy,vz,5,8,2,3)

      if( vol <= 0d0 ) then
        error stop
      endif

      !% Assign computed volume to metrics object
      b%vol(i,j,k) = vol

    enddo; enddo; enddo
    !$omp end parallel

  contains

    pure function tvol(vx, vy, vz, i1, i2, i3, i4) result(volume)
      implicit none
      real(kind=8), intent(in)  :: vx(8), vy(8), vz(8)
      integer, intent(in)       :: i1, i2, i3, i4
      real(kind=8)              :: volume

      volume = abs(((vx(i2)-vx(i1))* &
        ((vy(i3)-vy(i1))*(vz(i4)-vz(i1))-(vy(i4)-vy(i1))*(vz(i3)-vz(i1)))+ &
                                (vy(i2)-vy(i1))* &
        ((vx(i4)-vx(i1))*(vz(i3)-vz(i1))-(vx(i3)-vx(i1))*(vz(i4)-vz(i1)))+ &
                                (vz(i2)-vz(i1))* &
        ((vx(i3)-vx(i1))*(vy(i4)-vy(i1))-(vx(i4)-vx(i1))*(vy(i3)-vy(i1)))) &
        /6.d0)

    end function tvol

  end subroutine compute_volume_tec


  subroutine compute_boundingbox_tec( b )
    use ATLAS_high_level

    implicit none
    type(var_block), intent(inout) :: b
    ! Local
    integer :: i, j, k, d
    real(8) :: min_x, max_x, min_y, max_y, min_z, max_z

    !> Compute the block bounding-box
    min_x = b%node(0,0,0)%c(1)
    max_x = b%node(0,0,0)%c(1)
    min_y = b%node(0,0,0)%c(2)
    max_y = b%node(0,0,0)%c(2)
    min_z = b%node(0,0,0)%c(3)
    max_z = b%node(0,0,0)%c(3)
    !$omp parallel private(i,j,k,d)
    !$omp do collapse(3)
    do k = 1, b%dim(3)
      do j = 1, b%dim(2)
        do i = 1, b%dim(1)
          do d = 1, 3
            b%bbmin(i,j,k)%c(d) = min(b%node(i-1,j-1,k-1)%c(d),b%node(i,j-1,k-1)%c(d), &
                                      b%node(i-1,j,k-1)%c(d),b%node(i-1,j-1,k)%c(d), &
                                      b%node(i,j,k)%c(d),b%node(i,j,k-1)%c(d), &
                                      b%node(i,j-1,k)%c(d),b%node(i-1,j,k)%c(d))

            b%bbmax(i,j,k)%c(d) = max(b%node(i-1,j-1,k-1)%c(d),b%node(i,j-1,k-1)%c(d), &
                                      b%node(i-1,j,k-1)%c(d),b%node(i-1,j-1,k)%c(d), &
                                      b%node(i,j,k)%c(d),b%node(i,j,k-1)%c(d), &
                                      b%node(i,j-1,k)%c(d),b%node(i-1,j,k)%c(d))
          enddo
        enddo
      enddo
    enddo

    !$omp do collapse(3) reduction(min:min_x,min_y,min_z) reduction(max:max_x,max_y,max_z)
    do k = 0, b%dim(3)
      do j = 0, b%dim(2)
        do i = 0, b%dim(1)
          if (b%node(i,j,k)%c(1).lt.min_x) min_x = b%node(i,j,k)%c(1)
          if (b%node(i,j,k)%c(1).gt.max_x) max_x = b%node(i,j,k)%c(1)
          if (b%node(i,j,k)%c(2).lt.min_y) min_y = b%node(i,j,k)%c(2)
          if (b%node(i,j,k)%c(2).gt.max_y) max_y = b%node(i,j,k)%c(2)
          if (b%node(i,j,k)%c(3).lt.min_z) min_z = b%node(i,j,k)%c(3)
          if (b%node(i,j,k)%c(3).gt.max_z) max_z = b%node(i,j,k)%c(3)
        enddo
      enddo
    enddo
    !$omp end parallel
    b%block_bounding_min(1) = min_x
    b%block_bounding_max(1) = max_x
    b%block_bounding_min(2) = min_y
    b%block_bounding_max(2) = max_y
    b%block_bounding_min(3) = min_z
    b%block_bounding_max(3) = max_z

  end subroutine compute_boundingbox_tec



















end module IC_lib_POWER
