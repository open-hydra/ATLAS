  module ATLAS_high_level
    use TOM
    use phase_module
    use lib_bc
    implicit none
    private
    public:: import_nodes
    public:: build_geometry

    type, extends(vector_nD_type) :: obj_boundary_cellface
      type(obj_bc_cellface_properties) :: bc
      real(8), dimension(3)            :: normal
      real(8)                          :: area
    end type obj_boundary_cellface

    type, public :: obj_face
      integer :: Nm, Nn
      type(obj_bc_cellface_properties):: bc                                ! Homogeneous BC
      type(obj_boundary_cellface), dimension(:,:), allocatable :: center   ! Cell specific BC applied over cell faces 
      type(obj_bc_cell_properties), dimension(:,:,:), allocatable :: cell  ! Cell specific BC applied to ghost cells (only for chimera)
    end type obj_face

    type, extends(block_type), public :: ATLAS_block
      !! IC
      character(len=20)                          :: type
      ! IC - IG
      real(8), dimension(:,:,:,:), allocatable   :: density
      real(8), dimension(:,:,:), allocatable     :: temperature
      real(8), dimension(:,:,:), allocatable     :: pressure
      real(8), dimension(:,:,:), allocatable     :: mil, kl
      real(8), dimension(:,:,:,:), allocatable   :: turbprop
      real(8), dimension(:,:,:,:), allocatable   :: velocity
      real(8)                                    :: gamma, R
      ! IC - CD
      real(8), dimension(:,:,:,:), allocatable   :: densityP
      real(8), dimension(:,:,:,:,:), allocatable :: velocityP
      real(8), dimension(:,:,:,:), allocatable   :: temperatureP
      real(8), dimension(:,:,:,:), allocatable   :: nP
      real(8), dimension(:,:,:,:), allocatable   :: PP
      ! IC - SP
      real(8), dimension(:,:,:), allocatable     :: mID
      real(8), dimension(:,:,:), allocatable     :: qvol
      !! BC
      integer :: nfaces
      type(obj_face), dimension(:), allocatable  :: face
      integer :: nproperties
      real(8), dimension(:), allocatable:: properties
      !! Misc
      type(phase_type), dimension(:), allocatable :: associated_phase
      integer :: id
    contains
      private
      procedure, pass(self), public :: free
      procedure, pass(self), public :: allocate
      procedure, pass(self), public :: compute_face_centers
    end type ATLAS_block

    type :: vector_3D_type
      real(kind=8)   :: c(3)
    end type vector_3D_type

    type, public :: var_block
      integer                                :: dim(3)
      type(vector_3D_type), allocatable      :: node(:,:,:)
      type(vector_3D_type), allocatable      :: center(:,:,:)
      real(8), allocatable                   :: vol(:,:,:)
      real(8), allocatable                   :: var(:,:,:)
      real(8)                                :: block_bounding_min(3)
      real(8)                                :: block_bounding_max(3)
      type(vector_nD_type), allocatable      :: bbmin(:,:,:)
      type(vector_nD_type), allocatable      :: bbmax(:,:,:)
    end type var_block

