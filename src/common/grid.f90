!>@brief: Module for geometrical derived data types. 
module grid_mod
  implicit none
  private :: xy_area_fraction

  ! --- Mesh type identifiers ---
  integer, parameter :: MESH_PURE_2D = -2  ! Pure 2D (no extrusion)
  integer, parameter :: MESH_PURE_1D = -1  ! Pure 1D (no extrusion)
  integer, parameter :: MESH_1D      =  1  ! One-dimensional
  integer, parameter :: MESH_2D      =  2  ! 2D plane / axisymmetric
  integer, parameter :: MESH_3D      =  3  ! Three-dimensional

  type :: mesh_config_type
    integer, dimension(3) :: gc        ! number of ghost layers
    integer               :: meshType  ! MESH_PURE_2D / MESH_PURE_1D / MESH_1D / MESH_2D / MESH_3D
    real(kind=8)          :: delthe    ! grid axisymmetric angle
  end type mesh_config_type

  type(mesh_config_type) :: mesh_cfg

  type :: vector_3D_type
    real(kind=8)   :: c(3)
  end type vector_3D_type

  type :: vector_nD_type
    real(kind=8)   :: c(5)
  end type vector_nD_type

  ! Object for the storage of metric quantities in a face. All static components.
  type :: f_metrics_type
    real(kind=8), dimension(3)   :: n  ! Unit normal vector.
    real(kind=8)                 :: a  ! Interface area.
  end type f_metrics_type

  ! Object for the storage cell faces along a grid direction. Allocatable.
  type :: d_metrics_type
    type(f_metrics_type), allocatable  :: f(:,:,:)   
  end type d_metrics_type
  ! -

  ! Baseline object for a block. Contains dimensions, and allocatable metric-related objects.
  type :: block_type
    integer                            :: dim(3)                      ! Number of cells in i-j-k (ghost not included).
    real(8),              allocatable  :: vol(:,:,:)                  ! Cell volume.
    type(vector_nD_type), allocatable  :: node(:,:,:)                 ! Mesh grid points (including ghost).
    type(vector_nD_type), allocatable  :: center(:,:,:)               ! Cell center coordinates
    type(d_metrics_type)               :: dir(3)                      ! Direction object. Contains: i-faces, j-faces, k-faces; eg: dir(1)%face(i,j,k)%n.
    ! Chimera
    real(8)                            :: block_bounding_min(3)
    real(8)                            :: block_bounding_max(3)
    type(vector_nD_type), allocatable  :: bbmin(:,:,:)
    type(vector_nD_type), allocatable  :: bbmax(:,:,:)
  contains
    private
    procedure, pass(self), public :: destroy
    procedure, pass(self), public :: extrapolate_nodes
    procedure, pass(self), public :: compute_centers
    procedure, pass(self), public :: compute_norm_area
    procedure, pass(self), public :: compute_volume
    procedure, pass(self), public :: compute_bounding
    procedure, pass(self), public :: build_geometry

  end type block_type

