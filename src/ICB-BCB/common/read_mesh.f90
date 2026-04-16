module read_mesh_mod
  use Lib_ORION_data
  use IR_Precision

  implicit none
  private
  public:: read_mesh

contains

  subroutine read_mesh(orion,path)
    use Lib_Tecplot
    use Lib_PLOT3D
    implicit none
    type(orion_data), intent(inout)        :: orion
    character(len=*), intent(in), optional :: path
    integer :: error

    if (present(path)) then
      if (index(path,'.tec')>0) then
        orion%tec%node = .false.
        orion%tec%bc = .false.
        orion%tec%format = 'ascii'
        error = tec_read_structured_multiblock(orion=orion,filename=trim(path))
      elseif (index(path,'.szplt')>0) then
        orion%tec%node = .false.
        orion%tec%bc = .false.
        orion%tec%format = 'binary'
        error = tec_read_structured_multiblock(orion=orion,filename=trim(path))
      elseif (index(path,'.p3d')>0) then
        error = p3d_read_multiblock(orion=orion,filename=path)
      else
        write(*,*) '[ERROR] mesh file is not readable'
        stop
      endif
    else
      orion%tec%node = .false.
      orion%tec%bc = .false.
      orion%tec%format = 'ascii'
      error = tec_read_structured_multiblock(orion=orion,filename='mesh.tec')
      if (error/=0) then   
        error = p3d_read_multiblock(orion=orion,filename='mesh.p3d')
        if (error/=0) then
          orion%tec%format = 'binary'
          error = tec_read_structured_multiblock(orion=orion,filename='mesh.szplt')
        endif
      endif
      if (error/=0) then   
        write(*,*) '[ERROR] mesh file is not readable'
      endif
    endif

    if (size(orion%block) == 0) then
      write(*,*) "[ERROR] mesh file read, but no blocks imported!"
      stop
    endif


  end subroutine read_mesh

end module read_mesh_mod
