module ATLAS_IO
  use Lib_ORION_data
  implicit none
  private
  public:: write_idealgas_bc_file
  public:: write_cdp_bc_file
  public:: write_vtk_tec
  public:: read_solfile, write_solfile
  public:: read_TECmesh
  public:: read_idealgas_properties
  public:: read_phase

  integer:: i,j,k,s,ap,p
  integer:: unitfile

  contains
  
  subroutine write_idealgas_bc_file(name,block)
    use variables
    use ATLAS_high_level, only: ATLAS_block
    use chimera
    implicit none
    character(len=*), intent(in)  :: name
    type(ATLAS_block), intent(in) :: block(:)
    character(len=len(name))      :: name_
    integer                       :: p, b, f, m, n, mend(6), nend(6)
    integer                       :: Ai, Aj, Ak, ii, jj, kk
    logical                       :: match

    if (trim(name)=='') then
      name_ = name
    else
      name_ = trim(name)//'-'
    endif

    match = .false.
    do b = 1, size(block)
      do p = 1, size(block(b)%associated_phase(:))
        if (index(trim(name),trim(block(b)%associated_phase(p)%name))>0) match = .true.
      enddo
    enddo

    if (match) then
      open(newunit=unitfile,FILE=outpath//trim(name_)//'bc.txt',action='write')
    else
      return
    endif

    do b = 1, size(block)
      match = .false.
      do p = 1, size(block(b)%associated_phase(:))
        if (index(trim(name),trim(block(b)%associated_phase(p)%name))>0) match = .true.
      enddo
      if (.not.match) cycle
      mend(1:2) = block(b)%dim(2); nend(1:2) = block(b)%dim(3)
      mend(3:4) = block(b)%dim(1); nend(3:4) = block(b)%dim(3)
      mend(5:6) = block(b)%dim(1); nend(5:6) = block(b)%dim(2)
      do f = 1, 6
        do n = 1, nend(f)
          do m = 1, mend(f)
            
            call fmn2ijk(f,m,n,block(b)%dim(1),block(b)%dim(2),block(b)%dim(3),Ai,Aj,Ak)
            write(unitfile,'(6I8)')b,Ai,Aj,Ak,f,block(b)%face(f)%center(m,n)%bc%definition

            select case (block(b)%face(f)%center(m,n)%bc%definition)

              case(1)
                do i = 1, block(b)%face(f)%center(m,n)%bc%nproperties-1-nrans
                  write(unitfile,'(I8)',advance='no') nint(block(b)%face(f)%center(m,n)%bc%properties(i))
                enddo
                do i = 1, size(block(b)%face(f)%center(m,n)%bc%connection)
                  write(unitfile,'(I8)',advance='no') block(b)%face(f)%center(m,n)%bc%connection(i)
                enddo
                write(unitfile,'(A)') ''

              case(2,3,11)

              case(4)
                do i = 1, block(b)%face(f)%center(m,n)%bc%nproperties
                  write(unitfile,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(i),','
                enddo
                do i = 1, block(b)%face(f)%center(m,n)%bc%species%n
                  write(unitfile,'(E14.5,A)',advance='no') block(b)%face(f)%center(m,n)%bc%species%massf(i),','
                enddo
                write(unitfile,'(A)') ''
              
              case(5,6,9,10)
                write(unitfile,'(E14.5,A1)') block(b)%face(f)%center(m,n)%bc%properties(1)
              
              case(8)
                write(unitfile,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(1)
                write(unitfile,'(E14.5,A1)') block(b)%face(f)%center(m,n)%bc%properties(2)
              
              case(12)
                do i = 1, 5
                  write(unitfile,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(i),','
                enddo
                write(unitfile,'(A)') ''
              
              case(666)
                
                ! Ghost i-1
                select case(f)
                  case(1)
                    ii = Ai-1
                    jj = Aj
                    kk = Ak
                  case(2)
                    ii = Ai+1
                    jj = Aj
                    kk = Ak
                  case(3)
                    jj = Aj-1
                    ii = Ai
                    kk = Ak
                  case(4)
                    jj = Aj+1
                    ii = Ai
                    kk = Ak
                  case(5)
                    kk = Ak-1
                    ii = Ai
                    jj = Aj
                  case(6)
                    kk = Ak+1
                    ii = Ai
                    jj = Aj
                end select     

                write(unitfile,'(I8)',advance='no') size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)
              
                ! Ghost i-2
                select case(f)
                  case(1)
                    ii = Ai-2
                    jj = Aj
                    kk = Ak
                  case(2)
                    ii = Ai+2
                    jj = Aj
                    kk = Ak
                  case(3)
                    jj = Aj-2
                    ii = Ai
                    kk = Ak
                  case(4)
                    jj = Aj+2
                    ii = Ai
                    kk = Ak
                  case(5)
                    kk = Ak-2
                    ii = Ai
                    jj = Aj
                  case(6)
                    kk = Ak+2
                    ii = Ai
                    jj = Aj
                end select  

                write(unitfile,'(I8)') size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)

                ! Ghost i-1
                select case(f)
                  case(1)
                    ii = Ai-1
                    jj = Aj
                    kk = Ak
                  case(2)
                    ii = Ai+1
                    jj = Aj
                    kk = Ak
                  case(3)
                    jj = Aj-1
                    ii = Ai
                    kk = Ak
                  case(4)
                    jj = Aj+1
                    ii = Ai
                    kk = Ak
                  case(5)
                    kk = Ak-1
                    ii = Ai
                    jj = Aj
                  case(6)
                    kk = Ak+1
                    ii = Ai
                    jj = Aj
                end select     

                do i = 1, size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)
                  write(unitfile,'(4I8)',advance='no') (nint(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,j)),j=1,4)
                  write(unitfile,'(E20.10)') block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,5)
                enddo     
                
                ! Ghost i-2
                select case(f)
                  case(1)
                    ii = Ai-2
                    jj = Aj
                    kk = Ak
                  case(2)
                    ii = Ai+2
                    jj = Aj
                    kk = Ak
                  case(3)
                    jj = Aj-2
                    ii = Ai
                    kk = Ak
                  case(4)
                    jj = Aj+2
                    ii = Ai
                    kk = Ak
                  case(5)
                    kk = Ak-2
                    ii = Ai
                    jj = Aj
                  case(6)
                    kk = Ak+2
                    ii = Ai
                    jj = Aj
                end select  

                do i = 1, size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)
                  write(unitfile,'(4I8)',advance='no') (nint(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,j)),j=1,4)
                  write(unitfile,'(E20.10)') block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,5)
                enddo     
              
            end select
          enddo
        enddo
      enddo
    enddo

    close(unitfile)

  end subroutine write_idealgas_bc_file


  subroutine write_cdp_bc_file(name,block)
    use variables
    use ATLAS_high_level, only: ATLAS_block
    use chimera
    implicit none
    character(len=*), intent(in)  :: name
    type(ATLAS_block), intent(in) :: block(:)
    character(len=len(name))      :: name_
    integer                       :: b, p, f, m, n, mend(6), nend(6)
    integer                       :: Ai, Aj, Ak, ii, jj, kk, u
    logical                       :: match

    if (trim(name)=='') then
      name_ = name
    else
      name_ = trim(name)//'-'
    endif

    match = .false.
    do b = 1, size(block)
      do p = 1, size(block(b)%associated_phase(:))
        if (index(trim(name),trim(block(b)%associated_phase(p)%name))>0) match = .true.
      enddo
    enddo

    if (match) then
      open(newunit=u,FILE=outpath//trim(name_)//'bc.txt',action='write')
    else
      return
    endif

    do b = 1, size(block)
      match = .false.
      do p = 1, size(block(b)%associated_phase(:))
        if (index(trim(name),trim(block(b)%associated_phase(p)%name))>0) match = .true.
      enddo
      if (.not.match) cycle
      mend(1:2) = block(b)%dim(2); nend(1:2) = block(b)%dim(3)
      mend(3:4) = block(b)%dim(1); nend(3:4) = block(b)%dim(3)
      mend(5:6) = block(b)%dim(1); nend(5:6) = block(b)%dim(2)
      do p = 1, npCP
      do f = 1, 6
        do n = 1, nend(f)
          do m = 1, mend(f)
            
            call fmn2ijk(f,m,n,block(b)%dim(1),block(b)%dim(2),block(b)%dim(3),Ai,Aj,Ak)
            
            write(u,'(7I8)')b,Ai,Aj,Ak,f,p,block(b)%face(f)%center(m,n)%bc%definition

            select case (block(b)%face(f)%center(m,n)%bc%definition)

              case(1)
                do i = 1, block(b)%face(f)%center(m,n)%bc%nproperties
                  write(u,'(I8)',advance='no') nint(block(b)%face(f)%center(m,n)%bc%properties(i))
                enddo
                do i = 1, size(block(b)%face(f)%center(m,n)%bc%connection)
                  write(u,'(I8)',advance='no') block(b)%face(f)%center(m,n)%bc%connection(i)
                enddo
                write(u,'(A)') ''

              case(2,3,5,6,8,9,11)

              case(4)
                do i = 1, block(b)%face(f)%center(m,n)%bc%cp_nproperties
                  write(u,'(E14.5)',advance='no') block(b)%face(f)%center(m,n)%bc%cp_properties(p,i)
                enddo
                write(u,'(A)') ''
              
              case(10)
                write(u,'(E14.5,A1)') block(b)%face(f)%center(m,n)%bc%cp_properties(p,1)
              
              case(666)
                
                ! Ghost i-1
                select case(f)
                  case(1)
                    ii = Ai-1
                    jj = Aj
                    kk = Ak
                  case(2)
                    ii = Ai+1
                    jj = Aj
                    kk = Ak
                  case(3)
                    jj = Aj-1
                    ii = Ai
                    kk = Ak
                  case(4)
                    jj = Aj+1
                    ii = Ai
                    kk = Ak
                  case(5)
                    kk = Ak-1
                    ii = Ai
                    jj = Aj
                  case(6)
                    kk = Ak+1
                    ii = Ai
                    jj = Aj
                end select     

                write(unitfile,'(I8)',advance='no') size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)
              
                ! Ghost i-2
                select case(f)
                  case(1)
                    ii = Ai-2
                    jj = Aj
                    kk = Ak
                  case(2)
                    ii = Ai+2
                    jj = Aj
                    kk = Ak
                  case(3)
                    jj = Aj-2
                    ii = Ai
                    kk = Ak
                  case(4)
                    jj = Aj+2
                    ii = Ai
                    kk = Ak
                  case(5)
                    kk = Ak-2
                    ii = Ai
                    jj = Aj
                  case(6)
                    kk = Ak+2
                    ii = Ai
                    jj = Aj
                end select  

                write(unitfile,'(I8)') size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)



                ! Ghost i-1
                select case(f)
                  case(1)
                    ii = Ai-1
                    jj = Aj
                    kk = Ak
                  case(2)
                    ii = Ai+1
                    jj = Aj
                    kk = Ak
                  case(3)
                    jj = Aj-1
                    ii = Ai
                    kk = Ak
                  case(4)
                    jj = Aj+1
                    ii = Ai
                    kk = Ak
                  case(5)
                    kk = Ak-1
                    ii = Ai
                    jj = Aj
                  case(6)
                    kk = Ak+1
                    ii = Ai
                    jj = Aj
                end select     

                do i = 1, size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)
                  write(unitfile,'(4I8)',advance='no') (nint(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,j)),j=1,4)
                  write(unitfile,'(E20.10)') block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,5)
                enddo     
                
                ! Ghost i-2
                select case(f)
                  case(1)
                    ii = Ai-2
                    jj = Aj
                    kk = Ak
                  case(2)
                    ii = Ai+2
                    jj = Aj
                    kk = Ak
                  case(3)
                    jj = Aj-2
                    ii = Ai
                    kk = Ak
                  case(4)
                    jj = Aj+2
                    ii = Ai
                    kk = Ak
                  case(5)
                    kk = Ak-2
                    ii = Ai
                    jj = Aj
                  case(6)
                    kk = Ak+2
                    ii = Ai
                    jj = Aj
                end select  

                do i = 1, size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)
                  write(unitfile,'(4I8)',advance='no') (nint(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,j)),j=1,4)
                  write(unitfile,'(E20.10)') block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,5)
                enddo     
              
            end select
          enddo
          enddo
        enddo
      enddo
    enddo

  end subroutine write_cdp_bc_file


  !> write media.init
  subroutine write_solfile(block)
    use variables, only: nrans, outpath
    use ATLAS_high_level, only: ATLAS_block
    implicit none
    type(ATLAS_block), intent(in) :: block(:)
    integer :: b, nb, s

    nb = size(block)
    
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
      write(unitfile)((((dble(block(b)%density(s,i,j,k)),s=1,block(b)%species%n), &
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


  subroutine read_TECmesh(orion,path)
    use Lib_Tecplot
    implicit none
    type(orion_data), intent(inout) :: orion
    character(len=*), intent(in)    :: path
    integer                         :: error

    orion%tec%node = .false.
    orion%tec%bc = .false.
    orion%tec%format = 'ascii'
    error = tec_read_structured_multiblock(orion=orion,filename=path)

  end subroutine read_TECmesh


  subroutine read_solfile(filename,icblock,n)
    use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
    use variables, only: nrans, llen
    use ATLAS_high_level, only: ATLAS_block
    implicit none
    integer, intent(in)              :: n
    character(len=llen), intent(in)  :: filename
    type(ATLAS_block), intent(inout) :: icblock(:)
    integer                          :: b, nb, Nmax(3), cnt, io
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
    
    close(unitfile)

  end subroutine read_solfile


  !> \brief Write the initial conditions to VTK or Tecplot format.
  !! \param[in] phase Array of phase types.
  !! \param[in] ICformat String specifying the format ('vtk' or 'tec').
  !! \param[in] block Array of ATLAS_block containing the simulation data.
  subroutine write_vtk_tec(phase,ICformat,block)
    use IR_Precision
    use Lib_VTK
    use Lib_Tecplot
    use variables, only: nrans, llen, outpath
    use ATLAS_high_level
    implicit none
    type(phase_type), intent(in)       :: phase(:)
    character(len=*), intent(in)       :: ICformat
    type(ATLAS_block), intent(in)      :: block(:)
    type(orion_data)                   :: orion
    character(len=llen)                :: localpath_vtk, localpath
    integer(I4P)                       :: E_IO, b, s, nb, cnt
    character(len=llen)                :: varnames
    character(len=llen)                :: name_

    localpath = outpath
    varnames=' '

    do p = 1, size(phase)
      select case(phase(p)%type)
        case('IG')
          do s = 1, block(1)%species%n
            varnames = trim(varnames)//' r'//trim(str(.true.,s))
          enddo
          varnames = trim(varnames)//' u v w p'
          if (nrans==1) then
            varnames = trim(varnames)//' mi_t'
          elseif (nrans==2) then
            varnames = trim(varnames)//' kappa omega'
          elseif (nrans==7) then
            varnames = trim(varnames)//" ru'u' rv'v' rw'w' ru'v' ru'w' rv'w' omega"
          endif
        case('SP')
          varnames = 'T'
      end select

      nb = 0
      do b = 1, size(block)
        do ap = 1, size(block(b)%associated_phase(:))
          if (index(phase(p)%name,block(b)%associated_phase(ap)%name)>0) nb = nb + 1
        enddo
      enddo
      if (allocated(orion%block)) deallocate(orion%block)
      allocate(orion%block(1:nb))

      cnt = 0
      do b = 1, size(block)
        if (index(phase(p)%name,block(b)%associated_phase(1)%name)==0) cycle
        cnt = cnt + 1
        orion%block(cnt)%Ni = block(b)%dim(1)
        orion%block(cnt)%Nj = block(b)%dim(2)
        orion%block(cnt)%Nk = block(b)%dim(3)
        allocate(orion%block(cnt)%mesh(1:3,0:block(b)%dim(1),0:block(b)%dim(2),0:block(b)%dim(3)))
        do k = 0, block(b)%dim(3); do j = 0, block(b)%dim(2); do i = 0, block(b)%dim(1)
          orion%block(cnt)%mesh(:,i,j,k) = block(b)%node(i,j,k)%c(1:3)
        enddo; enddo; enddo
        select case(phase(p)%type)
        case('IG')
          orion%block(cnt)%name = 'B'//trim(str(.true.,b))//'-IG'
          allocate(orion%block(cnt)%vars(1:block(b)%species%n+4+nrans,1:block(b)%dim(1),1:block(b)%dim(2),1:block(b)%dim(3)))
          orion%block(cnt)%vars(1:block(b)%species%n,:,:,:) = block(b)%density
          orion%block(cnt)%vars(block(b)%species%n+1:block(b)%species%n+3,:,:,:) = block(b)%velocity
          orion%block(cnt)%vars(block(b)%species%n+4,:,:,:) = block(b)%pressure
          if (nrans>0) then
            orion%block(cnt)%vars(block(b)%species%n+5:block(b)%species%n+4+nrans,:,:,:) = block(b)%turbprop
          endif
        case('SP')
          orion%block(cnt)%name = 'B'//trim(str(.true.,b))//'-SP'
          allocate(orion%block(cnt)%vars(1,1:block(b)%dim(1),1:block(b)%dim(2),1:block(b)%dim(3)))
          orion%block(cnt)%vars(1,:,:,:) = block(b)%temperature
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
        write(*,*)
        write(*,*)' Writing vtk-fomat file'
        orion%vtk%format = 'ascii'
        orion%vtk%node = .false.
        E_IO = vtk_write_structured_multiblock(orion=orion,vtspath=trim(localpath_vtk), &
                                               vtmpath=trim(localpath)//'/'//trim(name_)//'ic',varnames=varnames)
      else
        write(*,*)
        write(*,*)' Writing tec-fomat file'
        orion%tec%format = 'ascii'
        orion%tec%node = .false.
        E_IO = tec_write_structured_multiblock(orion=orion,varnames=varnames, &
                                               filename=trim(localpath)//'/'//trim(name_)//'ic.tec')
      endif

    enddo

  end subroutine write_vtk_tec


  subroutine read_idealgas_properties(prefix, sp)
    use species
    use strings, only: parse
    use Lib_Tecplot
    implicit none
    character(len=*), intent(in):: prefix
    type(obj_species), intent(inout) :: sp
    integer :: n, ios, Ti1, Ti2
    character(len=30) :: wholestring, args(2)
    type(orion_data) :: orion

    open(newunit=unitFile,file=trim(prefix)//'phase.txt',status='old',iostat=ios)
    if (ios/=0) return!error stop ("Error reading phase file")
    ios = 0; n = -1
    read(unitfile,*)!skip first line
    do while(ios==0)
      read(unitFile,'(A)',iostat=ios)
      n = n + 1
    enddo
    sp%n = n
    allocate(sp%name(1:n))
    allocate(sp%w(1:n))
    rewind(unitFile)
    read(unitfile,*)!skip first line
    do i = 1, n
      read(unitFile,'(A)') wholestring
      call parse(wholestring,' ',args)
      sp%name(i) = trim(adjustl(args(1)))
      read(args(2),*) sp%w(i)
    end do
    close(unitFile)

    ios = tec_read_points_multivars(orion,4,trim(prefix)//'thermo.dat')
    if (ios/=0) return!error stop ("Error reading ideal-gas thermo file")
    Ti1 = nint(orion%block(1)%mesh(1,1,1,1))
    Ti2 = Ti1 + orion%block(1)%Ni - 1
    allocate(sp%cp(1:sp%n,Ti1:Ti2))
    allocate(sp%dcp(1:sp%n,Ti1:Ti2))
    allocate(sp%h(1:sp%n,Ti1:Ti2))
    allocate(sp%s(1:sp%n,Ti1:Ti2))
    do i = 1, sp%n
      sp%cp(i,Ti1:Ti2) = orion%block(i)%vars(1,1:orion%block(1)%Ni,1,1)
      sp%h(i,Ti1:Ti2) = orion%block(i)%vars(2,:,1,1)
      sp%s(i,Ti1:Ti2) = orion%block(i)%vars(3,:,1,1)
      sp%dcp(i,Ti1:Ti2) = orion%block(i)%vars(4,:,1,1)
    enddo

  end subroutine read_idealgas_properties


  subroutine read_phase(phase)
    use strings, only: parse
    use ATLAS_high_level, only: phase_type
    use variables, only: npCP
    implicit none
    type(phase_type), allocatable, intent(out) :: phase(:)
    character(len=128) :: filename, stringa(2)
    integer :: i, num_files, u, ios
    character(len=128), allocatable :: file_list(:)
    character(len=128) :: type, dummy

    ! Get the list of .txt files in the current directory
    call get_file_list(file_list, num_files)

    ! Check if the file is a species file (ideal-gas) or a material file (condensed-dispersed or a solid phase)
    if (num_files>=1) then
      allocate(phase(num_files))
      phase%type = 'JD'
      do i = 1, size(phase)
        filename = trim(adjustl(file_list(i)))
        ! Check if the phase has a name. If not, an empty string is returned
        call parse(filename,'-',stringa)
        if (stringa(2)=='') then
          stringa(2) = stringa(1)
          stringa(1) = ''
        endif
        if (index(stringa(2),'phase')>0) then
          open(newunit=u, file=filename, status="old")
          read(u,'(A)',iostat=ios) type
          if (index(type,'condensed-dispersed')>0) then
            phase(i)%type = 'CD'
            read(u,*,iostat=ios) dummy, npCP
            close(u)
          elseif (index(type,'solid')>0) then
            phase(i)%type = 'SP'
          elseif (index(type,'ideal-gas')>0) then
            phase(i)%type = 'IG'
          else
            write(*,*) 'Error: unknown phase type'
            stop
          endif
        endif
        phase(i)%name = stringa(1)
      end do
      deallocate(file_list)
    else
      ! If no species or material file is present, the ideal-gas phase is assumed
      allocate(phase(1))
      phase%type = 'IG'
      phase%name = ''
    endif

  end subroutine read_phase


  subroutine get_file_list(file_list, num_files)
      implicit none
      character(len=*), allocatable, intent(out) :: file_list(:)
      integer, intent(out) :: num_files
      character(len=256) :: line
      integer :: ios, unit, u

      open(newunit=u, file="filelist.txt", status="old", action="read", iostat=ios)

      num_files = 0
      do
        read(u, '(A)', iostat=ios) line
        if (ios /= 0) exit
        num_files = num_files + 1
      end do

      rewind(u)
      allocate(file_list(num_files))

      do unit = 1, num_files
        read(u, '(A)', iostat=ios) file_list(unit)
      end do

      close(u)
  end subroutine get_file_list

end module ATLAS_IO
