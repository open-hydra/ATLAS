module Interpolator
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  implicit none

  logical :: onemesh, onespecies
  character(len=20) :: law
  integer  :: nz_extrude
  real(R8) :: thetamax_extrude

contains

  subroutine intersol(newspecies,oldspeciesfile,meshfile,oldmeshfile,oldsolutionfile,oldid,id)
    use variables
    use IO, only: read_solfile, read_TECmesh, orion, read_species
    use ATLAS_high_level, only: ATLAS_block
    use tom, only: block_type
    use Lib_ORION_data
    use CEA_module
    implicit none
    type(obj_species), intent(in)                       :: newspecies
    character(len=llen), intent(inout)                  :: oldspeciesfile
    character(len=llen), intent(inout)                  :: meshfile, oldsolutionfile
    character(len=llen), intent(inout)                  :: oldmeshfile
    integer, intent(in), optional                       :: oldid, id
    type(obj_species)                                   :: oldspecies
    character(2)                                        :: sym_type
    type(ATLAS_block), dimension(:), allocatable        :: oldblock, block
    class(block_type), dimension(:), allocatable        :: dummyblock, eblock
    integer                                             :: nb_, cnt, s, sold, i, j, k, b, bb, trueb
    integer                                             :: ii, jj, kk, counter
    integer, dimension(3)                               :: mask
    integer                                             :: i2, j2, k2, i2d, j2d, k2d
    integer                                             :: im, jm, km, ip, jp, kp
    integer, dimension(3)                               :: ind, indold
    logical, dimension(:,:), allocatable                :: same_dimension
    integer                                             :: start, end

    if (.not.onespecies) call read_species(adjustl(trim(oldspeciesfile)),oldspecies%n,oldspecies%name)

    if (onemesh .and. onespecies) then
      write(*,*)" Nothing to interpolate!"
      stop
    endif
    if (onemesh) oldmeshfile = meshfile
    if (onespecies) oldspecies = newspecies

    ! Old files reading and data allocation
    if (.not.present(id)) write(*,*)' Reading mesh file: ', trim(oldmeshfile)
    call read_TECmesh(dummyblock,oldmeshfile)
    if (law=='extrude') then
      if (.not.present(id)) write(*,*)" Old mesh extrusion"
      call extrude360(1)
      if (.not.present(id)) write(*,*) 
    endif
    nb_ = size(dummyblock)
    allocate(ATLAS_block::oldblock(1:nb_))
    do b = 1, nb_
      ! if (law=='extrude') then
      !   call oldblock(b)%pass_geometry(eblock(b))
      ! else
      !   call oldblock(b)%pass_geometry(dummyblock(b))
      ! endif
      call oldblock(b)%allocate(nrans,oldspecies%n,oldblock(b)%dim(1),oldblock(b)%dim(2),oldblock(b)%dim(3))
    end do
    if (.not.present(id)) write(*,*)" Reading solution file: ", trim(oldsolutionfile)
    call read_solfile(oldsolutionfile,oldblock,oldspecies%n)
    if (law=='extrude') then
      if (.not.present(id)) write(*,*)" Old solution extrusion"
      call extrude360(2)
      if (.not.present(id)) write(*,*)
    endif

    if (present(id)) then
      start = id; end = id
    else
      if (.not.onemesh) then
        write(*,*)
        write(*,*)" Reading mesh file: ", trim(meshfile)
        call read_TECmesh(dummyblock,meshfile)
        nb_ = size(dummyblock)
      endif
      allocate(ATLAS_block::block(1:nb_))
      ! do b = 1, nb_
      !   call block(b)%pass_geometry(dummyblock(b))
      ! enddo
      block(:)%species = newspecies
      do b = 1, nb_
        call block(b)%allocate(nrans,newspecies%n,block(b)%dim(1),block(b)%dim(2),block(b)%dim(3))
      enddo
      start = 1; end = nb_
    endif

    if (.not.present(id)) then
    write(*,*) " Building new solution"
    write(*,*) " Old species number: ", oldspecies%n
    write(*,*) " New species number: ", newspecies%n
    endif

    ! Interpolazion Procedures depending on LAW
    select case(law)

      ! General Interpolation Methods
      case('index')
        write(*,*) 
        write(*,*) " General Interpolation"
        write(*,*)
        call index_interpolation()
      
      case('multiple')
        write(*,*) 
        write(*,*) " General Interpolation"
        write(*,*)
        call multiple_interpolation()

      case('minimum_distance')
        write(*,*) 
        write(*,*) " General Interpolation"
        write(*,*)
        call distance_interpolation()

      case('spherical_minimum_distance')
        write(*,*) 
        write(*,*) " General Interpolation"
        write(*,*)
        call spherical_distance_interpolation()
      
      case default
        call distance_interpolation()
      
      ! Specific Block Interpolation Method

      case('index_block')
        write(*,*) 
        write(*,*) " Specific Block Interpolation"
        write(*,*)
        call index_block_interpolation()

      case('minimum_distance_block')
        write(*,*) 
        write(*,*) " Specific Block Interpolation"
        write(*,*)
        Call distance_block_interpolation()   
      
      case('spherical_minimum_distance_block')
        write(*,*) 
        write(*,*) " Specific Block Interpolation"
        write(*,*)
        Call spherical_distance_block_interpolation()

      end select


      
      


      

  


    if (.not.present(id)) then
      write(*,*) " Interpolation Completed Successfully"
      write(*,*)
    endif

contains


!=======================================================================================!
!========================= EXTRUSION INTERPOLATION =====================================!
!=======================================================================================!

subroutine extrude360(fase)
  implicit none
  integer, intent(in) :: fase
  real, parameter :: pi=4.0*atan(1.0)
  real    ::theta(nz_extrude+1)
  
  if (.not.present(id)) then
  write(*,*)" Extrusion angle    = ", thetamax_extrude
  write(*,*)" Extrusion elements = ", nz_extrude
  endif
 
  if (fase==1) then

    do i = 1, nz_extrude+1
      theta(i) = (thetamax_extrude*pi/180)/nz_extrude*i
    enddo

    allocate(block_type::eblock(1:nb_))
    do b = 1, nb_
      eblock(b)%dim(1) = dummyblock(b)%dim(1)
      eblock(b)%dim(2) = dummyblock(b)%dim(2)
      eblock(b)%dim(3) = nz_extrude
      allocate(eblock(b)%center(1:eblock(b)%dim(1),1:eblock(b)%dim(2),1:eblock(b)%dim(3)))
      do i = 1, eblock(b)%dim(1)
        do j = 1, eblock(b)%dim(2)
          do k = 1, eblock(b)%dim(3)
            eblock(b)%center(i,j,k)%c(1) = dummyblock(b)%center(i,j,1)%c(1)
            eblock(b)%center(i,j,k)%c(2) = dummyblock(b)%center(i,j,1)%c(2)*cos(theta(k))
            eblock(b)%center(i,j,k)%c(3) = dummyblock(b)%center(i,j,1)%c(2)*sin(theta(k))
          enddo
        enddo
      enddo
      allocate(eblock(b)%node(0:eblock(b)%dim(1),0:eblock(b)%dim(2),0:eblock(b)%dim(3)))
      do i = 0, eblock(b)%dim(1)
        do j = 0, eblock(b)%dim(2)
          do k = 0, eblock(b)%dim(3)
            eblock(b)%node(i,j,k)%c(1) = dummyblock(b)%node(i,j,1)%c(1)
            eblock(b)%node(i,j,k)%c(2) = dummyblock(b)%node(i,j,1)%c(2)*cos(theta(k+1))
            eblock(b)%node(i,j,k)%c(3) = dummyblock(b)%node(i,j,1)%c(2)*sin(theta(k+1))
          enddo
        enddo
      enddo
    enddo

  else
  
    do i = 1, nz_extrude
      theta(i) = (thetamax_extrude*pi/180)/nz_extrude*i
    enddo

    do b = 1, nb_
      do k = 1, oldblock(b)%dim(3)
        oldblock(b)%density(:,:,:,k) = oldblock(b)%density(:,:,:,1)
        oldblock(b)%velocity(1,:,:,k) = oldblock(b)%velocity(1,:,:,1)
        oldblock(b)%velocity(2,:,:,k) = oldblock(b)%velocity(2,:,:,1)*cos(theta(k))
        oldblock(b)%velocity(3,:,:,k) = oldblock(b)%velocity(2,:,:,1)*sin(theta(k))
        oldblock(b)%pressure(:,:,k) = oldblock(b)%pressure(:,:,1)
        if (nrans>0) oldblock(b)%turbprop(:,:,:,k) = oldblock(b)%turbprop(:,:,:,1)
      enddo
    enddo

  endif