contains

  subroutine import_nodes(input,output)
    use Lib_ORION_data
    implicit none
    type(orion_data), intent(in)                :: input
    type(ATLAS_block), allocatable, intent(out) :: output(:)
    integer :: b, i, j, k

    call check_mesh_type(input%block(1)%mesh)

    if (meshType==-2) then
      gc = [2, 2, 0]
    else
      gc = 2
    endif 

    allocate(output(size(input%block)))
    do b = 1, size(input%block)
      output(b)%dim(1) = input%block(b)%Ni
      output(b)%dim(2) = input%block(b)%Nj
      output(b)%dim(3) = max(input%block(b)%Nk,1) ! Handle 2D meshes
      allocate(output(b)%node(0-gc(1):output(b)%dim(1)+gc(1),0-gc(2):output(b)%dim(2)+gc(2),0-gc(3):output(b)%dim(3)+gc(3)))
      if (meshType/=-2) then
        do k = 0, output(b)%dim(3); do j = 0, output(b)%dim(2); do i = 0, output(b)%dim(1)
              output(b)%node(i,j,k)%c(1:3) = input%block(b)%mesh(1:3,i,j,k)
        enddo; enddo; enddo
      else
        do k = 0, output(b)%dim(3); do j = 0, output(b)%dim(2); do i = 0, output(b)%dim(1)
              output(b)%node(i,j,k)%c(1:2) = input%block(b)%mesh(1:2,i,j,0)
              output(b)%node(i,j,k)%c(3) = dble(k)
        enddo; enddo; enddo
      endif
    enddo

  end subroutine import_nodes

  subroutine build_geometry(block)
    implicit none
    type(ATLAS_block), intent(inout) :: block(:)
    integer :: b

    do b = 1, size(block)
      call block(b)%extrapolate_nodes(gc)
      call block(b)%compute_volume(gc)
      call block(b)%compute_centers(gc)
      call block(b)%compute_face_centers()
      call block(b)%compute_bounding(gc)
    enddo

  end subroutine build_geometry

  subroutine free(self)
    implicit none
    class(ATLAS_block), intent(inout) :: self

    if (allocated(self%vol)) deallocate(self%vol)
    if (allocated(self%node)) deallocate(self%node)
    if (allocated(self%center)) deallocate(self%center)
    if (allocated(self%m)) deallocate(self%m)
    if (allocated(self%dl)) deallocate(self%dl)
    if (allocated(self%bbmin)) deallocate(self%bbmin)
    if (allocated(self%bbmax)) deallocate(self%bbmax)
    if (allocated(self%yn)) deallocate(self%yn)

  end subroutine free

  subroutine allocate(self,rr,ss,ii,jj,kk)
    implicit none
    class(ATLAS_block), intent(inout) :: self
    integer, intent(in)          :: ss, rr, ii, jj, kk

    allocate(self%density(1:ss,1:ii,1:jj,1:kk))
    allocate(self%velocity(1:3,1:ii,1:jj,1:kk))
    allocate(self%pressure(1:ii,1:jj,1:kk))
    allocate(self%turbprop(1:rr,1:ii,1:jj,1:kk))
    allocate(self%mil(1:ii,1:jj,1:kk))
    allocate(self%kl(1:ii,1:jj,1:kk))
    allocate(self%temperature(1:ii,1:jj,1:kk))
    allocate(self%mID(1:ii,1:jj,1:kk))
    allocate(self%qvol(1:ii,1:jj,1:kk))

  end subroutine allocate

  subroutine compute_face_centers(self)
    implicit none
    class(ATLAS_block), intent(inout) :: self
    integer :: m, n

    if (meshType==1) then
      self%nfaces = 2
    elseif (meshType==-2) then
      self%nfaces = 4
    else
      self%nfaces = 6
    endif

    allocate(self%face(1:self%nfaces))

    !> Compute the face center coords
    self%face(1)%Nm = self%dim(2); self%face(1)%Nn = self%dim(3)
    self%face(2)%Nm = self%dim(2); self%face(2)%Nn = self%dim(3)
    if (meshType/=1) then
      self%face(3)%Nm = self%dim(1); self%face(3)%Nn = self%dim(3)
      self%face(4)%Nm = self%dim(1); self%face(4)%Nn = self%dim(3)
    endif
    if (meshType>=2) then
      self%face(5)%Nm = self%dim(1); self%face(5)%Nn = self%dim(2)
      self%face(6)%Nm = self%dim(1); self%face(6)%Nn = self%dim(2)
    endif

    allocate(self%face(1)%center(1-gc(2):self%dim(2)+gc(2),1-gc(3):self%dim(3)+gc(3)))
    allocate(self%face(2)%center(1-gc(2):self%dim(2)+gc(2),1-gc(3):self%dim(3)+gc(3)))
    if (meshType/=1) then
      allocate(self%face(3)%center(1-gc(1):self%dim(1)+gc(1),1-gc(3):self%dim(3)+gc(3)))
      allocate(self%face(4)%center(1-gc(1):self%dim(1)+gc(1),1-gc(3):self%dim(3)+gc(3)))
    endif
    if (meshType>=2) then
      allocate(self%face(5)%center(1-gc(1):self%dim(1)+gc(1),1-gc(2):self%dim(2)+gc(2)))
      allocate(self%face(6)%center(1-gc(1):self%dim(1)+gc(1),1-gc(2):self%dim(2)+gc(2)))
    endif

    !$omp parallel private(m,n)
    associate( this => self%face(1) )
    !$omp do collapse(2)
    do n = 1, this%Nn
      do m = 1, this%Nm
        this%center(m,n)%c = 0.25*(self%node( 0 ,m-1,n-1)%c+ &
                                       self%node( 0 , m ,n-1)%c+ &
                                       self%node( 0 ,m-1, n )%c+ &
                                       self%node( 0 , m , n )%c)
        this%center(m,n)%normal = CalculateNormal(self%node( 0 ,m-1,n-1)%c, &
                                                  self%node( 0 , m ,n-1)%c, &
                                                  self%node( 0 ,m-1, n )%c, &
                                                  self%node( 0 , m , n )%c)
        if (meshType == -2) then
          this%center(m,n)%area = sqrt((self%node(0,m,n-1)%c(1)-self%node(0,m-1,n-1)%c(1))**2+(self%node(0,m,n-1)%c(2)-self%node(0,m-1,n-1)%c(2))**2)
        else
          this%center(m,n)%area = CalculateArea(self%node( 0 ,m-1,n-1)%c,     &
                                                    self%node( 0 , m ,n-1)%c, &
                                                    self%node( 0 ,m-1, n )%c, &
                                                    self%node( 0 , m , n )%c)
        endif
        if (meshType == -2) then
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(1:2))
        else
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
        endif
      enddo
    enddo
    endassociate
    associate( this => self%face(2) )
    !$omp do collapse(2)
    do n = 1, this%Nn
      do m = 1, this%Nm
        this%center(m,n)%c = 0.25*(self%node(self%dim(1),m-1,n-1)%c+ &
                                       self%node(self%dim(1), m ,n-1)%c+ &
                                       self%node(self%dim(1),m-1, n )%c+ &
                                       self%node(self%dim(1), m , n )%c)
        this%center(m,n)%normal = CalculateNormal(self%node(self%dim(1),m-1,n-1)%c, &
                                                  self%node(self%dim(1), m ,n-1)%c, &
                                                  self%node(self%dim(1),m-1, n )%c, &
                                                  self%node(self%dim(1), m , n )%c)
        if (meshType == -2) then
          this%center(m,n)%area = sqrt((self%node(self%dim(1),m,n-1)%c(1)-self%node(self%dim(1),m-1,n-1)%c(1))**2+(self%node(self%dim(1),m,n-1)%c(2)-self%node(self%dim(1),m-1,n-1)%c(2))**2)
        else
          this%center(m,n)%area = CalculateArea(self%node(self%dim(1),m-1,n-1)%c,     &
                                                    self%node(self%dim(1), m ,n-1)%c, &
                                                    self%node(self%dim(1),m-1, n )%c, &
                                                    self%node(self%dim(1), m , n )%c)
        endif
        if (meshType == -2) then
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(1:2))
        else
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
        endif
      enddo
    enddo
    endassociate
    !$omp end parallel

    if (meshType==1) return

    !$omp parallel private(m,n)
    associate( this => self%face(3) )
    !$omp do collapse(2)
    do n = 1, this%Nn
      do m = 1, this%Nm
        this%center(m,n)%c = 0.25*(self%node(m-1, 0 ,n-1)%c+ &
                                        self%node( m , 0 ,n-1)%c+ &
                                        self%node(m-1, 0 , n )%c+ &
                                        self%node( m , 0 , n )%c)
        this%center(m,n)%normal = CalculateNormal(self%node(m-1, 0 ,n-1)%c, &
                                                  self%node( m , 0 ,n-1)%c, &
                                                  self%node(m-1, 0 , n )%c, &
                                                  self%node( m , 0 , n )%c)
        if (meshType == -2) then
          this%center(m,n)%area = sqrt((self%node(m,0,n-1)%c(1)-self%node(m-1,0,n-1)%c(1))**2+(self%node(m,0,n-1)%c(2)-self%node(m-1,0,n-1)%c(2))**2)
        else
          this%center(m,n)%area = CalculateArea(self%node(m-1, 0 ,n-1)%c,     &
                                                    self%node( m , 0 ,n-1)%c, &
                                                    self%node(m-1, 0 , n )%c, &
                                                    self%node( m , 0 , n )%c)
        endif
        if (meshType == -2) then
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(1:2))
        else
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
        endif
      enddo
    enddo
    endassociate
    associate( this => self%face(4) )
    !$omp do collapse(2)
    do n = 1, this%Nn
      do m = 1, this%Nm
        this%center(m,n)%c = 0.25*(self%node(m-1,self%dim(2),n-1)%c+ &
                                       self%node( m ,self%dim(2),n-1)%c+ &
                                       self%node(m-1,self%dim(2), n )%c+ &
                                       self%node( m ,self%dim(2), n )%c)
        this%center(m,n)%normal = CalculateNormal(self%node(m-1,self%dim(2),n-1)%c, &
                                                  self%node( m ,self%dim(2),n-1)%c, &
                                                  self%node(m-1,self%dim(2), n )%c, &
                                                  self%node( m ,self%dim(2), n )%c)
        if (meshType == -2) then
          this%center(m,n)%area = sqrt((self%node(m,self%dim(2),n-1)%c(1)-self%node(m-1,self%dim(2),n-1)%c(1))**2+(self%node(m,self%dim(2),n-1)%c(2)-self%node(m-1,self%dim(2),n-1)%c(2))**2)
        else
          this%center(m,n)%area = CalculateArea(self%node(m-1,self%dim(2),n-1)%c,     &
                                                    self%node( m ,self%dim(2),n-1)%c, &
                                                    self%node(m-1,self%dim(2), n )%c, &
                                                    self%node( m ,self%dim(2), n )%c)
        endif
        if (meshType == -2) then
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(1:2))
        else
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
        endif
      enddo
    enddo
    endassociate
    !$omp end parallel

    if (meshType<2) return

    !$omp parallel private(m,n)
    associate( this => self%face(5) )
    !$omp do collapse(2)
    do n = 1, this%Nn
      do m = 1, this%Nm
        this%center(m,n)%c = 0.25*(self%node(m-1,n-1, 0 )%c+ &
                                       self%node( m ,n-1, 0 )%c+ &
                                       self%node(m-1, n , 0 )%c+ &
                                       self%node( m , n , 0 )%c)
        this%center(m,n)%normal = CalculateNormal(self%node(m-1,n-1, 0 )%c, &
                                                  self%node( m ,n-1, 0 )%c, &
                                                  self%node(m-1, n , 0 )%c, &
                                                  self%node( m , n , 0 )%c)
        this%center(m,n)%area = CalculateArea(self%node(m-1,n-1, 0 )%c,     &
                                                  self%node( m ,n-1, 0 )%c, &
                                                  self%node(m-1, n , 0 )%c, &
                                                  self%node( m , n , 0 )%c)
        this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
      enddo
    enddo
    endassociate
    associate( this => self%face(6) )
    !$omp do collapse(2)
    do n = 1, this%Nn
      do m = 1, this%Nm
        this%center(m,n)%c = 0.25*(self%node(m-1,n-1,self%dim(3))%c+ &
                                       self%node( m ,n-1,self%dim(3))%c+ &
                                       self%node(m-1, n ,self%dim(3))%c+ &
                                       self%node( m , n ,self%dim(3))%c)
        this%center(m,n)%normal = CalculateNormal(self%node(m-1,n-1,self%dim(3))%c, &
                                                  self%node( m ,n-1,self%dim(3))%c, &
                                                  self%node(m-1, n ,self%dim(3))%c, &
                                                  self%node( m , n ,self%dim(3))%c)
        this%center(m,n)%area = CalculateArea(self%node(m-1,n-1,self%dim(3))%c,     &
                                                  self%node( m ,n-1,self%dim(3))%c, &
                                                  self%node(m-1, n ,self%dim(3))%c, &
                                                  self%node( m , n ,self%dim(3))%c)
        this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
      enddo
    enddo
    endassociate
    !$omp end parallel

  end subroutine compute_face_centers

  pure function CalculateArea(A,B,C,D) result(Area)
    implicit none

    ! Declare variables
    real*8, dimension(3), intent(in) :: A, B, C, D
    real*8                           :: Area
    real*8                           :: dumx, dumy, dumz
    real*8                           :: DAx, DAy, DAz, BCx, BCy, BCz
    real*8                           :: Magnitude

    ! Calculate vectors AD and BC
    DAx = D(1) - A(1)
    DAy = D(2) - A(2)
    DAz = D(3) - A(3)
    BCx = C(1) - B(1)
    BCy = C(2) - B(2)
    BCz = C(3) - B(3)

    ! Calculate the half cross product 
    dumx = (DAy * BCz - DAz * BCy) * 0.5d0
    dumy = (DAz * BCx - DAx * BCz) * 0.5d0
    dumz = (DAx * BCy - DAy * BCx) * 0.5d0

    ! Compute the area
    Area = sqrt(dumx**2 + dumy**2 + dumz**2)

  end function CalculateArea

pure function CalculateNormal(A,B,C,D) result(n)
  implicit none

  ! Declare variables
  real*8, dimension(3), intent(in) :: A, B, C, D
  real*8, dimension(3)             :: n
  real*8                           :: nx, ny, nz
  real*8                           :: ABx, ABy, ABz, BCx, BCy, BCz
  real*8                           :: Magnitude

  ! Calculate vectors AB and BC
  ABx = B(1) - A(1)
  ABy = B(2) - A(2)
  ABz = B(3) - A(3)
  BCx = C(1) - B(1)
  BCy = C(2) - B(2)
  BCz = C(3) - B(3)

  ! Calculate the cross product (dim(1), dim(2), dim(3))
  nx = ABy * BCz - ABz * BCy
  ny = ABz * BCx - ABx * BCz
  nz = ABx * BCy - ABy * BCx

  ! Normalize the normal vector
  Magnitude = sqrt(nx**2 + ny**2 + nz**2)
  nx = nx / Magnitude
  ny = ny / Magnitude
  nz = nz / Magnitude

  n = [nx, ny, nz]

end function CalculateNormal

end module ATLAS_high_level