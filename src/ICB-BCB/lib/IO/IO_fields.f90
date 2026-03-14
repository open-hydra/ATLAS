module ATLAS_IO_fields
  use Lib_ORION_data
  use IR_Precision

  implicit none
  private
  public:: read_vtk_tec ,write_vtk_tec
  public:: read_solfile, write_solfile
  public:: read_mesh

  integer:: unitfile

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
      if (error==0) return   
      error = p3d_read_multiblock(orion=orion,filename='mesh.p3d')
      if (error/=0) then
      orion%tec%format = 'binary'
      error = tec_read_structured_multiblock(orion=orion,filename='mesh.szplt')
      if (error==0) return   
        write(*,*) '[ERROR] mesh file is not readable'
        stop
      endif
    endif

    if (error/=0) &
      stop ("[ERROR] mesh reading failed")

  end subroutine read_mesh


  subroutine write_solfile(phase,inblock)
    use variables, only: nrans, outpath
    use ATLAS_high_level, only: ATLAS_block
    use phase_module
    implicit none
    type(phase_type), intent(in)   :: phase
    type(ATLAS_block), intent(in)  :: inblock(:)
    type(ATLAS_block), allocatable :: block(:)
    integer :: b, nb, i, j, k ,s, ap, nsc, cnt

    nb = 0
    do b = 1, size(inblock)
      do ap = 1, size(inblock(b)%associated_phase(:))
        if (index(phase%name,inblock(b)%associated_phase(ap)%name)>0) then
          nb = nb + 1
          nsc = inblock(b)%associated_phase(ap)%species%n
        endif
      enddo
    enddo
    if (allocated(block)) deallocate(block)
    allocate(block(1:nb))

    cnt = 0
    do b = 1, size(inblock)
      do ap = 1, size(inblock(b)%associated_phase(:))
        if (index(phase%name,inblock(b)%associated_phase(ap)%name)>0) then
          cnt = cnt + 1 
          block(cnt) = inblock(b)
        endif
      enddo
    enddo
  
    write(*,*)
    write(*,*)' Writing native-fomat file'
    open(newunit=unitfile,file=outpath//'/media.init',form='unformatted',convert='big_endian')

    write(unitfile) nb
    do b = 1, nb; write(unitfile) block(b)%dim(1); end do
    do b = 1, nb; write(unitfile) block(b)%dim(2); end do
    do b = 1, nb; write(unitfile) block(b)%dim(3); end do

    !write(*,*)' Writing  variables'
    !write(*,*)'        -----> rho(Ns)'
    do b = 1, nb
      write(unitfile)((((dble(block(b)%density(s,i,j,k)),s=1,nsc), &
                                             i=1,block(b)%dim(1)),j=1,block(b)%dim(2)),k=1,block(b)%dim(3))
    end do
    !write(*,*)'        -----> u'
    do b = 1, nb
      write(unitfile) (((dble(block(b)%velocity(1,i,j,k)),i=1,block(b)%dim(1)),j=1,block(b)%dim(2)),k=1,block(b)%dim(3))
    end do
    !write(*,*)'        -----> v'
    do b = 1, nb
      write(unitfile) (((dble(block(b)%velocity(2,i,j,k)),i=1,block(b)%dim(1)),j=1,block(b)%dim(2)),k=1,block(b)%dim(3))
    end do
    !write(*,*)'        -----> w'
    do b = 1, nb
      write(unitfile) (((dble(block(b)%velocity(3,i,j,k)),i=1,block(b)%dim(1)),j=1,block(b)%dim(2)),k=1,block(b)%dim(3))
    end do
    !write(*,*)'        -----> p'
    do b = 1, nb
      write(unitfile) (((dble(block(b)%pressure(i,j,k)),i=1,block(b)%dim(1)),j=1,block(b)%dim(2)),k=1,block(b)%dim(3))
    end do

    if (nrans>0) then
      do b = 1, nb
        write(unitfile) ((((dble(block(b)%turbprop(s,i,j,k)),s=1,nrans),i=1,block(b)%dim(1)),j=1,block(b)%dim(2)),k=1,block(b)%dim(3))
      end do
    endif

    ! scrittura della variabile tempo
    write(unitfile) 0.d0

    close(unitfile)

  end subroutine write_solfile


  subroutine read_solfile(phase_type,filename,icblock,n)
    use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
    use variables, only: nrans, llen
    use ATLAS_high_level, only: ATLAS_block
    implicit none
    character(len=2), intent(in)     :: phase_type
    integer, intent(in), optional    :: n
    character(len=llen), intent(in)  :: filename
    type(ATLAS_block), intent(inout) :: icblock(:)
    ! Local
    integer                          :: i, j, k, s, b, nb, Nmax(3), cnt, io
    integer, allocatable             :: Nx(:), Ny(:), Nz(:)
    real(kind=R8), dimension(:,:,:,:), allocatable      :: var
    real(kind=R8), dimension(:,:,:,:,:), allocatable    :: vars, vart

    open(newunit=unitfile, file = filename, status = 'old', form = 'unformatted', convert='big_endian')

    read(unitfile) nb
    allocate(Nx(nb))
    allocate(Ny(nb))
    allocate(Nz(nb))

    do b = 1, (nb)
      read(unitfile) Nx(b)
    end do
    Nmax(1) = maxval(Nx)

    do b = 1, (nb)
      read(unitfile) Ny(b)
    end do
    Nmax(2) = maxval(Ny)

    do b = 1, (nb)
      read(unitfile) Nz(b)
    end do
    Nmax(3) = maxval(Nz)

    if (phase_type=='IG') then

      allocate(var(1:nb,1:Nmax(1),1:Nmax(2),1:Nmax(3)))
      allocate(vars(1:n,1:nb,1:Nmax(1),1:Nmax(2),1:Nmax(3)))
      allocate(vart(1:nrans,1:nb,1:Nmax(1),1:Nmax(2),1:Nmax(3)))
    
      do b = 1, nb
        read(unitfile)((((vars(s,b,i,j,k),s=1,n),i=1,Nx(b)),j=1,Ny(b)),k=1,Nz(b))
        icblock(b)%density(1:n,1:Nx(b),1:Ny(b),1:Nz(b)) = vars(1:n,b,1:Nx(b),1:Ny(b),1:Nz(b))
      end do
      do cnt = 1, 3
        do b = 1, nb
          read(unitfile)(((var(b,i,j,k),i=1,Nx(b)),j=1,Ny(b)),k=1,Nz(b))
          icblock(b)%velocity(cnt,1:Nx(b),1:Ny(b),1:Nz(b)) = var(b,1:Nx(b),1:Ny(b),1:Nz(b))
        end do
      end do
      do b = 1, nb
        read(unitfile)(((var(b,i,j,k),i=1,Nx(b)),j=1,Ny(b)),k=1,Nz(b))
        icblock(b)%pressure(1:Nx(b),1:Ny(b),1:Nz(b)) = var(b,1:Nx(b),1:Ny(b),1:Nz(b))
      end do
      ! Turbulent models
      do b = 1, nb
        read(unitfile,iostat=io)((((vart(s,b,i,j,k),s=1,nrans),i=1,Nx(b)),j=1,Ny(b)),k=1,Nz(b))
        if (io==0) then
          icblock(b)%turbprop(1:nrans,1:Nx(b),1:Ny(b),1:Nz(b)) = vart(:,b,1:Nx(b),1:Ny(b),1:Nz(b))
        else
          icblock(b)%turbprop(1:nrans,1:Nx(b),1:Ny(b),1:Nz(b)) = 0.0
        endif
      enddo

    elseif (phase_type=='SP') then

      allocate(var(1:nb,1:Nmax(1),1:Nmax(2),1:Nmax(3)))
    
      do b = 1, nb
        read(unitfile)(((var(b,i,j,k),i=1,Nx(b)),j=1,Ny(b)),k=1,Nz(b))
        icblock(b)%temperature(1:Nx(b),1:Ny(b),1:Nz(b)) = var(b,1:Nx(b),1:Ny(b),1:Nz(b))
      end do

      do b = 1, nb
        read(unitfile)(((var(b,i,j,k),i=1,Nx(b)),j=1,Ny(b)),k=1,Nz(b))
        icblock(b)%mID(1:Nx(b),1:Ny(b),1:Nz(b)) = var(b,1:Nx(b),1:Ny(b),1:Nz(b))
      end do

      do b = 1, nb
        read(unitfile)(((var(b,i,j,k),i=1,Nx(b)),j=1,Ny(b)),k=1,Nz(b))
        icblock(b)%qvol(1:Nx(b),1:Ny(b),1:Nz(b)) = var(b,1:Nx(b),1:Ny(b),1:Nz(b))
      end do

    endif
    
    close(unitfile)

  end subroutine read_solfile


  subroutine read_vtk_tec (phase_type,filename,icblock,n)
    use Lib_VTK
    use Lib_Tecplot
    use Lib_ORION_data
    use variables, only: nrans, llen
    use ATLAS_high_level
    implicit none
    character(len=2), intent(in)     :: phase_type
    integer, intent(in), optional    :: n
    character(len=llen), intent(in)  :: filename
    type(ATLAS_block), allocatable, intent(inout) :: icblock(:)
    ! Local
    type(Orion_Data) :: IOfield
    integer:: error, b, s

    if (index(filename,'.tec')>0) then
      IOfield%tec%format = 'ascii'
      error = tec_read_structured_multiblock(orion=IOfield,filename=trim(filename))
    elseif (index(filename,'.szplt')>0) then
      IOfield%tec%format = 'binary'
      error = tec_read_structured_multiblock(orion=IOfield,filename=trim(filename))
    endif

    if (error/=0) stop "[ERROR] reading "//trim(filename)

    call import_nodes(input=IOfield,output=icblock)

    if (phase_type=='IG') then
      do b = 1, size(icblock)
        call icblock(b)%compute_centers([0,0,0])
        call icblock(b)%allocate(nrans,n,icblock(b)%dim(1),icblock(b)%dim(2),icblock(b)%dim(3))
        if (size(IOfield%block(b)%vars)>0) then
          do s = 1, n
            icblock(b)%density(s,1:icblock(b)%dim(1),1:icblock(b)%dim(2),1:icblock(b)%dim(3)) = IOfield%block(b)%vars(s,:,:,:)
          enddo
          icblock(b)%velocity(1:3,1:icblock(b)%dim(1),1:icblock(b)%dim(2),1:icblock(b)%dim(3)) = IOfield%block(b)%vars(n+1:n+3,:,:,:)
          icblock(b)%pressure(1:icblock(b)%dim(1),1:icblock(b)%dim(2),1:icblock(b)%dim(3)) = IOfield%block(b)%vars(n+4,:,:,:)
          do s = 1, nrans
            icblock(b)%turbprop(s,1:icblock(b)%dim(1),1:icblock(b)%dim(2),1:icblock(b)%dim(3)) = IOfield%block(b)%vars(n+4+s,:,:,:)
          enddo 
        endif
      end do
    
    elseif (phase_type=='SP') then
      do b = 1, size(icblock)
        call icblock(b)%compute_centers([0,0,0])
        call icblock(b)%allocate(1,1,icblock(b)%dim(1),icblock(b)%dim(2),icblock(b)%dim(3))
        if (size(IOfield%block(b)%vars)>0) then
          icblock(b)%temperature(1:icblock(b)%dim(1),1:icblock(b)%dim(2),1:icblock(b)%dim(3)) = IOfield%block(b)%vars(1,:,:,:)
          icblock(b)%mID(1:icblock(b)%dim(1),1:icblock(b)%dim(2),1:icblock(b)%dim(3)) = IOfield%block(b)%vars(2,:,:,:)
          icblock(b)%qvol(1:icblock(b)%dim(1),1:icblock(b)%dim(2),1:icblock(b)%dim(3)) = IOfield%block(b)%vars(3,:,:,:)
        endif
      end do
    endif

  end subroutine read_vtk_tec


  subroutine write_vtk_tec(phase,ICformat,block)
    use IR_Precision
    use Lib_VTK
    use Lib_Tecplot
    use variables, only: nrans, neuler, llen, outpath
    use ATLAS_high_level
    use phase_module, only: phase_type
    use material_module, only: obj_material
    use ATLAS_Mod_Grid, only: meshtype
    implicit none
    type(phase_type), intent(in)       :: phase(:)
    character(len=*), intent(in)       :: ICformat
    type(ATLAS_block), intent(in)      :: block(:)
    type(orion_data)                   :: orion
    type(obj_material)                 :: mat
    character(len=llen)                :: localpath_vtk, localpath
    integer(I4P)                       :: E_IO, b, s, nb, cnt, nsc, p, ap
    integer(I4P)                       :: i, j, k, m, g, nnn
    character(len=10*llen)             :: varnames, filename
    character(len=llen)                :: name_
    logical                            :: thereis

    localpath = outpath
    orion%solutiontime = -10.0

    do p = 1, size(phase)
      write(*,*)' - Phase : ',trim(phase(p)%name)

      varnames=' '

      nb = 0
      do b = 1, size(block)
        do ap = 1, size(block(b)%associated_phase(:))
          if (index(phase(p)%name,block(b)%associated_phase(ap)%name)>0) then
            nb = nb + 1
            if (phase(p)%type=='IG') nsc = block(b)%associated_phase(ap)%species%n
            if (phase(p)%type=='CD') mat = block(b)%associated_phase(ap)%material
          endif
        enddo
      enddo
      if (allocated(orion%block)) deallocate(orion%block)
      allocate(orion%block(1:nb))

      select case(phase(p)%type)
        case('IG')
          do s = 1, nsc
            varnames = trim(varnames)//' "rho'//trim(str(.true.,s))//'"'
          enddo
          if (meshtype == 10) then
            varnames = trim(varnames)//' "u" "p"'
          elseif (meshtype == -2) then
            varnames = trim(varnames)//' "u" "v" "p"'
          else
            varnames = trim(varnames)//' "u" "v" "w" "p"'
          endif
          if (nrans==1) then
            varnames = trim(varnames)//' "mi_t"'
          elseif (nrans==2) then
            varnames = trim(varnames)//' "kappa" "omega"'
          elseif (nrans==7) then
            varnames = trim(varnames)//' "ru''u''" "rv''v''" "rw''w''" "ru''v''" "ru''w''" "rv''w''" "omega"'
          endif
        case('CD')
          nnn = 0
          do m = 1, mat%n
            do g = 1, mat%npCP(m)
              nnn = nnn + 1
              varnames = trim(varnames)//' "rp_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              varnames = trim(varnames)//' "up_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              varnames = trim(varnames)//' "vp_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              varnames = trim(varnames)//' "wp_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              if (neuler==1) then
                varnames = trim(varnames)//' "Pp_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              endif
              if (neuler==6) then
                varnames = trim(varnames)//' "Pp11_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
                varnames = trim(varnames)//' "Pp12_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
                varnames = trim(varnames)//' "Pp13_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
                varnames = trim(varnames)//' "Pp22_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
                varnames = trim(varnames)//' "Pp23_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
                varnames = trim(varnames)//' "Pp33_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              endif
              varnames = trim(varnames)//' "Tp_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              varnames = trim(varnames)//' "np_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
            enddo
          enddo
        case('SP')
          varnames = trim(varnames)//"T matID qvol"
      end select

      cnt = 0
      do b = 1, size(block)
        thereis = .false.
        do ap = 1, size(block(b)%associated_phase)
          if (index(phase(p)%name,block(b)%associated_phase(ap)%name)>0) thereis = .true.
        enddo
        if (.not.thereis) cycle
        cnt = cnt + 1
        orion%block(cnt)%Ni = block(b)%dim(1)
        orion%block(cnt)%Nj = block(b)%dim(2)
        orion%block(cnt)%Nk = block(b)%dim(3)
        if (meshtype==-2) then
          allocate(orion%block(cnt)%mesh(1:2,0:block(b)%dim(1),0:block(b)%dim(2),0:0))
          do j = 0, block(b)%dim(2); do i = 0, block(b)%dim(1)
            orion%block(cnt)%mesh(1:2,i,j,0) = block(b)%node(i,j,0)%c(1:2)
          enddo; enddo
        else
          allocate(orion%block(cnt)%mesh(1:3,0:block(b)%dim(1),0:block(b)%dim(2),0:block(b)%dim(3)))
          do k = 0, block(b)%dim(3); do j = 0, block(b)%dim(2); do i = 0, block(b)%dim(1)
            orion%block(cnt)%mesh(:,i,j,k) = block(b)%node(i,j,k)%c(1:3)
          enddo; enddo; enddo
        endif
        select case(phase(p)%type)
        case('IG')
          orion%block(cnt)%name = 'B'//trim(str(.true.,b))//'-IG'
          if (meshtype == 10) then
            allocate(orion%block(cnt)%vars(1:nsc+2,1:block(b)%dim(1),1:block(b)%dim(2),1:block(b)%dim(3)))
            orion%block(cnt)%vars(1:nsc,:,:,:) = block(b)%density
            orion%block(cnt)%vars(nsc+1,:,:,:) = block(b)%velocity(1,:,:,:)
            orion%block(cnt)%vars(nsc+2,:,:,:) = block(b)%pressure
          elseif (meshtype == -2) then
            allocate(orion%block(cnt)%vars(1:nsc+3+nrans,1:block(b)%dim(1),1:block(b)%dim(2),1:block(b)%dim(3)))
            orion%block(cnt)%vars(1:nsc,:,:,:) = block(b)%density
            orion%block(cnt)%vars(nsc+1:nsc+2,:,:,:) = block(b)%velocity(1:2,:,:,:)
            orion%block(cnt)%vars(nsc+3,:,:,:) = block(b)%pressure
            if (nrans>0) then
              orion%block(cnt)%vars(nsc+4:nsc+3+nrans,:,:,:) = block(b)%turbprop
            endif
          else
            allocate(orion%block(cnt)%vars(1:nsc+4+nrans,1:block(b)%dim(1),1:block(b)%dim(2),1:block(b)%dim(3)))
            orion%block(cnt)%vars(1:nsc,:,:,:) = block(b)%density
            orion%block(cnt)%vars(nsc+1:nsc+3,:,:,:) = block(b)%velocity
            orion%block(cnt)%vars(nsc+4,:,:,:) = block(b)%pressure
            if (nrans>0) then
              orion%block(cnt)%vars(nsc+5:nsc+4+nrans,:,:,:) = block(b)%turbprop
            endif
          endif
        case('CD')
          orion%block(cnt)%name = 'B'//trim(str(.true.,b))//'-CD'
          allocate(orion%block(cnt)%vars(1:nnn*(6+neuler),1:block(b)%dim(1),1:block(b)%dim(2),1:block(b)%dim(3)))
          s = 1
          do m = 1, nnn
            orion%block(cnt)%vars(s,:,:,:) = block(b)%densityp(m,:,:,:)
            orion%block(cnt)%vars(s+1,:,:,:) = block(b)%velocityp(m,1,:,:,:)
            orion%block(cnt)%vars(s+2,:,:,:) = block(b)%velocityp(m,2,:,:,:)
            orion%block(cnt)%vars(s+3,:,:,:) = block(b)%velocityp(m,3,:,:,:)
            if (neuler==1) then
              orion%block(cnt)%vars(s+4,:,:,:) = block(b)%PP(m,:,:,:)
            endif
            if (neuler==6) then
              orion%block(cnt)%vars(s+4,:,:,:) = block(b)%PP(m,:,:,:)
              orion%block(cnt)%vars(s+5,:,:,:) = 0d0
              orion%block(cnt)%vars(s+6,:,:,:) = 0d0
              orion%block(cnt)%vars(s+7,:,:,:) = block(b)%PP(m,:,:,:)
              orion%block(cnt)%vars(s+8,:,:,:) = 0d0
              orion%block(cnt)%vars(s+9,:,:,:) = block(b)%PP(m,:,:,:)
            endif
            orion%block(cnt)%vars(s+4+neuler,:,:,:) = block(b)%temperatureP(m,:,:,:)
            orion%block(cnt)%vars(s+5+neuler,:,:,:) = block(b)%np(m,:,:,:)
            s = s + 6 + neuler
          enddo
        case('SP')
          orion%block(cnt)%name = 'B'//trim(str(.true.,b))//'-SP'
          allocate(orion%block(cnt)%vars(3,1:block(b)%dim(1),1:block(b)%dim(2),1:block(b)%dim(3)))
          orion%block(cnt)%vars(1,:,:,:) = block(b)%temperature
          orion%block(cnt)%vars(2,:,:,:) = block(b)%mID
          orion%block(cnt)%vars(3,:,:,:) = block(b)%qvol
        end select
      enddo

      if (phase(p)%name=='') then
        name_ = ''
      else
        name_ = trim(phase(p)%name)//'-'
      endif

      if (index(ICformat,'vtk')>0) then
        localpath_vtk = trim(localpath)//'/vtk/'
        call execute_command_line('mkdir -p '//trim(localpath_vtk))
        write(*,*)' - Writing vtk-fomat file'
        orion%vtk%format = 'ascii'
        orion%vtk%node = .false.
        E_IO = vtk_write_structured_multiblock(orion=orion,vtspath=trim(localpath_vtk), &
                                               vtmpath=trim(localpath)//'/'//trim(name_)//'ic',varnames=varnames)
      else
        write(*,*)' - Writing tec-fomat file'
        if (index(ICformat,'binary')>0) then
          orion%tec%format = 'binary'
          filename = trim(localpath)//'/'//trim(name_)//'ic.szplt'
        else
          orion%tec%format = 'ascii'
          filename = trim(localpath)//'/'//trim(name_)//'ic.tec'
        endif
        orion%tec%node = .false.
        E_IO = tec_write_structured_multiblock(orion=orion,varnames=varnames, filename=trim(filename))
      endif
    
    write(*,*)
    enddo

  end subroutine write_vtk_tec

end module ATLAS_IO_fields