end subroutine extrude360



!=======================================================================================!
!=======================================================================================!
!=======================================================================================!
!========================= GENERAL INTERPOLATION METHODS ===============================!
!=======================================================================================!
!=======================================================================================!
!=======================================================================================!


!=======================================================================================!
!============================= INDEX INTERPOLATION =====================================!
!=======================================================================================!

subroutine index_interpolation()
  implicit none

  ! Check mesh have the same dimensions Nx, Ny and eventually Nz
  allocate(same_dimension(1:2,start:end))
  if (size(oldblock) == size(block)) then 
    do b = start, end
      if (oldblock(b)%dim(1) == block(b)%dim(1)) then
        same_dimension(1,b) = .true.
      endif
      if (oldblock(b)%dim(2) == block(b)%dim(2)) then
        same_dimension(2,b) = .true.
      endif
      if (oldblock(b)%dim(3) == block(b)%dim(3)) then
        sym_type = "3D"
      else
        if  (oldblock(b)%dim(3) == 1) then
          sym_type = "2D"
        else
          write(*,*) 
          write(*,*) " ERROR : 3D Meshes with different Nz"
          write(*,*) " Can't use law = 'index' in this case"
          write(*,*)
          stop    
        endif
      endif
    enddo
  else
    write(*,*) 
    write(*,*) " ERROR : Different number of blocks"
    write(*,*) " Interpolation FAILED"
    write(*,*)
    stop
  endif

  ! Case 2D-3D interpolation
  if (all(same_dimension).and.sym_type=="2D") then
    write(*,*) 
    write(*,*) " 2D-3D Index based interpolation algorithm"
    write(*,*)
    
    do b = start, end
      write(*,*) " Block : ", b
      do k = 1, block(b)%dim(3)
        do j = 1, block(b)%dim(2)
          do i = 1, block(b)%dim(1)
            
            ! Density
            do s = 1, newspecies%n
              block(b)%density(s,i,j,k) = 1e-20
              do sold = 1, oldspecies%n
                if (newspecies%name(s)==oldspecies%name(sold)) then
                  block(b)%density(s,i,j,k) = oldblock(b)%density(s,i,j,1)
                endif
              enddo
            enddo
            
            ! Velocity
            block(b)%velocity(1,i,j,k) = oldblock(b)%velocity(1,i,j,1)
            block(b)%velocity(2,i,j,k) = oldblock(b)%velocity(2,i,j,1)*&
            cos(atan2(block(b)%center(i,j,k)%c(3),block(b)%center(i,j,k)%c(2)))
            block(b)%velocity(3,i,j,k) = oldblock(b)%velocity(3,i,j,1)*&
            sin(atan2(block(b)%center(i,j,k)%c(3),block(b)%center(i,j,k)%c(2)))
            
            ! Pressure
            block(b)%pressure(i,j,k) = oldblock(b)%pressure(i,j,1)
            
            ! Turbulent properties
            block(b)%turbprop(:,i,j,k) = oldblock(b)%turbprop(:,i,j,1)
            
          enddo
        enddo
      enddo
    enddo

  ! Case 3D-3D interpolation
  elseif (all(same_dimension).and.sym_type=="3D") then
    write(*,*) 
    write(*,*) " 3D-3D Index based interpolation algorithm"
    write(*,*)

    do b = start, end
      write(*,*) " Block : ", b
      do k = 1, block(b)%dim(3)
        do j = 1, block(b)%dim(2)
          do i = 1, block(b)%dim(1)

            ! Density
            do s = 1, newspecies%n
              block(b)%density(s,i,j,k) = 1e-20
              do sold = 1, oldspecies%n
                if (newspecies%name(s)==oldspecies%name(sold)) then
                  block(b)%density(s,i,j,k) = oldblock(b)%density(s,i,j,k)
                endif
              enddo
            enddo
            
            ! Velocity
            block(b)%velocity(1,i,j,k) = oldblock(b)%velocity(1,i,j,k)
            block(b)%velocity(2,i,j,k) = oldblock(b)%velocity(2,i,j,k)                
            block(b)%velocity(3,i,j,k) = oldblock(b)%velocity(3,i,j,k)
            
            ! Pressure
            block(b)%pressure(i,j,k) = oldblock(b)%pressure(i,j,k)
            
            ! Turbulent properties
            block(b)%turbprop(:,i,j,k) = oldblock(b)%turbprop(:,i,j,1)

          enddo
        enddo
      enddo
    enddo     

  else
    write(*,*) 
    write(*,*) " ERROR : 2D and 3D Mesh do not have the same Nx and Ny elements"
    write(*,*) " Interpolation FAILED"
    write(*,*)
    stop
  endif

end subroutine index_interpolation


!=======================================================================================!
!============================= MULTIPLE INTERPOLATION ==================================!
!=======================================================================================!

