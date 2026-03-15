module Interpolator_IG
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use variables
  use ATLAS_high_level
  use ATLAS_IO_fields, only: read_solfile, read_mesh, read_vtk_tec
  use ATLAS_read_phase, only: read_idealgas_properties
  use Lib_ORION_data
  use species, only: obj_species
  implicit none

  logical                                      :: onespecies
  integer                                      :: nz_extrude
  real(R8)                                     :: thetamax_extrude
  character(len=32)                            :: law
  type(ATLAS_block), dimension(:), allocatable :: oldblock
  type(obj_species)                            :: oldspecies
  character(len=llen)                          :: oldsolutionfile

contains

  subroutine build_old_solution(oldmeshfile_,oldsolutionfile_,oldspeciesfile_,newspecies)
    implicit none
    character(len=llen), intent(inout) :: oldspeciesfile_
    character(len=llen), intent(inout) :: oldsolutionfile_
    character(len=llen), intent(inout) :: oldmeshfile_
    type(obj_species), intent(in)      :: newspecies
    type(orion_data)                   :: oldorion
    integer :: b

    oldsolutionfile = oldsolutionfile_

    if (.not.onespecies) then
      call read_idealgas_properties(oldspeciesfile_, oldspecies)
    else
      oldspecies = newspecies
    endif

    ! Old files reading and data allocation
    if (oldmeshfile_/='Darwin') then
      if (verbose) write(*,*)"[LOG] Reading mesh file: ", trim(oldmeshfile_)
      call read_mesh(oldorion,oldmeshfile_)
      call import_nodes(input=oldorion,output=oldblock)
      deallocate(oldorion%block)
      if (law=='extrude') then
        if (verbose) write(*,*)"[LOG] Old mesh extrusion"
        call extrude360(1)
        if (verbose) write(*,*) 
      endif
      do b = 1, size(oldblock)
        call oldblock(b)%compute_centers([0,0,0])
        call oldblock(b)%allocate(nrans,oldspecies%n,oldblock(b)%dim(1),oldblock(b)%dim(2),oldblock(b)%dim(3))
      end do
      if (verbose) write(*,*)"[LOG] Reading solution file: ", trim(oldsolutionfile)
      call read_solfile('IG',oldsolutionfile,oldblock,oldspecies%n)
      if (law=='extrude') then
        if (verbose) write(*,*)"[LOG] Old solution extrusion"
        call extrude360(2)
        if (verbose) write(*,*)
      endif

    else

      if (verbose) write(*,*)"[LOG] Reading solution file: ", trim(oldsolutionfile)
      call read_vtk_tec('IG',oldsolutionfile,oldblock,oldspecies%n)
      if (law=='extrude') then
        if (verbose) write(*,*)"[LOG] Old mesh extrusion"
        call extrude360(1)
        if (verbose) write(*,*) 
      endif
      if (law=='extrude') then
        if (verbose) write(*,*)"[LOG] Old solution extrusion"
        call extrude360(2)
        if (verbose) write(*,*)
      endif
    endif

  contains

    !=======================================================================================!
    !========================= EXTRUSION INTERPOLATION =====================================!
    !=======================================================================================!

    subroutine extrude360(fase)
      implicit none
      integer, intent(in)   :: fase
      real(R8), parameter   :: pi=4.0*atan(1.0)
      real(R8)              :: theta(nz_extrude+1)
      real(R8), allocatable :: mesh(:,:,:,:)
      integer :: i, j, k
      
      if (verbose) then
        write(*,*)"[LOG] Extrusion angle    = ", thetamax_extrude
        write(*,*)"[LOG] Extrusion elements = ", nz_extrude
      endif
  
      if (fase==1) then

        do i = 1, nz_extrude+1
          theta(i) = (thetamax_extrude*pi/180)/nz_extrude*i
        enddo

        allocate(mesh(1:3,0:maxval(oldblock(:)%dim(1)),0:maxval(oldblock(:)%dim(2)),0:1))

        do b = 1, size(oldblock)
          ! Dummy 2D mesh allocated and initialized before new allocation of oldblock
          do i = 0, oldblock(b)%dim(1); do j = 0, oldblock(b)%dim(2); do k = 0, oldblock(b)%dim(3)
                mesh(:,i,j,k) = oldblock(b)%node(i,j,k)%c(1:3)
          enddo; enddo; enddo
          deallocate(oldblock(b)%node)
          oldblock(b)%dim(3) = nz_extrude
          allocate(oldblock(b)%node(0:oldblock(b)%dim(1),0:oldblock(b)%dim(2),0:oldblock(b)%dim(3)))
          do i = 0, oldblock(b)%dim(1); do j = 0, oldblock(b)%dim(2); do k = 0, oldblock(b)%dim(3)
                oldblock(b)%node(i,j,k)%c(1) = mesh(1,i,j,1)
                oldblock(b)%node(i,j,k)%c(2) = mesh(2,i,j,1)*cos(theta(k+1))
                oldblock(b)%node(i,j,k)%c(3) = mesh(2,i,j,1)*sin(theta(k+1))
          enddo; enddo; enddo
        enddo

      else
      
        do i = 1, nz_extrude
          theta(i) = (thetamax_extrude*pi/180)/nz_extrude*i
        enddo

        do b = 1, size(oldblock)
          do k = 1, oldblock(b)%dim(3)
            oldblock(b)%density(:,:,:,k) = oldblock(b)%density(:,:,:,1)
            oldblock(b)%velocity(1,:,:,k) = oldblock(b)%velocity(1,:,:,1)
            oldblock(b)%velocity(2,:,:,k) = oldblock(b)%velocity(2,:,:,1)*cos(theta(k))
            oldblock(b)%velocity(3,:,:,k) = oldblock(b)%velocity(2,:,:,1)*sin(theta(k))
            oldblock(b)%pressure(:,:,k) = oldblock(b)%pressure(:,:,1)
            if (nrans>0) oldblock(b)%turbprop(1:nrans,:,:,k) = oldblock(b)%turbprop(1:nrans,:,:,1)
          enddo
        enddo

      endif

    end subroutine extrude360

  end subroutine build_old_solution

  subroutine intersol(block,oldmeshfile_,oldsolutionfile_,oldspeciesfile_,oldid)
    implicit none
    type(ATLAS_block), intent(inout)     :: block
    character(len=llen), intent(inout)   :: oldspeciesfile_
    character(len=llen), intent(inout)   :: oldsolutionfile_
    character(len=llen), intent(inout)   :: oldmeshfile_
    integer, intent(in)                  :: oldid
    type(obj_species)                    :: newspecies
    character(2)                         :: sym_type
    integer                              :: cnt, s, sold, i, j, k, b, bb, trueb
    integer                              :: ii, jj, kk, counter
    integer, dimension(3)                :: mask
    integer                              :: i2, j2, k2, i2d, j2d, k2d
    integer                              :: im, jm, km, ip, jp, kp
    integer, dimension(3)                :: ind, indold
    logical, dimension(:), allocatable   :: same_dimension

    newspecies = block%associated_phase(1)%species

    ! First block interpolation requires old solution build
    if (.not. allocated(oldblock)) then
      call build_old_solution(oldmeshfile_,oldsolutionfile_,oldspeciesfile_,newspecies)
    ! if multiple solutions files are employed, the old solution is rebuilt
    elseif (allocated(oldblock) .and. oldsolutionfile_/=oldsolutionfile) then
      deallocate(oldblock)
      call build_old_solution(oldmeshfile_,oldsolutionfile_,oldspeciesfile_,newspecies)
    endif

    if (verbose) then
      write(*,*) "[LOG] Building new solution"
      write(*,*) "[LOG] Old species number: ", oldspecies%n
      write(*,*) "[LOG] New species number: ", newspecies%n
    endif

    b = block%id
    if (oldid>0) b = oldid

    ! Interpolazion Procedures depending on LAW
    select case(law)

      ! General Interpolation Methods
      case('index')
        call index_interpolation()
      
      case('multiple')
        call multiple_interpolation()

      case('minimum_distance')
        call distance_interpolation()

      case('spherical_minimum_distance')
        call spherical_distance_interpolation()
      
      case default
        call distance_interpolation()

      end select

    if (verbose) then
      write(*,*) "[LOG] Interpolation Completed Successfully"
      write(*,*)
    endif

  contains

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
  allocate(same_dimension(1:2))
  if (oldblock(b)%dim(1) == block%dim(1)) then
    same_dimension(1) = .true.
  endif
  if (oldblock(b)%dim(2) == block%dim(2)) then
    same_dimension(2) = .true.
  endif
  if (oldblock(b)%dim(3) == block%dim(3)) then
    sym_type = "3D"
  else
    if  (oldblock(b)%dim(3) == 1) then
      sym_type = "2D"
    else
      write(*,*) 
      write(*,*) "[ERROR] 3D Meshes with different Nz"
      write(*,*) " Can't use law = 'index' in this case"
      stop
    endif
  endif

  ! Case 2D-3D interpolation
  if (all(same_dimension).and.sym_type=="2D") then
    if (verbose) then
      write(*,*)
      write(*,*) "[LOG] 2D-3D Index based interpolation algorithm"
      write(*,*)
    endif

    !$omp parallel private(i,j,k,s,sold)
    !$omp do collapse(3)
    do k = 1, block%dim(3)
      do j = 1, block%dim(2)
        do i = 1, block%dim(1)

          ! Density
          if (any(block%density(:,i,j,k)/=0.d0)) then
            if (oldspecies%n==1) then
              block%density(:,i,j,k) = block%density(:,i,j,k)*oldblock(b)%density(1,i,j,1)
            else
              error stop "[ERROR] Species mass fractions decomposition available only if old species number = 1"
            endif
          else
            do s = 1, newspecies%n
              do sold = 1, oldspecies%n
                if (newspecies%name(s)==oldspecies%name(sold)) then
                  block%density(s,i,j,k) = oldblock(b)%density(sold,i,j,1)
                  exit
                endif
              enddo
            enddo
          endif

          ! Velocity
          block%velocity(1,i,j,k) = oldblock(b)%velocity(1,i,j,1)
          block%velocity(2,i,j,k) = oldblock(b)%velocity(2,i,j,1)*&
          cos(atan2(block%center(i,j,k)%c(3),block%center(i,j,k)%c(2)))
          block%velocity(3,i,j,k) = oldblock(b)%velocity(3,i,j,1)*&
          sin(atan2(block%center(i,j,k)%c(3),block%center(i,j,k)%c(2)))

          ! Pressure
          block%pressure(i,j,k) = oldblock(b)%pressure(i,j,1)

          ! Turbulent properties
          if (nrans > 0 ) block%turbprop(1:nrans,i,j,k) = oldblock(b)%turbprop(1:nrans,i,j,1)

        enddo
      enddo
    enddo
    !$omp end parallel

  ! Case 3D-3D interpolation
  elseif (all(same_dimension).and.sym_type=="3D") then
    if (verbose) then
      write(*,*) 
      write(*,*) "[LOG] 3D-3D Index based interpolation algorithm"
      write(*,*)
    endif

    !$omp parallel private(i,j,k,s,sold)
    !$omp do collapse(3)
    do k = 1, block%dim(3)
      do j = 1, block%dim(2)
        do i = 1, block%dim(1)

          ! Density
          if (any(block%density(:,i,j,k)/=0.d0)) then
            if (oldspecies%n==1) then
              block%density(:,i,j,k) = block%density(:,i,j,k)*oldblock(b)%density(1,i,j,1)
            else
              error stop "[ERROR] Species mass fractions decomposition available only if old species number = 1"
            endif
          else
            do s = 1, newspecies%n
              do sold = 1, oldspecies%n
                if (newspecies%name(s)==oldspecies%name(sold)) then
                  block%density(s,i,j,k) = oldblock(b)%density(sold,i,j,1)
                  exit
                endif
              enddo
            enddo
          endif

          ! Velocity
          block%velocity(1,i,j,k) = oldblock(b)%velocity(1,i,j,k)
          block%velocity(2,i,j,k) = oldblock(b)%velocity(2,i,j,k)
          block%velocity(3,i,j,k) = oldblock(b)%velocity(3,i,j,k)

          ! Pressure
          block%pressure(i,j,k) = oldblock(b)%pressure(i,j,k)

          ! Turbulent properties
          if (nrans > 0 ) block%turbprop(1:nrans,i,j,k) = oldblock(b)%turbprop(1:nrans,i,j,k)

        enddo
      enddo
    enddo
    !$omp end parallel

  else
    write(*,*) 
    write(*,*) "[ERROR] 2D and 3D Mesh do not have the same Nx and Ny elements"
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
  logical                            :: xint_dimension
  real(kind=R8)                      :: a0, a1, a2, a3, a4
  integer, dimension(6)              :: id
  integer                            :: indi, indj, indk, rap

  ! Check mesh have dimensions Nx, Ny, Nz that are an INTEGER multiple of one another
  rapNx = float(block%dim(1))/float(oldblock(b)%dim(1))
  rapNy = float(block%dim(2))/float(oldblock(b)%dim(2))
  rapNz = float(block%dim(3))/float(oldblock(b)%dim(3))    
  if (rapNx==rapNy.and.mod(max(block%dim(1),oldblock(b)%dim(1)),min(block%dim(1),oldblock(b)%dim(1)))==0) then
    if (rapNz==rapNx) then
      sym_type = "3D"
      xint_dimension = .true.
      rap = nint(rapNx)
    elseif (block%dim(3)==1.and.oldblock(b)%dim(3)==1) then
      sym_type = "2D"
      xint_dimension = .true.
      rap = nint(rapNx)
    endif
  endif

  if (xint_dimension) then
    if (verbose) then
      write(*,*) 
      write(*,*) "[LOG] New mesh / Old mesh Ratio = ", rapNx
    endif

    ! Reconstruction algorithm fo MESH RATIO = 0.5
    if (rapNx==0.5) then
      if (verbose) then
        write(*,*) "[LOG] Mesh ratio = 0.5 - Specific algorithm"
        write(*,*)
      endif

      ! Interpolation Coefficients
      if (sym_type=="3D") then
        coeffs(1:4) = 1./8.
        coeffs(5:8) = 1./8.        
      elseif (sym_type=="2D") then
        coeffs(1:4) = 1./4.
        coeffs(5:8) = 0.0
      end if
  
      !$omp parallel private(i,j,k,i2,j2,k2,i2d,j2d,k2d,s,sold,cnt)
      !$omp do collapse(3)
      do k = 1, block%dim(3)
        do j = 1, block%dim(2)
          do i = 1, block%dim(1)

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
              block%density(s,i,j,k) = 1e-20
              do sold = 1, oldspecies%n
                if (newspecies%name(s)==oldspecies%name(sold)) then
                  block%density(s,i,j,k)      =  coeffs(1)*oldblock(b)%density(sold,i2d,j2d,k2d)   &
                                              +  coeffs(2)*oldblock(b)%density(sold,i2, j2d,k2d)   &
                                              +  coeffs(3)*oldblock(b)%density(sold,i2d,j2, k2d)   &
                                              +  coeffs(4)*oldblock(b)%density(sold,i2, j2, k2d)   &
                                              +  coeffs(5)*oldblock(b)%density(sold,i2d,j2d,k2)    &
                                              +  coeffs(6)*oldblock(b)%density(sold,i2, j2d,k2)    &
                                              +  coeffs(7)*oldblock(b)%density(sold,i2d,j2, k2)    &
                                              +  coeffs(8)*oldblock(b)%density(sold,i2, j2, k2)
                  exit
                endif
              enddo
            enddo

            ! Velocity
            do cnt = 1, 3
              block%velocity(cnt,i,j,k)     =  coeffs(1)*oldblock(b)%velocity(cnt,i2d,j2d,k2d)   &
                                            +  coeffs(2)*oldblock(b)%velocity(cnt,i2, j2d,k2d)   &
                                            +  coeffs(3)*oldblock(b)%velocity(cnt,i2d,j2, k2d)   &
                                            +  coeffs(4)*oldblock(b)%velocity(cnt,i2, j2, k2d)   &
                                            +  coeffs(5)*oldblock(b)%velocity(cnt,i2d,j2d,k2)    &
                                            +  coeffs(6)*oldblock(b)%velocity(cnt,i2, j2d,k2)    &
                                            +  coeffs(7)*oldblock(b)%velocity(cnt,i2d,j2, k2)    &
                                            +  coeffs(8)*oldblock(b)%velocity(cnt,i2, j2, k2)
            enddo

            ! Pressure
            block%pressure(i,j,k)     =  coeffs(1)*oldblock(b)%pressure(i2d,j2d,k2d)   &
                                      +  coeffs(2)*oldblock(b)%pressure(i2, j2d,k2d)   &
                                      +  coeffs(3)*oldblock(b)%pressure(i2d,j2, k2d)   &
                                      +  coeffs(4)*oldblock(b)%pressure(i2, j2, k2d)   &
                                      +  coeffs(5)*oldblock(b)%pressure(i2d,j2d,k2)    &
                                      +  coeffs(6)*oldblock(b)%pressure(i2, j2d,k2)    &
                                      +  coeffs(7)*oldblock(b)%pressure(i2d,j2, k2)    &
                                      +  coeffs(8)*oldblock(b)%pressure(i2, j2, k2)

            ! Turbulent properties
            if (nrans > 0 ) then
              do cnt = 1, nrans
              block%turbprop(cnt,i,j,k)     =  coeffs(1)*oldblock(b)%turbprop(cnt,i2d,j2d,k2d)   &
                                            +  coeffs(2)*oldblock(b)%turbprop(cnt,i2, j2d,k2d)   &
                                            +  coeffs(3)*oldblock(b)%turbprop(cnt,i2d,j2, k2d)   &
                                            +  coeffs(4)*oldblock(b)%turbprop(cnt,i2, j2, k2d)   &
                                            +  coeffs(5)*oldblock(b)%turbprop(cnt,i2d,j2d,k2)    &
                                            +  coeffs(6)*oldblock(b)%turbprop(cnt,i2, j2d,k2)    &
                                            +  coeffs(7)*oldblock(b)%turbprop(cnt,i2d,j2, k2)    &
                                            +  coeffs(8)*oldblock(b)%turbprop(cnt,i2, j2, k2)
              enddo
            endif
          enddo
        enddo
      enddo
      !$omp end parallel


    ! Spcific algorithm for MESH RATIO = 2 (both 2D and 3D)
    elseif (rapNx==2.0) then
      if (verbose) then
        write(*,*) "[LOG] Mesh ratio = 2 - Specific algorithm"
        write(*,*)
      endif

      ! Interpolation Coefficients
      if (sym_type=="3D") then
        a1 = 27./64.
        a2 = 9./64.
        a3 = 3./64.
        a4 = 1./64.
        coeffs(1:8) = [a1,a2,a2,a2,a3,a3,a3,a4]            

      elseif (sym_type=="2D") then
        a1 = 9./16.
        a2 = 3./16.
        a3 = 1./16.
        a4 = 0./16.
        coeffs(1:8) = [a1,a2,a2,a4,a3,a4,a4,a4]
      end if

      !$omp parallel private(i,j,k,i2,j2,k2,i2d,j2d,k2d,im,jm,km,ip,jp,kp,id,counter,ii,jj,kk,mask,s,sold,cnt)
      !$omp do collapse(3)
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

            id(1:6) = [im,jm,km,ip,jp,kp]

            counter = 1

            do kk = k2d, k2
              do jj = j2d, j2
                do ii = i2d, i2

                  if (sym_type=="2D") then
                    if (counter==1) mask(1:3)=[1,2,3]
                    if (counter==2) mask(1:3)=[4,2,3]
                    if (counter==3) mask(1:3)=[1,5,3]
                    if (counter==4) mask(1:3)=[4,5,3]
                  endif

                  if(sym_type=="3D") then
                    if (counter==1) mask(1:3)=[1,2,3]
                    if (counter==2) mask(1:3)=[4,2,3]
                    if (counter==3) mask(1:3)=[1,5,3]
                    if (counter==4) mask(1:3)=[4,5,3]
                    if (counter==5) mask(1:3)=[1,2,6]
                    if (counter==6) mask(1:3)=[4,2,6]
                    if (counter==7) mask(1:3)=[1,5,6]
                    if (counter==8) mask(1:3)=[4,5,6]
                  endif

                  ! Density
                  do s = 1, newspecies%n
                    block%density(s,ii,jj,kk) = 1e-20
                    do sold = 1, oldspecies%n
                      if (newspecies%name(s)==oldspecies%name(sold)) then
                        block%density(s,ii,jj,kk)   = coeffs(1)*oldblock(b)%density(sold,i,j,k)     &
                                                    +  coeffs(2)*oldblock(b)%density(sold,id(mask(1)),j,k)    &
                                                    +  coeffs(3)*oldblock(b)%density(sold,i,id(mask(2)),k)    &
                                                    +  coeffs(4)*oldblock(b)%density(sold,i,j,id(mask(3)))    &
                                                    +  coeffs(5)*oldblock(b)%density(sold,id(mask(1)),id(mask(2)),k)   &
                                                    +  coeffs(6)*oldblock(b)%density(sold,id(mask(1)),j,id(mask(3)))   &
                                                    +  coeffs(7)*oldblock(b)%density(sold,i,id(mask(2)),id(mask(3)))   &
                                                    +  coeffs(8)*oldblock(b)%density(sold,id(mask(1)),id(mask(2)),id(mask(3)))
                        exit
                      endif
                    enddo
                  enddo

                  ! Velocity
                  do cnt = 1, 3
                    block%velocity(cnt,ii,jj,kk)    = coeffs(1)*oldblock(b)%velocity(cnt,i,j,k)     &
                                                    +  coeffs(2)*oldblock(b)%velocity(cnt,id(mask(1)),j,k)    &
                                                    +  coeffs(3)*oldblock(b)%velocity(cnt,i,id(mask(2)),k)    &
                                                    +  coeffs(4)*oldblock(b)%velocity(cnt,i,j,id(mask(3)))    &
                                                    +  coeffs(5)*oldblock(b)%velocity(cnt,id(mask(1)),id(mask(2)),k)   &
                                                    +  coeffs(6)*oldblock(b)%velocity(cnt,id(mask(1)),j,id(mask(3)))   &
                                                    +  coeffs(7)*oldblock(b)%velocity(cnt,i,id(mask(2)),id(mask(3)))   &
                                                    +  coeffs(8)*oldblock(b)%velocity(cnt,id(mask(1)),id(mask(2)),id(mask(3)))
                  enddo

                  ! Pressure
                  block%pressure(ii,jj,kk)    = coeffs(1)*oldblock(b)%pressure(i,j,k)     &
                                              +  coeffs(2)*oldblock(b)%pressure(id(mask(1)),j,k)    &
                                              +  coeffs(3)*oldblock(b)%pressure(i,id(mask(2)),k)    &
                                              +  coeffs(4)*oldblock(b)%pressure(i,j,id(mask(3)))    &
                                              +  coeffs(5)*oldblock(b)%pressure(id(mask(1)),id(mask(2)),k)   &
                                              +  coeffs(6)*oldblock(b)%pressure(id(mask(1)),j,id(mask(3)))   &
                                              +  coeffs(7)*oldblock(b)%pressure(i,id(mask(2)),id(mask(3)))   &
                                              +  coeffs(8)*oldblock(b)%pressure(id(mask(1)),id(mask(2)),id(mask(3)))

                  ! Turbulent properties
                  if (nrans > 0 ) then
                    do cnt = 1, nrans
                    block%turbprop(cnt,ii,jj,kk)    = coeffs(1)*oldblock(b)%turbprop(cnt,i,j,k)     &
                                                    +  coeffs(2)*oldblock(b)%turbprop(cnt,id(mask(1)),j,k)    &
                                                    +  coeffs(3)*oldblock(b)%turbprop(cnt,i,id(mask(2)),k)    &
                                                    +  coeffs(4)*oldblock(b)%turbprop(cnt,i,j,id(mask(3)))    &
                                                    +  coeffs(5)*oldblock(b)%turbprop(cnt,id(mask(1)),id(mask(2)),k)   &
                                                    +  coeffs(6)*oldblock(b)%turbprop(cnt,id(mask(1)),j,id(mask(3)))   &
                                                    +  coeffs(7)*oldblock(b)%turbprop(cnt,i,id(mask(2)),id(mask(3)))   &
                                                    +  coeffs(8)*oldblock(b)%turbprop(cnt,id(mask(1)),id(mask(2)),id(mask(3)))
                    enddo
                  endif

                  counter = counter + 1

                enddo
              enddo
            enddo

          enddo
        enddo
      enddo
      !$omp end parallel


    ! Spcific algorithm for MESH RATIO = 3 (both 2D and 3D)
    elseif (rapNx==3.0) then
      if (verbose) then
        write(*,*) "[LOG] Mesh ratio = 3 - Specific Algorithm"
        write(*,*) "[LOG] 2D works! - GOTTA FIND OUT IF 3D WORKS as well"
        write(*,*)
      endif

      ! Interpolation Coefficients
      if (sym_type=="3D") then
        a0 = 0.
        a1 = 1.
        coeff_c(1:8) = [a1,a0,a0,a0,a0,a0,a0,a0]

        a1 = 2./3.
        a2 = 1./3.
        coeff_cf_i(1:8) = [a1,a2,a0,a0,a0,a0,a0,a0]
        coeff_cf_j(1:8) = [a1,a0,a2,a0,a0,a0,a0,a0] 
        coeff_cf_k(1:8) = [a1,a0,a0,a2,a0,a0,a0,a0]

        a1 = 9./16.
        a2 = 3./16.
        a3 = 1./16.
        coeff_cs_jk(1:8) = [a1,a0,a2,a2,a0,a0,a2,a0]
        coeff_cs_ik(1:8) = [a1,a2,a0,a2,a0,a2,a0,a0]
        coeff_cs_ij(1:8) = [a1,a2,a2,a0,a2,a0,a0,a0]

        a1 = 27./64.
        a2 = 9./64.
        a3 = 3./64.
        a4 = 1./64.
        coeff_v(1:8) = [a1,a2,a2,a2,a3,a3,a3,a4] 
      
      elseif (sym_type=="2D") then
        a0 = 0.
        a1 = 1.
        coeff_c(1:8) = [a1,a0,a0,a0,a0,a0,a0,a0]
        
        a1 = 2./3.
        a2 = 1./3.
        coeff_cf_i(1:8) = [a1,a2,a0,a0,a0,a0,a0,a0]           
        coeff_cf_j(1:8) = [a1,a0,a2,a0,a0,a0,a0,a0]
        
        a1 = 9./16.
        a2 = 3./16.
        a3 = 1./16.
        coeff_v(1:8) = [a1,a2,a2,a0,a3,a0,a0,a0]
      end if


      !$omp parallel private(i,j,k,i2,j2,k2,i2d,j2d,k2d,im,jm,km,ip,jp,kp,id,counter,ii,jj,kk,mask,coeffs,s,sold,cnt)
      !$omp do collapse(3)
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

            id(1:6) = [im,jm,km,ip,jp,kp]

            counter = 1

            do kk = k2d, k2
              do jj = j2d, j2
                do ii = i2d, i2
                  
                  if (sym_type=="2D") then
                    ! k is always a filler for 2D (un-used)
                    if (counter==1) then
                      mask(1:3)=[1,2,3]
                      coeffs = coeff_v
                    endif
                    if (counter==2) then
                      mask(1:3)=[1,2,3] ! Riempitivo i
                      coeffs = coeff_cf_j
                    endif                        
                    if (counter==3) then
                      mask(1:3)=[4,2,3]
                      coeffs = coeff_v
                    endif
                    if (counter==4) then
                      mask(1:3)=[1,2,3] ! Riempitivo j
                      coeffs = coeff_cf_i
                    endif
                    if (counter==5) then
                      mask(1:3)=[1,2,3] ! Riempitivo i,j
                      coeffs = coeff_c
                    endif
                    if (counter==6) then
                      mask(1:3)=[4,2,3] ! Riempitivo j
                      coeffs = coeff_cf_i
                    endif
                    if (counter==7) then
                      mask(1:3)=[1,5,3]
                      coeffs = coeff_v
                    endif
                    if (counter==8) then
                      mask(1:3)=[1,5,3] ! Riempitivo i
                      coeffs = coeff_cf_j
                    endif
                    if (counter==9) then
                      mask(1:3)=[4,5,3]
                      coeffs = coeff_v
                    endif                       
                  endif

                  if(sym_type=="3D") then
                    ! k = 1
                    if (counter==1) then
                      mask(1:3)=[1,2,3]
                      coeffs = coeff_v
                    endif
                    if (counter==2) then
                      mask(1:3)=[1,2,3] ! Riempitivo i
                      coeffs = coeff_cs_jk
                    endif                        
                    if (counter==3) then
                      mask(1:3)=[4,2,3]
                      coeffs = coeff_v
                    endif
                    if (counter==4) then
                      mask(1:3)=[1,2,3] ! Riempitivo j
                      coeffs = coeff_cs_ik
                    endif
                    if (counter==5) then
                      mask(1:3)=[1,2,3] ! Riempitivo i,j
                      coeffs = coeff_cf_k
                    endif
                    if (counter==6) then
                      mask(1:3)=[4,2,3] ! Riempitivo j
                      coeffs = coeff_cs_ik
                    endif
                    if (counter==7) then
                      mask(1:3)=[1,5,3]
                      coeffs = coeff_v
                    endif
                    if (counter==8) then
                      mask(1:3)=[1,5,3] ! Riempitivo i
                      coeffs = coeff_cs_jk
                    endif
                    if (counter==9) then
                      mask(1:3)=[4,5,3]
                      coeffs = coeff_v
                    endif   
                    
                    ! k = 2
                    if (counter==10) then
                      mask(1:3)=[1,2,3] ! Riempitivo k
                      coeffs = coeff_cs_ij
                    endif
                    if (counter==11) then
                      mask(1:3)=[1,2,3] ! Riempitivo i,k
                      coeffs = coeff_cf_j
                    endif                        
                    if (counter==12) then
                      mask(1:3)=[4,2,3] ! Riempitivo k
                      coeffs = coeff_cs_ij
                    endif
                    if (counter==13) then
                      mask(1:3)=[1,2,3] ! Riempitivo j,k
                      coeffs = coeff_cf_i
                    endif
                    if (counter==14) then
                      mask(1:3)=[1,2,3] ! Riempitivo i,j,k
                      coeffs = coeff_c
                    endif
                    if (counter==15) then
                      mask(1:3)=[4,2,3] ! Riempitivo j,k
                      coeffs = coeff_cf_i
                    endif
                    if (counter==16) then
                      mask(1:3)=[1,5,3] ! Riempitivo k
                      coeffs = coeff_cs_ij
                    endif
                    if (counter==17) then
                      mask(1:3)=[1,5,3] ! Riempitivo i,k
                      coeffs = coeff_cf_j
                    endif
                    if (counter==18) then
                      mask(1:3)=[4,5,3] ! Riempitivo k
                      coeffs = coeff_cs_ij
                    endif
                    
                    ! k = 3
                    if (counter==19) then
                      mask(1:3)=[1,2,6]
                      coeffs = coeff_v
                    endif
                    if (counter==20) then
                      mask(1:3)=[1,2,6] ! Riempitivo i
                      coeffs = coeff_cs_jk
                    endif                        
                    if (counter==21) then
                      mask(1:3)=[4,2,6]
                      coeffs = coeff_v
                    endif
                    if (counter==22) then
                      mask(1:3)=[1,2,6] ! Riempitivo j
                      coeffs = coeff_cs_ik
                    endif
                    if (counter==23) then
                      mask(1:3)=[1,2,6] ! Riempitivo i,j
                      coeffs = coeff_cf_k
                    endif
                    if (counter==24) then
                      mask(1:3)=[4,2,6] ! Riempitivo j
                      coeffs = coeff_cs_ik
                    endif
                    if (counter==25) then
                      mask(1:3)=[1,5,6]
                      coeffs = coeff_v
                    endif
                    if (counter==26) then
                      mask(1:3)=[1,5,6] ! Riempitivo i
                      coeffs = coeff_cs_jk
                    endif
                    if (counter==27) then
                      mask(1:3)=[4,5,6]
                      coeffs = coeff_v
                    endif   
                  endif
                  
                  ! Density
                  do s = 1, newspecies%n
                    block%density(s,ii,jj,kk) = 1e-20
                    do sold = 1, oldspecies%n
                      if (newspecies%name(s)==oldspecies%name(sold)) then
                        block%density(s,ii,jj,kk)   =  coeffs(1)*oldblock(b)%density(sold,i,j,k)     &
                                                    +  coeffs(2)*oldblock(b)%density(sold,id(mask(1)),j,k)    &
                                                    +  coeffs(3)*oldblock(b)%density(sold,i,id(mask(2)),k)    &
                                                    +  coeffs(4)*oldblock(b)%density(sold,i,j,id(mask(3)))    &
                                                    +  coeffs(5)*oldblock(b)%density(sold,id(mask(1)),id(mask(2)),k)   &
                                                    +  coeffs(6)*oldblock(b)%density(sold,id(mask(1)),j,id(mask(3)))   &
                                                    +  coeffs(7)*oldblock(b)%density(sold,i,id(mask(2)),id(mask(3)))   &
                                                    +  coeffs(8)*oldblock(b)%density(sold,id(mask(1)),id(mask(2)),id(mask(3)))
                        exit
                      endif
                    enddo
                  end do

                  ! Velocity
                  do cnt = 1, 3
                    block%velocity(cnt,ii,jj,kk)    =  coeffs(1)*oldblock(b)%velocity(cnt,i,j,k)     &
                                                    +  coeffs(2)*oldblock(b)%velocity(cnt,id(mask(1)),j,k)    &
                                                    +  coeffs(3)*oldblock(b)%velocity(cnt,i,id(mask(2)),k)    &
                                                    +  coeffs(4)*oldblock(b)%velocity(cnt,i,j,id(mask(3)))    &
                                                    +  coeffs(5)*oldblock(b)%velocity(cnt,id(mask(1)),id(mask(2)),k)   &
                                                    +  coeffs(6)*oldblock(b)%velocity(cnt,id(mask(1)),j,id(mask(3)))   &
                                                    +  coeffs(7)*oldblock(b)%velocity(cnt,i,id(mask(2)),id(mask(3)))   &
                                                    +  coeffs(8)*oldblock(b)%velocity(cnt,id(mask(1)),id(mask(2)),id(mask(3)))
                  enddo

                  ! Pressure
                  block%pressure(ii,jj,kk)    =  coeffs(1)*oldblock(b)%pressure(i,j,k)     &
                                              +  coeffs(2)*oldblock(b)%pressure(id(mask(1)),j,k)    &
                                              +  coeffs(3)*oldblock(b)%pressure(i,id(mask(2)),k)    &
                                              +  coeffs(4)*oldblock(b)%pressure(i,j,id(mask(3)))    &
                                              +  coeffs(5)*oldblock(b)%pressure(id(mask(1)),id(mask(2)),k)   &
                                              +  coeffs(6)*oldblock(b)%pressure(id(mask(1)),j,id(mask(3)))   &
                                              +  coeffs(7)*oldblock(b)%pressure(i,id(mask(2)),id(mask(3)))   &
                                              +  coeffs(8)*oldblock(b)%pressure(id(mask(1)),id(mask(2)),id(mask(3)))

                  ! Turbulent properties
                  if (nrans > 0 ) then
                    do cnt = 1, nrans
                    block%turbprop(cnt,ii,jj,kk)    =  coeffs(1)*oldblock(b)%turbprop(cnt,i,j,k)     &
                                                    +  coeffs(2)*oldblock(b)%turbprop(cnt,id(mask(1)),j,k)    &
                                                    +  coeffs(3)*oldblock(b)%turbprop(cnt,i,id(mask(2)),k)    &
                                                    +  coeffs(4)*oldblock(b)%turbprop(cnt,i,j,id(mask(3)))    &
                                                    +  coeffs(5)*oldblock(b)%turbprop(cnt,id(mask(1)),id(mask(2)),k)   &
                                                    +  coeffs(6)*oldblock(b)%turbprop(cnt,id(mask(1)),j,id(mask(3)))   &
                                                    +  coeffs(7)*oldblock(b)%turbprop(cnt,i,id(mask(2)),id(mask(3)))   &
                                                    +  coeffs(8)*oldblock(b)%turbprop(cnt,id(mask(1)),id(mask(2)),id(mask(3)))
                    enddo
                  endif
                
                  counter = counter + 1
                
                enddo
              enddo
            enddo
            
          enddo
        enddo
      enddo
      !$omp end parallel


    ! General algorithm for MESH RATIO = integer (both 2D and 3D)
    else
      if (verbose) then
        write(*,*) "[LOG] Mesh ratio = ", rap, " - Generic algorithm"
        write(*,*)
      endif

      !$omp parallel private(i,j,k,indi,indj,indk,s,sold,cnt)
      !$omp do collapse(3)
      do k = 1, block%dim(3)
        do j = 1, block%dim(2)
          do i = 1, block%dim(1)

            indi = (i-1)/rap + 1
            indj = (j-1)/rap + 1
            indk = (k-1)/rap + 1

            ! Density
            do s = 1, newspecies%n
              block%density(s,i,j,k) = 1e-20
              do sold = 1, oldspecies%n
                if (newspecies%name(s)==oldspecies%name(sold)) then
                  block%density(s,i,j,k) = oldblock(b)%density(sold,indi,indj,indk)
                  exit
                endif
              enddo
            enddo

            ! Velocity
            do cnt = 1, 3
              block%velocity(cnt,i,j,k) = oldblock(b)%velocity(cnt,indi,indj,indk)
            enddo

            ! Pressure
            block%pressure(i,j,k) = oldblock(b)%pressure(indi,indj,indk)

            ! Turbulent properties
            if (nrans > 0 ) block%turbprop(1:nrans,i,j,k) = oldblock(b)%turbprop(1:nrans,indi,indj,indk)

          enddo
        enddo
      enddo
      !$omp end parallel
    
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
  integer, dimension(3)                               :: maxdim

  if (verbose) then
    write(*,*)
    write(*,*) "[LOG] Cell Centers Minimum Distance interpolation algorithm"
    write(*,*)
  endif

  ! Compute max dimensions for pre-allocation
  if (oldid == 0) then
    maxdim = 0
    do bb = 1, size(oldblock)
      maxdim(1) = max(maxdim(1), oldblock(bb)%dim(1))
      maxdim(2) = max(maxdim(2), oldblock(bb)%dim(2))
      maxdim(3) = max(maxdim(3), oldblock(bb)%dim(3))
    enddo
  else
    maxdim(1) = oldblock(oldid)%dim(1)
    maxdim(2) = oldblock(oldid)%dim(2)
    maxdim(3) = oldblock(oldid)%dim(3)
  endif

  trueb = 1
  !$omp parallel private(i,j,k,bb,dx,dy,dz,dist,truedist,mindist,indold,ind,trueb,s,sold,cnt)
  allocate(dx(1:maxdim(1),1:maxdim(2),1:maxdim(3)))
  allocate(dy(1:maxdim(1),1:maxdim(2),1:maxdim(3)))
  allocate(dz(1:maxdim(1),1:maxdim(2),1:maxdim(3)))
  allocate(dist(1:maxdim(1),1:maxdim(2),1:maxdim(3)))
  !$omp do collapse(3) schedule(dynamic)
  do k = 1, block%dim(3)
    do j = 1, block%dim(2)
      do i = 1, block%dim(1)

        ! Cell centers minimum distance algorithm
        truedist = 1d+5
        trueb = 1
        if (oldid == 0) then
          do bb = 1, size(oldblock)
            dx(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)) = &
              (block%center(i,j,k)%c(1)-oldblock(bb)%center(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3))%c(1))**2
            dy(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)) = &
              (block%center(i,j,k)%c(2)-oldblock(bb)%center(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3))%c(2))**2
            dz(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)) = &
              (block%center(i,j,k)%c(3)-oldblock(bb)%center(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3))%c(3))**2
            dist(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)) = &
              sqrt(dx(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)) &
                  +dy(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)) &
                  +dz(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)))
            indold = minloc(dist(1:oldblock(bb)%dim(1),1:oldblock(bb)%dim(2),1:oldblock(bb)%dim(3)),MASK=.true.)
            mindist = dist(indold(1),indold(2),indold(3))
            if (mindist<truedist) then
              truedist = mindist
              ind = indold
              trueb = bb
            endif
          enddo

        else
          dx(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)) = &
            (block%center(i,j,k)%c(1)-oldblock(oldid)%center(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3))%c(1))**2
          dy(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)) = &
            (block%center(i,j,k)%c(2)-oldblock(oldid)%center(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3))%c(2))**2
          dz(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)) = &
            (block%center(i,j,k)%c(3)-oldblock(oldid)%center(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3))%c(3))**2
          dist(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)) = &
            sqrt(dx(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)) &
                +dy(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)) &
                +dz(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)))
          indold = minloc(dist(1:oldblock(oldid)%dim(1),1:oldblock(oldid)%dim(2),1:oldblock(oldid)%dim(3)),MASK=.true.)
          mindist = dist(indold(1),indold(2),indold(3))
          if (mindist<truedist) then
            truedist = mindist
            ind = indold
            trueb = oldid
          endif

        endif

        ! Density
        do s = 1, newspecies%n
          block%density(s,i,j,k) = 1e-20
          do sold = 1, oldspecies%n
            if (newspecies%name(s)==oldspecies%name(sold)) then
              block%density(s,i,j,k) = oldblock(trueb)%density(sold,ind(1),ind(2),ind(3))
              exit
            endif
          enddo
        enddo

        ! Velocity
        do cnt = 1, 3
          block%velocity(cnt,i,j,k) = oldblock(trueb)%velocity(cnt,ind(1),ind(2),ind(3))
        end do

        ! Pressure
        block%pressure(i,j,k) = oldblock(trueb)%pressure(ind(1),ind(2),ind(3))

        ! Turbulent properties
        if (nrans > 0 ) block%turbprop(1:nrans,i,j,k) = oldblock(trueb)%turbprop(1:nrans,ind(1),ind(2),ind(3))

      enddo
    enddo
  enddo
  deallocate(dx); deallocate(dy); deallocate(dz); deallocate(dist)
  !$omp end parallel

