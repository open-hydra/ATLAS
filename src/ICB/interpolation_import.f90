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
  integer                                      :: old_mesh_type = 0  ! meshType of the loaded old-solution source
  ! the law and the sector the loaded source was read with (an extruded source is not the file's own block)
  character(len=llen)                          :: oldlaw = ''
  real(R8)                                     :: oldtheta = 0.0_R8
  integer                                      :: oldnz = 0


contains


  subroutine build_old_solution(oldsolutionfile_, phase, n_species)
    use grid_mod, only: mesh_config_type
    implicit none
    character(len=llen), intent(inout) :: oldsolutionfile_
    character(len=*),    intent(in)    :: phase
    integer, optional,   intent(in)    :: n_species
    !! Local
    type(mesh_config_type) :: ocfg

    oldsolutionfile = oldsolutionfile_
    oldlaw   = config_interpolation % law
    oldtheta = config_interpolation % theta
    oldnz    = config_interpolation % nz

    if (verbose) write(*,*)" Reading solution file: ", trim(oldsolutionfile)
    call read_vtk_tec(phase,oldsolutionfile,oldblock,n_species,src_cfg=ocfg)
    old_mesh_type = ocfg%meshType

    if (config_interpolation % law=='extrude') then
      if (verbose) then
        write(*,*)" Old mesh extrusion"
        write(*,*)" Extrusion angle    = ", config_interpolation % theta
        write(*,*)" Extrusion elements = ", config_interpolation % nz
      endif
      call extrude_old_solution(phase, config_interpolation % nz, config_interpolation % theta, old_mesh_type == -2)
      old_mesh_type = 3   ! the revolved source is a 3D block
      if (verbose) write(*,*) "[LOG] Old solution built"
    endif

  end subroutine build_old_solution


  !> interpolation-law = extrude: every block of the one-cell (2D) source is revolved about the x axis
  !> through theta degrees in nz cells. Node plane k (k = 0..nz) lies at the azimuth k*theta/nz, so the
  !> source plane is azimuth 0 and the sector turns towards +z. Every field is copied onto each cell of
  !> the sector; the velocity (v, w) and, under the Reynolds-stress model, the stresses are turned by
  !> the azimuth of the cell centre (minus the azimuth of the source cell for a one-cell wedge source).
  !> The target cells then take the nearest cell of the revolved source (compute_interp_map): on a
  !> target revolved with the same cells this is the field of the index law.
  subroutine extrude_old_solution(phase, nz, theta_deg, src_pure2d)
    use grid_mod, only: mesh_cfg
    implicit none
    character(len=*), intent(in) :: phase
    integer,          intent(in) :: nz
    real(R8),         intent(in) :: theta_deg
    logical,          intent(in) :: src_pure2d
    real(R8), allocatable :: xs(:,:), rs(:,:), asrc(:,:)
    real(R8) :: dphi, dth, c, s, v, w
    integer  :: b, i, j, k, ni, nj, m, nr

    if (nz < 1) then
      write(*,'(A,I0,A)') "[ERROR] interpolation-law = extrude: nz = ", nz, " (the number of cells of the sector must be >= 1)"
      stop 1
    endif
    if (.not. (theta_deg > 0.0_R8 .and. theta_deg <= 360.0_R8)) then
      write(*,'(A,ES12.5,A)') "[ERROR] interpolation-law = extrude: theta = ", theta_deg, &
        " degrees (the angle of the sector must lie in (0, 360])"
      stop 1
    endif
    if (mesh_cfg%meshType == -2 .or. mesh_cfg%meshType == -1) then
      write(*,'(A)') "[ERROR] interpolation-law = extrude revolves the source into a 3D sector, but the target mesh is"// &
        " not 3D: use index, minimum_distance or another law of a 2D target"
      stop 1
    endif
    dphi = (theta_deg*acos(-1.0_R8)/180.0_R8)/real(nz, R8)

    do b = 1, size(oldblock)
      if (oldblock(b)%dim(3) /= 1) then
        write(*,'(A,I0,A,I0,A)') "[ERROR] interpolation-law = extrude revolves a one-cell (2D) source, but block ", b, &
          " of the source has ", oldblock(b)%dim(3), " cells along k: use index or a distance law for a 3D source"
        stop 1
      endif
      ni = oldblock(b)%dim(1); nj = oldblock(b)%dim(2)
      allocate(xs(0:ni,0:nj), rs(0:ni,0:nj), asrc(1:ni,1:nj))
      ! source plane: x and the radius of every node (a pure-2D file holds (x, r) in (x, y); a one-cell
      ! wedge holds its two node planes at the same radius) and the azimuth of every source cell
      do j = 0, nj; do i = 0, ni
        xs(i,j) = oldblock(b)%node(i,j,0)%c(1)
        if (src_pure2d) then
          rs(i,j) = oldblock(b)%node(i,j,0)%c(2)
        else
          rs(i,j) = 0.5_R8*(sqrt(oldblock(b)%node(i,j,0)%c(2)**2 + oldblock(b)%node(i,j,0)%c(3)**2) + &
                            sqrt(oldblock(b)%node(i,j,1)%c(2)**2 + oldblock(b)%node(i,j,1)%c(3)**2))
        endif
      enddo; enddo
      asrc = 0.0_R8
      if (.not. src_pure2d) then
        do j = 1, nj; do i = 1, ni
          asrc(i,j) = atan2(oldblock(b)%center(i,j,1)%c(3), oldblock(b)%center(i,j,1)%c(2))
        enddo; enddo
      endif

      ! revolved nodes and centres
      deallocate(oldblock(b)%node)
      allocate(oldblock(b)%node(0:ni,0:nj,0:nz))
      do k = 0, nz; do j = 0, nj; do i = 0, ni
        oldblock(b)%node(i,j,k)%c(1) = xs(i,j)
        oldblock(b)%node(i,j,k)%c(2) = rs(i,j)*cos(k*dphi)
        oldblock(b)%node(i,j,k)%c(3) = rs(i,j)*sin(k*dphi)
        oldblock(b)%node(i,j,k)%c(4:5) = 0.0_R8
      enddo; enddo; enddo
      oldblock(b)%dim(3) = nz
      if (allocated(oldblock(b)%center)) deallocate(oldblock(b)%center)
      call oldblock(b)%compute_centers([0,0,0])

      ! fields: copied onto every cell of the sector, velocity (and stresses) turned by the cell azimuth
      select case (phase)
      case ('SP')
        call grow3(oldblock(b)%sp%temperature)
        call grow3(oldblock(b)%sp%mID)
      case ('IG')
        call grow4(oldblock(b)%ig%density)
        call grow4(oldblock(b)%ig%velocity)
        call grow3(oldblock(b)%ig%pressure)
        nr = 0
        if (allocated(oldblock(b)%ig%turbprop)) then
          call grow4(oldblock(b)%ig%turbprop)
          nr = size(oldblock(b)%ig%turbprop, 1)
        endif
        do k = 1, nz; do j = 1, nj; do i = 1, ni
          dth = azimuth(i,j,k)
          c = cos(dth); s = sin(dth)
          v = oldblock(b)%ig%velocity(2,i,j,k); w = oldblock(b)%ig%velocity(3,i,j,k)
          oldblock(b)%ig%velocity(2,i,j,k) = v*c - w*s
          oldblock(b)%ig%velocity(3,i,j,k) = v*s + w*c
          if (nr == 7) call turn_stresses(oldblock(b)%ig%turbprop(:,i,j,k), c, s)
        enddo; enddo; enddo
      case ('RF')
        call grow3(oldblock(b)%rf%enthalpy)
        call grow3(oldblock(b)%rf%pressure)
        call grow4(oldblock(b)%rf%velocity)
        nr = 0
        if (allocated(oldblock(b)%rf%turbprop)) then
          call grow4(oldblock(b)%rf%turbprop)
          nr = size(oldblock(b)%rf%turbprop, 1)
        endif
        do k = 1, nz; do j = 1, nj; do i = 1, ni
          dth = azimuth(i,j,k)
          c = cos(dth); s = sin(dth)
          v = oldblock(b)%rf%velocity(2,i,j,k); w = oldblock(b)%rf%velocity(3,i,j,k)
          oldblock(b)%rf%velocity(2,i,j,k) = v*c - w*s
          oldblock(b)%rf%velocity(3,i,j,k) = v*s + w*c
          if (nr == 7) call turn_stresses(oldblock(b)%rf%turbprop(:,i,j,k), c, s)
        enddo; enddo; enddo
      case ('CD', 'DP')
        call grow4(oldblock(b)%dp%density)
        call grow5(oldblock(b)%dp%velocity)
        call grow4(oldblock(b)%dp%temperature)
        call grow4(oldblock(b)%dp%nP)
        call grow4(oldblock(b)%dp%pseudopressure)
        do k = 1, nz; do j = 1, nj; do i = 1, ni
          dth = azimuth(i,j,k)
          c = cos(dth); s = sin(dth)
          do m = 1, size(oldblock(b)%dp%velocity, 1)
            v = oldblock(b)%dp%velocity(m,2,i,j,k); w = oldblock(b)%dp%velocity(m,3,i,j,k)
            oldblock(b)%dp%velocity(m,2,i,j,k) = v*c - w*s
            oldblock(b)%dp%velocity(m,3,i,j,k) = v*s + w*c
          enddo
        enddo; enddo; enddo
      end select
      deallocate(xs, rs, asrc)
    enddo

  contains

    !> azimuth by which the source vector of cell (i,j) is turned onto revolved cell (i,j,k)
    real(R8) function azimuth(i, j, k)
      integer, intent(in) :: i, j, k
      azimuth = atan2(oldblock(b)%center(i,j,k)%c(3), oldblock(b)%center(i,j,k)%c(2)) - asrc(i,j)
    end function azimuth

    !> Reynolds stresses (Rxx Ryy Rzz Rxy Rxz Ryz omega) turned about x (as rotate_2d_to_3d)
    subroutine turn_stresses(rst, c, s)
      real(R8), intent(inout) :: rst(:)
      real(R8), intent(in)    :: c, s
      real(R8) :: Ryy, Rzz, Ryz, Rxy, Rxz
      Ryy = rst(2)*c*c + rst(3)*s*s - 2.0_R8*rst(6)*s*c
      Rzz = rst(2)*s*s + rst(3)*c*c + 2.0_R8*rst(6)*s*c
      Ryz = (rst(2) - rst(3))*s*c + rst(6)*(c*c - s*s)
      Rxy = rst(4)*c - rst(5)*s
      Rxz = rst(4)*s + rst(5)*c
      rst(2) = Ryy; rst(3) = Rzz; rst(4) = Rxy; rst(5) = Rxz; rst(6) = Ryz
    end subroutine turn_stresses

    subroutine grow3(a)
      real(8), allocatable, intent(inout) :: a(:,:,:)
      real(8), allocatable :: t(:,:,:)
      integer :: kk
      if (.not. allocated(a)) return
      allocate(t(size(a,1), size(a,2), nz))
      do kk = 1, nz
        t(:,:,kk) = a(:,:,1)
      enddo
      call move_alloc(t, a)
    end subroutine grow3

    subroutine grow4(a)
      real(8), allocatable, intent(inout) :: a(:,:,:,:)
      real(8), allocatable :: t(:,:,:,:)
      integer :: kk
      if (.not. allocated(a)) return
      allocate(t(size(a,1), size(a,2), size(a,3), nz))
      do kk = 1, nz
        t(:,:,:,kk) = a(:,:,:,1)
      enddo
      call move_alloc(t, a)
    end subroutine grow4

    subroutine grow5(a)
      real(8), allocatable, intent(inout) :: a(:,:,:,:,:)
      real(8), allocatable :: t(:,:,:,:,:)
      integer :: kk
      if (.not. allocated(a)) return
      allocate(t(size(a,1), size(a,2), size(a,3), size(a,4), nz))
      do kk = 1, nz
        t(:,:,:,:,kk) = a(:,:,:,:,1)
      enddo
      call move_alloc(t, a)
    end subroutine grow5

  end subroutine extrude_old_solution


  subroutine ensure_old_solution(oldsolutionfile_, phase, n_species)
    implicit none
    character(len=llen), intent(inout) :: oldsolutionfile_
    character(len=*),    intent(in)    :: phase
    integer, optional,   intent(in)    :: n_species

    if (.not. allocated(oldblock)) then
      call build_old_solution(oldsolutionfile_, phase, n_species)
    elseif (oldsolutionfile_ /= oldsolutionfile .or. config_interpolation % law /= oldlaw .or. &
            (oldlaw == 'extrude' .and. (config_interpolation % theta /= oldtheta .or. config_interpolation % nz /= oldnz))) then
      ! another file, or the same file read with another law (an extruded source is not the file's block)
      deallocate(oldblock)
      call build_old_solution(oldsolutionfile_, phase, n_species)
    endif
  end subroutine ensure_old_solution

end module ic_interpolation_old_mod