subroutine multiple_interpolation()
  implicit none
  real(kind=R8)                      :: rapNx, rapNy, rapNz
  real(kind=R8), dimension(8)        :: coeffs, coeff_c, coeff_v
  real(kind=R8), dimension(8)        :: coeff_cf_i, coeff_cf_j, coeff_cf_k
  real(kind=R8), dimension(8)        :: coeff_cs_jk, coeff_cs_ik, coeff_cs_ij
  logical, dimension(:), allocatable :: xint_dimension
  real(kind=R8)                      :: a0, a1, a2, a3, a4
  integer, dimension(6)              :: id
  integer                            :: indi, indj, indk, rap

  ! Check mesh have dimensions Nx, Ny, Nz that are an INTEGER multiple of one another
  allocate(xint_dimension(start:end))
  if (size(oldblock) == size(block)) then 
    do b = start, end
      rapNx = float(block(b)%dim(1))/float(oldblock(b)%dim(1))
      rapNy = float(block(b)%dim(2))/float(oldblock(b)%dim(2))
      rapNz = float(block(b)%dim(3))/float(oldblock(b)%dim(3))    
      if (rapNx==rapNy.and.mod(max(block(b)%dim(1),oldblock(b)%dim(1)),min(block(b)%dim(1),oldblock(b)%dim(1)))==0) then
        if (rapNz==rapNx) then
          sym_type = "3D"
          xint_dimension(b) = .true.
          rap = nint(rapNx)
        elseif (block(b)%dim(3)==1.and.oldblock(b)%dim(3)==1) then
          sym_type = "2D"
          xint_dimension(b) = .true.
          rap = nint(rapNx)
        endif
      endif
    enddo 
  else
    write(*,*) 
    write(*,*) " ERROR: Different number of blocks"
    write(*,*) " Interpolation FAILED"
    write(*,*)
    stop          
  endif

  if (all(xint_dimension)) then
    write(*,*) 
    write(*,*) " New mesh / Old mesh Ratio = ", rapNx
    write(*,*)

    ! Reconstruction algorithm fo MESH RATIO = 0.5
    if (rapNx==0.5) then
      write(*,*)
      write(*,*) " Mesh ratio = 0.5 - Specific algorithm"
      write(*,*)

      ! Interpolation Coefficients
      if (sym_type=="3D") then
        write(*,*) " 3D"
        coeffs(1:4) = 1./8.
        coeffs(5:8) = 1./8.        
      elseif (sym_type=="2D") then
        write(*,*) " 2D"
        coeffs(1:4) = 1./4.
        coeffs(5:8) = 0.0
      end if

      do b = start, end      
        write(*,*) " Block : ", b
        do k = 1, block(b)%dim(3)         
          do j = 1, block(b)%dim(2)            
            do i = 1, block(b)%dim(1)

              i2 = 2*i
              j2 = 2*j
              k2 = 2*k
              i2d = i2-1
              j2d = j2-1
              k2d = k2-1

              if (sym_type=="2D") then
                k2  = 1
                k2d = 1
              endif

              ! Density
              do s = 1, newspecies%n
                block(b)%density(s,i,j,k) = 1e-20
                do sold = 1, oldspecies%n
                  if (newspecies%name(s)==oldspecies%name(sold)) then
                    block(b)%density(s,i,j,k)   =  coeffs(1)*oldblock(b)%density(s,i2d,j2d,k2d)   &
                                                +  coeffs(2)*oldblock(b)%density(s,i2, j2d,k2d)   &
                                                +  coeffs(3)*oldblock(b)%density(s,i2d,j2, k2d)   &
                                                +  coeffs(4)*oldblock(b)%density(s,i2, j2, k2d)   &
                                                +  coeffs(5)*oldblock(b)%density(s,i2d,j2d,k2)    &
                                                +  coeffs(6)*oldblock(b)%density(s,i2, j2d,k2)    &
                                                +  coeffs(7)*oldblock(b)%density(s,i2d,j2, k2)    &
                                                +  coeffs(8)*oldblock(b)%density(s,i2, j2, k2)    
                  endif
                enddo
              enddo

              ! Velocity
              do cnt = 1, 3
                block(b)%velocity(cnt,i,j,k)  =  coeffs(1)*oldblock(b)%velocity(cnt,i2d,j2d,k2d)   &
                                              +  coeffs(2)*oldblock(b)%velocity(cnt,i2, j2d,k2d)   &
                                              +  coeffs(3)*oldblock(b)%velocity(cnt,i2d,j2, k2d)   &
                                              +  coeffs(4)*oldblock(b)%velocity(cnt,i2, j2, k2d)   &
                                              +  coeffs(5)*oldblock(b)%velocity(cnt,i2d,j2d,k2)    &
                                              +  coeffs(6)*oldblock(b)%velocity(cnt,i2, j2d,k2)    &
                                              +  coeffs(7)*oldblock(b)%velocity(cnt,i2d,j2, k2)    &
                                              +  coeffs(8)*oldblock(b)%velocity(cnt,i2, j2, k2)    
              enddo

              ! Pressure
              block(b)%pressure(i,j,k)  =  coeffs(1)*oldblock(b)%pressure(i2d,j2d,k2d)   &
                                        +  coeffs(2)*oldblock(b)%pressure(i2, j2d,k2d)   &
                                        +  coeffs(3)*oldblock(b)%pressure(i2d,j2, k2d)   &
                                        +  coeffs(4)*oldblock(b)%pressure(i2, j2, k2d)   &
                                        +  coeffs(5)*oldblock(b)%pressure(i2d,j2d,k2)    &
                                        +  coeffs(6)*oldblock(b)%pressure(i2, j2d,k2)    &
                                        +  coeffs(7)*oldblock(b)%pressure(i2d,j2, k2)    &
                                        +  coeffs(8)*oldblock(b)%pressure(i2, j2, k2)    

              ! Turbulent properties
              block(b)%turbprop(:,i,j,k) =  coeffs(1)*oldblock(b)%turbprop(:,i2d,j2d,k2d)   &
                                          +  coeffs(2)*oldblock(b)%turbprop(:,i2, j2d,k2d)   &
                                          +  coeffs(3)*oldblock(b)%turbprop(:,i2d,j2, k2d)   &
                                          +  coeffs(4)*oldblock(b)%turbprop(:,i2, j2, k2d)   &
                                          +  coeffs(5)*oldblock(b)%turbprop(:,i2d,j2d,k2)    &
                                          +  coeffs(6)*oldblock(b)%turbprop(:,i2, j2d,k2)    &
                                          +  coeffs(7)*oldblock(b)%turbprop(:,i2d,j2, k2)    &
                                          +  coeffs(8)*oldblock(b)%turbprop(:,i2, j2, k2) 
            enddo
          enddo     
        enddo
      enddo


    ! Spcific algorithm for MESH RATIO = 2 (both 2D and 3D)
    elseif (rapNx==2.0) then
      write(*,*)
      write(*,*) " Mesh ratio = 2 - Specific algorithm"
      write(*,*)

      ! Interpolation Coefficients
      if (sym_type=="3D") then
        write(*,*) " 3D"
        a1 = 27./64.
        a2 = 9./64.
        a3 = 3./64.
        a4 = 1./64.
        coeffs(1:8) = (/a1,a2,a2,a2,a3,a3,a3,a4/)            

      elseif (sym_type=="2D") then
        write(*,*) " 2D"
        a1 = 9./16.
        a2 = 3./16.
        a3 = 1./16.
        a4 = 0./16.
        coeffs(1:8) = (/a1,a2,a2,a4,a3,a4,a4,a4/)
      end if

      do b = start, end
        write(*,*) " Block : ", b
        do k = 1, oldblock(b)%dim(3)
          do j = 1, oldblock(b)%dim(2)
            do i = 1, oldblock(b)%dim(1)

              i2 = rap*i
              j2 = rap*j
              k2 = rap*k
              i2d = i2-(rap-1)
              j2d = j2-(rap-1)
              k2d = k2-(rap-1)

              if (sym_type=="2D") then
                k2  = 1
                k2d = 1
              endif

              im = max(1,i-1)
              jm = max(1,j-1)
              km = max(1,k-1)

              ip = min(oldblock(b)%dim(1),i+1)
              jp = min(oldblock(b)%dim(2),j+1)
              kp = min(oldblock(b)%dim(3),k+1)

              id(1:6) = (/im,jm,km,ip,jp,kp/)

              counter = 1

              do kk = k2d, k2          
                do jj = j2d, j2            
                  do ii = i2d, i2

                    if (sym_type=="2D") then
                      if (counter==1) mask(1:3)=(/1,2,3/)
                      if (counter==2) mask(1:3)=(/4,2,3/)
                      if (counter==3) mask(1:3)=(/1,5,3/)
                      if (counter==4) mask(1:3)=(/4,5,3/)
                    endif

                    if(sym_type=="3D") then
                      if (counter==1) mask(1:3)=(/1,2,3/)
                      if (counter==2) mask(1:3)=(/4,2,3/)
                      if (counter==3) mask(1:3)=(/1,5,3/)
                      if (counter==4) mask(1:3)=(/4,5,3/)
                      if (counter==5) mask(1:3)=(/1,2,6/)
                      if (counter==6) mask(1:3)=(/4,2,6/)
                      if (counter==7) mask(1:3)=(/1,5,6/)
                      if (counter==8) mask(1:3)=(/4,5,6/)
                    endif

                    ! Density
                    do s = 1, newspecies%n
                      block(b)%density(s,ii,jj,kk) = 1e-20
                      do sold = 1, oldspecies%n
                        if (newspecies%name(s)==oldspecies%name(sold)) then
                          block(b)%density(s,ii,jj,kk) = coeffs(1)*oldblock(b)%density(s,i,j,k)     &
                                                      +  coeffs(2)*oldblock(b)%density(s,id(mask(1)),j,k)    &
                                                      +  coeffs(3)*oldblock(b)%density(s,i,id(mask(2)),k)    &
                                                      +  coeffs(4)*oldblock(b)%density(s,i,j,id(mask(3)))    &
                                                      +  coeffs(5)*oldblock(b)%density(s,id(mask(1)),id(mask(2)),k)   &
                                                      +  coeffs(6)*oldblock(b)%density(s,id(mask(1)),j,id(mask(3)))   &
                                                      +  coeffs(7)*oldblock(b)%density(s,i,id(mask(2)),id(mask(3)))   &
                                                      +  coeffs(8)*oldblock(b)%density(s,id(mask(1)),id(mask(2)),id(mask(3)))
                        endif
                      enddo
                    enddo

                    ! Velocity
                    do cnt = 1, 3
                      block(b)%velocity(cnt,ii,jj,kk) = coeffs(1)*oldblock(b)%velocity(cnt,i,j,k)     &
                                                      +  coeffs(2)*oldblock(b)%velocity(cnt,id(mask(1)),j,k)    &
                                                      +  coeffs(3)*oldblock(b)%velocity(cnt,i,id(mask(2)),k)    &
                                                      +  coeffs(4)*oldblock(b)%velocity(cnt,i,j,id(mask(3)))    &
                                                      +  coeffs(5)*oldblock(b)%velocity(cnt,id(mask(1)),id(mask(2)),k)   &
                                                      +  coeffs(6)*oldblock(b)%velocity(cnt,id(mask(1)),j,id(mask(3)))   &
                                                      +  coeffs(7)*oldblock(b)%velocity(cnt,i,id(mask(2)),id(mask(3)))   &
                                                      +  coeffs(8)*oldblock(b)%velocity(cnt,id(mask(1)),id(mask(2)),id(mask(3)))
                    enddo

                    ! Pressure
                    block(b)%pressure(ii,jj,kk) = coeffs(1)*oldblock(b)%pressure(i,j,k)     &
                                                +  coeffs(2)*oldblock(b)%pressure(id(mask(1)),j,k)    &
                                                +  coeffs(3)*oldblock(b)%pressure(i,id(mask(2)),k)    &
                                                +  coeffs(4)*oldblock(b)%pressure(i,j,id(mask(3)))    &
                                                +  coeffs(5)*oldblock(b)%pressure(id(mask(1)),id(mask(2)),k)   &
                                                +  coeffs(6)*oldblock(b)%pressure(id(mask(1)),j,id(mask(3)))   &
                                                +  coeffs(7)*oldblock(b)%pressure(i,id(mask(2)),id(mask(3)))   &
                                                +  coeffs(8)*oldblock(b)%pressure(id(mask(1)),id(mask(2)),id(mask(3)))

                    ! Turbulent properties
                    block(b)%turbprop(:,ii,jj,kk) = coeffs(1)*oldblock(b)%turbprop(:,i,j,k)     &
                                                  +  coeffs(2)*oldblock(b)%turbprop(:,id(mask(1)),j,k)    &
                                                  +  coeffs(3)*oldblock(b)%turbprop(:,i,id(mask(2)),k)    &
                                                  +  coeffs(4)*oldblock(b)%turbprop(:,i,j,id(mask(3)))    &
                                                  +  coeffs(5)*oldblock(b)%turbprop(:,id(mask(1)),id(mask(2)),k)   &
                                                  +  coeffs(6)*oldblock(b)%turbprop(:,id(mask(1)),j,id(mask(3)))   &
                                                  +  coeffs(7)*oldblock(b)%turbprop(:,i,id(mask(2)),id(mask(3)))   &
                                                  +  coeffs(8)*oldblock(b)%turbprop(:,id(mask(1)),id(mask(2)),id(mask(3)))

                    counter = counter + 1

                  enddo
                enddo
              enddo

            enddo
          enddo     
        enddo
      enddo


    ! Spcific algorithm for MESH RATIO = 3 (both 2D and 3D)
    elseif (rapNx==3.0) then
      write(*,*)
      write(*,*) " Mesh ratio = 3 - Specific Algorithm"
      write(*,*) " 2D works! - GOTTA FIND OUT IF 3D WORKS as well"
      write(*,*)

      ! Interpolation Coefficients
      if (sym_type=="3D") then
        write(*,*) " 3D"
        a0 = 0.
        a1 = 1.
        coeff_c(1:8) = (/a1,a0,a0,a0,a0,a0,a0,a0/)

        a1 = 2./3.
        a2 = 1./3.
        coeff_cf_i(1:8) = (/a1,a2,a0,a0,a0,a0,a0,a0/)
        coeff_cf_j(1:8) = (/a1,a0,a2,a0,a0,a0,a0,a0/) 
        coeff_cf_k(1:8) = (/a1,a0,a0,a2,a0,a0,a0,a0/)

        a1 = 9./16.
        a2 = 3./16.
        a3 = 1./16.
        coeff_cs_jk(1:8) = (/a1,a0,a2,a2,a0,a0,a2,a0/)
        coeff_cs_ik(1:8) = (/a1,a2,a0,a2,a0,a2,a0,a0/)
        coeff_cs_ij(1:8) = (/a1,a2,a2,a0,a2,a0,a0,a0/)

        a1 = 27./64.
        a2 = 9./64.
        a3 = 3./64.
        a4 = 1./64.
        coeff_v(1:8) = (/a1,a2,a2,a2,a3,a3,a3,a4/) 
      
      elseif (sym_type=="2D") then
        write(*,*) " 2D"           
        a0 = 0.
        a1 = 1.
        coeff_c(1:8) = (/a1,a0,a0,a0,a0,a0,a0,a0/)
        
        a1 = 2./3.
        a2 = 1./3.
        coeff_cf_i(1:8) = (/a1,a2,a0,a0,a0,a0,a0,a0/)           
        coeff_cf_j(1:8) = (/a1,a0,a2,a0,a0,a0,a0,a0/)
        
        a1 = 9./16.
        a2 = 3./16.
        a3 = 1./16.
        coeff_v(1:8) = (/a1,a2,a2,a0,a3,a0,a0,a0/)
      end if


      do b = start, end
        write(*,*) " Block : ", b
        do k = 1, oldblock(b)%dim(3)         
          do j = 1, oldblock(b)%dim(2)            
            do i = 1, oldblock(b)%dim(1)
                
              i2 = rap*i
              j2 = rap*j
              k2 = rap*k
              i2d = i2-(rap-1)
              j2d = j2-(rap-1)
              k2d = k2-(rap-1)
              
              if (sym_type=="2D") then
                k2  = 1
                k2d = 1
              endif
              
              im = max(1,i-1)
              jm = max(1,j-1)
              km = max(1,k-1)

              ip = min(oldblock(b)%dim(1),i+1)
              jp = min(oldblock(b)%dim(2),j+1)
              kp = min(oldblock(b)%dim(3),k+1)

              id(1:6) = (/im,jm,km,ip,jp,kp/)
              
              counter = 1
              
              do kk = k2d, k2          
                do jj = j2d, j2            
                  do ii = i2d, i2
                    
                    if (sym_type=="2D") then
                      ! k is always a filler for 2D (un-used)
                      if (counter==1) then
                        mask(1:3)=(/1,2,3/)
                        coeffs = coeff_v
                      endif
                      if (counter==2) then
                        mask(1:3)=(/1,2,3/) ! Riempitivo i
                        coeffs = coeff_cf_j
                      endif                        
                      if (counter==3) then
                        mask(1:3)=(/4,2,3/)
                        coeffs = coeff_v
                      endif
                      if (counter==4) then
                        mask(1:3)=(/1,2,3/) ! Riempitivo j
                        coeffs = coeff_cf_i
                      endif
                      if (counter==5) then
                        mask(1:3)=(/1,2,3/) ! Riempitivo i,j
                        coeffs = coeff_c
                      endif
                      if (counter==6) then
                        mask(1:3)=(/4,2,3/) ! Riempitivo j
                        coeffs = coeff_cf_i
                      endif
                      if (counter==7) then
                        mask(1:3)=(/1,5,3/)
                        coeffs = coeff_v
                      endif
                      if (counter==8) then
                        mask(1:3)=(/1,5,3/) ! Riempitivo i
                        coeffs = coeff_cf_j
                      endif
                      if (counter==9) then
                        mask(1:3)=(/4,5,3/)
                        coeffs = coeff_v
                      endif                       
                    endif

                    if(sym_type=="3D") then
                      ! k = 1
                      if (counter==1) then
                        mask(1:3)=(/1,2,3/)
                        coeffs = coeff_v
                      endif
                      if (counter==2) then
                        mask(1:3)=(/1,2,3/) ! Riempitivo i
                        coeffs = coeff_cs_jk
                      endif                        
                      if (counter==3) then
                        mask(1:3)=(/4,2,3/)
                        coeffs = coeff_v
                      endif
                      if (counter==4) then
                        mask(1:3)=(/1,2,3/) ! Riempitivo j
                        coeffs = coeff_cs_ik
                      endif
                      if (counter==5) then
                        mask(1:3)=(/1,2,3/) ! Riempitivo i,j
                        coeffs = coeff_cf_k
                      endif
                      if (counter==6) then
                        mask(1:3)=(/4,2,3/) ! Riempitivo j
                        coeffs = coeff_cs_ik
                      endif
                      if (counter==7) then
                        mask(1:3)=(/1,5,3/)
                        coeffs = coeff_v
                      endif
                      if (counter==8) then
                        mask(1:3)=(/1,5,3/) ! Riempitivo i
                        coeffs = coeff_cs_jk
                      endif
                      if (counter==9) then
                        mask(1:3)=(/4,5,3/)
                        coeffs = coeff_v
                      endif   
                      
                      ! k = 2
                      if (counter==10) then
                        mask(1:3)=(/1,2,3/) ! Riempitivo k
                        coeffs = coeff_cs_ij
                      endif
                      if (counter==11) then
                        mask(1:3)=(/1,2,3/) ! Riempitivo i,k
                        coeffs = coeff_cf_j
                      endif                        
                      if (counter==12) then
                        mask(1:3)=(/4,2,3/) ! Riempitivo k
                        coeffs = coeff_cs_ij
                      endif
                      if (counter==13) then
                        mask(1:3)=(/1,2,3/) ! Riempitivo j,k
                        coeffs = coeff_cf_i
                      endif
                      if (counter==14) then
                        mask(1:3)=(/1,2,3/) ! Riempitivo i,j,k
                        coeffs = coeff_c
                      endif
                      if (counter==15) then
                        mask(1:3)=(/4,2,3/) ! Riempitivo j,k
                        coeffs = coeff_cf_i
                      endif
                      if (counter==16) then
                        mask(1:3)=(/1,5,3/) ! Riempitivo k
                        coeffs = coeff_cs_ij
                      endif
                      if (counter==17) then
                        mask(1:3)=(/1,5,3/) ! Riempitivo i,k
                        coeffs = coeff_cf_j
                      endif
                      if (counter==18) then
                        mask(1:3)=(/4,5,3/) ! Riempitivo k
                        coeffs = coeff_cs_ij
                      endif
                      
                      ! k = 3
                      if (counter==19) then
                        mask(1:3)=(/1,2,6/)
                        coeffs = coeff_v
                      endif
                      if (counter==20) then
                        mask(1:3)=(/1,2,6/) ! Riempitivo i
                        coeffs = coeff_cs_jk
                      endif                        
                      if (counter==21) then
                        mask(1:3)=(/4,2,6/)
                        coeffs = coeff_v
                      endif
                      if (counter==22) then
                        mask(1:3)=(/1,2,6/) ! Riempitivo j
                        coeffs = coeff_cs_ik
                      endif
                      if (counter==23) then
                        mask(1:3)=(/1,2,6/) ! Riempitivo i,j
                        coeffs = coeff_cf_k
                      endif
                      if (counter==24) then
                        mask(1:3)=(/4,2,6/) ! Riempitivo j
                        coeffs = coeff_cs_ik
                      endif
                      if (counter==25) then
                        mask(1:3)=(/1,5,6/)
                        coeffs = coeff_v
                      endif
                      if (counter==26) then
                        mask(1:3)=(/1,5,6/) ! Riempitivo i
                        coeffs = coeff_cs_jk
                      endif
                      if (counter==27) then
                        mask(1:3)=(/4,5,6/)
                        coeffs = coeff_v
                      endif   
                    endif
                    
                    ! Density
                    do s = 1, newspecies%n
                      block(b)%density(s,ii,jj,kk) = 1e-20
                      do sold = 1, oldspecies%n
                        if (newspecies%name(s)==oldspecies%name(sold)) then
                          block(b)%density(s,ii,jj,kk) = coeffs(1)*oldblock(b)%density(s,i,j,k)     &
                                                      +  coeffs(2)*oldblock(b)%density(s,id(mask(1)),j,k)    &
                                                      +  coeffs(3)*oldblock(b)%density(s,i,id(mask(2)),k)    &
                                                      +  coeffs(4)*oldblock(b)%density(s,i,j,id(mask(3)))    &
                                                      +  coeffs(5)*oldblock(b)%density(s,id(mask(1)),id(mask(2)),k)   &
                                                      +  coeffs(6)*oldblock(b)%density(s,id(mask(1)),j,id(mask(3)))   &
                                                      +  coeffs(7)*oldblock(b)%density(s,i,id(mask(2)),id(mask(3)))   &
                                                      +  coeffs(8)*oldblock(b)%density(s,id(mask(1)),id(mask(2)),id(mask(3)))
                        endif
                      enddo
                    end do

                    ! Velocity
                    do cnt = 1, 3
                      block(b)%velocity(cnt,ii,jj,kk) = coeffs(1)*oldblock(b)%velocity(cnt,i,j,k)     &
                                                      +  coeffs(2)*oldblock(b)%velocity(cnt,id(mask(1)),j,k)    &
                                                      +  coeffs(3)*oldblock(b)%velocity(cnt,i,id(mask(2)),k)    &
                                                      +  coeffs(4)*oldblock(b)%velocity(cnt,i,j,id(mask(3)))    &
                                                      +  coeffs(5)*oldblock(b)%velocity(cnt,id(mask(1)),id(mask(2)),k)   &
                                                      +  coeffs(6)*oldblock(b)%velocity(cnt,id(mask(1)),j,id(mask(3)))   &
                                                      +  coeffs(7)*oldblock(b)%velocity(cnt,i,id(mask(2)),id(mask(3)))   &
                                                      +  coeffs(8)*oldblock(b)%velocity(cnt,id(mask(1)),id(mask(2)),id(mask(3)))
                    enddo

                    ! Pressure
                    block(b)%pressure(ii,jj,kk) = coeffs(1)*oldblock(b)%pressure(i,j,k)     &
                                                +  coeffs(2)*oldblock(b)%pressure(id(mask(1)),j,k)    &
                                                +  coeffs(3)*oldblock(b)%pressure(i,id(mask(2)),k)    &
                                                +  coeffs(4)*oldblock(b)%pressure(i,j,id(mask(3)))    &
                                                +  coeffs(5)*oldblock(b)%pressure(id(mask(1)),id(mask(2)),k)   &
                                                +  coeffs(6)*oldblock(b)%pressure(id(mask(1)),j,id(mask(3)))   &
                                                +  coeffs(7)*oldblock(b)%pressure(i,id(mask(2)),id(mask(3)))   &
                                                +  coeffs(8)*oldblock(b)%pressure(id(mask(1)),id(mask(2)),id(mask(3)))

                    ! Turbulent properties
                    block(b)%turbprop(:,ii,jj,kk) = coeffs(1)*oldblock(b)%turbprop(:,i,j,k)     &
                                                  +  coeffs(2)*oldblock(b)%turbprop(:,id(mask(1)),j,k)    &
                                                  +  coeffs(3)*oldblock(b)%turbprop(:,i,id(mask(2)),k)    &
                                                  +  coeffs(4)*oldblock(b)%turbprop(:,i,j,id(mask(3)))    &
                                                  +  coeffs(5)*oldblock(b)%turbprop(:,id(mask(1)),id(mask(2)),k)   &
                                                  +  coeffs(6)*oldblock(b)%turbprop(:,id(mask(1)),j,id(mask(3)))   &
                                                  +  coeffs(7)*oldblock(b)%turbprop(:,i,id(mask(2)),id(mask(3)))   &
                                                  +  coeffs(8)*oldblock(b)%turbprop(:,id(mask(1)),id(mask(2)),id(mask(3)))
                  
                    counter = counter + 1
                  
                  enddo
                enddo
              enddo
              
            enddo
          enddo     
        enddo
      enddo


    ! General algorithm for MESH RATIO = integer (both 2D and 3D)
    else
      write(*,*)
      write(*,*) " Mesh ratio = ", rap, " - Generic algorithm"
      write(*,*)
      
      if (sym_type=="3D") then
        write(*,*) " 3D"
      elseif (sym_type=="2D") then
        write(*,*) " 2D"
      endif

      do b = start, end
        write(*,*)" Block : ", b
        indk = 1
        do k = 1, block(b)%dim(3)         
          indj = 1
          do j = 1, block(b)%dim(2)            
            indi = 1
            do i = 1, block(b)%dim(1)
              
              ! Density           
              do s = 1, newspecies%n
                block(b)%density(s,i,j,k) = 1e-20
                do sold = 1, oldspecies%n
                  if (newspecies%name(s)==oldspecies%name(sold)) then
                    block(b)%density(s,i,j,k) = oldblock(b)%density(s,indi,indj,indk)
                  endif
                enddo
              enddo
              
              ! Velocity
              do cnt = 1, 3
                block(b)%velocity(cnt,i,j,k) = oldblock(b)%velocity(cnt,indi,indj,indk)
              enddo
              
              ! Pressure        
              block(b)%pressure(i,j,k) = oldblock(b)%pressure(indi,indj,indk)
              
                ! Turbulent properties
              block(b)%turbprop(:,i,j,k) = oldblock(b)%turbprop(:,indi,indj,indk)
              
              if (mod(i,rap)==0) then
                indi = indi+1
              endif
            enddo
            if (mod(j,rap)==0) then
              indj = indj+1
            endif
          enddo
          if (mod(k,rap)==0) then
            indk = indk+1
          endif       
        enddo
      enddo
    
    endif
  
  else
    write(*,*) 
    write(*,*) " ERROR : Interpolation with law='multiple' is impossible"
    write(*,*) " ERROR : Meshes are not multiple of one another"
    write(*,*)
    stop
  endif

