!>@file BCB-Q2D.f90
!>@brief Q2D Line-Strip to 3D Boundary File Mapper
!>
!> Maps Q2D line probe output (1D periodic circumferential data) onto a 3D cylindrical face.
!> The circumferential coordinate is auto-detected from the Q2D strip geometry.
!> Interpolation is periodic in theta-space.
!>
!> @section config Configuration (input.ini, section [BCB-Q2D])
!>   meshfile     - 3D mesh file (default: mesh.tec)
!>   q2dfile      - Q2D line probe output file (required)
!>   outfile      - Output file (default: q2d_bc.tec)
!>   center       - Cylinder center coordinates x y z (required)
!>   face         - ATLAS face (1-6): 1,2=i-faces(axis x), 3,4=j-faces(axis y), 5,6=k-faces(axis z)
!>   strip-j-face - Q2D strip J face to use: 0 or 1 (default: 1)
!>
!> @note Circumferential coordinate is auto-detected from strip geometry.
!>
!> @author Alessandro Montanari

program BCB_Q2D
  use, intrinsic :: iso_fortran_env, only: R8 => real64
  use variables
  use finer, only: file_ini
  use BCB_Q2D_Map
  implicit none

  type(file_ini)     :: fini
  character(len=200) :: meshfile, q2dfile, outfile
  integer            :: face, strip_j_face, error
  real(R8)           :: cyl_center(3)

  call parse_args()

  write(*,*)
  write(*,*) '=============================================='
  write(*,*) ' ATLAS - Q2D to 3D Boundary Mapper'
  write(*,*) '=============================================='
  write(*,*)

  call fini%load(filename='input.ini')

  call fini%get(section_name='BCB-Q2D', option_name='q2dfile', val=q2dfile, error=error)
  if (error /= 0) stop "[ERROR] Missing BCB-Q2D input .tec file in input.ini"

  call fini%get(section_name='BCB-Q2D', option_name='meshfile', val=meshfile, error=error)
  if (error /= 0) meshfile = 'mesh.tec'

  call fini%get(section_name='BCB-Q2D', option_name='outfile', val=outfile, error=error)
  if (error /= 0) outfile = 'q2d_bc.tec'

  call fini%get(section_name='BCB-Q2D', option_name='center', val=cyl_center, error=error)
  if (error /= 0) stop "[ERROR] Missing BCB-Q2D:center in input.ini (x y z)"

  call fini%get(section_name='BCB-Q2D', option_name='face', val=face, error=error)
  if (error /= 0) face = 5

  call fini%get(section_name='BCB-Q2D', option_name='strip-j-face', val=strip_j_face, error=error)
  if (error /= 0) strip_j_face = 1

  if (verbose) then
    write(*,*) '[CONFIG] meshfile    = ', trim(meshfile)
    write(*,*) '[CONFIG] q2dfile     = ', trim(q2dfile)
    write(*,*) '[CONFIG] outfile     = ', trim(outfile)
    write(*,'(A,3ES14.6)') ' [CONFIG] center     = ', cyl_center
    write(*,*) '[CONFIG] face        = ', face
    write(*,*) '[CONFIG] strip-j-face= ', strip_j_face
    write(*,*)
  endif

  if (face < 1 .or. face > 6) stop "[ERROR] face must be 1-6"
  if (strip_j_face < 0 .or. strip_j_face > 1) stop "[ERROR] strip-j-face must be 0 or 1"

  call run_q2d_bc_map(meshfile, q2dfile, outfile, face, strip_j_face, cyl_center)

  write(*,*)
  write(*,*) '[DONE] BCB-Q2D mapping completed successfully'
  write(*,*)

contains

  subroutine parse_args()
    character(99) :: arg
    integer :: i
    verbose = .false.
    do i = 1, command_argument_count()
      call get_command_argument(i, arg)
      if (arg == '-v' .or. arg == '--verbose') verbose = .true.
      if (arg == '-h' .or. arg == '--help') call print_help()
    enddo
  end subroutine

  subroutine print_help()
    write(*,*) 'BCB-Q2D - Maps Q2D line probe data onto 3D cylindrical face'
    write(*,*) ''
    write(*,*) 'Usage: BCB-Q2D [-v|--verbose] [-h|--help]'
    write(*,*) ''
    write(*,*) 'Config: input.ini [BCB-Q2D]'
    write(*,*) '  q2dfile       Q2D line probe file (required)'
    write(*,*) '  meshfile      3D mesh file (default: mesh.tec)'
    write(*,*) '  outfile       Output file (default: q2d_bc.tec)'
    write(*,*) '  center        Cylinder center x y z (required)'
    write(*,*) '  face          ATLAS face 1-6 (default: 5)'
    write(*,*) '                1,2: i-faces (axis x)'
    write(*,*) '                3,4: j-faces (axis y)'
    write(*,*) '                5,6: k-faces (axis z)'
    write(*,*) '  strip-j-face  Q2D strip J face: 0 or 1 (default: 1)'
    write(*,*) ''
    write(*,*) 'Note: Circ. coord auto-detected from strip geometry.'
    stop
  end subroutine

end program BCB_Q2D
