module chimera
  implicit none
  private
  public:: chimera_wrapper

  real(8), parameter, public :: fs=1000

contains

  subroutine chimera_wrapper(block)
    use intersection_module
    use ATLAS_high_level
    use TOM, only: gc
    implicit none
    type(ATLAS_block), intent(inout) :: block(:)
    character(len=200) :: master_path
    integer                 :: ir,jr,kr,br,ni,nint
    integer                 :: unitfile1, unitfile2
    type(intersection_type), allocatable :: intersection(:)
    logical, allocatable                 :: nodeinside(:,:,:,:)

    !% Look for intersections
    ni = 0; nint = 0
    open(newunit=unitfile1,file='couples.txt')
    open(newunit=unitfile2,file='points.txt')

    ! Loop over the receiver block cells
    do br = 1, size(block)

      allocate(block(br)%face(1)%cell(1-gc(1):0,                                 1-gc(2):block(br)%dim(2)+gc(2),            1-gc(3):block(br)%dim(3)+gc(3)))
      allocate(block(br)%face(2)%cell(block(br)%dim(1)+1:block(br)%dim(1)+gc(1), 1-gc(2):block(br)%dim(2)+gc(2),            1-gc(3):block(br)%dim(3)+gc(3)))
      allocate(block(br)%face(3)%cell(1-gc(1):block(br)%dim(1)+gc(1),            1-gc(2):0,                                 1-gc(3):block(br)%dim(3)+gc(3)))
      allocate(block(br)%face(4)%cell(1-gc(1):block(br)%dim(1)+gc(1),            block(br)%dim(2)+1:block(br)%dim(2)+gc(2), 1-gc(3):block(br)%dim(3)+gc(3)))
      allocate(block(br)%face(5)%cell(1-gc(1):block(br)%dim(1)+gc(1),            1-gc(2):block(br)%dim(2)+gc(2),            1-gc(3):0))
      allocate(block(br)%face(6)%cell(1-gc(1):block(br)%dim(1)+gc(1),            1-gc(2):block(br)%dim(2)+gc(2),            block(br)%dim(3)+1:block(br)%dim(3)+gc(3)))

      ! Face 1
      if (allocated(nodeinside)) deallocate(nodeinside)
      allocate(nodeinside(8,1-gc(1):0,1-gc(2):block(br)%dim(2)+gc(2),1-gc(3):block(br)%dim(3)+gc(3)))
      nodeinside = .false.
      do kr = 1-gc(3), block(br)%dim(3)+gc(3); do jr = 1-gc(2), block(br)%dim(2)+gc(2); do ir = 1-gc(1), 0
        call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[1-gc(1),1-gc(2),1-gc(3)])
        ni = ni+nint
      enddo; enddo; enddo

      ! Face 2
      if (allocated(nodeinside)) deallocate(nodeinside)
      allocate(nodeinside(8,block(br)%dim(1)+1:block(br)%dim(1)+gc(1),1-gc(2):block(br)%dim(2)+gc(2),1-gc(3):block(br)%dim(3)+gc(3)))
      nodeinside = .false.
      do kr = 1-gc(3), block(br)%dim(3)+gc(3); do jr = 1-gc(2), block(br)%dim(2)+gc(2); do ir = block(br)%dim(1)+1,block(br)%dim(1)+gc(1)
        call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[block(br)%dim(1)+1,1-gc(2),1-gc(3)])
        ni = ni+nint
      enddo; enddo; enddo

      ! Face 3
      if (allocated(nodeinside)) deallocate(nodeinside)
      allocate(nodeinside(8,1-gc(1):block(br)%dim(1)+gc(1),1-gc(2):0,1-gc(3):block(br)%dim(3)+gc(3)))
      nodeinside = .false.
      do kr = 1-gc(3), block(br)%dim(3)+gc(3); do jr = 1-gc(2), 0; do ir = 1-gc(1), block(br)%dim(1)+gc(1)
        call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[1-gc(1),1-gc(2),1-gc(3)])
        ni = ni+nint
      enddo; enddo; enddo

      ! Face 4
      if (allocated(nodeinside)) deallocate(nodeinside)
      allocate(nodeinside(8,1-gc(1):block(br)%dim(1)+gc(1),block(br)%dim(2)+1:block(br)%dim(2)+gc(2),1-gc(3):block(br)%dim(3)+gc(3)))
      nodeinside = .false.
      do kr = 1-gc(3), block(br)%dim(3)+gc(3); do jr = block(br)%dim(2)+1, block(br)%dim(2)+gc(2); do ir = 1-gc(1), block(br)%dim(1)+gc(1)
        call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[1-gc(1),block(br)%dim(2)+1,1-gc(3)])
        ni = ni+nint
      enddo; enddo; enddo

      ! Face 5
      if (allocated(nodeinside)) deallocate(nodeinside)
      allocate(nodeinside(8,1-gc(1):block(br)%dim(1)+gc(1),1-gc(2):block(br)%dim(2)+gc(2),1-gc(3):0))
      nodeinside = .false.
      do kr = 1-gc(3), 0; do jr = 1-gc(2), block(br)%dim(2)+gc(2); do ir = 1-gc(1), block(br)%dim(1)+gc(1)
        call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[1-gc(1),1-gc(2),1-gc(3)])
        ni = ni+nint
      enddo; enddo; enddo

      !Face 6
      if (allocated(nodeinside)) deallocate(nodeinside)
      allocate(nodeinside(8,1-gc(1):block(br)%dim(1)+gc(1),1-gc(2):block(br)%dim(2)+gc(2),block(br)%dim(3)+1:block(br)%dim(3)+gc(3)))
      nodeinside = .false.
      do kr = block(br)%dim(3)+1,block(br)%dim(3)+gc(3); do jr = 1-gc(2), block(br)%dim(2)+gc(2); do ir = 1-gc(1), block(br)%dim(1)+gc(1)
        call LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,[1-gc(1),1-gc(2),block(br)%dim(3)+1])
        ni = ni+nint
      enddo; enddo; enddo
      
    enddo

    close(unitfile1); close(unitfile2)

    call get_environment_variable('ATLASDIR',master_path)
    call IntersectionVolumes(trim(master_path)//'/src/ICB-BCB/lib/convexHull.py',ni,intersection)

    !% Check volume division for receivers
    do br = 1, size(block)
      ! Face 1
      do kr = 1, block(br)%dim(3); do jr = 1, block(br)%dim(2); do ir = 1-gc(1), 0
        call VolumeFractions(block,br,1,ir,jr,kr,ni,intersection)
      enddo; enddo; enddo
      ! Face 2
      do kr = 1, block(br)%dim(3); do jr = 1, block(br)%dim(2); do ir = block(br)%dim(1)+1,block(br)%dim(1)+gc(1)
        call VolumeFractions(block,br,2,ir,jr,kr,ni,intersection)
      enddo; enddo; enddo
      ! Face 3
      do kr = 1, block(br)%dim(3); do jr = 1-gc(2), 0; do ir = 1, block(br)%dim(1)
        call VolumeFractions(block,br,3,ir,jr,kr,ni,intersection)
      enddo; enddo; enddo
      ! Face 4
      do kr = 1, block(br)%dim(3); do jr = block(br)%dim(2)+1, block(br)%dim(2)+gc(2); do ir = 1, block(br)%dim(1)
        call VolumeFractions(block,br,4,ir,jr,kr,ni,intersection)
      enddo; enddo; enddo
      ! Face 5
      do kr = 1-gc(3), 0; do jr = 1, block(br)%dim(2); do ir = 1, block(br)%dim(1)
        call VolumeFractions(block,br,5,ir,jr,kr,ni,intersection)
      enddo; enddo; enddo
      ! Face 6
      do kr = block(br)%dim(3)+1,block(br)%dim(3)+gc(3); do jr = 1, block(br)%dim(2); do ir = 1, block(br)%dim(1)
        call VolumeFractions(block,br,6,ir,jr,kr,ni,intersection)
      enddo; enddo; enddo
    enddo

  end subroutine chimera_wrapper

  subroutine LoopOverDonors(block,unitfile1,unitfile2,br,ir,jr,kr,nodeinside,nint,startingIndexes)
    use atlas_high_level, only: atlas_block
    use intersection_module
    use ir_precision
    implicit none
    type(atlas_block), intent(in) :: block(:)
    integer, intent(in)    :: unitfile1, unitfile2
    integer, intent(in)    :: br,ir,jr,kr
    integer, intent(in)    :: startingIndexes(3)
    logical, intent(inout) :: nodeinside(:,startingIndexes(1):,startingIndexes(2):,startingIndexes(3):)
    integer, intent(out)   :: nint

    integer                :: bd,id,jd,kd,p,d,ff
    logical                :: next
    real(8)                :: receiver(3,8), donor(3,8), toll
    real(8), allocatable   :: hull_points(:)
    character(len=18)       :: fmt
       
    

    ! Check if center-face inside any donor BLOCK bounding-box (I level)
    next = .false.
    toll = 1e-10
    ff = 0
    do bd = 1, size(block)
      if (bd==br) cycle

      ! Face 1 
      if (ir.le.0) then
        ff = 0
        do d = 1, 3
          if ( (block(br)%face(1)%center(jr,kr)%c(d) > block(bd)%block_bounding_min(d)-toll) .and. &
               (block(br)%face(1)%center(jr,kr)%c(d) < block(bd)%block_bounding_max(d)+toll) ) ff = ff + 1
        enddo

        if (ff==3) next = .true.

      endif

      ! Face 2
      if (ir.ge.block(br)%dim(1)+1) then
        ff = 0
        do d = 1, 3
          if ( (block(br)%face(2)%center(jr,kr)%c(d) > block(bd)%block_bounding_min(d)-toll) .and. &
               (block(br)%face(2)%center(jr,kr)%c(d) < block(bd)%block_bounding_max(d)+toll) ) ff = ff + 1
        enddo 

        if (ff==3) next = .true.

      endif

      ! Face 3
      if (jr.le.0) then   
        ff = 0
        do d = 1, 3
          if ( (block(br)%face(3)%center(ir,kr)%c(d) > block(bd)%block_bounding_min(d)-toll) .and. &
               (block(br)%face(3)%center(ir,kr)%c(d) < block(bd)%block_bounding_max(d)+toll) ) ff = ff + 1
        enddo 

        if (ff==3) next = .true.

      endif

      ! Face 4
      if (jr.ge.block(br)%dim(2)+1) then        
        ff = 0
        do d = 1, 3
          if ( (block(br)%face(4)%center(ir,kr)%c(d) > block(bd)%block_bounding_min(d)-toll) .and. &
               (block(br)%face(4)%center(ir,kr)%c(d) < block(bd)%block_bounding_max(d)+toll) ) ff = ff + 1
        enddo 

        if (ff==3) next = .true.

      endif

      ! Face 5
      if (kr.le.0) then   
        ff = 0
        do d = 1, 3
          if ( (block(br)%face(5)%center(ir,jr)%c(d) > block(bd)%block_bounding_min(d)-toll) .and. &
               (block(br)%face(5)%center(ir,jr)%c(d) < block(bd)%block_bounding_max(d)+toll) ) ff = ff + 1
        enddo 

        if (ff==3) next = .true.

      endif

      ! Face 6
      if (kr.ge.block(br)%dim(3)+1) then        
        ff = 0
        do d = 1, 3
          if ( (block(br)%face(6)%center(ir,jr)%c(d) > block(bd)%block_bounding_min(d)-toll) .and. &
               (block(br)%face(6)%center(ir,jr)%c(d) < block(bd)%block_bounding_max(d)+toll) ) ff = ff + 1
        enddo 

        if (ff==3) next = .true.

      endif

      if (next) then 
        !print*, 'Passed I Level'
        !print*, br,ir,jr,kr,bd
        goto 1234
      endif

    enddo    

    ! If the point in not in any block bounding box --> It is not a connection.
    if (.not.next) then
      nint = 0    
      return
    endif

1234    continue

    ! Check if center-face inside any donor BLOCK cell (II level)
    next = .false.
    do bd = 1, size(block)
      if (bd==br) cycle

      do kd = 1, block(bd)%dim(3); do jd = 1, block(bd)%dim(2); do id = 1, block(bd)%dim(1)
        donor(:,1)    = block(bd)%node(id-1,jd-1,kd-1)%c(1:3)*fs
        donor(:,2)    = block(bd)%node(id-1, jd ,kd-1)%c(1:3)*fs
        donor(:,3)    = block(bd)%node(id-1,jd-1, kd )%c(1:3)*fs
        donor(:,4)    = block(bd)%node(id-1, jd , kd) %c(1:3)*fs
        donor(:,5)    = block(bd)%node( id ,jd-1,kd-1)%c(1:3)*fs
        donor(:,6)    = block(bd)%node( id , jd ,kd-1)%c(1:3)*fs
        donor(:,7)    = block(bd)%node( id ,jd-1, kd )%c(1:3)*fs
        donor(:,8)    = block(bd)%node( id , jd , kd )%c(1:3)*fs
        
        ! Face 1 
        if (ir.le.0) then
          call pointInsideHexahedron(block(br)%face(1)%center(jr,kr)%c(1:3)*fs, donor, next)
        endif
        ! Face 2
        if (ir.ge.block(br)%dim(1)+1) then
          call pointInsideHexahedron(block(br)%face(2)%center(jr,kr)%c(1:3)*fs, donor, next)
        endif
        ! Face 3
        if (jr.le.0) then
          call pointInsideHexahedron(block(br)%face(3)%center(ir,kr)%c(1:3)*fs, donor, next)
        endif
        ! Face 4
        if (jr.ge.block(br)%dim(2)+1) then
          call pointInsideHexahedron(block(br)%face(4)%center(ir,kr)%c(1:3)*fs, donor, next)
        endif
        ! Face 5
        if (kr.le.0) then
          call pointInsideHexahedron(block(br)%face(5)%center(ir,jr)%c(1:3)*fs, donor, next)
        endif
        ! Face 6
        if (kr.ge.block(br)%dim(3)+1) then
          call pointInsideHexahedron(block(br)%face(6)%center(ir,jr)%c(1:3)*fs, donor, next)
        endif 
        
        if ( next ) then
          !print*, 'Passed II Level'
          !print*, br,ir,jr,kr,bd
          goto 2345
        endif
      
      enddo; enddo; enddo
    enddo
    
    ! If the point in not in any cell of any block --> It is not a connection.
    if (.not.next) then
      nint = 0    
      return
    endif

2345    continue

    ! Loop over the donor block cells
    nint = 0   
    do bd = 1, size(block)
      if (bd==br) cycle

        do kd = 1, block(bd)%dim(3); do jd = 1, block(bd)%dim(2); do id = 1, block(bd)%dim(1)
               
          ! Check with bounding-box algorithm (III level)
          next = .false.
          do d = 1, 3
            if( (block(bd)%bbmin(id,jd,kd)%c(d)>block(br)%bbmax(ir,jr,kr)%c(d)) .and. &
                (block(bd)%bbmax(id,jd,kd)%c(d)>block(br)%bbmax(ir,jr,kr)%c(d)) ) next = .true.
            if( (block(bd)%bbmin(id,jd,kd)%c(d)<block(br)%bbmin(ir,jr,kr)%c(d)) .and. &
                (block(bd)%bbmax(id,jd,kd)%c(d)<block(br)%bbmin(ir,jr,kr)%c(d)) ) next = .true.
          enddo
          if (next) cycle

          ! Check with serious algorithm (IV level)
          if (allocated(hull_points)) deallocate(hull_points)
          receiver(:,1) = block(br)%node(ir-1,jr-1,kr-1)%c(1:3)*fs
          receiver(:,2) = block(br)%node(ir-1, jr ,kr-1)%c(1:3)*fs
          receiver(:,3) = block(br)%node(ir-1,jr-1, kr )%c(1:3)*fs
          receiver(:,4) = block(br)%node(ir-1, jr , kr )%c(1:3)*fs
          receiver(:,5) = block(br)%node( ir ,jr-1,kr-1)%c(1:3)*fs
          receiver(:,6) = block(br)%node( ir , jr ,kr-1)%c(1:3)*fs
          receiver(:,7) = block(br)%node( ir ,jr-1, kr )%c(1:3)*fs
          receiver(:,8) = block(br)%node( ir , jr , kr )%c(1:3)*fs
          donor(:,1)    = block(bd)%node(id-1,jd-1,kd-1)%c(1:3)*fs
          donor(:,2)    = block(bd)%node(id-1, jd ,kd-1)%c(1:3)*fs
          donor(:,3)    = block(bd)%node(id-1,jd-1, kd )%c(1:3)*fs
          donor(:,4)    = block(bd)%node(id-1, jd , kd) %c(1:3)*fs
          donor(:,5)    = block(bd)%node( id ,jd-1,kd-1)%c(1:3)*fs
          donor(:,6)    = block(bd)%node( id , jd ,kd-1)%c(1:3)*fs
          donor(:,7)    = block(bd)%node( id ,jd-1, kd )%c(1:3)*fs
          donor(:,8)    = block(bd)%node( id , jd , kd )%c(1:3)*fs

          call HexahedronIntesectingPoints( receiver, donor, hull_points, nodeinside(:,ir,jr,kr) )
          
          ! If hull_points are filled, write down the intersections info in dummy file
          if (allocated(hull_points) .and. size(hull_points)>0) then
            nint = nint+1
            write(unitfile1,'(8I4)') br,ir,jr,kr,bd,id,jd,kd
            write(unitfile1,*) nodeinside(:,ir,jr,kr)
            fmt = '('//trim(str(.true.,size(hull_points)))//'E20.10)'
            write(unitfile2,fmt) (hull_points(p),p=1,size(hull_points))
          endif

        enddo; enddo; enddo
    enddo

  end subroutine LoopOverDonors


  subroutine VolumeFractions(block,br,fr,ir,jr,kr,ni,intersection)
    use atlas_high_level, only: atlas_block
    use intersection_module
    use tom, only: ijk2mn
    implicit none
    type(atlas_block), intent(inout)       :: block(:)
    integer, intent(in)                    :: ir,jr,kr,fr,br,ni
    type(intersection_type), intent(inout) :: intersection(:)
    
    integer                 :: localID(4)
    real(8)                 :: volume
    integer                 :: k,i,m,n,t,t_init,t_end
    integer                 :: ni_per_receiver
    logical                 :: nodeinside_local(8)

    localID = [br,ir,jr,kr]
    volume = 0.d0
    ni_per_receiver = 0
    t = 0
    do i = 1, ni
      if (all(intersection(i)%receiverID==localID)) then
        t = t + 1
        if ( t == 1) t_init = i
        volume = volume+intersection(i)%inter_volume
        if (intersection(i)%inter_volume>0.d0) ni_per_receiver = ni_per_receiver+1
        nodeinside_local = intersection(i)%nodeinside
      endif
    enddo
    t_end = t_init + t-1
    
    if (volume==0.d0) return
    
    do i = t_init,t_end
      intersection(i)%volume_fraction = intersection(i)%inter_volume/volume
    enddo
    
    allocate(block(br)%face(fr)%cell(ir,jr,kr)%chimerainfo(1:ni_per_receiver,1:5))
    call ijk2mn(ir,jr,kr,fr,m,n)
    block(br)%face(fr)%center(m,n)%bc%definition = 666

    k = 0
    do i = 1, ni
      if (all(intersection(i)%receiverID==localID)) then
        if (intersection(i)%inter_volume>0.d0) then
          k = k+1
          block(br)%face(fr)%cell(ir,jr,kr)%chimerainfo(k,1:4) = real(intersection(i)%donorID)
          block(br)%face(fr)%cell(ir,jr,kr)%chimerainfo(k,5) = intersection(i)%volume_fraction
        endif
      endif
    enddo

    if (abs((volume-block(br)%vol(ir,jr,kr))/block(br)%vol(ir,jr,kr))>1d-3) then
      if (all(nodeinside_local)) then
        write(*,*) 'Chimera volume division failed'
        write(*,*) ' - Receiver ID           = ', br,ir,jr,kr
        write(*,*) ' - Receiver total volume = ', volume
        write(*,*) ' - Receiver real volume  = ', block(br)%vol(ir,jr,kr)
        !stop
      else
        write(*,*) 'Volume division succesful (not checkable)'
        write(*,*) ' - Receiver ID           = ', br,ir,jr,kr
        write(*,*) ' - Receiver total volume = ', volume
        write(*,*) ' - Receiver real volume  = ', block(br)%vol(ir,jr,kr)
      endif
    else
      write(*,*) 'Volume division succesful'
      write(*,*) ' - Receiver ID           = ', br,ir,jr,kr
      write(*,*) ' - Receiver total volume = ', volume
      write(*,*) ' - Receiver real volume  = ', block(br)%vol(ir,jr,kr)
    endif

  end subroutine VolumeFractions


  subroutine IntersectionVolumes(python_path,ni,intersection)
    use intersection_module
    implicit none
    character(len=*), intent(in)                        :: python_path
    integer, intent(in)                                 :: ni
    type(intersection_type), allocatable, intent(inout) :: intersection(:)
    integer :: unitfile1, ios, i

    !% Allocate and store intersections info
    allocate(intersection(1:ni))
    open(newunit=unitfile1,file='couples.txt',iostat=ios)
    if ( ios /= 0 ) stop "Error opening couples.txt"
    do i = 1, ni
        read(unitfile1,*) intersection(i)%receiverID, intersection(i)%donorID
        read(unitfile1,*) intersection(i)%nodeinside
    enddo
    close(unitfile1)

    !% Compute the convex hull (intersection) volume with a python script and import the values
    call execute_command_line('python3 -B  '//trim(python_path))
    open(newunit=unitfile1,file='volumes.txt',iostat=ios)
    if ( ios /= 0 ) stop "Error opening volumes.txt"
    do i = 1, ni
        read(unitfile1,*,iostat=ios) intersection(i)%inter_volume
        intersection(i)%inter_volume = intersection(i)%inter_volume/(fs**3)
        if (ios/=0) stop "Error reading volumes.txt"
    enddo
    close(unitfile1)

  end subroutine IntersectionVolumes

end module chimera
