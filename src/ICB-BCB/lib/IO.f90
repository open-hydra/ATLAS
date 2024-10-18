module IO
  use Lib_ORION_data
  implicit none
  private
  public:: write_mediabound
  public:: write_cp_bc_file
  public:: write_vtk_tec
  public:: read_MISCELA
  public:: read_w
  public:: read_solfile, write_solfile
  !public:: count_blocks
  public:: read_TECmesh
  public:: read_species
  public:: read_array
  public:: write_array

  integer:: i,j,k,s
  integer:: unitfile

  contains
  
  subroutine write_mediabound(block)
    use variables, only: nrans
    use ATLAS_high_level, only: ATLAS_block
    use chimera
    implicit none
    type(ATLAS_block), intent(in) :: block(:)
    integer                       :: b, f, m, n, mend(6), nend(6)
    integer                       :: Ai, Aj, Ak, ii, jj, kk

    do b = 1, size(block)
      mend(1:2) = block(b)%dim(2); nend(1:2) = block(b)%dim(3)
      mend(3:4) = block(b)%dim(1); nend(3:4) = block(b)%dim(3)
      mend(5:6) = block(b)%dim(1); nend(5:6) = block(b)%dim(2)
      do f = 1, 6
        do n = 1, nend(f)
          do m = 1, mend(f)
            
            call fmn2ijk(f,m,n,block(b)%dim(1),block(b)%dim(2),block(b)%dim(3),Ai,Aj,Ak)
            
            write(40,'(6I8)')b,Ai,Aj,Ak,f,block(b)%face(f)%center(m,n)%bc%definition

            select case (block(b)%face(f)%center(m,n)%bc%definition)

              case(1)
                do i = 1, block(b)%face(f)%center(m,n)%bc%nproperties-1-nrans
                  write(40,'(I8)',advance='no') nint(block(b)%face(f)%center(m,n)%bc%properties(i))
                enddo
                do i = 1, size(block(b)%face(f)%center(m,n)%bc%connection)
                  write(40,'(I8)',advance='no') block(b)%face(f)%center(m,n)%bc%connection(i)
                enddo
                write(40,'(A)') ''

              case(2,3,11)

              case(4)
                do i = 1, block(b)%face(f)%center(m,n)%bc%nproperties
                  write(40,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(i),','
                enddo
                do i = 1, block(b)%face(f)%center(m,n)%bc%species%n
                  write(40,'(E14.5,A)',advance='no') block(b)%face(f)%center(m,n)%bc%species%massf(i),','
                enddo
                write(40,'(A)') ''
              
              case(5,6,9,10)
                write(40,'(E14.5,A1)') block(b)%face(f)%center(m,n)%bc%properties(1)
              
              case(8)
                write(40,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(1)
                write(40,'(E14.5,A1)') block(b)%face(f)%center(m,n)%bc%properties(2)
              
              case(12)
                do i = 1, 5
                  write(40,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(i),','
                enddo
              
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

                write(40,'(I8)',advance='no') size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)
              
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

                write(40,'(I8)') size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)

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
                  write(40,'(4I8)',advance='no') (nint(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,j)),j=1,4)
                  write(40,'(E20.10)') block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,5)
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
                  write(40,'(4I8)',advance='no') (nint(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,j)),j=1,4)
                  write(40,'(E20.10)') block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,5)
                enddo     
              
            end select
          enddo
        enddo
      enddo
    enddo

  end subroutine write_mediabound


  subroutine write_cp_bc_file(block,u,npCP)
    use ATLAS_high_level, only: ATLAS_block
    use chimera
    implicit none
    type(ATLAS_block), intent(in) :: block(:)
    integer, intent(in)           :: u, npCP
    integer                       :: b, p, f, m, n, mend(6), nend(6)
    integer                       :: Ai, Aj, Ak, ii, jj, kk

    mend(1:2) = block%dim(2); nend(1:2) = block%dim(3)
    mend(3:4) = block%dim(1); nend(3:4) = block%dim(3)
    mend(5:6) = block%dim(1); nend(5:6) = block%dim(2)

    do b = 1, size(block)
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

                write(40,'(I8)',advance='no') size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)
              
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

                write(40,'(I8)') size(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo,1)



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
                  write(40,'(4I8)',advance='no') (nint(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,j)),j=1,4)
                  write(40,'(E20.10)') block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,5)
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
                  write(40,'(4I8)',advance='no') (nint(block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,j)),j=1,4)
                  write(40,'(E20.10)') block(b)%face(f)%cell(ii,jj,kk)%chimerainfo(i,5)
                enddo     
              
            end select
          enddo
          enddo
        enddo
      enddo
    enddo

  end subroutine write_cp_bc_file


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


  subroutine read_TECmesh(block,path)
    use Lib_Tecplot
    implicit none
    type(orion_data), allocatable, intent(inout) :: block(:)
    character(len=*), intent(in)     :: path
    integer                          :: error

    orion_%tec%node = .false.
    orion_%tec%bc = .false.
    orion_%tec%format = 'ascii'
    error = tec_read_structured_multiblock(orion=block,filename=path)

    !call check_mesh_type(block_(1))

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
        icblock(b)%turbprop(:,1:Nx(b),1:Ny(b),1:Nz(b)) = vart(:,b,1:Nx(b),1:Ny(b),1:Nz(b))
      else
        icblock(b)%turbprop(:,1:Nx(b),1:Ny(b),1:Nz(b)) = 0.0
      endif
    enddo
    
    close(unitfile)

  end subroutine read_solfile


  subroutine write_vtk_tec(block)
    use IR_Precision
    use Lib_VTK
    use Lib_Tecplot
    use variables, only: nrans, llen, outpath
    use ATLAS_high_level, only: ATLAS_block
    implicit none
    type(ATLAS_block), intent(in)      :: block(:)
    character(len=llen)                :: localpath_vtk, localpath
    integer(I4P)                       :: E_IO, b, s
    character(len=llen)                :: varnames

    localpath = outpath
    localpath_vtk = trim(localpath)//'/vtk'
    call execute_command_line('mkdir -p '//trim(localpath_vtk))

    do b = 1, size(orion%block)
      allocate(orion%block(b)%vars(1:block(b)%species%n+4+nrans,1:block(b)%dim(1),1:block(b)%dim(2),1:block(b)%dim(3)))
      orion%block(b)%vars(1:block(b)%species%n,:,:,:) = block(b)%density
      orion%block(b)%vars(block(b)%species%n+1:block(b)%species%n+3,:,:,:) = block(b)%velocity
      orion%block(b)%vars(block(b)%species%n+4,:,:,:) = block(b)%pressure
      if (nrans>0) then
        orion%block(b)%vars(block(b)%species%n+5:block(b)%species%n+4+nrans,:,:,:) = block(b)%turbprop
      endif
    enddo

    varnames=' '
    do s = 1, block(1)%species%n
      varnames = trim(varnames)//'r'//trim(str(.true.,s))
    enddo
    varnames = trim(varnames)//' u v w p'
    if (nrans==1) then
      varnames = trim(varnames)//' mi_t'
    elseif (nrans==2) then
      varnames = trim(varnames)//' kappa omega'
    elseif (nrans==7) then
      varnames = trim(varnames)//" ru'u' rv'v' rw'w' ru'v' ru'w' rv'w' omega"
    endif

    write(*,*)
    write(*,*)' Writing vtk-fomat file'
    orion%vtk%format = 'ascii'
    orion%vtk%node = .false.
    E_IO = vtk_write_structured_multiblock(orion=orion,vtspath=trim(localpath_vtk)//'/field', &
                                                       vtmpath=trim(localpath)//'/field',varnames=varnames)

    write(*,*)
    write(*,*)' Writing tec-fomat file'
    E_IO = tec_write_structured_multiblock(orion=orion,varnames=varnames,filename=trim(localpath)//'/field.tec')

  end subroutine write_vtk_tec


  !> Read wm.dat
  subroutine read_w(n, w)
    implicit none
    integer, intent(in) :: n
    real(8), allocatable, intent(inout) :: w(:)
    integer :: ios

    allocate(w(1:n))
    open(unit=1,file='wm.dat',iostat=ios,status='old',action='read')
    if (ios/=0) open(unit=1,file='toAFFS/wm.dat',iostat=ios,status='old',action='read')
    do j = 1, size(w)
      read(1,*) w(j)
    enddo
    if ( ios /= 0 ) stop "Error opening file name"
    close(1)

  end subroutine read_w


  !> read MISCELA (tabella_ms and wm)
  subroutine read_MISCELA(w,cp,dcp,h)
    implicit none
    real(8), dimension(:,:), allocatable, intent(out):: cp, dcp, h
    real(8), dimension(:), allocatable, intent(inout):: w
    integer :: n(2), ios, idum
    real(8) :: dummy

    open(unit=1,file='tabellams.dat',iostat=ios,status='old',action='read')
    if (ios/=0) open(unit=1,file='toAFFS/tabellams.dat',iostat=ios,status='old',action='read')
    read(1,*) n(1), n(2)
    allocate(cp(1:n(1),0:n(2)))
    allocate(dcp(1:n(1),0:n(2)))
    allocate(h(1:n(1),0:n(2)))
    do i = 1, n(1)
      do j = 1, n(2)
        read(1,*) idum, idum, h(i,j), dummy, cp(i,j), dcp(i,j), dummy, dummy
      enddo
    enddo
    h(:,0) = h(:,1)
    cp(:,0) = cp(:,1)
    dcp(:,0) = dcp(:,1)
    close(1)

    call read_w(n(1),w)

  end subroutine read_MISCELA

  subroutine read_species(file,n,name)
    implicit none
    character(len=*), intent(in):: file
    integer, intent(inout):: n
    character(len=20), dimension(:), allocatable, intent(inout):: name

    open(newunit=unitFile,file=adjustl(trim(file)),status='unknown')
    read(unitFile,*) n
    allocate(name(1:n))
    do i = 1, n
      read(unitFile,'(A)') name(i)
      name(i) = adjustl(trim(name(i)))
    end do
    close(unitFile)

  end subroutine read_species


  subroutine read_array(file,array)
    implicit none
    character(len=*), intent(in):: file
    integer:: ios, n
    real, dimension(:), allocatable, intent(out):: array

    i = 0; ios = 0
    open(newunit=unitFile,file=adjustl(trim(file)))
    do while(ios==0)
      i = i+1
    enddo
    n = i
    allocate(array(1:n))
    do i = 1, n
      read(unitFile,*) array(i)
    enddo
    close(unitFile)

  end subroutine read_array


  subroutine write_array(file,n,array)
    implicit none
    character(len=*), intent(in):: file
    integer, intent(in):: n
    real, dimension(:), intent(in), optional:: array
    real, dimension(:), allocatable :: dummy

    if (.not.present(array)) allocate(dummy(1:n))
    dummy = 1.0

    open(newunit=unitFile,file=adjustl(trim(file)))
    write(unitFile,*) n
    do i = 1, n
      if (present(array)) then
        write(unitFile,*) array(i)
      else
        write(unitFile,*) dummy(i)
      endif
    enddo
    close(unitFile)

  end subroutine write_array



end module IO
