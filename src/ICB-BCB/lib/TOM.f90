!>@brief: Module for geometrical derived data types. 
module TOM
  implicit none

  integer, parameter   :: gc=2       !> number of ghost layers
  integer              :: meshType   !> 1 -> 1D, 2 -> 2D, 3 -> 3D
  real(kind=8), public :: delthe     !> grid axisymmetric angle


  !% 3D tensor object. All static components.
  type :: tensor_3D_type
    real(kind=8)                 :: c(3,3)           !> Metric tensor components.
  end type tensor_3D_type
  ! - 

  !% 3D vector object. All static components.
  type :: vector_nD_type
    real(kind=8), allocatable   :: c(:)              !> Average cell length components.
  end type vector_nD_type
  ! - 

  !% Rank 3, 3D tensor object. All static components.
  type :: tensor_3D_R3_type
    real(kind=8)                 :: c(3,3,3)         !> Metric tensor components.
  end type tensor_3D_R3_type
  ! - 

  !% Object for the storage of metric quantities in a face. All static components.
  type :: f_metrics_type
    real(kind=8), dimension(3)   :: n                !> Unit normal vector.
    real(kind=8)                 :: a                !> Interface area.
  end type f_metrics_type
  ! -

  !% Object for the storage cell faces along a grid direction. Allocatable.
  type :: d_metrics_type
    type(f_metrics_type), allocatable  :: f(:,:,:)   
  end type d_metrics_type
  ! -

  !% Baseline object for a block. Contains dimensions, and allocatable metric-related objects.
  !% Refer to this as ..%block(b)%dim(d), ..%block(b)%node(i,j,k)%c(l), ..%block(b)%vol(i,j,k) etc.
  type :: block_type
    integer                            :: dim(3)                      !> Number of cells in i-j-k (ghost not included).
    real(kind=8),         allocatable  :: vol(:,:,:)                  !> Cell volume.
    type(vector_nD_type), allocatable  :: node(:,:,:)                 !> Mesh grid points (including ghost).
    type(vector_nD_type), allocatable  :: center(:,:,:)
    type(tensor_3D_type), allocatable  :: m(:,:,:)                    !> Metric transformation tensor.
    type(vector_nD_type), allocatable  :: dl(:,:,:)                   !> Average cell length (in i/j/k direction). eg: dl%c(1) is sqrt(dx**2+dy**2+dz**2) of the cell in the i direction.
    type(d_metrics_type)               :: dir(3)                      !> Direction object. Contains: i-faces, j-faces, k-faces; eg: dir(1)%face(i,j,k)%n.
    ! Chimera
    real(8)                            :: block_bounding_min(3)
    real(8)                            :: block_bounding_max(3)
    type(vector_nD_type), allocatable  :: bbmin(:,:,:)
    type(vector_nD_type), allocatable  :: bbmax(:,:,:)
    ! Turbulence
    real(kind=8),         allocatable  :: yn(:,:,:)                   !> Nearest wall distance.
  contains
    private
    procedure, pass(self), public :: extrapolate_nodes
    procedure, pass(self), public :: compute_centers
    procedure, pass(b), public :: compute_norm_area_volume
    procedure, pass(b), public :: compute_metric_tensor
    procedure, pass(self), public :: compute_bounding
  end type block_type
  ! -

contains

