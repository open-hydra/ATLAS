module io_fields_mod
  use Lib_ORION_data
  use IR_Precision

  implicit none

  character(len=18), parameter :: outpath = 'fromATLAStoSolver/'

contains


  subroutine read_tec_file ( file, varblocks )
    use grid_mod
    use ic_block_mod
    use Lib_ORION_data
    use Lib_Tecplot

    implicit none
    character(len=*), intent(in)    :: file
    type(var_block),  intent(inout) :: varblocks(:)
    ! Local
    type(Orion_Data) :: IOfield
    integer          :: error
    integer          :: i, j, k, b

    IOfield%tec%format = 'ascii'
    error = tec_read_structured_multiblock( orion=IOfield, filename=trim(file) )

    call import_nodes(input=IOfield,output=varblocks)
    do b = 1, size(varblocks)
      call varblocks(b)%compute_volume(gc=[0, 0, 0])
      call varblocks(b)%compute_centers(gc=[0, 0, 0])
      call varblocks(b)%compute_bounding(gc=[0, 0, 0])

      ! Fill variables field
      allocate(varblocks(b)%var(1:IOfield%block(b)%Ni,1:IOfield%block(b)%Nj,1:IOfield%block(b)%Nk))
      do i = 1, varblocks(b)%dim(1); do j = 1, varblocks(b)%dim(2); do k = 1, varblocks(b)%dim(3)
        varblocks(b)%var(i,j,k) = IOfield%block(b)%vars(1,i,j,k)
      enddo; enddo; enddo
    enddo
    
  end subroutine read_tec_file


  subroutine read_vtk_tec (phase_type,filename,blk,n)
    use Lib_VTK
    use Lib_Tecplot
    use Lib_ORION_data
    use global_mod, only: llen
    use ic_block_mod
    implicit none
    character(len=2), intent(in)     :: phase_type
    integer, intent(in), optional    :: n
    character(len=llen), intent(in)  :: filename
    type(IC_block), allocatable, intent(inout) :: blk(:)
    ! Local
    type(Orion_Data) :: IOfield
    integer:: error, b, s, m
    integer :: n_species, nnn, nvel

    if (index(filename,'.tec')>0) then
      IOfield%tec%format = 'ascii'
      error = tec_read_structured_multiblock(orion=IOfield,filename=trim(filename))
    elseif (index(filename,'.szplt')>0) then
      IOfield%tec%format = 'binary'
      error = tec_read_structured_multiblock(orion=IOfield,filename=trim(filename))
    endif

    if (error/=0) then
      write(*,*) "[ERROR] reading "//trim(filename)
      stop
    endif

    allocate(blk(size(IOfield%block)))
    call import_nodes(input=IOfield,output=blk)

    if (phase_type=='IG') then
      ! Derive species count from file if n is not supplied
      if (present(n)) then
        n_species = n
      else
        n_species = size(IOfield%block(1)%vars, 1) - 4 - blk(1)%nrans
      endif
      do b = 1, size(blk)
        call blk(b)%compute_centers([0,0,0])
        call blk(b)%allocate(blk(b)%nrans,n_species,blk(b)%dim(1),blk(b)%dim(2),blk(b)%dim(3))
        if (size(IOfield%block(b)%vars)>0) then
          do s = 1, n_species
            blk(b)%ig%density(s,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(s,:,:,:)
          enddo
          blk(b)%ig%velocity(1:3,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(n_species+1:n_species+3,:,:,:)
          blk(b)%ig%pressure(1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(n_species+4,:,:,:)
          do s = 1, blk(b)%nrans
            blk(b)%ig%turbprop(s,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(n_species+4+s,:,:,:)
          enddo
        endif
      end do
    
    elseif (phase_type=='SP') then
      do b = 1, size(blk)
        call blk(b)%compute_centers([0,0,0])
        call blk(b)%allocate(1,1,blk(b)%dim(1),blk(b)%dim(2),blk(b)%dim(3))
        if (size(IOfield%block(b)%vars)>0) then
          blk(b)%ig%temperature(1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(1,:,:,:)
          blk(b)%sp%mID(1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(2,:,:,:)
        endif
      end do

    elseif (phase_type=='CD') then
      ! Derive population count: each population has 6+blk(1)%neuler variables
      nnn = size(IOfield%block(1)%vars, 1) / (6 + blk(1)%neuler)
      do b = 1, size(blk)
        call blk(b)%compute_centers([0,0,0])
        allocate(blk(b)%dp%density      (1:nnn, 1:blk(b)%dim(1), 1:blk(b)%dim(2), 1:blk(b)%dim(3)))
        allocate(blk(b)%dp%velocity     (1:nnn, 1:3, 1:blk(b)%dim(1), 1:blk(b)%dim(2), 1:blk(b)%dim(3)))
        allocate(blk(b)%dp%temperature  (1:nnn, 1:blk(b)%dim(1), 1:blk(b)%dim(2), 1:blk(b)%dim(3)))
        allocate(blk(b)%dp%nP           (1:nnn, 1:blk(b)%dim(1), 1:blk(b)%dim(2), 1:blk(b)%dim(3)))
        allocate(blk(b)%dp%pseudopressure(1:nnn,1:blk(b)%dim(1), 1:blk(b)%dim(2), 1:blk(b)%dim(3)))
        blk(b)%dp%pseudopressure = 0.0_R8P
        if (size(IOfield%block(b)%vars) > 0) then
          do m = 1, nnn
            s = (m-1)*(6+blk(b)%neuler) + 1
            blk(b)%dp%density  (m,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(s,  :,:,:)
            blk(b)%dp%velocity (m,1,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(s+1,:,:,:)
            blk(b)%dp%velocity (m,2,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(s+2,:,:,:)
            blk(b)%dp%velocity (m,3,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(s+3,:,:,:)
            if (blk(b)%neuler >= 1) then
              blk(b)%dp%pseudopressure(m,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(s+4,:,:,:)
            endif
            blk(b)%dp%temperature(m,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(s+4+blk(b)%neuler,:,:,:)
            blk(b)%dp%nP         (m,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(s+5+blk(b)%neuler,:,:,:)
          enddo
        endif
      enddo

    elseif (phase_type=='RF') then
      nvel = size(IOfield%block(1)%vars, 1) - 3 - blk(1)%nrans
      do b = 1, size(blk)
        call blk(b)%compute_centers([0,0,0])
        if (.not.allocated(blk(b)%rf%pressure)) then
          allocate(blk(b)%rf%velocity(1:3,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
          allocate(blk(b)%rf%pressure(1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
          allocate(blk(b)%rf%enthalpy(1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
          if (blk(b)%nrans>0) allocate(blk(b)%rf%turbprop(1:blk(b)%nrans,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
        endif
        if (size(IOfield%block(b)%vars) > 0) then
          blk(b)%rf%pressure   (1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(1,:,:,:)
          blk(b)%rf%velocity = 0.0_R8P
          do s = 1, nvel
            blk(b)%rf%velocity(s,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(s+1,:,:,:)
          enddo
          blk(b)%rf%enthalpy   (1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(nvel+2,:,:,:)
          do s = 1, blk(b)%nrans
            blk(b)%rf%turbprop(s,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(nvel+3+s,:,:,:)
          enddo
        endif
      enddo
    endif

  end subroutine read_vtk_tec


  subroutine write_vtk_tec(phase,ICformat,blk)
    use IR_Precision
    use Lib_VTK
    use Lib_Tecplot
    use global_mod, only: llen
    use ic_block_mod
    use phase_mod, only: phase_t, material_t
    use grid_mod, only: mesh_cfg
    implicit none
    type(phase_t), intent(in)          :: phase(:)
    character(len=*), intent(in)       :: ICformat
    type(IC_block), intent(in)         :: blk(:)
    type(orion_data)                   :: orion
    type(material_t)                   :: mat
    character(len=llen)                :: localpath_vtk, localpath
    integer(I4P)                       :: E_IO, b, s, nb, cnt, nsc, p, ap
    integer(I4P)                       :: i, j, k, m, g, nnn
    character(len=10*llen)             :: varnames, filename
    character(len=llen)                :: name_
    logical                            :: thereis
    integer                            :: nrans_ref, neuler_ref

    localpath = outpath
    orion%solutiontime = -10.0

    call execute_command_line('mkdir -p '//trim(outpath))

    do p = 1, size(phase)
      write(*,*)' - Phase : ',trim(phase(p)%name)

      varnames=' '
      nrans_ref = 0
      neuler_ref = 0

      nb = 0
      do b = 1, size(blk)
        do ap = 1, size(blk(b)%associated_phase(:))
          if (index(phase(p)%name,blk(b)%associated_phase(ap)%name)>0) then
            nb = nb + 1
            if (phase(p)%type=='IG') nsc = blk(b)%associated_phase(ap)%species%n
            if (phase(p)%type=='CD') mat = blk(b)%associated_phase(ap)%material
            nrans_ref  = blk(b)%nrans
            neuler_ref = blk(b)%neuler
          endif
        enddo
      enddo
      if (allocated(orion%block)) deallocate(orion%block)
      allocate(orion%block(1:nb))

      select case(phase(p)%type)
        case('IG')
          do s = 1, nsc
            varnames = trim(varnames)//' rho'//trim(str(.true.,s))
          enddo
          if (mesh_cfg%meshType == 10) then
            varnames = trim(varnames)//' u p'
          elseif (mesh_cfg%meshType == -2) then
            varnames = trim(varnames)//' u v p'
          else
            varnames = trim(varnames)//' u v w p'
          endif
          if (nrans_ref==1) then
            varnames = trim(varnames)//' mi_t'
          elseif (nrans_ref==2) then
            varnames = trim(varnames)//' kappa omega'
          elseif (nrans_ref==7) then
            varnames = trim(varnames)//' ru''u'' rv''v'' rw''w'' ru''v'' ru''w'' rv''w'' omega'
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
              if (neuler_ref==1) then
                varnames = trim(varnames)//' "Pp_'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              endif
              if (neuler_ref==6) then
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
          varnames = trim(varnames)//"T matID"
        case('RF')
          if (mesh_cfg%meshType == -2) then
            varnames = trim(varnames)//' "p" "u" "v" "h"'
          else
            varnames = trim(varnames)//' "p" "u" "v" "w" "h"'
          endif
          if (nrans_ref==1) then
            varnames = trim(varnames)//' "mi_t"'
          elseif (nrans_ref==2) then
            varnames = trim(varnames)//' "kappa" "omega"'
          elseif (nrans_ref==7) then
            varnames = trim(varnames)// &
              ' "ru''u''" "rv''v''" "rw''w''" "ru''v''" "ru''w''" "rv''w''" "omega"'
          endif
      end select

      cnt = 0
      do b = 1, size(blk)
        thereis = .false.
        do ap = 1, size(blk(b)%associated_phase)
          if (index(phase(p)%name,blk(b)%associated_phase(ap)%name)>0) thereis = .true.
        enddo
        if (.not.thereis) cycle
        cnt = cnt + 1
        orion%block(cnt)%Ni = blk(b)%dim(1)
        orion%block(cnt)%Nj = blk(b)%dim(2)
        orion%block(cnt)%Nk = blk(b)%dim(3)
        if (mesh_cfg%meshType==-2) then
          allocate(orion%block(cnt)%mesh(1:2,0:blk(b)%dim(1),0:blk(b)%dim(2),0:0))
          do j = 0, blk(b)%dim(2); do i = 0, blk(b)%dim(1)
            orion%block(cnt)%mesh(1:2,i,j,0) = blk(b)%node(i,j,0)%c(1:2)
          enddo; enddo
        else
          allocate(orion%block(cnt)%mesh(1:3,0:blk(b)%dim(1),0:blk(b)%dim(2),0:blk(b)%dim(3)))
          do k = 0, blk(b)%dim(3); do j = 0, blk(b)%dim(2); do i = 0, blk(b)%dim(1)
            orion%block(cnt)%mesh(:,i,j,k) = blk(b)%node(i,j,k)%c(1:3)
          enddo; enddo; enddo
        endif

        select case(phase(p)%type)

        case('IG')
          orion%block(cnt)%name = 'B'//trim(str(.true.,b))//'-IG'
          if (mesh_cfg%meshType == 10) then
            allocate(orion%block(cnt)%vars(1:nsc+2,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
            orion%block(cnt)%vars(1:nsc,:,:,:) = blk(b)%ig%density
            orion%block(cnt)%vars(nsc+1,:,:,:) = blk(b)%ig%velocity(1,:,:,:)
            orion%block(cnt)%vars(nsc+2,:,:,:) = blk(b)%ig%pressure
          elseif (mesh_cfg%meshType == -2) then
            allocate(orion%block(cnt)%vars(1:nsc+3+blk(b)%nrans,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
            orion%block(cnt)%vars(1:nsc,:,:,:) = blk(b)%ig%density
            orion%block(cnt)%vars(nsc+1:nsc+2,:,:,:) = blk(b)%ig%velocity(1:2,:,:,:)
            orion%block(cnt)%vars(nsc+3,:,:,:) = blk(b)%ig%pressure
            if (blk(b)%nrans>0) then
              orion%block(cnt)%vars(nsc+4:nsc+3+blk(b)%nrans,:,:,:) = blk(b)%ig%turbprop
            endif
          else
            allocate(orion%block(cnt)%vars(1:nsc+4+blk(b)%nrans,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
            orion%block(cnt)%vars(1:nsc,:,:,:) = blk(b)%ig%density
            orion%block(cnt)%vars(nsc+1:nsc+3,:,:,:) = blk(b)%ig%velocity
            orion%block(cnt)%vars(nsc+4,:,:,:) = blk(b)%ig%pressure
            if (blk(b)%nrans>0) then
              orion%block(cnt)%vars(nsc+5:nsc+4+blk(b)%nrans,:,:,:) = blk(b)%ig%turbprop
            endif
          endif

        case('CD')
          orion%block(cnt)%name = 'B'//trim(str(.true.,b))//'-CD'
          allocate(orion%block(cnt)%vars(1:nnn*(6+blk(b)%neuler),1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
          s = 1
          do m = 1, nnn
            orion%block(cnt)%vars(s,:,:,:) = blk(b)%dp%density(m,:,:,:)
            orion%block(cnt)%vars(s+1,:,:,:) = blk(b)%dp%velocity(m,1,:,:,:)
            orion%block(cnt)%vars(s+2,:,:,:) = blk(b)%dp%velocity(m,2,:,:,:)
            orion%block(cnt)%vars(s+3,:,:,:) = blk(b)%dp%velocity(m,3,:,:,:)
            if (blk(b)%neuler==1) then
              orion%block(cnt)%vars(s+4,:,:,:) = blk(b)%dp%pseudopressure(m,:,:,:)
            endif
            if (blk(b)%neuler==6) then
              orion%block(cnt)%vars(s+4,:,:,:) = blk(b)%dp%pseudopressure(m,:,:,:)
              orion%block(cnt)%vars(s+5,:,:,:) = 0d0
              orion%block(cnt)%vars(s+6,:,:,:) = 0d0
              orion%block(cnt)%vars(s+7,:,:,:) = blk(b)%dp%pseudopressure(m,:,:,:)
              orion%block(cnt)%vars(s+8,:,:,:) = 0d0
              orion%block(cnt)%vars(s+9,:,:,:) = blk(b)%dp%pseudopressure(m,:,:,:)
            endif
            orion%block(cnt)%vars(s+4+blk(b)%neuler,:,:,:) = blk(b)%dp%temperature(m,:,:,:)
            orion%block(cnt)%vars(s+5+blk(b)%neuler,:,:,:) = blk(b)%dp%np(m,:,:,:)
            s = s + 6 + blk(b)%neuler
          enddo

        case('SP')
          orion%block(cnt)%name = 'B'//trim(str(.true.,b))//'-SP'
          allocate(orion%block(cnt)%vars(2,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
          orion%block(cnt)%vars(1,:,:,:) = blk(b)%sp%temperature
          orion%block(cnt)%vars(2,:,:,:) = blk(b)%sp%mID

        case('RF')
          orion%block(cnt)%name = 'B'//trim(str(.true.,b))//'-RF'
          if (mesh_cfg%meshType == 10) then
            allocate(orion%block(cnt)%vars(1:3+blk(b)%nrans,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
            orion%block(cnt)%vars(1,:,:,:) = blk(b)%rf%pressure
            orion%block(cnt)%vars(2,:,:,:) = blk(b)%rf%velocity(1,:,:,:)
            orion%block(cnt)%vars(3,:,:,:) = blk(b)%rf%enthalpy
            if (blk(b)%nrans>0) orion%block(cnt)%vars(4:3+blk(b)%nrans,:,:,:) = blk(b)%rf%turbprop
          elseif (mesh_cfg%meshType == -2) then
            allocate(orion%block(cnt)%vars(1:4+blk(b)%nrans,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
            orion%block(cnt)%vars(1,:,:,:)   = blk(b)%rf%pressure
            orion%block(cnt)%vars(2:3,:,:,:) = blk(b)%rf%velocity(1:2,:,:,:)
            orion%block(cnt)%vars(4,:,:,:)   = blk(b)%rf%enthalpy
            if (blk(b)%nrans>0) orion%block(cnt)%vars(5:4+blk(b)%nrans,:,:,:) = blk(b)%rf%turbprop
          else
            allocate(orion%block(cnt)%vars(1:5+blk(b)%nrans,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
            orion%block(cnt)%vars(1,:,:,:)   = blk(b)%rf%pressure
            orion%block(cnt)%vars(2:4,:,:,:) = blk(b)%rf%velocity
            orion%block(cnt)%vars(5,:,:,:)   = blk(b)%rf%enthalpy
            if (blk(b)%nrans>0) orion%block(cnt)%vars(6:5+blk(b)%nrans,:,:,:) = blk(b)%rf%turbprop
          endif

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
        if (index(ICformat,'binary')>0) then
          orion%vtk%format = 'binary'
        elseif (index(ICformat,'ascii')>0) then
          orion%vtk%format = 'ascii'
        else
          orion%vtk%format = 'raw'
        endif
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

end module io_fields_mod