contains


  !> Import mesh nodes from an ORION dataset and classify the mesh (classify_mesh).
  !> Without cfg (PRIMARY mesh) the classification becomes the global mesh_cfg, as always.
  !> With cfg (SECONDARY mesh, e.g. an interpolation source or a file-backed zone field) the
  !> classification is returned in cfg only and the global mesh_cfg is not touched, so that it keeps
  !> describing the primary mesh (output layout, ghost layers, delthe). A block imported with
  !> cfg= must not be given to build_geometry/compute_* (they read the global mesh_cfg).
  subroutine import_nodes(input,output,cfg)
    use Lib_ORION_data
    implicit none
    type(orion_data), intent(in)                :: input
    class(block_type), intent(out)              :: output(:)
    type(mesh_config_type), intent(out), optional :: cfg
    type(mesh_config_type) :: lcfg
    integer :: b, i, j, k, bz

    ! the mesh is classified in its own configuration: returned in cfg when given (a secondary mesh,
    ! e.g. an interpolation source), otherwise it becomes the global mesh_cfg (the primary mesh)
    lcfg = mesh_cfg
    call classify_mesh(input%block(1)%mesh, lcfg)

    ! Block 1 decides the mesh type. With three coordinates, a block with a single node plane next to
    ! blocks with several would be read out of bounds (k = 1) or flattened: refused. A single plane
    ! read as 2D whose z varies is not an x-y plane: the mesh is its projection (WARNING); a plane
    ! perpendicular to x-y projects on a line (cells without area): refused.
    if (size(input%block(1)%mesh,1) == 3) then
      do b = 1, size(input%block)
        if ((size(input%block(b)%mesh,4) == 1) .neqv. (size(input%block(1)%mesh,4) == 1)) then
          write(*,'(A,I0,A,I0,A,I0,A)') ' [ERROR] mesh block ', b, ' has ', size(input%block(b)%mesh,4), &
            ' node plane(s) in k and block 1 has ', size(input%block(1)%mesh,4), &
            ': a single-plane (K = 1) block cannot be mixed with blocks of several planes'
          stop 1
        endif
      enddo
      if (size(input%block(1)%mesh,4) == 1) then
        bz = 0
        do b = 1, size(input%block)
          if (maxval(input%block(b)%mesh(3,:,:,:)) - minval(input%block(b)%mesh(3,:,:,:)) > &
              1.d-9 * max(1.d0, maxval(abs(input%block(b)%mesh(1:2,:,:,:))))) then
            if (xy_area_fraction(input%block(b)%mesh) < 1.d-6) then
              write(*,'(A,I0,A)') ' [ERROR] mesh block ', b, ': three coordinates on a single node plane'// &
                ' that is perpendicular to x-y: its projection on x-y has no area (write the mesh in the x-y plane)'
              stop 1
            endif
            if (bz == 0) bz = b
          endif
        enddo
        if (bz > 0) write(*,'(A,I0,A)') ' [WARNING] mesh block ', bz, ': three coordinates on a single node plane'// &
          ' are read as a 2D (x, y) mesh, but z is not constant: the mesh is the projection on x-y'
      endif
    endif

    if (lcfg%meshType==-2) then
      lcfg%gc = [2, 2, 0]
    elseif (lcfg%meshType==-1) then
      lcfg%gc = [2, 0, 0]
    else
      lcfg%gc = 2
    endif

    if (present(cfg)) then
      cfg = lcfg
    else
      mesh_cfg = lcfg
    endif

    do b = 1, size(input%block)
      output(b)%dim(1) = input%block(b)%Ni
      output(b)%dim(2) = input%block(b)%Nj
      output(b)%dim(3) = max(input%block(b)%Nk,1) ! Handle 2D meshes
      allocate(output(b)%node( &
        0-lcfg%gc(1):output(b)%dim(1)+lcfg%gc(1), &
        0-lcfg%gc(2):output(b)%dim(2)+lcfg%gc(2), &
        0-lcfg%gc(3):output(b)%dim(3)+lcfg%gc(3)))
      ! ghost nodes that no extrapolation fills stay defined: compute_centers reads them for the ghost
      ! centres (ifx DEBUG trapped on garbage coordinates of 2D ICB meshes, RELEASE stored garbage)
      block
        integer :: dd
        do dd = 1, size(output(b)%node(0,0,0)%c)
          output(b)%node%c(dd) = 0.0d0
        enddo
      end block
      if (lcfg%meshType/=-2) then
        !$omp parallel do collapse(3) private(i,j,k)
        do k = 0, output(b)%dim(3); do j = 0, output(b)%dim(2); do i = 0, output(b)%dim(1)
              output(b)%node(i,j,k)%c(1:3) = input%block(b)%mesh(1:3,i,j,k)
              output(b)%node(i,j,k)%c(4:5) = 0.0d0
        enddo; enddo; enddo
        !$omp end parallel do
      else
        !$omp parallel do collapse(3) private(i,j,k)
        do k = 0, output(b)%dim(3); do j = 0, output(b)%dim(2); do i = 0, output(b)%dim(1)
              output(b)%node(i,j,k)%c(1:2) = input%block(b)%mesh(1:2,i,j,0)
              output(b)%node(i,j,k)%c(3) = dble(k)
              output(b)%node(i,j,k)%c(4:5) = 0.0d0
        enddo; enddo; enddo
        !$omp end parallel do
      endif
    enddo

  end subroutine import_nodes


  !@brief Build geometry for the block
  subroutine build_geometry(self)
    implicit none
    class(block_type), intent(inout) :: self

    call self%extrapolate_nodes(mesh_cfg%gc)
    call self%compute_volume(mesh_cfg%gc)
    call self%compute_centers(mesh_cfg%gc)
    call self%compute_bounding(mesh_cfg%gc)

  end subroutine build_geometry


  !@brief: Deallocate all allocatable components of the block object.
  pure subroutine destroy(self)
    implicit none
    class(block_type), intent(inout) :: self

    if (allocated(self%vol)) deallocate(self%vol)
    if (allocated(self%node)) deallocate(self%node)
    if (allocated(self%center)) deallocate(self%center)
    if (allocated(self%bbmin)) deallocate(self%bbmin)
    if (allocated(self%bbmax)) deallocate(self%bbmax)

  end subroutine destroy

  !>@brief: subroutine to compute interface areas and normal vectors for a block
  ! compute_norm_area has no caller in ATLAS (the face areas and normals come from compute_centers
  ! and the builders); it is kept.
  subroutine compute_norm_area( self )
    implicit none
    class(block_type), intent(inout) :: self
    ! Local
    real(kind=8) :: Ai, snix, sniy, sniz,  Aj, snjx, snjy, snjz, Ak, snkx, snky, snkz
    integer      :: i, j, k, im, jm, km
    real(kind=8) :: d1(3), d2(3), d3(3)
    real(kind=8) :: snixx, sniyy, snizz, snjxx, snjyy, snjzz, snkxx, snkyy, snkzz
    real(kind=8) :: scal, signi, signj, signk

    ! Peliminary operations
    im = self%dim(1)
    jm = self%dim(2)
    km = self%dim(3)

    ! compute sign of normal vectors to the intefaces

    !------------------------------------------------------------------------------------------------
    ! i direction
    d1 = self%node(1,1,1)%c(1:3) - self%node(1,0,0)%c(1:3)
    d2 = self%node(1,0,1)%c(1:3) - self%node(1,1,0)%c(1:3)

    d3(1)=(d1(2)*d2(3)-d1(3)*d2(2))
    d3(2)=(d1(3)*d2(1)-d1(1)*d2(3))
    d3(3)=(d1(1)*d2(2)-d1(2)*d2(1))

    snixx=d3(1)
    sniyy=d3(2)
    snizz=d3(3)

    d1 = 0.25d0*( self%node(1,1,1)%c(1:3) + self%node(1,0,1)%c(1:3) + self%node(1,0,0)%c(1:3) + self%node(1,1,0)%c(1:3) )
    d2 = 0.25d0*( self%node(0,1,1)%c(1:3) + self%node(0,0,1)%c(1:3) + self%node(0,0,0)%c(1:3) + self%node(0,1,0)%c(1:3) )

    d3(1)=d1(1)-d2(1)
    d3(2)=d1(2)-d2(2)
    d3(3)=d1(3)-d2(3)

    scal=d3(1)*snixx+d3(2)*sniyy+d3(3)*snizz

    signi=sign(1.d0,scal)
  !------------------------------------------------------------------------------------------------
    ! j direction
    d1 = self%node(0,1,1)%c(1:3) - self%node(1,1,0)%c(1:3)
    d2 = self%node(1,1,1)%c(1:3) - self%node(0,1,0)%c(1:3)

    d3(1)=(d1(2)*d2(3)-d1(3)*d2(2))
    d3(2)=(d1(3)*d2(1)-d1(1)*d2(3))
    d3(3)=(d1(1)*d2(2)-d1(2)*d2(1))

    snjxx=d3(1)
    snjyy=d3(2)
    snjzz=d3(3)

    d1 = 0.25d0*( self%node(1,1,1)%c(1:3) + self%node(0,1,1)%c(1:3) + self%node(0,1,0)%c(1:3) + self%node(1,1,0)%c(1:3) )
    d2 = 0.25d0*( self%node(1,0,1)%c(1:3) + self%node(0,0,1)%c(1:3) + self%node(0,0,0)%c(1:3) + self%node(1,0,0)%c(1:3) )

    d3(1)=d1(1)-d2(1)
    d3(2)=d1(2)-d2(2)
    d3(3)=d1(3)-d2(3)

    scal=d3(1)*snjxx+d3(2)*snjyy+d3(3)*snjzz

    signj=sign(1.d0,scal)
  !------------------------------------------------------------------------------------------------
    ! k direction
    d1 = self%node(0,1,1)%c(1:3) - self%node(1,0,1)%c(1:3)
    d2 = self%node(0,0,1)%c(1:3) - self%node(1,1,1)%c(1:3)

    d3(1)=(d1(2)*d2(3)-d1(3)*d2(2))
    d3(2)=(d1(3)*d2(1)-d1(1)*d2(3))
    d3(3)=(d1(1)*d2(2)-d1(2)*d2(1))

    snkxx=d3(1)
    snkyy=d3(2)
    snkzz=d3(3)

    d1 = 0.25d0*( self%node(1,1,1)%c(1:3) + self%node(0,1,1)%c(1:3) + self%node(0,0,1)%c(1:3) + self%node(1,0,1)%c(1:3) )
    d2 = 0.25d0*( self%node(1,1,0)%c(1:3) + self%node(0,1,0)%c(1:3) + self%node(0,0,0)%c(1:3) + self%node(1,0,0)%c(1:3) )

    d3(1)=d1(1)-d2(1)
    d3(2)=d1(2)-d2(2)
    d3(3)=d1(3)-d2(3)

    scal=d3(1)*snkxx+d3(2)*snkyy+d3(3)*snkzz

    signk=sign(1.d0,scal)
  !------------------------------------------------------------------------------------------------
    
    ! compute metrics: n, A
    
    !$omp parallel private (d1,d2,d3,i,j,k,snix,sniy,sniz,Ai,Aj,snjx,snjy,snjz,Ak,snkx,snky,snkz)
    
    ! i direction
    !$omp do collapse(3)
    do k = 1, km ; do j = 1, jm ; do i = 0, im

      d1 = self%node(i,j,k)%c(1:3) - self%node(i,j-1,k-1)%c(1:3)
      d2 = self%node(i,j-1,k)%c(1:3) - self%node(i,j,k-1)%c(1:3)

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
      self%dir(1)%f(i,j,k)%a = Ai
      self%dir(1)%f(i,j,k)%n = [ snix, sniy, sniz ]
      
    end do ; end do ; end do

    ! j direction
    !$omp do collapse(3)
    do k = 1, km ; do j = 0, jm ; do  i = 1, im

      d1 = self%node(i-1,j,k)%c(1:3) - self%node(i,j,k-1)%c(1:3)
      d2 = self%node(i,j,k)%c(1:3) - self%node(i-1,j,k-1)%c(1:3)

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
      self%dir(2)%f(i,j,k)%A = Aj
      self%dir(2)%f(i,j,k)%n = [ snjx, snjy, snjz ]
  
    end do ; end do ; end do

    ! k direction
    !$omp do collapse(3)
    do k = 0, km ; do j = 1, jm ; do i = 1, im

      d1 = self%node(i-1,j,k)%c(1:3) - self%node(i,j-1,k)%c(1:3)
      d2 = self%node(i-1,j-1,k)%c(1:3) - self%node(i,j,k)%c(1:3)

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
      self%dir(3)%f(i,j,k)%A = Ak
      self%dir(3)%f(i,j,k)%n = [ snkx, snky, snkz ]

    end do ; end do ; end do
    !$omp end parallel

  end subroutine compute_norm_area


  !@brief: Compute the volume of each cell in the block with 2nd order accuracy.
  subroutine compute_volume( self, gc )
    implicit none
    class(block_type), intent(inout) :: self
    integer, intent(in) :: gc(:)
    ! Local
    real(kind=8) :: vol
    integer      :: i, j, k, im, jm, km
    real(kind=8) :: vx(8), vy(8), vz(8)

    if (mesh_cfg%meshType==-2) return

    ! Peliminary operations
    im = self%dim(1)
    jm = self%dim(2)
    km = self%dim(3)

    allocate(self%vol(1-gc(1):im+gc(1),1-gc(2):jm+gc(2),1-gc(3):km+gc(3)))

    ! cell volume computation
    !$omp parallel private(vx,vy,vz,vol,i,j,k)
    !$omp do collapse(3)
    do k = 1-gc(3), km+gc(3) ; do j = 1-gc(2), jm+gc(2) ; do i = 1-gc(1), im+gc(1)

      vx(1)=self%node(i-1,j-1,k-1)%c(1)
      vy(1)=self%node(i-1,j-1,k-1)%c(2)
      vz(1)=self%node(i-1,j-1,k-1)%c(3)

      vx(2)=self%node(i  ,j-1,k-1)%c(1)
      vy(2)=self%node(i  ,j-1,k-1)%c(2)
      vz(2)=self%node(i  ,j-1,k-1)%c(3)

      vx(3)=self%node(i-1,j  ,k-1)%c(1)
      vy(3)=self%node(i-1,j  ,k-1)%c(2)
      vz(3)=self%node(i-1,j  ,k-1)%c(3)

      vx(4)=self%node(i  ,j  ,k-1)%c(1)
      vy(4)=self%node(i  ,j  ,k-1)%c(2)
      vz(4)=self%node(i  ,j  ,k-1)%c(3)

      vx(5)=self%node(i-1,j-1,k  )%c(1)
      vy(5)=self%node(i-1,j-1,k  )%c(2)
      vz(5)=self%node(i-1,j-1,k  )%c(3)

      vx(6)=self%node(i  ,j-1,k  )%c(1)
      vy(6)=self%node(i  ,j-1,k  )%c(2)
      vz(6)=self%node(i  ,j-1,k  )%c(3)

      vx(7)=self%node(i-1,j  ,k  )%c(1)
      vy(7)=self%node(i-1,j  ,k  )%c(2)
      vz(7)=self%node(i-1,j  ,k  )%c(3)

      vx(8)=self%node(i  ,j  ,k  )%c(1)
      vy(8)=self%node(i  ,j  ,k  )%c(2)
      vz(8)=self%node(i  ,j  ,k  )%c(3)


      vol = tvol(vx,vy,vz,1,2,3,5) + tvol(vx,vy,vz,2,4,3,8) &
          + tvol(vx,vy,vz,5,8,6,2) + tvol(vx,vy,vz,5,7,8,3) &
          + tvol(vx,vy,vz,5,8,2,3)

      if( vol <= 0d0 ) then
        !write(*,*) 'Negative volume in i,j,k', i, j, k
        cycle
      endif

      !% Assign computed volume to metrics object
      self%vol(i,j,k) = vol
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

  end subroutine compute_volume


  !>@brief: Extrapolate ghost cell nodes with 2nd order accuracy.
  subroutine extrapolate_nodes(self, gc)
    implicit none
    class(block_type), intent(inout) :: self
    integer, intent(in) :: gc(:)
    integer :: im, jm, km, kl, ku
    integer :: i, j, k, n

    im = self%dim(1); jm = self%dim(2); km = self%dim(3)

    kl = lbound(self%node, dim=3); ku = ubound(self%node, dim=3)
    kl = max(kl, -1)             ; ku = min(ku, km+1)

    ! i-faces
    !$omp parallel do collapse(2) private(j,k,n)
    do k = 0, km ; do j = 0, jm
      do n = 1, gc(1)
        self%node(-n,j,k)%c   = 2d0*self%node(-n+1,j,k)%c   - self%node(-n+2,j,k)%c
        self%node(im+n,j,k)%c = 2d0*self%node(im+n-1,j,k)%c - self%node(im+n-2,j,k)%c
      end do
    enddo ; enddo
    !$omp end parallel do

    ! j-faces
    !$omp parallel do collapse(2) private(i,k,n)
    do k = 0, km ; do i = -gc(1), im+gc(1)
      do n = 1, gc(2)
        self%node(i,-n,k)%c   = 2d0*self%node(i,-n+1,k)%c   - self%node(i,-n+2,k)%c
        self%node(i,jm+n,k)%c = 2d0*self%node(i,jm+n-1,k)%c - self%node(i,jm+n-2,k)%c
      enddo
    end do ; end do
    !$omp end parallel do

    ! k-faces
    if (mesh_cfg%meshType==2 .and. mesh_cfg%delthe/=0d0) then

      ! 2Dax: extrapolation with a rotation angle delthe (exact).
      !$omp parallel do collapse(2) private(i,j,n)
      do j = -gc(2), jm+gc(2) ; do i = -gc(1), im+gc(1)
        do n = 1, gc(3)
          self%node(i,j,-n)%c(1) = self%node(i,j,-n+1)%c(1)
          self%node(i,j,km+n)%c(1) = self%node(i,j,km+n-1)%c(1) ! same x

          self%node(i,j,-n)%c(2) = self%node(i,j,-n+1)%c(2)/cos(mesh_cfg%delthe*(0.5d0+n-1))*cos(mesh_cfg%delthe*(0.5d0+n))
          self%node(i,j,-n)%c(3) = self%node(i,j,-n+1)%c(3)/sin(mesh_cfg%delthe*(0.5d0+n-1))*sin(mesh_cfg%delthe*(0.5d0+n))

          self%node(i,j,km+n)%c(2) = self%node(i,j,-n)%c(2)
          self%node(i,j,km+n)%c(3) = -self%node(i,j,-n)%c(3)
        end do
      end do ; end do
      !$omp end parallel do

    else

      !$omp parallel do collapse(2) private(i,j,n)
      do j = -gc(2), jm+gc(2) ; do i = -gc(1), im+gc(1)
        do n = 1, gc(3)
          self%node(i,j,-n)%c =   2d0*self%node(i,j,-n+1)%c   - self%node(i,j,-n+2)%c
          self%node(i,j,km+n)%c = 2d0*self%node(i,j,km+n-1)%c - self%node(i,j,km+n-2)%c
        enddo
      end do ; end do
      !$omp end parallel do
      
    endif

    ! Extrapolate edge nodes
    
    ! Edge 3-1
    i = -1; j = -1
    do k = kl, ku
      self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j+1,k)%c - self%node(i,j+2,k)%c + &
                                2d0*self%node(i+1,j,k)%c - self%node(i+2,j,k)%c )
    enddo
    ! Edge 4-1
    i = -1; j = jm+1
    do k = kl, ku
      self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j-1,k)%c - self%node(i,j-2,k)%c + &
                                2d0*self%node(i+1,j,k)%c - self%node(i+2,j,k)%c )
    enddo
    if (mesh_cfg%meshType>=2) then
      ! Edge 5-1
      i = -1; k = -1
      do j = -1, jm+1
        self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j,k+1)%c - self%node(i,j,k+2)%c + &
                                  2d0*self%node(i+1,j,k)%c - self%node(i+2,j,k)%c )
      enddo
      ! Edge 6-1
      i = -1; k = km+1
      do j = -1, jm+1
        self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j,k-1)%c - self%node(i,j,k-2)%c + &
                                  2d0*self%node(i+1,j,k)%c - self%node(i+2,j,k)%c )
      enddo
    endif
    
    ! Edge 3-2
    i = im+1; j = -1
    do k = kl, ku
      self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j+1,k)%c - self%node(i,j+2,k)%c + &
                                2d0*self%node(i-1,j,k)%c - self%node(i-2,j,k)%c )
    enddo
    ! Edge 4-2
    i = im+1; j = jm+1
    do k = kl, ku
      self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j-1,k)%c - self%node(i,j-2,k)%c + &
                                2d0*self%node(i-1,j,k)%c - self%node(i-2,j,k)%c )
    enddo
    if (mesh_cfg%meshType>=2) then
      ! Edge 5-2
      i = im+1; k = -1
      do j = -1, jm+1
        self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j,k+1)%c - self%node(i,j,k+2)%c + &
                                  2d0*self%node(i-1,j,k)%c - self%node(i-2,j,k)%c )
      enddo
      ! Edge 6-2
      i = im+1; k = km+1
      do j = -1, jm+1
        self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j,k-1)%c - self%node(i,j,k-2)%c + &
                                  2d0*self%node(i-1,j,k)%c - self%node(i-2,j,k)%c )
      enddo
    endif

    if (mesh_cfg%meshType>=2) then
      ! Edge 3-5
      j = -1; k = -1
      do i = 0, im
        self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j,k+1)%c - self%node(i,j,k+2)%c + &
                                  2d0*self%node(i,j+1,k)%c - self%node(i,j+2,k)%c )
      enddo
      ! Edge 4-5
      j = jm+1; k = -1
      do i = 0, im
        self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j,k+1)%c - self%node(i,j,k+2)%c + &
                                  2d0*self%node(i,j-1,k)%c - self%node(i,j-2,k)%c )
      enddo
      ! Edge 3-6
      j = -1; k = km+1
      do i = 0, im
        self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j,k-1)%c - self%node(i,j,k-2)%c + &
                                  2d0*self%node(i,j+1,k)%c - self%node(i,j+2,k)%c )
      enddo
      ! Edge 4-6
      j = jm+1; k = km+1
      do i = 0, im
        self%node(i,j,k)%c = 0.5*(2d0*self%node(i,j,k-1)%c - self%node(i,j,k-2)%c + &
                                  2d0*self%node(i,j-1,k)%c - self%node(i,j-2,k)%c )
      enddo
    endif

  end subroutine extrapolate_nodes


  !> Area of the cells of a single node plane (three coordinates, k = 1) projected on x-y, over their area in
  !> space: 1 for a plane parallel to x-y, 0 for a plane perpendicular to it (1 when the block has no cell).
  pure function xy_area_fraction( mesh ) result( f )
    implicit none
    real(8), intent(in) :: mesh(:,:,:,:)
    real(8) :: f, d1(3), d2(3), c(3), a3, axy
    integer :: i, j
    a3 = 0.d0; axy = 0.d0
    do j = 1, size(mesh,3)-1
      do i = 1, size(mesh,2)-1
        d1 = mesh(1:3,i+1,j+1,1) - mesh(1:3,i,j,1)
        d2 = mesh(1:3,i,j+1,1) - mesh(1:3,i+1,j,1)
        c = [d1(2)*d2(3) - d1(3)*d2(2), d1(3)*d2(1) - d1(1)*d2(3), d1(1)*d2(2) - d1(2)*d2(1)]
        a3 = a3 + norm2(c)
        axy = axy + abs(c(3))
      enddo
    enddo
    f = 1.d0
    if (a3 > 0.d0) f = axy / a3
  end function xy_area_fraction


  !> Classify a mesh (pure 2D, 1D, 2D plane or axisymmetric, 3D) into cfg (meshType, delthe): each
  !> mesh is classified in its own configuration (import_nodes), the global mesh_cfg is never touched here
  subroutine classify_mesh( mesh, cfg )
    implicit none
    real(8), intent(in) :: mesh(:,0:,0:,0:)
    type(mesh_config_type), intent(inout) :: cfg
    real(8)             :: theta1, theta2, theta(2)
    integer             :: jm

    ! Mesh definition (2D,2Dplane,2Daxi,3D)
    if (size(mesh,4)>2) then
      ! 3D
      cfg%meshType = 3
    elseif (size(mesh,1)==2) then
      ! 2D
      cfg%meshType = -2
    elseif (size(mesh,1)==1) then
      ! 1D
      cfg%meshType = -1
    elseif (size(mesh,4)==1) then
      ! three coordinates on a single node plane (a PLOT3D file written 'Ni Nj 1'): the pure 2D mesh of
      ! its (x, y) plane, as a Tecplot zone with K = 1 is read; z is not used
      cfg%meshType = -2
    elseif (size(mesh,3)==2 .and. size(mesh,4)==2) then
      ! 1D (3D file)
      cfg%meshType = 1
    else
      cfg%meshType = 2
      theta1 = atan2( mesh(3,0,1,0),mesh(2,0,1,0) )
      theta2 = atan2( mesh(3,0,1,1),mesh(2,0,1,1) )
      theta(1) = theta2-theta1
      jm = ubound(mesh,3)
      theta1 = atan2( mesh(3,0,jm,0), mesh(2,0,jm,0) )
      theta2 = atan2( mesh(3,0,jm,1), mesh(2,0,jm,1) )
      theta(2) = theta2-theta1
      if ( abs(theta(1)-theta(2)) < 1.d-5 ) then   ! |.| (a decreasing y gave a negative difference: always axi)
        ! 2Daxi
        cfg%delthe = theta(1)
      else
        ! 2Dplane
        cfg%delthe = 0.d0
      endif
    endif

  end subroutine classify_mesh


  !>@brief Compute the bounding box of each cell and of the whole block.
  subroutine compute_bounding(self, gc)

    implicit none
    class(block_type), intent(inout) :: self
    integer, intent(in)              :: gc(:)
    ! Local
    integer :: i, j, k, d
    real(8) :: min_x,max_x,min_y,max_y,min_z,max_z

    allocate(self%bbmin (1-gc(1):self%dim(1)+gc(1),1-gc(2):self%dim(2)+gc(2),1-gc(3):self%dim(3)+gc(3)))
    allocate(self%bbmax (1-gc(1):self%dim(1)+gc(1),1-gc(2):self%dim(2)+gc(2),1-gc(3):self%dim(3)+gc(3)))

    min_x = self%node(0,0,0)%c(1)
    max_x = self%node(0,0,0)%c(1)
    min_y = self%node(0,0,0)%c(2)
    max_y = self%node(0,0,0)%c(2)
    min_z = self%node(0,0,0)%c(3)
    max_z = self%node(0,0,0)%c(3)

    !$omp parallel private(i,j,k,d)

    !$omp do collapse(3)
    do k = 1-gc(3), self%dim(3)+gc(3)
      do j = 1-gc(2), self%dim(2)+gc(2)
        do i = 1-gc(1), self%dim(1)+gc(1)
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
    !$omp do collapse(3) reduction(min:min_x,min_y,min_z) reduction(max:max_x,max_y,max_z)
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

    !$omp end parallel

    self%block_bounding_min(1) = min_x
    self%block_bounding_max(1) = max_x
    self%block_bounding_min(2) = min_y
    self%block_bounding_max(2) = max_y
    self%block_bounding_min(3) = min_z
    self%block_bounding_max(3) = max_z

  end subroutine compute_bounding


  !>@brief Compute the centers of each cell in the block.
  subroutine compute_centers(self, gc)
    implicit none
    class(block_type), intent(inout) :: self
    integer, intent(in)              :: gc(:)
    ! local
    integer :: i, j, k, d

    allocate(self%center(1-gc(1):self%dim(1)+gc(1),1-gc(2):self%dim(2)+gc(2),1-gc(3):self%dim(3)+gc(3)))

    !> Compute the cells center coords
    !$omp parallel private(i,j,k,d)
    !$omp do collapse(3)
    do k = 1-gc(3), self%dim(3)+gc(3)
      do j = 1-gc(2), self%dim(2)+gc(2)
        do i = 1-gc(1), self%dim(1)+gc(1)
          do d = 1, 3
            self%center(i,j,k)%c(d)=0.125d0*(self%node(i-1,j-1,k-1)%c(d)+self%node(i,j-1,k-1)%c(d)+ &
                                             self%node(i-1,j,k-1)%c(d)+self%node(i-1,j-1,k)%c(d)+ &
                                             self%node(i,j,k)%c(d)+self%node(i,j,k-1)%c(d)+ &
                                             self%node(i,j-1,k)%c(d)+self%node(i-1,j,k)%c(d))
          enddo
          if (mesh_cfg%meshType == -2) then
            self%center(i,j,k)%c(4:5) = cartesian2cyl(self%center(i,j,k)%c(1:2))
          else
            self%center(i,j,k)%c(4:5) = cartesian2cyl(self%center(i,j,k)%c(2:3))
          endif
        enddo
      enddo
    enddo
    !$omp end parallel

  end subroutine compute_centers


  !> Convert Cartesian coordinates to cylindrical coordinates (r, theta).
  pure function cartesian2cyl(cart) result(cyl)
    implicit none
    real*8, intent(in)  :: cart(2)
    real*8              :: cyl(2)

    cyl(1) = sqrt(cart(1)**2+cart(2)**2)
    cyl(2) = datan2(cart(2),cart(1))

  end function cartesian2cyl


  !> Convert i,j,k indices to m,n indices for a given face direction.
  subroutine ijk2mn(Ai,Aj,Ak,af,am,an)
    implicit none
    integer, intent(in) :: Ai, Aj, Ak, af
    integer, intent(out) :: am, an
    
    select case (af)
    case(1,2)
      am = Aj; an = Ak
    case(3,4)
      am = Ai; an = Ak
    case(5,6)
      am = Ai; an = Aj
    end select

  end subroutine ijk2mn


  !> Convert m,n indices to i,j,k indices for a given face direction.
  subroutine fmn2ijk(af,am,an,Nx,Ny,Nz,Ai,Aj,Ak)
    implicit none
    integer, intent(in)  :: am, an, af, Nx, Ny, Nz
    integer, intent(out) :: Ai, Aj, Ak

    select case (af)
    case(1)
      Ai = 1; Aj = am; Ak = an
    case(2)
      Ai = Nx; Aj = am; Ak = an
    case(3)
      Aj = 1; Ai = am; Ak = an
    case(4)
      Aj = Ny; Ai = am; Ak = an
    case(5)
      Ak = 1; Ai = am; Aj = an
    case(6)
      Ak = Nz; Ai = am; Aj = an
    end select

  end subroutine fmn2ijk

end module grid_mod
