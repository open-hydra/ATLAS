module st_io_mod
  use Lib_ORION_data
  use IR_Precision
  implicit none

  character(len=18), parameter :: outpath = 'fromATLAStoSolver/'

contains

  !>
  !> Write var field to Tecplot and/or VTK format
  !>
  !> the output format (-o) asks for a binary Tecplot file (st.szplt) but the
  !> build has no TecIO: refused at start (the writer below keeps the same guard).
  subroutine check_st_format_build(output_format)
    implicit none
    character(len=*), intent(in) :: output_format
#if !defined(TECIO)
    if ((index(output_format, 'tec') > 0 .or. index(output_format, 'all') > 0) .and. index(output_format, 'binary') > 0) then
      write(*,'(A)') '[ERROR] output format '//trim(output_format)//' asks for a binary Tecplot file (st.szplt)'// &
                     ' but this build has no TecIO (configure with -DUSE_TECIO=true, or use tec-ascii / vtk-binary)'
      stop 1
    endif
#endif
  end subroutine check_st_format_build

  subroutine write_st_vtk_tec(st_blocks, mesh_blocks, output_format)
    use Lib_VTK
    use Lib_Tecplot
    use global_mod, only: llen
    use st_block_mod
    use grid_mod, only: block_type, mesh_cfg
    implicit none

    type(st_block), intent(in) :: st_blocks(:)
    type(block_type), intent(in) :: mesh_blocks(:)
    character(len=*), intent(in) :: output_format

    type(orion_data) :: orion
    character(len=llen) :: localpath_vtk, localpath
    integer(I4P) :: E_IO, b, i, j, k
    character(len=256) :: varnames, filename
    logical :: write_tec, write_vtk, any_st

    ! Skip output when no block has a configured source term
    ! (e.g. STB run only to build area variation files)
    any_st = .false.
    do b = 1, size(st_blocks)
      if (allocated(st_blocks(b)%var)) any_st = .true.
    enddo
    if (.not. any_st) then
      write(*,*)
      write(*,*) ' - No volumetric source terms configured: skipping qvol output files'
      ! Nothing is written, so a qvol file left by a previous run would be
      ! picked up by the solver as if it were current: say so.
      call warn_if_stale(trim(outpath)//'st.tec')
      call warn_if_stale(trim(outpath)//'st.szplt')
      call warn_if_stale(trim(outpath)//'qvol.vtm')
      write(*,*)
      return
    endif

    localpath = outpath
    orion%solutiontime = -10.0

    ! Parse output format
    write_tec = (index(output_format, 'tec') > 0 .or. index(output_format, 'all') > 0)
    write_vtk = (index(output_format, 'vtk') > 0 .or. index(output_format, 'all') > 0)

    call execute_command_line('mkdir -p '//trim(outpath))

    ! Allocate orion blocks
    if (allocated(orion%block)) deallocate(orion%block)
    allocate(orion%block(1:size(st_blocks)))

    write(*,*)
    write(*,*) ' - Building source terms output files'

    do b = 1, size(st_blocks)
      orion%block(b)%Ni = mesh_blocks(b)%dim(1)
      orion%block(b)%Nj = mesh_blocks(b)%dim(2)
      orion%block(b)%Nk = mesh_blocks(b)%dim(3)

      ! Copy mesh coordinates
      if (mesh_cfg%meshType == -2) then
        ! 2D mesh
        allocate(orion%block(b)%mesh(1:2, 0:mesh_blocks(b)%dim(1), 0:mesh_blocks(b)%dim(2), 0:0))
        do j = 0, mesh_blocks(b)%dim(2)
          do i = 0, mesh_blocks(b)%dim(1)
            orion%block(b)%mesh(1:2, i, j, 0) = mesh_blocks(b)%node(i,j,0)%c(1:2)
          enddo
        enddo
      else
        ! 3D mesh
        allocate(orion%block(b)%mesh(1:3, 0:mesh_blocks(b)%dim(1), &
                                         0:mesh_blocks(b)%dim(2), &
                                         0:mesh_blocks(b)%dim(3)))
        do k = 0, mesh_blocks(b)%dim(3)
          do j = 0, mesh_blocks(b)%dim(2)
            do i = 0, mesh_blocks(b)%dim(1)
              orion%block(b)%mesh(1:3, i, j, k) = mesh_blocks(b)%node(i,j,k)%c(1:3)
            enddo
          enddo
        enddo
      endif

      ! Copy ST variable
      allocate(orion%block(b)%vars(1:1, 1:mesh_blocks(b)%dim(1), &
                                        1:mesh_blocks(b)%dim(2), &
                                        1:mesh_blocks(b)%dim(3)))
      if (allocated(st_blocks(b)%var)) then
        orion%block(b)%vars(1, :, :, :) = st_blocks(b)%var
      else
        ! Block without a qvol configuration: no heat source (the solver reads
        ! every block of the file, so the block cannot be omitted).
        orion%block(b)%vars(1, :, :, :) = 0.0_R8P
      endif
      orion%block(b)%name = 'B'//trim(str(.true., b))//'-ST'
    enddo

    varnames = ' qvol'

    ! Write VTK format
    if (write_vtk) then
      localpath_vtk = trim(localpath)//'/vtk/'
      call execute_command_line('mkdir -p '//trim(localpath_vtk))
      write(*,*) '   - Writing VTK format'
      
      ! Determine VTK format from output_format string
      if (index(output_format, 'binary') > 0) then
        orion%vtk%format = 'binary'
      else if (index(output_format, 'ascii') > 0) then
        orion%vtk%format = 'ascii'
      else
        orion%vtk%format = 'raw'
      endif
      
      orion%vtk%node = .false.
      E_IO = vtk_write_structured_multiblock(orion=orion, vtspath=trim(localpath_vtk), &
                                             vtmpath=trim(localpath)//'/qvol', &
                                             varnames=varnames)
      
      if (E_IO /= 0) write(*,'(A,I0)') '   [WARNING] VTK write error: ', E_IO
    endif

    ! Write Tecplot format
    if (write_tec) then
      write(*,*) '   - Writing Tecplot format'
      
      if (index(output_format, 'binary') > 0) then
#if !defined(TECIO)
        write(*,'(A)') '[ERROR] output format '//trim(output_format)//': a binary Tecplot file (st.szplt) needs a TecIO build'
        stop 1
#endif
        orion%tec%format = 'binary'
        filename = trim(localpath)//'/st.szplt'
      else
        orion%tec%format = 'ascii'
        filename = trim(localpath)//'/st.tec'
      endif
      
      orion%tec%node = .false.
      E_IO = tec_write_structured_multiblock(orion=orion, varnames=varnames, &
                                             filename=trim(filename))
      
      if (E_IO /= 0) write(*,'(A,I0)') '   [WARNING] Tecplot write error: ', E_IO
    endif

    write(*,*)
  end subroutine write_st_vtk_tec

  !>
  !> Warn when an output file of a previous run is left in place
  !>
  subroutine warn_if_stale(filename)
    implicit none
    character(len=*), intent(in) :: filename
    logical :: found

    inquire(file=filename, exist=found)
    if (found) write(*,*) '   [WARNING] '//filename//' exists from a previous run and has NOT been updated'
  end subroutine warn_if_stale

end module st_io_mod