end subroutine distance_interpolation


subroutine spherical_distance_interpolation
  implicit none
  integer                                             :: c, ii, jj, kk
  real(kind=R8)                                       :: r, xc, yc, zc, x, y, z, dx, dy, dz
  real(kind=R8)                                       :: dist, truedist

  if (verbose) then
    write(*,*)
    write(*,*) "[LOG] Cell Centers Spherical Minimum Distance interpolation algorithm"
    write(*,*)
  endif

  call block%compute_bounding([0,0,0])

  !$omp parallel private(i,j,k,c,r,xc,yc,zc,dx,dy,dz,x,y,z,dist,truedist,trueb,ind,ii,jj,kk,bb,s,sold,cnt)
  !$omp do collapse(3) schedule(dynamic)
  do k = 1, block%dim(3)
    do j = 1, block%dim(2)
      do i = 1, block%dim(1)

        xc = block%center(i,j,k)%c(1)
        yc = block%center(i,j,k)%c(2)
        zc = block%center(i,j,k)%c(3)
        dx = block%bbmax(i,j,k)%c(1) - block%bbmin(i,j,k)%c(1)
        dy = block%bbmax(i,j,k)%c(2) - block%bbmin(i,j,k)%c(2)
        dz = block%bbmax(i,j,k)%c(3) - block%bbmin(i,j,k)%c(3)
        truedist = 1d+5
        r = 0.0
        c = 0

        if (oldid == 0) then

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

        else

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
                      trueb = oldid
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

        endif


        ! Density
        do s = 1, newspecies%n
          block%density(s,i,j,k) = 1e-20
          do sold = 1, oldspecies%n
            if (newspecies%name(s)==oldspecies%name(sold)) then
              block%density(s,i,j,k) = oldblock(trueb)%density(sold,ind(1),ind(2),ind(3))
              exit
            endif
          enddo
        enddo

        ! Velocity
        do cnt = 1, 3
          block%velocity(cnt,i,j,k) = oldblock(trueb)%velocity(cnt,ind(1),ind(2),ind(3))
        end do

        ! Pressure
        block%pressure(i,j,k) = oldblock(trueb)%pressure(ind(1),ind(2),ind(3))

        ! Turbulent properties
        if (nrans > 0 ) block%turbprop(1:nrans,i,j,k) = oldblock(trueb)%turbprop(1:nrans,ind(1),ind(2),ind(3))

      enddo
    enddo
  enddo
  !$omp end parallel

end subroutine spherical_distance_interpolation

end subroutine intersol

end module Interpolator_IG