end subroutine multiple_interpolation


!=======================================================================================!
!========================== MINIMUM DISTANCE INTERPOLATION =============================!
!=======================================================================================!

subroutine distance_interpolation
  implicit none
  real(kind=R8)                                       :: truedist, mindist
  real(kind=R8), dimension(:,:,:), allocatable        :: dx, dy, dz, dist

  if (.not.present(id)) then
    write(*,*)
    write(*,*) " Cell Centers Minimum Distance interpolation algorithm"
    write(*,*)
  endif

  do b = start, end
    trueb = 1
    write(*,*) " Block : ", b
    do k = 1, block(b)%dim(3)
      do j = 1, block(b)%dim(2)
        do i = 1, block(b)%dim(1)

        ! Cell centers minimum distance algorithm
          truedist = 1d+5
          do bb = 1, size(oldblock)
            allocate(dx(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)))
            allocate(dy(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)))
            allocate(dz(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)))
            allocate(dist(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)))
            !dx(:,:,:) = (block(b)%center(i,j,k)%c(1)-oldblock(bb)%center(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3))%c(1))**2
            !dy(:,:,:) = (block(b)%center(i,j,k)%c(2)-oldblock(bb)%center(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3))%c(2))**2
            !dz(:,:,:) = (block(b)%center(i,j,k)%c(3)-oldblock(bb)%center(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3))%c(3))**2
            dist(:,:,:) = sqrt(dx(:,:,:)+dy(:,:,:)+dz(:,:,:))
            indold = minloc(dist(:,:,:),MASK=.true.)
            mindist = dist(indold(1),indold(2),indold(3))
            if (mindist<truedist) then
              truedist = mindist
              ind = indold
              trueb = bb
            endif
            deallocate(dx);deallocate(dy);deallocate(dz);deallocate(dist)
          enddo
          
          ! Density
          do s = 1, newspecies%n
            block(b)%density(s,i,j,k) = 1e-20
            do sold = 1, oldspecies%n
              if (newspecies%name(s)==oldspecies%name(sold)) then
                block(b)%density(s,i,j,k) = oldblock(trueb)%density(s,ind(1),ind(2),ind(3))
              endif
            enddo
          enddo

          ! Velocity
          do cnt = 1, 3
            block(b)%velocity(cnt,i,j,k) = oldblock(trueb)%velocity(cnt,ind(1),ind(2),ind(3))
          end do
          
          ! Pressure
          block(b)%pressure(i,j,k) = oldblock(trueb)%pressure(ind(1),ind(2),ind(3))
          
          ! Turbulent properties
          block(b)%turbprop(:,i,j,k) = oldblock(trueb)%turbprop(:,ind(1),ind(2),ind(3))
          
        enddo
      enddo
    enddo
  enddo

