  module ATLAS_high_level
    use ATLAS_Mod_Grid
    use phase_module
    use lib_bc
    use var_block_mod, only: var_block
    use geometry_mod, only: CalculateArea, CalculateNormal
    implicit none
    private
    public:: import_nodes
    public:: build_geometry
    public:: var_block

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

    ! IC sub-types: ideal-gas, condensed-phase dispersed, solid-phase
    type, public :: block_ic_ig
      real(8), dimension(:,:,:,:), allocatable   :: density
      real(8), dimension(:,:,:), allocatable     :: temperature
      real(8), dimension(:,:,:), allocatable     :: pressure
      real(8), dimension(:,:,:), allocatable     :: mil, kl
      real(8), dimension(:,:,:,:), allocatable   :: turbprop
      real(8), dimension(:,:,:,:), allocatable   :: velocity
      real(8)                                    :: gamma = 0.d0
      real(8)                                    :: R = 0.d0
    end type block_ic_ig

    type, public :: block_ic_cd
      real(8), dimension(:,:,:,:), allocatable   :: densityP
      real(8), dimension(:,:,:,:,:), allocatable :: velocityP
      real(8), dimension(:,:,:,:), allocatable   :: temperatureP
      real(8), dimension(:,:,:,:), allocatable   :: nP
      real(8), dimension(:,:,:,:), allocatable   :: PP
    end type block_ic_cd

    type, public :: block_ic_sp
      real(8), dimension(:,:,:), allocatable     :: mID
      real(8), dimension(:,:,:), allocatable     :: qvol
    end type block_ic_sp

    type, extends(block_type), public :: ATLAS_block
      character(len=20)                          :: type
      type(block_ic_ig)                          :: ig
      type(block_ic_cd)                          :: cd
      type(block_ic_sp)                          :: sp
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
      procedure, pass(self), public :: allocate
      procedure, pass(self), public :: compute_face_centers
    end type ATLAS_block

