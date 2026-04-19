module ic_interpolation_old_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use global_mod
  use config_mod,    only: config_interpolation
  use ic_block_mod,  only: IC_block
  use io_fields_mod, only: read_vtk_tec
  use Lib_ORION_data
  implicit none

  real(R8), parameter   :: pi=4.0*atan(1.0)

  type(IC_block), dimension(:), allocatable    :: oldblock
  character(len=llen)                          :: oldsolutionfile


contains


  subroutine build_old_solution(oldsolutionfile_, phase)
    implicit none
    character(len=llen), intent(inout) :: oldsolutionfile_
    character(len=*),    intent(in)    :: phase
    !! Local
    real(R8), allocatable :: mesh(:,:,:,:)
    real(R8), allocatable :: theta(:)
    real(R8)              :: thetamax_extrude
    integer(I4)           :: nz
    integer :: i, j, k, b

    nz = config_interpolation % nz
    thetamax_extrude = config_interpolation % theta

    oldsolutionfile = oldsolutionfile_

    allocate(theta(1:nz+1))

    if (verbose) write(*,*)" Reading solution file: ", trim(oldsolutionfile)
    call read_vtk_tec(phase,oldsolutionfile,oldblock)

    if (config_interpolation % law=='extrude') then

      if (verbose) then
        write(*,*)" Old mesh extrusion"
        write(*,*)" Extrusion angle    = ", thetamax_extrude
        write(*,*)" Extrusion elements = ", nz
      endif

      do i = 1, nz+1
        theta(i) = (thetamax_extrude*pi/180_R8)/nz*i
      enddo

      allocate(mesh(1:3,0:maxval(oldblock(:)%dim(1)),0:maxval(oldblock(:)%dim(2)),0:1))

      do b = 1, size(oldblock)
        ! Dummy 2D mesh allocated and initialized before new allocation of oldblock
        do i = 0, oldblock(b)%dim(1); do j = 0, oldblock(b)%dim(2); do k = 0, oldblock(b)%dim(3)
              mesh(:,i,j,k) = oldblock(b)%node(i,j,k)%c(1:3)
        enddo; enddo; enddo
        deallocate(oldblock(b)%node)
        oldblock(b)%dim(3) = nz
        allocate(oldblock(b)%node(0:oldblock(b)%dim(1),0:oldblock(b)%dim(2),0:oldblock(b)%dim(3)))
        do i = 0, oldblock(b)%dim(1); do j = 0, oldblock(b)%dim(2); do k = 0, oldblock(b)%dim(3)
              oldblock(b)%node(i,j,k)%c(1) = mesh(1,i,j,1)
              oldblock(b)%node(i,j,k)%c(2) = mesh(2,i,j,1)*cos(theta(k+1))
              oldblock(b)%node(i,j,k)%c(3) = mesh(2,i,j,1)*sin(theta(k+1))
        enddo; enddo; enddo
      enddo
      
      do i = 1, nz
        theta(i) = (thetamax_extrude*pi/180_R8)/nz*i
      enddo

      select case(phase)

      case('SP')
        do b = 1, size(oldblock)
          do k = 1, oldblock(b)%dim(3)
            oldblock(b)%sp%temperature(:,:,k) = oldblock(b)%sp%temperature(:,:,1)
            oldblock(b)%sp%mID(:,:,k) = oldblock(b)%sp%mID(:,:,1)
            oldblock(b)%sp%qvol(:,:,k) = oldblock(b)%sp%qvol(:,:,1)
          enddo
        enddo

      case('IG')
        do b = 1, size(oldblock)
          do k = 1, oldblock(b)%dim(3)
            oldblock(b)%ig%density(:,:,:,k) = oldblock(b)%ig%density(:,:,:,1)
            oldblock(b)%ig%velocity(1,:,:,k) = oldblock(b)%ig%velocity(1,:,:,1)
            oldblock(b)%ig%velocity(2,:,:,k) = oldblock(b)%ig%velocity(2,:,:,1)*cos(theta(k))
            oldblock(b)%ig%velocity(3,:,:,k) = oldblock(b)%ig%velocity(2,:,:,1)*sin(theta(k))
            oldblock(b)%ig%pressure(:,:,k) = oldblock(b)%ig%pressure(:,:,1)
            if (oldblock(b)%nrans>0) oldblock(b)%ig%turbprop(1:oldblock(b)%nrans,:,:,k) = &
              oldblock(b)%ig%turbprop(1:oldblock(b)%nrans,:,:,1)
          enddo
        enddo

      case('RF')
        do b = 1, size(oldblock)
          do k = 1, oldblock(b)%dim(3)
            oldblock(b)%rf%enthalpy(:,:,k) = oldblock(b)%rf%enthalpy(:,:,1)
            oldblock(b)%rf%pressure(:,:,k) = oldblock(b)%rf%pressure(:,:,1)
            oldblock(b)%rf%velocity(1,:,:,k) = oldblock(b)%rf%velocity(1,:,:,1)
            oldblock(b)%rf%velocity(2,:,:,k) = oldblock(b)%rf%velocity(2,:,:,1)*cos(theta(k))
            oldblock(b)%rf%velocity(3,:,:,k) = oldblock(b)%rf%velocity(2,:,:,1)*sin(theta(k))
            if (oldblock(b)%nrans>0) oldblock(b)%rf%turbprop(1:oldblock(b)%nrans,:,:,k) = &
              oldblock(b)%rf%turbprop(1:oldblock(b)%nrans,:,:,1)
          enddo
        enddo

      case('CD')
        do b = 1, size(oldblock)
          do k = 1, oldblock(b)%dim(3)
            oldblock(b)%dp%density(:,:,:,k)          = oldblock(b)%dp%density(:,:,:,1)
            oldblock(b)%dp%velocity(:,1,:,:,k)       = oldblock(b)%dp%velocity(:,1,:,:,1)
            oldblock(b)%dp%velocity(:,2,:,:,k)       = oldblock(b)%dp%velocity(:,2,:,:,1)*cos(theta(k))
            oldblock(b)%dp%velocity(:,3,:,:,k)       = oldblock(b)%dp%velocity(:,2,:,:,1)*sin(theta(k))
            oldblock(b)%dp%temperature(:,:,:,k)      = oldblock(b)%dp%temperature(:,:,:,1)
            oldblock(b)%dp%nP(:,:,:,k)               = oldblock(b)%dp%nP(:,:,:,1)
            oldblock(b)%dp%pseudopressure(:,:,:,k)   = oldblock(b)%dp%pseudopressure(:,:,:,1)
          enddo
        enddo

      end select

      if (verbose) write(*,*) "[LOG] Old solution built"

    endif

  end subroutine build_old_solution


  subroutine ensure_old_solution(oldsolutionfile_, phase)
    implicit none
    character(len=llen), intent(inout) :: oldsolutionfile_
    character(len=*),    intent(in)    :: phase

    if (.not. allocated(oldblock)) then
      call build_old_solution(oldsolutionfile_, phase)
    elseif (oldsolutionfile_ /= oldsolutionfile) then
      deallocate(oldblock)
      call build_old_solution(oldsolutionfile_, phase)
    endif
  end subroutine ensure_old_solution

end module ic_interpolation_old_mod