end subroutine distance_interpolation


subroutine spherical_distance_interpolation
  implicit none
  integer                                             :: c, ii, jj, kk
  real(kind=R8)                                       :: r, xc, yc, zc, x, y, z, dx, dy, dz
  real(kind=R8)                                       :: dist, truedist

  if (.not.present(id)) then
    write(*,*)
    write(*,*) " Cell Centers Spherical Minimum Distance interpolation algorithm"
    write(*,*)
  endif

  do b = start, end
    write(*,*) " Block : ", b  
    do k = 1, block(b)%dim(3)
      do j = 1, block(b)%dim(2)
        do i = 1, block(b)%dim(1)
          
          xc = block(b)%center(i,j,k)%c(1)
          yc = block(b)%center(i,j,k)%c(2)
          zc = block(b)%center(i,j,k)%c(3)
          dx = block(b)%bbmax(i,j,k)%c(1) - block(b)%bbmin(i,j,k)%c(1)
          dy = block(b)%bbmax(i,j,k)%c(2) - block(b)%bbmin(i,j,k)%c(2)
          dz = block(b)%bbmax(i,j,k)%c(3) - block(b)%bbmin(i,j,k)%c(3)
          truedist = 1d+5
          r = 0.0
          c = 0
          
          do while (c == 0)
            r = r + max(dx,dy,dz)

            do bb = 1, size(oldblock)
              do kk = 1, oldblock(bb)%dim(3)
                do jj = 1, oldblock(bb)%dim(2)
                  do ii = 1, oldblock(bb)%dim(1)
                  
                    x = oldblock(bb)%center(ii,jj,kk)%c(1)
                    y = oldblock(bb)%center(ii,jj,kk)%c(2)
                    z = oldblock(bb)%center(ii,jj,kk)%c(3)

                    dist = sqrt((xc-x)**2 + (yc-y)**2 + (zc-z)**2)

                    if (dist < r) then
                      c = 1
                      if (dist < truedist) then
                        trueb = bb
                        ind(1) = ii
                        ind(2) = jj
                        ind(3) = kk
                        truedist = dist
                      endif
                    endif

                  enddo
                enddo
              enddo
            enddo

          enddo

          ! Density
          do s = 1, newspecies%n
            block(b)%density(s,i,j,k) = 1e-20
            do sold = 1, oldspecies%n
              if (newspecies%name(s)==oldspecies%name(sold)) then
                block(b)%density(s,i,j,k) = oldblock(trueb)%density(s,ind(1),ind(2),ind(3))
              endif
            enddo
          enddo

          ! Velocity
          do cnt = 1, 3
            block(b)%velocity(cnt,i,j,k) = oldblock(trueb)%velocity(cnt,ind(1),ind(2),ind(3))
          end do
          
          ! Pressure
          block(b)%pressure(i,j,k) = oldblock(trueb)%pressure(ind(1),ind(2),ind(3))
          
          ! Turbulent properties
          block(b)%turbprop(:,i,j,k) = oldblock(trueb)%turbprop(:,ind(1),ind(2),ind(3))

        enddo
      enddo
    enddo
  enddo

