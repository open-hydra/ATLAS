module ic_interpolation_cons_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use IR_Precision
  use ic_block_mod, only: IC_block, var_block
  use io_fields_mod, only: read_tec_file

  implicit none
  private
  public :: interpolate_conservative
  public :: set_conservative_receiver_blocks

  type(IC_block), pointer, save :: conservative_blocks(:) => null()
  type(var_block), allocatable, save :: conservative_donor(:)
  logical, save :: conservative_ready = .false.
  character(len=256), save :: conservative_file = ''


contains


  subroutine set_conservative_receiver_blocks(blocks)
    implicit none
    type(IC_block), target, intent(in) :: blocks(:)

    conservative_blocks => blocks
    conservative_ready = .false.

  end subroutine set_conservative_receiver_blocks


  subroutine interpolate_conservative(var, blk, sourcefile)
    implicit none
    type(IC_block), intent(inout) :: blk
    real(R8), dimension(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)), intent(inout) :: var
    character(len=*), intent(in) :: sourcefile

    if (.not.associated(conservative_blocks)) then
      write(*,*) '[ERROR] Conservative interpolation context not initialized'
      stop
    endif

    if (.not.allocated(conservative_donor) .or. trim(sourcefile)/=trim(conservative_file) .or. .not.conservative_ready) then
      if (allocated(conservative_donor)) deallocate(conservative_donor)
      call read_tec_file(trim(sourcefile), conservative_donor)
      call rescale_volumes(conservative_donor(1), conservative_blocks)
      conservative_file = sourcefile
      conservative_ready = .true.
    endif

    call assign(var, blk, conservative_donor(1))

  end subroutine interpolate_conservative

  
  subroutine rescale_volumes( donorblock, blocks )
    use intersection_mod
    use Lib_ORION_data
    use Lib_Tecplot
    use grid_mod

    implicit none
    type(var_block), intent(inout)    :: donorblock
    type(IC_block), intent(in)     :: blocks(:)

    ! Local
    type(intersection_type), allocatable :: intersection(:)
    integer                :: unitfile1, unitfile2, kr, jr, ir, b, kd, jd, id, d, nint, p, i
    logical                :: next
    real(R8), allocatable  :: hull_points(:)
    real(R8)               :: receiver(3,8), donor(3,8)
    logical, allocatable   :: nodeinside(:,:,:,:)
    character(len=18)      :: fmt
    character(len=256)     :: master_path
    integer                :: localID(4)
    real(R8)               :: volume


    open(newunit=unitfile1,file='couples.txt')
    open(newunit=unitfile2,file='points.txt')

    nint = 0
    ir = 1
    id = 1

    allocate(nodeinside(8,1:donorblock%dim(1),1:donorblock%dim(2),1:donorblock%dim(3)))
    
    ! Volume intersection
    do kr = 1, donorblock%dim(3); do jr = 1, donorblock%dim(2)

      ! Loop over the donor block cells
      do b = 12, 15


        do kd = 1, blocks(b)%dim(3); do jd = 1,blocks(b)%dim(2)

          ! Check with bounding-box algorithm (I level)
          next = .false.
          do d = 1, 3
            if( (blocks(b)%bbmin(id,jd,kd)%c(d)>donorblock%bbmax(ir,jr,kr)%c(d)) .and. &
              (blocks(b)%bbmax(id,jd,kd)%c(d)>donorblock%bbmax(ir,jr,kr)%c(d)) ) next = .true.
            if( (blocks(b)%bbmin(id,jd,kd)%c(d)<donorblock%bbmin(ir,jr,kr)%c(d)) .and. &
              (blocks(b)%bbmax(id,jd,kd)%c(d)<donorblock%bbmin(ir,jr,kr)%c(d)) ) next = .true.
          enddo
          if (next) cycle
        
          ! Check with serious algorithm (II level)
          if (allocated(hull_points)) deallocate(hull_points)
          receiver(:,1) = donorblock%node(ir-1,jr-1,kr-1)%c(1:3)*fs
          receiver(:,2) = donorblock%node(ir-1, jr ,kr-1)%c(1:3)*fs
          receiver(:,3) = donorblock%node(ir-1,jr-1, kr )%c(1:3)*fs
          receiver(:,4) = donorblock%node(ir-1, jr , kr )%c(1:3)*fs
          receiver(:,5) = donorblock%node( ir ,jr-1,kr-1)%c(1:3)*fs
          receiver(:,6) = donorblock%node( ir , jr ,kr-1)%c(1:3)*fs
          receiver(:,7) = donorblock%node( ir ,jr-1, kr )%c(1:3)*fs
          receiver(:,8) = donorblock%node( ir , jr , kr )%c(1:3)*fs
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

    ! Modify the donor block volumes with the intersection results
    do ir = 1, donorblock%dim(1)
      do kr = 1, donorblock%dim(3); do jr = 1, donorblock%dim(2)

        localID = [1,1,jr,kr]
        volume  = 0.d0
        do i = 1, nint
          if (all(intersection(i)%receiverID==localID)) then
            volume = volume + intersection(i)%inter_volume
          endif
        enddo
        donorblock%vol(ir,jr,kr) = volume

      enddo; enddo
    enddo

  end subroutine rescale_volumes


  subroutine assign ( var, blk, donorblock )
    use intersection_mod
    use Lib_ORION_data
    use Lib_Tecplot
    use grid_mod

    implicit none
    type(IC_block), intent(inout)  :: blk
    real(R8), dimension(1:blk%dim(1),1:blk%dim(2),1:blk%dim(3)), intent(inout) :: var
    type(var_block), intent(inout)    :: donorblock
    !Local
    type(intersection_type), allocatable :: intersection(:)
    integer                :: unitfile1, unitfile2, kr, jr, ir, kd, jd, id, d, nint, p, i
    logical                :: next
    real(R8), allocatable  :: hull_points(:)
    real(R8)               :: receiver(3,8), donor(3,8)
    logical, allocatable   :: nodeinside(:,:,:,:)
    character(len=18)      :: fmt
    character(len=200)     :: master_path
    integer                :: localID(4)
    real(R8)               :: var_integral, vol_frac, tot_var


    open(newunit=unitfile1,file='couples.txt')
    open(newunit=unitfile2,file='points.txt')

    nint = 0
    ir = 1
    id = 1

    allocate(nodeinside(8, 1:blk%dim(1), 1:blk%dim(2), 1:blk%dim(3)))

    ! Volume intersection
    do kr = 1, blk%dim(3); do jr = 1, blk%dim(2)

      ! Loop over the donor block cells
      do kd = 1, donorblock%dim(3); do jd = 1,donorblock%dim(2)

        ! Check with bounding-box algorithm (I level)
        next = .false.
        do d = 1, 3
            if( (donorblock%bbmin(id,jd,kd)%c(d)>blk%bbmax(ir,jr,kr)%c(d)) .and. &
              (donorblock%bbmax(id,jd,kd)%c(d)>blk%bbmax(ir,jr,kr)%c(d)) ) next = .true.
            if( (donorblock%bbmin(id,jd,kd)%c(d)<blk%bbmin(ir,jr,kr)%c(d)) .and. &
              (donorblock%bbmax(id,jd,kd)%c(d)<blk%bbmin(ir,jr,kr)%c(d)) ) next = .true.
        enddo
        if (next) cycle
        
        ! Check with serious algorithm (II level)
        if (allocated(hull_points)) deallocate(hull_points)
          receiver(:,1) = blk%node(ir-1,jr-1,kr-1)%c(1:3)*fs
          receiver(:,2) = blk%node(ir-1, jr ,kr-1)%c(1:3)*fs
          receiver(:,3) = blk%node(ir-1,jr-1, kr )%c(1:3)*fs
          receiver(:,4) = blk%node(ir-1, jr , kr )%c(1:3)*fs
          receiver(:,5) = blk%node( ir ,jr-1,kr-1)%c(1:3)*fs
          receiver(:,6) = blk%node( ir , jr ,kr-1)%c(1:3)*fs
          receiver(:,7) = blk%node( ir ,jr-1, kr )%c(1:3)*fs
          receiver(:,8) = blk%node( ir , jr , kr )%c(1:3)*fs
          donor(:,1)    = donorblock%node(id-1,jd-1,kd-1)%c(1:3)*fs
          donor(:,2)    = donorblock%node(id-1, jd ,kd-1)%c(1:3)*fs
          donor(:,3)    = donorblock%node(id-1,jd-1, kd )%c(1:3)*fs
          donor(:,4)    = donorblock%node(id-1, jd , kd) %c(1:3)*fs
          donor(:,5)    = donorblock%node( id ,jd-1,kd-1)%c(1:3)*fs
          donor(:,6)    = donorblock%node( id , jd ,kd-1)%c(1:3)*fs
          donor(:,7)    = donorblock%node( id ,jd-1, kd )%c(1:3)*fs
          donor(:,8)    = donorblock%node( id , jd , kd )%c(1:3)*fs

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

      tot_var = 0.d0
      do ir = 1, blk%dim(1)
        do kr = 1, blk%dim(3); do jr = 1, blk%dim(2)

          localID = [1,1,jr,kr]
          var_integral = 0.d0

          do i = 1, nint
            if (all(intersection(i)%receiverID==localID)) then
              vol_frac = intersection(i)%inter_volume / donorblock%vol( ir,intersection(i)%donorID(3),intersection(i)%donorID(4) )
              var_integral = var_integral + vol_frac * donorblock%var( ir,intersection(i)%donorID(3),intersection(i)%donorID(4) )
            endif
          enddo

          if ( var_integral == 0.d0 .or. isnan(var_integral) ) then
            var(ir,jr,kr) = 0.d0
            var_integral = 0.d0
          else
            var(ir,jr,kr) = var_integral / blk%vol(ir,jr,kr)
          endif

          tot_var = tot_var + var_integral

        enddo; enddo
      enddo

  end subroutine assign

end module ic_interpolation_cons_mod
