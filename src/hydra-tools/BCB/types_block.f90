!> BC block type: extends block_type with boundary-condition fields.
module bc_block_mod
  use grid_mod
  use phase_mod
  use bc_mod
  use geometry_mod, only: CalculateArea, CalculateNormal
  implicit none
  private
  public :: BC_block, obj_boundary_cellface, obj_face
  public :: import_nodes, build_geometry

  type, extends(vector_nD_type) :: obj_boundary_cellface
    type(bc_t)            :: bc
    real(8), dimension(3) :: normal
    real(8)               :: area
  end type obj_boundary_cellface

  type, public :: obj_face
    integer :: Nm, Nn
    type(bc_t)            :: bc
    type(obj_boundary_cellface),  dimension(:,:),   allocatable :: center
    type(obj_bc_cell_properties), dimension(:,:,:), allocatable :: cell
  end type obj_face

  type, extends(block_type), public :: BC_block
    integer :: nfaces = 0
    type(obj_face), dimension(:), allocatable  :: face
    integer                                    :: nproperties = 0
    real(8), dimension(:), allocatable         :: properties
    type(phase_t), dimension(:), allocatable   :: associated_phase
    integer                                    :: id = 0
  contains
    private
    procedure, pass(self), public :: compute_face_centers
  end type BC_block

contains

  subroutine compute_face_centers(self)
    implicit none
    class(BC_block), intent(inout) :: self
    integer :: m, n
    logical :: is_axi

    is_axi = (mesh_cfg%meshType == -2)

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

    allocate(self%face(1)%center( &
      1-mesh_cfg%gc(2):self%dim(2)+mesh_cfg%gc(2), &
      1-mesh_cfg%gc(3):self%dim(3)+mesh_cfg%gc(3)))
    allocate(self%face(2)%center( &
      1-mesh_cfg%gc(2):self%dim(2)+mesh_cfg%gc(2), &
      1-mesh_cfg%gc(3):self%dim(3)+mesh_cfg%gc(3)))
    if (mesh_cfg%meshType/=1) then
      allocate(self%face(3)%center( &
        1-mesh_cfg%gc(1):self%dim(1)+mesh_cfg%gc(1), &
        1-mesh_cfg%gc(3):self%dim(3)+mesh_cfg%gc(3)))
      allocate(self%face(4)%center( &
        1-mesh_cfg%gc(1):self%dim(1)+mesh_cfg%gc(1), &
        1-mesh_cfg%gc(3):self%dim(3)+mesh_cfg%gc(3)))
    endif
    if (mesh_cfg%meshType>=2) then
      allocate(self%face(5)%center( &
        1-mesh_cfg%gc(1):self%dim(1)+mesh_cfg%gc(1), &
        1-mesh_cfg%gc(2):self%dim(2)+mesh_cfg%gc(2)))
      allocate(self%face(6)%center( &
        1-mesh_cfg%gc(1):self%dim(1)+mesh_cfg%gc(1), &
        1-mesh_cfg%gc(2):self%dim(2)+mesh_cfg%gc(2)))
    endif

    !$omp parallel private(m,n)
    associate( this => self%face(1) )
    !$omp do collapse(2)
    do n = 1, this%Nn
      do m = 1, this%Nm
        call compute_face_point( &
            self%node( 0 ,m-1,n-1)%c, &
            self%node( 0 , m ,n-1)%c, &
            self%node( 0 ,m-1, n )%c, &
            self%node( 0 , m , n )%c, is_axi, &
            this%center(m,n)%c, &
            this%center(m,n)%normal, &
            this%center(m,n)%area)
      enddo
    enddo
    endassociate

    associate( this => self%face(2) )
    !$omp do collapse(2)
    do n = 1, this%Nn
      do m = 1, this%Nm
        call compute_face_point( &
            self%node(self%dim(1),m-1,n-1)%c, &
            self%node(self%dim(1), m ,n-1)%c, &
            self%node(self%dim(1),m-1, n )%c, &
            self%node(self%dim(1), m , n )%c, is_axi, &
            this%center(m,n)%c, &
            this%center(m,n)%normal, &
            this%center(m,n)%area)
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
        call compute_face_point( &
            self%node(m-1, 0 ,n-1)%c, &
            self%node( m , 0 ,n-1)%c, &
            self%node(m-1, 0 , n )%c, &
            self%node( m , 0 , n )%c, is_axi, &
            this%center(m,n)%c, &
            this%center(m,n)%normal, &
            this%center(m,n)%area)
      enddo
    enddo
    endassociate

    associate( this => self%face(4) )
    !$omp do collapse(2)
    do n = 1, this%Nn
      do m = 1, this%Nm
        call compute_face_point( &
            self%node(m-1,self%dim(2),n-1)%c, &
            self%node( m ,self%dim(2),n-1)%c, &
            self%node(m-1,self%dim(2), n )%c, &
            self%node( m ,self%dim(2), n )%c, is_axi, &
            this%center(m,n)%c, &
            this%center(m,n)%normal, &
            this%center(m,n)%area)
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
        call compute_face_point( &
            self%node(m-1,n-1, 0 )%c, &
            self%node( m ,n-1, 0 )%c, &
            self%node(m-1, n , 0 )%c, &
            self%node( m , n , 0 )%c, .false., &
            this%center(m,n)%c, &
            this%center(m,n)%normal, &
            this%center(m,n)%area)
      enddo
    enddo
    endassociate

    associate( this => self%face(6) )
    !$omp do collapse(2)
    do n = 1, this%Nn
      do m = 1, this%Nm
        call compute_face_point( &
            self%node(m-1,n-1,self%dim(3))%c, &
            self%node( m ,n-1,self%dim(3))%c, &
            self%node(m-1, n ,self%dim(3))%c, &
            self%node( m , n ,self%dim(3))%c, .false., &
            this%center(m,n)%c, &
            this%center(m,n)%normal, &
            this%center(m,n)%area)
      enddo
    enddo
    endassociate
    !$omp end parallel

  end subroutine compute_face_centers

  pure subroutine compute_face_point(p1, p2, p3, p4, is_axi, c, normal, area)
    real(8), intent(in) :: p1(5), p2(5), p3(5), p4(5)
    logical, intent(in) :: is_axi
    real(8), intent(out) :: c(5), normal(3), area

    c = 0.25d0*(p1 + p2 + p3 + p4)
    normal = CalculateNormal(p1, p2, p3, p4)
    if (is_axi) then
      area = sqrt((p2(1)-p1(1))**2+(p2(2)-p1(2))**2)
      c(4:5) = cartesian2cyl(c(1:2))
    else
      area = CalculateArea(p1, p2, p3, p4)
      c(4:5) = cartesian2cyl(c(2:3))
    endif
  end subroutine compute_face_point

end module bc_block_mod