end subroutine spherical_distance_interpolation



!=======================================================================================!
!=======================================================================================!
!=======================================================================================!
!====================== SPECIFIC BLOCK INTERPOLATION METHODS ===========================!
!=======================================================================================!
!=======================================================================================!
!=======================================================================================!


!=======================================================================================!
!============================= INDEX BLOCK INTERPOLATION ===============================!
!=======================================================================================!


subroutine index_block_interpolation()
  implicit none
  logical, dimension(:), allocatable      :: corresponding
  
  ! Check mesh have the same dimensions Nx, Ny and eventually Nz
  allocate(corresponding(1:2))

  if (oldblock(oldid)%dim(1) == block(id)%dim(1)) corresponding(1) = .true.
  if (oldblock(oldid)%dim(2) == block(id)%dim(2)) corresponding(2) = .true.
  if (oldblock(oldid)%dim(3) == block(id)%dim(3)) then
    sym_type = "3D"
  else 
    if (oldblock(oldid)%dim(3) == 1) then
      sym_type = "2D"
    else
      write(*,*) 
      write(*,*) " ERROR : 3D Meshes with different Nz"
      write(*,*) " Can't use law = 'index_block' in this case"
      write(*,*)
      stop    
    endif
  endif

  if (.not.all(corresponding)) then
    write(*,*) 
    write(*,*) " ERROR : Different dimensions of blocks"
    write(*,*) " Index Interpolation FAILED"
    write(*,*)
    stop
  endif
  
  ! Case 2D-3D interpolation
  if (all(corresponding).and.sym_type=="2D") then
    write(*,*) 
    write(*,*) " 2D-3D Index based interpolation algorithm "
    write(*,*) " New Block: ", id, " - Old Block: ", oldid
    write(*,*)

    do k = 1, block(b)%dim(3)
      do j = 1, block(b)%dim(2)
        do i = 1, block(b)%dim(1)

          ! Density
          do s = 1, newspecies%n
            block(id)%density(s,i,j,k) = 1e-20
            do sold = 1, oldspecies%n
              if (newspecies%name(s)==oldspecies%name(sold)) then
                block(id)%density(s,i,j,k) = oldblock(oldid)%density(s,i,j,1)
              endif
            enddo
          enddo
          
          ! Velocity
          block(id)%velocity(1,i,j,k) = oldblock(oldid)%velocity(1,i,j,1)
          block(id)%velocity(2,i,j,k) = oldblock(oldid)%velocity(2,i,j,1)*&
            cos(atan2(block(id)%center(i,j,k)%c(3),block(id)%center(i,j,k)%c(2)))
          block(id)%velocity(3,i,j,k) = oldblock(oldid)%velocity(3,i,j,1)*&
            sin(atan2(block(id)%center(i,j,k)%c(3),block(id)%center(i,j,k)%c(2)))
          
          ! Pressure
          block(id)%pressure(i,j,k) = oldblock(oldid)%pressure(i,j,1)
          
          ! Turbulent properties
          block(id)%turbprop(:,i,j,k) = oldblock(oldid)%turbprop(:,i,j,1)
          
        enddo
      enddo
    enddo

  ! Case 3D-3D interpolation
  elseif (all(corresponding).and.sym_type=="3D") then
    write(*,*) 
    write(*,*) " 3D-3D Index based interpolation algorithm "
    write(*,*) " New Block: ", id, " - Old Block: ", oldid
    write(*,*)
    
    do k = 1, block(id)%dim(3)
      do j = 1, block(id)%dim(2)
        do i = 1, block(id)%dim(1)

          ! Density
          do s = 1, newspecies%n
            block(id)%density(s,i,j,k) = 1e-20
            do sold = 1, oldspecies%n
              if (newspecies%name(s)==oldspecies%name(sold)) then
                block(id)%density(s,i,j,k) = oldblock(oldid)%density(s,i,j,k)
              endif
            enddo
          enddo
          
          ! Velocity
          block(id)%velocity(1,i,j,k) = oldblock(oldid)%velocity(1,i,j,k)
          block(id)%velocity(2,i,j,k) = oldblock(oldid)%velocity(2,i,j,k)                
          block(id)%velocity(3,i,j,k) = oldblock(oldid)%velocity(3,i,j,k)
          
          ! Pressure
          block(id)%pressure(i,j,k) = oldblock(oldid)%pressure(i,j,k)
          
          ! Turbulent properties
          block(id)%turbprop(:,i,j,k) = oldblock(oldid)%turbprop(:,i,j,1)
        
        enddo
      enddo
    enddo     

  else
    write(*,*) 
    write(*,*) " ERROR : 2D and 3D Mesh do not have the same Nx and Ny elements"
    write(*,*) " Interpolation FAILED"
    write(*,*)
    stop
  endif