contains

  subroutine import_nodes(input,output)
    use Lib_ORION_data
    implicit none
    type(orion_data), intent(in)                :: input
    type(ATLAS_block), allocatable, intent(out) :: output(:)
    integer :: b, i, j, k

    call check_mesh_type(input%block(1)%mesh)

    if (mesh_cfg%meshType==-2) then
      mesh_cfg%gc = [2, 2, 0]
    else
      mesh_cfg%gc = 2
    endif 

    allocate(output(size(input%block)))
    do b = 1, size(input%block)
      output(b)%dim(1) = input%block(b)%Ni
      output(b)%dim(2) = input%block(b)%Nj
      output(b)%dim(3) = max(input%block(b)%Nk,1) ! Handle 2D meshes
      allocate(output(b)%node( &
        0-mesh_cfg%gc(1):output(b)%dim(1)+mesh_cfg%gc(1), &
        0-mesh_cfg%gc(2):output(b)%dim(2)+mesh_cfg%gc(2), &
        0-mesh_cfg%gc(3):output(b)%dim(3)+mesh_cfg%gc(3)))
      if (mesh_cfg%meshType/=-2) then
        !$omp parallel do collapse(3) private(i,j,k)
        do k = 0, output(b)%dim(3); do j = 0, output(b)%dim(2); do i = 0, output(b)%dim(1)
              output(b)%node(i,j,k)%c(1:3) = input%block(b)%mesh(1:3,i,j,k)
        enddo; enddo; enddo
        !$omp end parallel do
      else
        !$omp parallel do collapse(3) private(i,j,k)
        do k = 0, output(b)%dim(3); do j = 0, output(b)%dim(2); do i = 0, output(b)%dim(1)
              output(b)%node(i,j,k)%c(1:2) = input%block(b)%mesh(1:2,i,j,0)
              output(b)%node(i,j,k)%c(3) = dble(k)
        enddo; enddo; enddo
        !$omp end parallel do
      endif
    enddo

  end subroutine import_nodes

  subroutine build_geometry(block)
    implicit none
    type(ATLAS_block), intent(inout) :: block(:)
    integer :: b

    do b = 1, size(block)
      call block(b)%extrapolate_nodes(mesh_cfg%gc)
      call block(b)%compute_volume(mesh_cfg%gc)
      call block(b)%compute_centers(mesh_cfg%gc)
      call block(b)%compute_face_centers()
      call block(b)%compute_bounding(mesh_cfg%gc)
    enddo

  end subroutine build_geometry

  subroutine allocate(self,rr,ss,ii,jj,kk)
    implicit none
    class(ATLAS_block), intent(inout) :: self
    integer, intent(in)          :: ss, rr, ii, jj, kk

    allocate(self%ig%density(1:ss,1:ii,1:jj,1:kk))
    allocate(self%ig%velocity(1:3,1:ii,1:jj,1:kk))
    allocate(self%ig%pressure(1:ii,1:jj,1:kk))
    allocate(self%ig%turbprop(1:rr,1:ii,1:jj,1:kk))
    allocate(self%ig%mil(1:ii,1:jj,1:kk))
    allocate(self%ig%kl(1:ii,1:jj,1:kk))
    allocate(self%ig%temperature(1:ii,1:jj,1:kk))
    allocate(self%sp%mID(1:ii,1:jj,1:kk))
    allocate(self%sp%qvol(1:ii,1:jj,1:kk))

  end subroutine allocate

  subroutine compute_face_centers(self)
    implicit none
    class(ATLAS_block), intent(inout) :: self
    integer :: m, n

    if (mesh_cfg%meshType==1) then
      self%nfaces = 2
    elseif (mesh_cfg%meshType==-2) then
      self%nfaces = 4
    else
      self%nfaces = 6
    endif

    allocate(self%face(1:self%nfaces))

    !> Compute the face center coords
    self%face(1)%Nm = self%dim(2); self%face(1)%Nn = self%dim(3)
    self%face(2)%Nm = self%dim(2); self%face(2)%Nn = self%dim(3)
    if (mesh_cfg%meshType/=1) then
      self%face(3)%Nm = self%dim(1); self%face(3)%Nn = self%dim(3)
      self%face(4)%Nm = self%dim(1); self%face(4)%Nn = self%dim(3)
    endif
    if (mesh_cfg%meshType>=2) then
      self%face(5)%Nm = self%dim(1); self%face(5)%Nn = self%dim(2)
      self%face(6)%Nm = self%dim(1); self%face(6)%Nn = self%dim(2)
    endif

    allocate(self%face(1)%center(1-mesh_cfg%gc(2):self%dim(2)+mesh_cfg%gc(2),1-mesh_cfg%gc(3):self%dim(3)+mesh_cfg%gc(3)))
    allocate(self%face(2)%center(1-mesh_cfg%gc(2):self%dim(2)+mesh_cfg%gc(2),1-mesh_cfg%gc(3):self%dim(3)+mesh_cfg%gc(3)))
    if (mesh_cfg%meshType/=1) then
      allocate(self%face(3)%center(1-mesh_cfg%gc(1):self%dim(1)+mesh_cfg%gc(1),1-mesh_cfg%gc(3):self%dim(3)+mesh_cfg%gc(3)))
      allocate(self%face(4)%center(1-mesh_cfg%gc(1):self%dim(1)+mesh_cfg%gc(1),1-mesh_cfg%gc(3):self%dim(3)+mesh_cfg%gc(3)))
    endif
    if (mesh_cfg%meshType>=2) then
      allocate(self%face(5)%center(1-mesh_cfg%gc(1):self%dim(1)+mesh_cfg%gc(1),1-mesh_cfg%gc(2):self%dim(2)+mesh_cfg%gc(2)))
      allocate(self%face(6)%center(1-mesh_cfg%gc(1):self%dim(1)+mesh_cfg%gc(1),1-mesh_cfg%gc(2):self%dim(2)+mesh_cfg%gc(2)))
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
        if (mesh_cfg%meshType == -2) then
          this%center(m,n)%area = sqrt((self%node(0,m,n-1)%c(1)-self%node(0,m-1,n-1)%c(1))**2+(self%node(0,m,n-1)%c(2)-self%node(0,m-1,n-1)%c(2))**2)
        else
          this%center(m,n)%area = CalculateArea(self%node( 0 ,m-1,n-1)%c,     &
                                                    self%node( 0 , m ,n-1)%c, &
                                                    self%node( 0 ,m-1, n )%c, &
                                                    self%node( 0 , m , n )%c)
        endif
        if (mesh_cfg%meshType == -2) then
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
        if (mesh_cfg%meshType == -2) then
          this%center(m,n)%area = sqrt((self%node(self%dim(1),m,n-1)%c(1)-self%node(self%dim(1),m-1,n-1)%c(1))**2+(self%node(self%dim(1),m,n-1)%c(2)-self%node(self%dim(1),m-1,n-1)%c(2))**2)
        else
          this%center(m,n)%area = CalculateArea(self%node(self%dim(1),m-1,n-1)%c,     &
                                                    self%node(self%dim(1), m ,n-1)%c, &
                                                    self%node(self%dim(1),m-1, n )%c, &
                                                    self%node(self%dim(1), m , n )%c)
        endif
        if (mesh_cfg%meshType == -2) then
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(1:2))
        else
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
        endif
      enddo
    enddo
    endassociate
    !$omp end parallel

    if (mesh_cfg%meshType==1) return

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
        if (mesh_cfg%meshType == -2) then
          this%center(m,n)%area = sqrt((self%node(m,0,n-1)%c(1)-self%node(m-1,0,n-1)%c(1))**2+(self%node(m,0,n-1)%c(2)-self%node(m-1,0,n-1)%c(2))**2)
        else
          this%center(m,n)%area = CalculateArea(self%node(m-1, 0 ,n-1)%c,     &
                                                    self%node( m , 0 ,n-1)%c, &
                                                    self%node(m-1, 0 , n )%c, &
                                                    self%node( m , 0 , n )%c)
        endif
        if (mesh_cfg%meshType == -2) then
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
        if (mesh_cfg%meshType == -2) then
          this%center(m,n)%area = sqrt((self%node(m,self%dim(2),n-1)%c(1)-self%node(m-1,self%dim(2),n-1)%c(1))**2+(self%node(m,self%dim(2),n-1)%c(2)-self%node(m-1,self%dim(2),n-1)%c(2))**2)
        else
          this%center(m,n)%area = CalculateArea(self%node(m-1,self%dim(2),n-1)%c,     &
                                                    self%node( m ,self%dim(2),n-1)%c, &
                                                    self%node(m-1,self%dim(2), n )%c, &
                                                    self%node( m ,self%dim(2), n )%c)
        endif
        if (mesh_cfg%meshType == -2) then
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(1:2))
        else
          this%center(m,n)%c(4:5) = cartesian2cyl(this%center(m,n)%c(2:3))
        endif
      enddo
    enddo
    endassociate
    !$omp end parallel

    if (mesh_cfg%meshType<2) return

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

end module ATLAS_high_level