!>@brief: legacy subroutine from AFFS gridfile to compute interface areas, normal vectors and cell volumes for a block
subroutine compute_norm_area_volume( b )
  implicit none
  class(block_type), intent(inout) :: b
  ! Local
  real(kind=8) :: Ai, snix, sniy, sniz,  Aj, snjx, snjy, snjz, Ak, snkx, snky, snkz, vol
  integer      :: i, j, k, im, jm, km
  real(kind=8) :: d1(3), d2(3), d3(3), vx(8), vy(8), vz(8)
  real(kind=8) :: snixx, sniyy, snizz, snjxx, snjyy, snjzz, snkxx, snkyy, snkzz
  real(kind=8) :: scal, signi, signj, signk

  ! Peliminary operations
  im = b%dim(1)
  jm = b%dim(2)
  km = b%dim(3)

  ! compute sign of normal vectors to the intefaces

  !------------------------------------------------------------------------------------------------
  ! i direction
  d1 = b%node(1,1,1)%c - b%node(1,0,0)%c
  d2 = b%node(1,0,1)%c - b%node(1,1,0)%c

  d3(1)=(d1(2)*d2(3)-d1(3)*d2(2))
  d3(2)=(d1(3)*d2(1)-d1(1)*d2(3))
  d3(3)=(d1(1)*d2(2)-d1(2)*d2(1))

  snixx=d3(1)
  sniyy=d3(2)
  snizz=d3(3)

  d1 = 0.25d0*( b%node(1,1,1)%c + b%node(1,0,1)%c + b%node(1,0,0)%c + b%node(1,1,0)%c )
  d2 = 0.25d0*( b%node(0,1,1)%c + b%node(0,0,1)%c + b%node(0,0,0)%c + b%node(0,1,0)%c )

  d3(1)=d1(1)-d2(1)
  d3(2)=d1(2)-d2(2)
  d3(3)=d1(3)-d2(3)

  scal=d3(1)*snixx+d3(2)*sniyy+d3(3)*snizz

  signi=sign(1.d0,scal)
!------------------------------------------------------------------------------------------------
  ! j direction
  d1 = b%node(0,1,1)%c - b%node(1,1,0)%c
  d2 = b%node(1,1,1)%c - b%node(0,1,0)%c

  d3(1)=(d1(2)*d2(3)-d1(3)*d2(2))
  d3(2)=(d1(3)*d2(1)-d1(1)*d2(3))
  d3(3)=(d1(1)*d2(2)-d1(2)*d2(1))

  snjxx=d3(1)
  snjyy=d3(2)
  snjzz=d3(3)

  d1 = 0.25d0*( b%node(1,1,1)%c + b%node(0,1,1)%c + b%node(0,1,0)%c + b%node(1,1,0)%c )
  d2 = 0.25d0*( b%node(1,0,1)%c + b%node(0,0,1)%c + b%node(0,0,0)%c + b%node(1,0,0)%c )

  d3(1)=d1(1)-d2(1)
  d3(2)=d1(2)-d2(2)
  d3(3)=d1(3)-d2(3)

  scal=d3(1)*snjxx+d3(2)*snjyy+d3(3)*snjzz

  signj=sign(1.d0,scal)
!------------------------------------------------------------------------------------------------
  ! k direction
  d1 = b%node(0,1,1)%c - b%node(1,0,1)%c
  d2 = b%node(0,0,1)%c - b%node(1,1,1)%c

  d3(1)=(d1(2)*d2(3)-d1(3)*d2(2))
  d3(2)=(d1(3)*d2(1)-d1(1)*d2(3))
  d3(3)=(d1(1)*d2(2)-d1(2)*d2(1))

  snkxx=d3(1)
  snkyy=d3(2)
  snkzz=d3(3)

  d1 = 0.25d0*( b%node(1,1,1)%c + b%node(0,1,1)%c + b%node(0,0,1)%c + b%node(1,0,1)%c )
  d2 = 0.25d0*( b%node(1,1,0)%c + b%node(0,1,0)%c + b%node(0,0,0)%c + b%node(1,0,0)%c )

  d3(1)=d1(1)-d2(1)
  d3(2)=d1(2)-d2(2)
  d3(3)=d1(3)-d2(3)

  scal=d3(1)*snkxx+d3(2)*snkyy+d3(3)*snkzz

  signk=sign(1.d0,scal)
