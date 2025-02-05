  module ATLAS_high_level
    use TOM
    use phase_module
    use bc
    implicit none
    private
    public:: import_nodes
    public:: build_geometry

    type, extends(vector_nD_type) :: obj_boundary_cellface
      type(obj_bc_cellface_properties) :: bc
      real(8), dimension(3)            :: normal
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
      ! IC - SP
      integer, dimension(:,:,:), allocatable     :: mID
      integer, dimension(:,:,:), allocatable     :: qvol
      !! BC
      type(obj_face), dimension(6) :: face
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

contains

  pure subroutine import_nodes(input,output)
    use Lib_ORION_data
    implicit none
    type(orion_data), intent(in)                :: input
    type(ATLAS_block), allocatable, intent(out) :: output(:)
    integer :: b, i, j, k

    allocate(output(size(input%block)))
    do b = 1, size(input%block)
      output(b)%dim(1) = input%block(b)%Ni
      output(b)%dim(2) = input%block(b)%Nj
      output(b)%dim(3) = input%block(b)%Nk
      allocate(output(b)%node(0-gc:output(b)%dim(1)+gc,0-gc:output(b)%dim(2)+gc,0-gc:output(b)%dim(3)+gc))
      do k = 0, output(b)%dim(3); do j = 0, output(b)%dim(2); do i = 0, output(b)%dim(1)
      !call output(b)%allocate_coords(5)
        output(b)%node(i,j,k)%c(1:3) = input%block(b)%mesh(:,i,j,k)
      enddo; enddo; enddo
    enddo

  end subroutine import_nodes

  subroutine build_geometry(block)
    implicit none
    type(ATLAS_block), intent(inout) :: block(:)
    integer :: b

    call check_mesh_type(block(1))

    do b = 1, size(block)
      call block(b)%extrapolate_nodes(gc)
      call block(b)%compute_volume(gc)
      call block(b)%compute_centers(gc)
      call block(b)%compute_bounding()
    enddo

  end subroutine build_geometry

  subroutine free(self)
    implicit none
    class(ATLAS_block), intent(inout) :: self

    if (allocated(self%node)) deallocate(self%node)
    if (allocated(self%center)) deallocate(self%center)

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

  end subroutine allocate

  subroutine compute_face_centers(self)
    implicit none
    class(ATLAS_block), intent(inout) :: self
    integer :: m, n

    !> Compute the face center coords
    self%face(1)%Nm = self%dim(2); self%face(1)%Nn = self%dim(3)
    self%face(2)%Nm = self%dim(2); self%face(2)%Nn = self%dim(3)
    self%face(3)%Nm = self%dim(1); self%face(3)%Nn = self%dim(3)
    self%face(4)%Nm = self%dim(1); self%face(4)%Nn = self%dim(3)
    self%face(5)%Nm = self%dim(1); self%face(5)%Nn = self%dim(2)
    self%face(6)%Nm = self%dim(1); self%face(6)%Nn = self%dim(2)

    allocate(self%face(1)%center(1-gc:self%dim(2)+gc,1-gc:self%dim(3)+gc))
    allocate(self%face(2)%center(1-gc:self%dim(2)+gc,1-gc:self%dim(3)+gc))
    allocate(self%face(3)%center(1-gc:self%dim(1)+gc,1-gc:self%dim(3)+gc))
    allocate(self%face(4)%center(1-gc:self%dim(1)+gc,1-gc:self%dim(3)+gc))
    allocate(self%face(5)%center(1-gc:self%dim(1)+gc,1-gc:self%dim(2)+gc))
    allocate(self%face(6)%center(1-gc:self%dim(1)+gc,1-gc:self%dim(2)+gc))

    associate( this => self%face(1) )
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
        this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
      enddo
    enddo
    endassociate
    associate( this => self%face(2) )
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
        this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
      enddo
    enddo
    endassociate
    associate( this => self%face(3) )
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
        this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
      enddo
    enddo
    endassociate
    associate( this => self%face(4) )
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
        this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
      enddo
    enddo
    endassociate
    associate( this => self%face(5) )
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
        this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
      enddo
    enddo
    endassociate
    associate( this => self%face(6) )
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
        this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
      enddo
    enddo
    endassociate

  end subroutine compute_face_centers

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