end subroutine index_block_interpolation


!=======================================================================================!
!====================== MINIMUM DISTANCE BLOCK INTERPOLATION ===========================!
!=======================================================================================!

subroutine distance_block_interpolation
  implicit none
  real(kind=R8)                                       :: truedist, mindist
  real(kind=R8), dimension(:,:,:), allocatable        :: dx, dy, dz, dist

  write(*,*)
  write(*,*) " Cell Centers Minimum Distance interpolation algorithm"
  write(*,*) " New Block: ", id, " - Old Block: ", oldid
  write(*,*)

  do k = 1, block(id)%dim(3)
    do j = 1, block(id)%dim(2)
      do i = 1, block(id)%dim(1)

        ! Cell centers minimum distance algorithm
        truedist = 1d+5
        allocate(dx(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)))
        allocate(dy(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)))
        allocate(dz(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)))
        allocate(dist(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)))
        !dx(:,:,:) = (block(id)%center(i,j,k)%c(1)-oldblock(oldid)%center(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3))%c(1))**2
        !dy(:,:,:) = (block(id)%center(i,j,k)%c(2)-oldblock(oldid)%center(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3))%c(2))**2
        !dz(:,:,:) = (block(id)%center(i,j,k)%c(3)-oldblock(oldid)%center(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3))%c(3))**2
        dist(:,:,:) = sqrt(dx(:,:,:)+dy(:,:,:)+dz(:,:,:))
        indold = minloc(dist(:,:,:),MASK=.true.)
        mindist = dist(indold(1),indold(2),indold(3))
        if (mindist<truedist) then
          truedist = mindist
          ind = indold
        endif
        deallocate(dx);deallocate(dy);deallocate(dz);deallocate(dist)

        ! Density
        do s = 1, newspecies%n
          block(id)%density(s,i,j,k) = 1e-20
          do sold = 1, oldspecies%n
            if (newspecies%name(s)==oldspecies%name(sold)) then
              block(id)%density(s,i,j,k) = oldblock(oldid)%density(s,ind(1),ind(2),ind(3))
            endif
          enddo
        enddo
        
        ! Velocity
        do cnt = 1, 3
          block(id)%velocity(cnt,i,j,k) = oldblock(oldid)%velocity(cnt,ind(1),ind(2),ind(3))
        end do

        ! Pressure
        block(id)%pressure(i,j,k) = oldblock(oldid)%pressure(ind(1),ind(2),ind(3))

        ! Turbulent properties
        block(id)%turbprop(:,i,j,k) = oldblock(oldid)%turbprop(:,ind(1),ind(2),ind(3))
        
      enddo
    enddo
  enddo