!------------------------------------------------------------------------------------------------
  
  ! compute metrics: n, A
  
  !$omp parallel private (d1,d2,d3,i,j,k,snix,sniy,sniz,Ai,Aj,snjx,snjy,snjz,Ak,snkx,snky,snkz), &
  !$omp private (vx,vy,vz,vol)
  
  ! i direction
  !$omp do collapse(3)
  do k = 1, km ; do j = 1, jm ; do i = 0, im

    d1 = b%node(i,j,k)%c - b%node(i,j-1,k-1)%c
    d2 = b%node(i,j-1,k)%c - b%node(i,j,k-1)%c

    d3(1)=(d1(2)*d2(3)-d1(3)*d2(2))*.5d0
    d3(2)=(d1(3)*d2(1)-d1(1)*d2(3))*.5d0
    d3(3)=(d1(1)*d2(2)-d1(2)*d2(1))*.5d0

    Ai = sqrt(d3(1)**2+d3(2)**2+d3(3)**2)

    snix = d3(1)/Ai*signi
    sniy = d3(2)/Ai*signi
    sniz = d3(3)/Ai*signi

    if (Ai == 0d0) then
      snix = 0d0
      sniy = 0d0
      sniz = 0d0
    end if

    !% Assign computed normal and area to metrics object
    b%dir(1)%f(i,j,k)%a = Ai
    b%dir(1)%f(i,j,k)%n = [ snix, sniy, sniz ]
    
  end do ; end do ; end do

  ! j direction
  !$omp do collapse(3)
  do k = 1, km ; do j = 0, jm ; do  i = 1, im

    d1 = b%node(i-1,j,k)%c - b%node(i,j,k-1)%c
    d2 = b%node(i,j,k)%c - b%node(i-1,j,k-1)%c

    d3(1)=(d1(2)*d2(3)-d1(3)*d2(2))*.5d0
    d3(2)=(d1(3)*d2(1)-d1(1)*d2(3))*.5d0
    d3(3)=(d1(1)*d2(2)-d1(2)*d2(1))*.5d0

    Aj = sqrt(d3(1)**2+d3(2)**2+d3(3)**2)

    snjx = d3(1)/Aj*signj
    snjy = d3(2)/Aj*signj
    snjz = d3(3)/Aj*signj

    if (Aj == 0d0) then
      snjx = 0d0
      snjy = 0d0
      snjz = 0d0
    end if

    !% Assign computed normal and area to metrics object
    b%dir(2)%f(i,j,k)%A = Aj
    b%dir(2)%f(i,j,k)%n = [ snjx, snjy, snjz ]

  end do ; end do ; end do

  ! k direction
  !$omp do collapse(3)
  do k = 0, km ; do j = 1, jm ; do i = 1, im

    d1 = b%node(i-1,j,k)%c - b%node(i,j-1,k)%c
    d2 = b%node(i-1,j-1,k)%c - b%node(i,j,k)%c

    d3(1)=(d1(2)*d2(3)-d1(3)*d2(2))*.5d0
    d3(2)=(d1(3)*d2(1)-d1(1)*d2(3))*.5d0
    d3(3)=(d1(1)*d2(2)-d1(2)*d2(1))*.5d0

    Ak = sqrt(d3(1)**2+d3(2)**2+d3(3)**2)

    snkx = d3(1)/Ak*signk
    snky = d3(2)/Ak*signk
    snkz = d3(3)/Ak*signk

    if (Ak == 0d0) then
      snkx = 0d0
      snky = 0d0
      snkz = 0d0
    end if

    !% Assign computed normal and area to metrics object
    b%dir(3)%f(i,j,k)%A = Ak
    b%dir(3)%f(i,j,k)%n = [ snkx, snky, snkz ]

  end do ; end do ; end do

  ! cell volume computation
  !$omp do collapse(3)
  do k = 1, km ; do j = 1, jm ; do i = 1, im

    vx(1)=b%node(i-1,j-1,k-1)%c(1)
    vy(1)=b%node(i-1,j-1,k-1)%c(2)
    vz(1)=b%node(i-1,j-1,k-1)%c(3)

    vx(2)=b%node(i  ,j-1,k-1)%c(1)
    vy(2)=b%node(i  ,j-1,k-1)%c(2)
    vz(2)=b%node(i  ,j-1,k-1)%c(3)

    vx(3)=b%node(i-1,j  ,k-1)%c(1)
    vy(3)=b%node(i-1,j  ,k-1)%c(2)
    vz(3)=b%node(i-1,j  ,k-1)%c(3)

    vx(4)=b%node(i  ,j  ,k-1)%c(1)
    vy(4)=b%node(i  ,j  ,k-1)%c(2)
    vz(4)=b%node(i  ,j  ,k-1)%c(3)

    vx(5)=b%node(i-1,j-1,k  )%c(1)
    vy(5)=b%node(i-1,j-1,k  )%c(2)
    vz(5)=b%node(i-1,j-1,k  )%c(3)

    vx(6)=b%node(i  ,j-1,k  )%c(1)
    vy(6)=b%node(i  ,j-1,k  )%c(2)
    vz(6)=b%node(i  ,j-1,k  )%c(3)

    vx(7)=b%node(i-1,j  ,k  )%c(1)
    vy(7)=b%node(i-1,j  ,k  )%c(2)
    vz(7)=b%node(i-1,j  ,k  )%c(3)

    vx(8)=b%node(i  ,j  ,k  )%c(1)
    vy(8)=b%node(i  ,j  ,k  )%c(2)
    vz(8)=b%node(i  ,j  ,k  )%c(3)


    vol = tvol(vx,vy,vz,1,2,3,5) + tvol(vx,vy,vz,2,4,3,8) &
        + tvol(vx,vy,vz,5,8,6,2) + tvol(vx,vy,vz,5,7,8,3) &
        + tvol(vx,vy,vz,5,8,2,3)

    if( vol <= 0d0 ) then
      write(*,*) 'Negative volume in i,j,k', i, j, k
      stop
    endif

    !% Assign computed volume to metrics object
    b%vol(i,j,k) = vol
  end do ; end do ; end do

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

  end subroutine compute_norm_area_volume


  !>@brief: legacy subroutine from AFFS gridfile to compute metric tensor
  subroutine compute_metric_tensor( b )
    implicit none
    class(block_type), intent(inout) :: b 
    ! Local
    integer :: i, j, k, im, jm, km, h
    real(kind=8) :: det, A(3,3), cofactor(3,3)

    im = b%dim(1) ; jm = b%dim(2) ; km = b%dim(3)

    ! Compute average cell dimension. A is M^-1, inverse of metric tensor.
    ! M1 = [ xcs, ycs, zcs ; xet, yet, zet ; xzi, yzi, zzi ].
    
    !$omp parallel do collapse(3), private(i, j, k, h, A, det, cofactor), shared(b, im, km)

    do k = 0, km+1 
    do j = 0, jm+1
    do i = 0, im+1

      A(1,:) = b%node(i  ,j  ,k  )%c - b%node(i-1,j  ,k  )%c + &
               b%node(i  ,j-1,k  )%c - b%node(i-1,j-1,k  )%c + &
               b%node(i  ,j  ,k-1)%c - b%node(i-1,j  ,k-1)%c + &
               b%node(i  ,j-1,k-1)%c - b%node(i-1,j-1,k-1)%c

      A(2,:) = b%node(i  ,j  ,k  )%c - b%node(i  ,j-1,k  )%c + &
               b%node(i-1,j  ,k  )%c - b%node(i-1,j-1,k  )%c + &
               b%node(i  ,j  ,k-1)%c - b%node(i  ,j-1,k-1)%c + &
               b%node(i-1,j  ,k-1)%c - b%node(i-1,j-1,k-1)%c

      A(3,:) = b%node(i  ,j  ,k  )%c - b%node(i  ,j  ,k-1)%c + &
               b%node(i-1,j  ,k  )%c - b%node(i-1,j  ,k-1)%c + &
               b%node(i  ,j-1,k  )%c - b%node(i  ,j-1,k-1)%c + &
               b%node(i-1,j-1,k  )%c - b%node(i-1,j-1,k-1)%c

      A = 0.25d0 * A

      ! Determinant of M^-1.
      det = A(1,1)*A(2,2)*A(3,3) - A(1,1)*A(2,3)*A(3,2)  &
          - A(1,2)*A(2,1)*A(3,3) + A(1,2)*A(2,3)*A(3,1)  &
          + A(1,3)*A(2,1)*A(3,2) - A(1,3)*A(2,2)*A(3,1)

      if ( abs(det) == 0d0 ) then
        write(*,'(A41,3I4,A43)') ' WARNING - Metric tensor det=0 in i,j,k: ', i,j,k,'. Should not happen, but going on with M==I'

        b%M(i,j,k)%c = 0d0
        do h = 1, 3
          b%M(i,j,k)%c(h,h) = 1d0
        end do

      else
        
        cofactor(1,1) =  (A(2,2)*A(3,3)-A(2,3)*A(3,2))
        cofactor(1,2) = -(A(2,1)*A(3,3)-A(2,3)*A(3,1))
        cofactor(1,3) =  (A(2,1)*A(3,2)-A(2,2)*A(3,1))
        cofactor(2,1) = -(A(1,2)*A(3,3)-A(1,3)*A(3,2))
        cofactor(2,2) =  (A(1,1)*A(3,3)-A(1,3)*A(3,1))
        cofactor(2,3) = -(A(1,1)*A(3,2)-A(1,2)*A(3,1))
        cofactor(3,1) =  (A(1,2)*A(2,3)-A(1,3)*A(2,2))
        cofactor(3,2) = -(A(1,1)*A(2,3)-A(1,3)*A(2,1))
        cofactor(3,3) =  (A(1,1)*A(2,2)-A(1,2)*A(2,1))

        b%M(i,j,k)%c = transpose(cofactor) / det

      end if

      ! Cell length in i,j,k.
      do h = 1, 3
        b%dl(i,j,k)%c(h) = sqrt( A(h,1)**2 + A(h,2)**2 + A(h,3)**2 )
      end do

    end do 
    end do
    end do


  end subroutine compute_metric_tensor


  !>@brief: Extrapolate ghost cell nodes with 2nd order accuracy.
  subroutine extrapolate_nodes(self, gc)
    implicit none
    class(block_type), intent(inout) :: self
    integer, intent(in) :: gc
    integer :: im, jm, km
    integer :: i, j, k, n

    im = self%dim(1); jm = self%dim(2); km = self%dim(3)

    ! i-faces
    do k = 0, km ; do j = 0, jm
      do n = 1, gc
        self%node(-n,j,k)%c = 3d0*self%node(-n+1,j,k)%c - 3d0*self%node(-n+2,j,k)%c + self%node(-n+3,j,k)%c
        self%node(im+n,j,k)%c = 3d0*self%node(im+n-1,j,k)%c -3d0*self%node(im+n-2,j,k)%c + self%node(im+n-3,j,k)%c
      end do
    enddo ; enddo

    ! j-faces
    if ( jm > 2 ) then

      do k = 0, km ; do i = -1, im+1
        do n = 1, gc
          self%node(i,0-n,k)%c  = 3d0*self%node(i,-n+1,k)%c  - 3d0*self%node(i,-n+2,k)%c   + self%node(i,-n+3,k)%c
          self%node(i,jm+n,k)%c = 3d0*self%node(i,jm+n-1,k)%c -3d0*self%node(i,jm+n-2,k)%c + self%node(i,jm+n-3,k)%c
        end do
      enddo ; enddo

    else

      do k = 0, km ; do i = -1, im+1
        do n = 1, gc
          self%node(i,-n,k)%c =   2d0*self%node(i,-n+1,k)%c   - self%node(i,-n+2,k)%c
          self%node(i,jm+n,k)%c = 2d0*self%node(i,jm+n-1,k)%c - self%node(i,jm+n-2,k)%c
        enddo
      end do ; end do

    endif

    ! k-faces
    if ( meshType==2 .and. delthe==0d0 .or. meshType==1 ) then
      ! 2D: extrapolation with only two nodes (exact).
      do j = -1, jm+1 ; do i = -1, im+1
        do n = 1, gc
          self%node(i,j,-n)%c =   2d0*self%node(i,j,-n+1)%c   - self%node(i,j,-n+2)%c
          self%node(i,j,km+n)%c = 2d0*self%node(i,j,km+n-1)%c - self%node(i,j,km+n-2)%c
        enddo
      end do ; end do
    elseif (meshType==2 .and. delthe/=0d0) then
      ! 2Dax: extrapolation with a rotation angle delthe (exact).
      do j = -1, jm+1 ; do i = -1, im+1
        do n = 1, gc
          self%node(i,j,-n)%c(1) = self%node(i,j,-n+1)%c(1)
          self%node(i,j,km+n)%c(1) = self%node(i,j,km+n-1)%c(1) ! same x
            
          self%node(i,j,-n)%c(2) = self%node(i,j,-n+1)%c(2)/cos(delthe*(0.5d0+n-1))*cos(delthe*(0.5d0+n))
          self%node(i,j,-n)%c(3) = self%node(i,j,-n+1)%c(3)/sin(delthe*(0.5d0+n-1))*sin(delthe*(0.5d0+n))

          self%node(i,j,km+n)%c(2) = self%node(i,j,-n)%c(2)
          self%node(i,j,km+n)%c(3) = -self%node(i,j,-n)%c(3)
        end do
      end do ; end do

    elseif (meshType==3) then
      do j = -1, jm+1 ; do i = -1, im+1
        do n = 1, gc
          self%node(i,j,-n)%c   = 3d0*self%node(i,j,-n+1)%c  - 3d0*self%node(i,j,-n+2)%c   + self%node(i,j,-n+3)%c
          self%node(i,j,km+n)%c = 3d0*self%node(i,j,km+n-1)%c -3d0*self%node(i,j,km+n-2)%c + self%node(i,j,km+n-3)%c
        end do
      end do ; end do
      
    endif

    ! Extrapolate edge nodes
    
    ! Edge 3-1
    i = -1; j = -1
    do k = -1, km+1
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j+1,k)%c - 3d0*self%node(i,j+2,k)%c + self%node(i,j+3,k)%c + &
                                    3d0*self%node(i+1,j,k)%c - 3d0*self%node(i+2,j,k)%c + self%node(i+3,j,k)%c)
    enddo
    ! Edge 4-1
    i = -1; j = jm+1
    do k = -1, km+1
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j-1,k)%c - 3d0*self%node(i,j-2,k)%c + self%node(i,j-3,k)%c + &
                                    3d0*self%node(i+1,j,k)%c - 3d0*self%node(i+2,j,k)%c + self%node(i+3,j,k)%c)
    enddo
    ! Edge 5-1
    i = -1; k = -1
    do j = -1, jm+1
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j,k+1)%c - 3d0*self%node(i,j,k+2)%c + self%node(i,j,k+3)%c + &
                                    3d0*self%node(i+1,j,k)%c - 3d0*self%node(i+2,j,k)%c + self%node(i+3,j,k)%c)
    enddo
    ! Edge 6-1
    i = -1; k = km+1
    do j = -1, jm+1
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j,k-1)%c - 3d0*self%node(i,j,k-2)%c + self%node(i,j,k-3)%c + &
                                    3d0*self%node(i+1,j,k)%c - 3d0*self%node(i+2,j,k)%c + self%node(i+3,j,k)%c)
    enddo
    
    ! Edge 3-2
    i = im+1; j = -1
    do k = -1, km+1
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j+1,k)%c - 3d0*self%node(i,j+2,k)%c + self%node(i,j+3,k)%c + &
                                    3d0*self%node(i-1,j,k)%c - 3d0*self%node(i-2,j,k)%c + self%node(i-3,j,k)%c)
    enddo
    ! Edge 4-2
    i = im+1; j = jm+1
    do k = -1, km+1
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j-1,k)%c - 3d0*self%node(i,j-2,k)%c + self%node(i,j-3,k)%c + &
                                    3d0*self%node(i-1,j,k)%c - 3d0*self%node(i-2,j,k)%c + self%node(i-3,j,k)%c)
    enddo
    ! Edge 5-2
    i = im+1; k = -1
    do j = -1, jm+1
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j,k+1)%c - 3d0*self%node(i,j,k+2)%c + self%node(i,j,k+3)%c + &
                                    3d0*self%node(i-1,j,k)%c - 3d0*self%node(i-2,j,k)%c + self%node(i-3,j,k)%c)
    enddo
    ! Edge 6-2
    i = im+1; k = km+1
    do j = -1, jm+1
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j,k-1)%c - 3d0*self%node(i,j,k-2)%c + self%node(i,j,k-3)%c + &
                                    3d0*self%node(i-1,j,k)%c - 3d0*self%node(i-2,j,k)%c + self%node(i-3,j,k)%c)
    enddo

    ! Edge 3-5
    j = -1; k = -1
    do i = 0, im
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j,k+1)%c - 3d0*self%node(i,j,k+2)%c + self%node(i,j,k+3)%c + &
                                    3d0*self%node(i,j+1,k)%c - 3d0*self%node(i,j+2,k)%c + self%node(i,j+3,k)%c)
    enddo
    ! Edge 4-5
    j = jm+1; k = -1
    do i = 0, im
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j,k+1)%c - 3d0*self%node(i,j,k+2)%c + self%node(i,j,k+3)%c + &
                                    3d0*self%node(i,j-1,k)%c - 3d0*self%node(i,j-2,k)%c + self%node(i,j-3,k)%c)
    enddo
    ! Edge 3-6
    j = -1; k = km+1
    do i = 0, im
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j,k-1)%c - 3d0*self%node(i,j,k-2)%c + self%node(i,j,k-3)%c + &
                                    3d0*self%node(i,j+1,k)%c - 3d0*self%node(i,j+2,k)%c + self%node(i,j+3,k)%c)
    enddo
    ! Edge 4-6
    j = jm+1; k = km+1
    do i = 0, im
      self%node(i,j,k)%c = 0.5*(3d0*self%node(i,j,k-1)%c - 3d0*self%node(i,j,k-2)%c + self%node(i,j,k-3)%c + &
                                    3d0*self%node(i,j-1,k)%c - 3d0*self%node(i,j-2,k)%c + self%node(i,j-3,k)%c)
    enddo

  end subroutine extrapolate_nodes


  !> Check mesh type 
  subroutine check_mesh_type( blk )
    use, intrinsic :: iso_fortran_env, only : iostat_end
    implicit none
    type(block_type), intent(in) :: blk
    real(8)                      :: theta1, theta2, theta(2)

    ! Mesh definition (2D,2Daxi,3D)
    if (Blk%dim(3)>1) then
      ! 3D
      meshType = 3
    elseif (Blk%dim(3)==1 .and. Blk%dim(2)==1) then
      ! 1D
      meshType = 1
    else
      ! 2D
      meshType = 2
      associate( node => Blk%node, jm => Blk%dim(2) ) ! simplify notation
        theta1 = atan2( node(0,1,0)%c(3),node(0,1,0)%c(2) ) ! computes axisymmetric angle
        theta2 = atan2( node(0,1,1)%c(3),node(0,1,1)%c(2) )
        theta(1) = theta2-theta1
        theta1 = atan2( node(0,jm,0)%c(3), node(0,jm,0)%c(2) )
        theta2 = atan2( node(0,jm,1)%c(3), node(0,jm,1)%c(2) )
      end associate
      theta(2) = theta2-theta1
      if ( (theta(1)-theta(2)) < 1.d-5 ) then
        ! 2Daxi
        delthe = theta(1)
      else
        ! 2D
        delthe = 0.d0
      endif
    endif

  end subroutine check_mesh_type

  subroutine compute_bounding(self)
    implicit none
    class(block_type), intent(inout) :: self
    integer :: i, j, k, d
    real(8) :: min_x,max_x,min_y,max_y,min_z,max_z

    allocate(self%bbmin (1-gc:self%dim(1)+gc,1-gc:self%dim(2)+gc,1-gc:self%dim(3)+gc))
    allocate(self%bbmax (1-gc:self%dim(1)+gc,1-gc:self%dim(2)+gc,1-gc:self%dim(3)+gc))

    do k = 1-gc, self%dim(3)+gc
      do j = 1-gc, self%dim(2)+gc
        do i = 1-gc, self%dim(1)+gc
          do d = 1, 3
            self%bbmin(i,j,k)%c(d) = min(self%node(i-1,j-1,k-1)%c(d),self%node(i,j-1,k-1)%c(d), &
                                             self%node(i-1,j,k-1)%c(d),self%node(i-1,j-1,k)%c(d), &
                                             self%node(i,j,k)%c(d),self%node(i,j,k-1)%c(d), &
                                             self%node(i,j-1,k)%c(d),self%node(i-1,j,k)%c(d))

            self%bbmax(i,j,k)%c(d) = max(self%node(i-1,j-1,k-1)%c(d),self%node(i,j-1,k-1)%c(d), &
                                             self%node(i-1,j,k-1)%c(d),self%node(i-1,j-1,k)%c(d), &
                                             self%node(i,j,k)%c(d),self%node(i,j,k-1)%c(d), &
                                             self%node(i,j-1,k)%c(d),self%node(i-1,j,k)%c(d))
          enddo
        enddo
      enddo
    enddo

    !> Compute the block bounding-box
    min_x = self%node(0,0,0)%c(1)
    max_x = self%node(0,0,0)%c(1)
    min_y = self%node(0,0,0)%c(2)
    max_y = self%node(0,0,0)%c(2)
    min_z = self%node(0,0,0)%c(3)
    max_z = self%node(0,0,0)%c(3) 
    do k = 0, self%dim(3)
      do j = 0, self%dim(2)
        do i = 0, self%dim(1)
          if (self%node(i,j,k)%c(1).lt.min_x) min_x = self%node(i,j,k)%c(1)
          if (self%node(i,j,k)%c(1).gt.max_x) max_x = self%node(i,j,k)%c(1)
          if (self%node(i,j,k)%c(2).lt.min_y) min_y = self%node(i,j,k)%c(2)
          if (self%node(i,j,k)%c(2).gt.max_y) max_y = self%node(i,j,k)%c(2)
          if (self%node(i,j,k)%c(3).lt.min_z) min_z = self%node(i,j,k)%c(3)
          if (self%node(i,j,k)%c(3).gt.max_z) max_z = self%node(i,j,k)%c(3)
        enddo
      enddo
    enddo
    self%block_bounding_min(1) = min_x
    self%block_bounding_max(1) = max_x
    self%block_bounding_min(2) = min_y
    self%block_bounding_max(2) = max_y
    self%block_bounding_min(3) = min_z
    self%block_bounding_max(3) = max_z

  end subroutine compute_bounding

  subroutine compute_centers(self)
    implicit none
    class(block_type), intent(inout) :: self
    integer :: i, j, k, d, m, n

    allocate(self%center(1-gc:self%dim(1)+gc,1-gc:self%dim(2)+gc,1-gc:self%dim(3)+gc))

    !> Compute the cells center coords
    do k = 1-gc, self%dim(3)+gc
      do j = 1-gc, self%dim(2)+gc
        do i = 1-gc, self%dim(1)+gc
          do d = 1, 3
            self%center(i,j,k)%c(d)=0.125d0*(self%node(i-1,j-1,k-1)%c(d)+self%node(i,j-1,k-1)%c(d)+ &
                                                 self%node(i-1,j,k-1)%c(d)+self%node(i-1,j-1,k)%c(d)+ &
                                                 self%node(i,j,k)%c(d)+self%node(i,j,k-1)%c(d)+ &
                                                 self%node(i,j-1,k)%c(d)+self%node(i-1,j,k)%c(d))
          enddo
          self%center(i,j,k)%c(4:5) = cartesian2cyl(self%center(i,j,k)%c(2:3))
        enddo
      enddo
    enddo

  end subroutine compute_centers

  pure function cartesian2cyl(cart) result(cyl)
    implicit none
    real*8, intent(in)  :: cart(2)
    real*8              :: cyl(2)

    cyl(1) = sqrt(cart(1)**2+cart(2)**2)
    cyl(2) = datan2(cart(2),cart(1))

  end function cartesian2cyl

end module TOM
