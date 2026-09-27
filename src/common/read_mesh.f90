module read_mesh_mod
  use Lib_ORION_data
  use IR_Precision

  implicit none
  private
  public:: read_mesh, has_ext, has_ext_series

contains

  ! Import the mesh. With `path` the named file is read; without it the default
  ! names are searched in the working directory in order of precedence
  ! (mesh.tec, mesh.p3d, mesh.szplt). The first file that EXISTS is read, with a
  ! WARNING naming it when another default name is present too. A mesh.tec that
  ! cannot be read stops the run (as upstream); a mesh.p3d that cannot be read
  ! falls back to mesh.szplt when it exists (as upstream), with a WARNING naming
  ! both files. Existence is asked to inquire(): the iostat returned by a failed
  ! open is compiler dependent (2 with gfortran, 29 with ifx) and cannot tell a
  ! missing file from an unreadable one.
  recursive subroutine read_mesh(orion,path)
    use Lib_Tecplot
    use Lib_PLOT3D
    implicit none
    type(orion_data), intent(inout)        :: orion
    character(len=*), intent(in), optional :: path
    character(len=10), parameter  :: default_mesh(3) = &
      [ character(len=10) :: 'mesh.tec', 'mesh.p3d', 'mesh.szplt' ]
    character(len=:), allocatable :: meshfile, label
    integer :: error, i, j
    integer(kind=selected_int_kind(18)) :: fsize
    logical :: found, fallback

    if (present(path)) then
      meshfile = trim(path)
      label = 'mesh file with path '//meshfile
      inquire(file=meshfile, exist=found)
      if (.not.found) then
        write(*,'(A)') ' [ERROR] '//label//' not found'
        stop 1
      endif
    else
      found = .false.
      do i = 1, size(default_mesh)
        meshfile = trim(default_mesh(i))
        inquire(file=meshfile, exist=found)
        if (found) exit
      enddo
      if (.not.found) then
        write(*,'(A)') ' [ERROR] no mesh file found: mesh.tec, mesh.p3d or mesh.szplt is required'
        stop 1
      endif
      label = meshfile
      do j = i+1, size(default_mesh)
        inquire(file=trim(default_mesh(j)), exist=found)
        if (found) write(*,'(A)') ' [WARNING] '//meshfile//' is read; '//trim(default_mesh(j))//' is also present and ignored'
      enddo
    endif
    fallback = .false.
    if (.not. present(path) .and. meshfile == 'mesh.p3d') inquire(file='mesh.szplt', exist=fallback)

    ! A file of size 0 is refused here with the usual message: ORION's PLOT3D reader
    ! has no iostat on its header reads and would end in a Fortran runtime error.
    inquire(file=meshfile, size=fsize)
    if (fsize == 0) then
      if (fallback) then
        call read_fallback('the file is empty')
        return
      endif
      write(*,'(A)') ' [ERROR] '//label//' found, but failed to read it (the file is empty)'
      stop 1
    endif

    if (has_ext_series(meshfile,'.tec')) then
      orion%tec%node = .false.
      orion%tec%bc = .false.
      orion%tec%format = 'ascii'
      error = tec_read_structured_multiblock(orion=orion,filename=meshfile)
    elseif (has_ext_series(meshfile,'.szplt')) then
#if defined(TECIO)
      orion%tec%node = .false.
      orion%tec%bc = .false.
      orion%tec%format = 'binary'
      error = tec_read_structured_multiblock(orion=orion,filename=meshfile)
#else
      write(*,'(A)') ' [ERROR] '//label//' is a binary Tecplot file, but this ATLAS build was configured without TecIO (USE_TECIO=false)'
      stop 1
#endif
    elseif (has_ext(meshfile,'.p3d')) then
      error = p3d_read_multiblock(orion=orion,filename=meshfile)
    else
      write(*,'(A)') ' [ERROR] '//label//' is not readable: unknown extension (expected .tec, .p3d or .szplt;'// &
        ' numbered series .tec.NNN / .szplt.NNN are accepted)'
      stop 1
    endif

    if (error/=0) then
      if (fallback) then
        call read_fallback('read error')
        return
      endif
      write(*,'(A)') ' [ERROR] '//label//' found, but failed to read it'
      stop 1
    endif

    if (size(orion%block) == 0) then
      write(*,*) "[ERROR] mesh file read, but no blocks imported!"
      stop 1
    endif

  contains

    ! mesh.p3d exists but cannot be read: mesh.szplt is read instead (the upstream chain)
    subroutine read_fallback(why)
      character(len=*), intent(in) :: why
      write(*,'(A)') ' [WARNING] mesh.p3d found, but failed to read it ('//why//'): mesh.szplt is read instead'
      if (allocated(orion%block)) deallocate(orion%block)
      call read_mesh(orion, 'mesh.szplt')
    end subroutine read_fallback

  end subroutine read_mesh

  ! .true. when `name` ends with `ext`: the extension decides the reader, a
  ! directory component such as `runs.tec/mesh.szplt` must not.
  pure logical function has_ext(name, ext)
    character(len=*), intent(in) :: name, ext
    has_ext = len(name) >= len(ext)
    if (has_ext) has_ext = name(len(name)-len(ext)+1:) == ext
  end function has_ext

  ! .true. when `name` ends with `ext`, or with `ext` followed by the numbered
  ! series suffix of solver dumps (`.NNN`, digits only): field.tec.001 is a .tec.
  ! A different last suffix (field.tecx, field.tec.bak) is not.
  pure logical function has_ext_series(name, ext)
    character(len=*), intent(in) :: name, ext
    integer :: p
    has_ext_series = has_ext(name, ext)
    if (has_ext_series) return
    p = index(name, '.', back=.true.)
    if (p <= 1 .or. p == len(name)) return
    if (verify(name(p+1:), '0123456789') /= 0) return
    has_ext_series = has_ext(name(1:p-1), ext)
  end function has_ext_series

end module read_mesh_mod