end subroutine distance_block_interpolation


subroutine spherical_distance_block_interpolation
  implicit none
  integer                                             :: c, ii, jj, kk
  real(kind=R8)                                       :: r, xc, yc, zc, x, y, z, dx, dy, dz
  real(kind=R8)                                       :: dist, truedist

  write(*,*)
  write(*,*) " Cell Centers Spherical Minimum Distance interpolation algorithm"
  write(*,*) " New Block: ", id, " - Old Block: ", oldid
  write(*,*)
  
  do k = 1, block(id)%dim(3)
    do j = 1, block(id)%dim(2)
      do i = 1, block(id)%dim(1)

        xc = block(id)%center(i,j,k)%c(1)
        yc = block(id)%center(i,j,k)%c(2)
        zc = block(id)%center(i,j,k)%c(3)
        dx = block(id)%bbmax(i,j,k)%c(1) - block(id)%bbmin(i,j,k)%c(1)
        dy = block(id)%bbmax(i,j,k)%c(2) - block(id)%bbmin(i,j,k)%c(2)
        dz = block(id)%bbmax(i,j,k)%c(3) - block(id)%bbmin(i,j,k)%c(3)
        truedist = 1d+5
        r = 0.0
        c = 0

        do while (c == 0)
          r = r + max(dx,dy,dz)

          do kk = 1, oldblock(oldid)%dim(3)
            do jj = 1, oldblock(oldid)%dim(2)
              do ii = 1, oldblock(oldid)%dim(1)
                
                x = oldblock(oldid)%center(ii,jj,kk)%c(1)
                y = oldblock(oldid)%center(ii,jj,kk)%c(2)
                z = oldblock(oldid)%center(ii,jj,kk)%c(3)

                dist = sqrt((xc-x)**2 + (yc-y)**2 + (zc-z)**2)

                if (dist < r) then
                  c = 1
                  if (dist < truedist) then
                    ind(1) = ii
                    ind(2) = jj
                    ind(3) = kk
                    truedist = dist
                  endif
                endif

              enddo
            enddo
          enddo

        enddo

        ! Density
        do s = 1, newspecies%n
          block(id)%density(s,i,j,k) = 1e-20
          do sold = 1, oldspecies%n
            if (newspecies%name(s)==oldspecies%name(sold)) then
              block(id)%density(s,i,j,k) = oldblock(oldid)%density(s,ind(1),ind(2),ind(3))
            endif
          enddo
        enddo

        ! Velocity
        do cnt = 1, 3
          block(id)%velocity(cnt,i,j,k) = oldblock(oldid)%velocity(cnt,ind(1),ind(2),ind(3))
        end do

        ! Pressure
        block(id)%pressure(i,j,k) = oldblock(oldid)%pressure(ind(1),ind(2),ind(3))
        
        ! Turbulent properties
        block(id)%turbprop(:,i,j,k) = oldblock(oldid)%turbprop(:,ind(1),ind(2),ind(3))
   
      enddo
    enddo
  enddo

end subroutine spherical_distance_block_interpolation




end subroutine intersol

end module Interpolator
