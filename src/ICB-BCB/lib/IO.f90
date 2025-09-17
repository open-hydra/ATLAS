module ATLAS_IO
  use Lib_ORION_data
  use IR_Precision

  implicit none
  private
  public:: write_idealgas_bc_file
  public:: write_cdp_bc_file
  public:: read_vtk_tec ,write_vtk_tec
  public:: read_solfile, write_solfile
  public:: read_mesh
  public:: read_idealgas_properties, read_cdp_properties
  public:: read_phase
  public:: coarse_mesh, check_multigrid

  integer:: i,j,k,s
  integer:: unitfile

  contains
  
  subroutine write_idealgas_bc_file(name,block,level)
    use variables
    use ATLAS_high_level, only: ATLAS_block
    use TOM, only: fmn2ijk, meshtype
    implicit none
    character(len=*), intent(in)  :: name
    type(ATLAS_block), intent(in) :: block(:)
    integer, intent(in)           :: level
    character(len=len(name))      :: name_
    integer                       :: p, b, f, m, n, mend(6), nend(6)
    integer                       :: Ai, Aj, Ak, ii, jj, kk
    integer                       :: print_def
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
      if (level == 1) then
        open(newunit=unitfile,FILE=outpath//trim(name_)//'bc.txt',action='write')
      else
        open(newunit=unitfile,FILE=outpath//trim(name_)//'bc'//trim(str(.true.,level))//'.txt',action='write')
      endif
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
      do f = 1, block(b)%nfaces
        do n = 1, nend(f)
          do m = 1, mend(f)

            if (block(b)%face(f)%center(m,n)%bc%properties(3)==0.0 .and. &
                block(b)%face(f)%center(m,n)%bc%definition==4) then
              print_def = 3
            else
              print_def = block(b)%face(f)%center(m,n)%bc%definition
            endif
            
            call fmn2ijk(f,m,n,block(b)%dim(1),block(b)%dim(2),block(b)%dim(3),Ai,Aj,Ak)

            if (print_def == 77) print_def = 1 ! Necessaria per evitare ambiguità per periodicità multiblocco
            if (meshtype==1) then
              write(unitfile,'(3I8)')block(b)%id,f,print_def
            elseif (meshtype==-2) then
              write(unitfile,'(5I8)')block(b)%id,Ai,Aj,f,print_def
            else
              write(unitfile,'(6I8)')block(b)%id,Ai,Aj,Ak,f,print_def
            endif

            select case (print_def)

              case(1,1000)
                if (meshType == -2) then
                  do i = 1, block(b)%face(f)%center(m,n)%bc%nproperties-1-nrans-1
                    write(unitfile,'(I8)',advance='no') nint(block(b)%face(f)%center(m,n)%bc%properties(i))
                  enddo
                else
                  do i = 1, block(b)%face(f)%center(m,n)%bc%nproperties-1-nrans
                    write(unitfile,'(I8)',advance='no') nint(block(b)%face(f)%center(m,n)%bc%properties(i))
                  enddo
                endif
                do i = 1, size(block(b)%face(f)%center(m,n)%bc%connection)
                  write(unitfile,'(I8)',advance='no') block(b)%face(f)%center(m,n)%bc%connection(i)
                enddo
                write(unitfile,'(A)') ''

              case(2,3,11)

              case(4,22)
                do i = 1, block(b)%face(f)%center(m,n)%bc%nproperties
                  if (block(b)%face(f)%center(m,n)%bc%IG_time_BC(i)) then
                    write(unitfile,'(X,A,A1)',advance='no') trim(block(b)%face(f)%center(m,n)%bc%IG_time_properties(i)),','
                  else
                    write(unitfile,'(E16.6,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(i),','
                  endif
                enddo
                do i = 1, block(b)%face(f)%center(m,n)%bc%species%n
                  write(unitfile,'(E14.5,A)',advance='no') block(b)%face(f)%center(m,n)%bc%species%massf(i),','
                enddo
                write(unitfile,'(A)') ''
              
              case(5,6,9,10,13)
                write(unitfile,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(1)
                write(unitfile,'(E14.5,A1)') block(b)%face(f)%center(m,n)%bc%properties(2) ! roughness
              
              case(7)
                write(unitfile,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(1)
                write(unitfile,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(2)
                write(unitfile,'(E14.5,A1)') block(b)%face(f)%center(m,n)%bc%properties(3)

              case(8)
                write(unitfile,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(1)
                write(unitfile,'(E14.5,A1)') block(b)%face(f)%center(m,n)%bc%properties(2)

              case(12)
                do i = 1, 5
                  write(unitfile,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(i),','
                enddo
                write(unitfile,'(E14.5,A1)') block(b)%face(f)%center(m,n)%bc%properties(6) ! roughness

              case(14)
                s = size(block(b)%face(f)%center(m,n)%bc%properties)-6
                !> mdot   =   ((1-kinj)*SF*SFgeo*rhop*a) * (p/pRef) ** n
                !> OUTPUT ==> ((1-kinj)*SF*SFgeo*rhop*a) | n | pRef | Taf | haf | ...species mass fractions...
                do i = s, s+4
                  write(unitfile,'(E14.5,A1)',advance='no') block(b)%face(f)%center(m,n)%bc%properties(i)
                enddo
                do i = 1, block(b)%face(f)%center(m,n)%bc%species%n
                  write(unitfile,'(E14.5,A)',advance='no') block(b)%face(f)%center(m,n)%bc%species%massf(i),','
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
    use TOM, only: fmn2ijk
    implicit none
    character(len=*), intent(in)  :: name
    type(ATLAS_block), intent(in) :: block(:)
    character(len=len(name))      :: name_
    integer                       :: b, mm, p, f, m, n, mend(6), nend(6), pCD
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
        if (index(trim(name),trim(block(b)%associated_phase(p)%name))>0) then
          match = .true.
          pCD = p
        endif
      enddo
      if (.not.match) cycle
      mend(1:2) = block(b)%dim(2); nend(1:2) = block(b)%dim(3)
      mend(3:4) = block(b)%dim(1); nend(3:4) = block(b)%dim(3)
      mend(5:6) = block(b)%dim(1); nend(5:6) = block(b)%dim(2)
      do mm = 1, block(b)%associated_phase(pCD)%material%n
      do p = 1, block(b)%associated_phase(pCD)%material%npCP(mm)
      do f = 1, 6
        do n = 1, nend(f)
          do m = 1, mend(f)
            
            call fmn2ijk(f,m,n,block(b)%dim(1),block(b)%dim(2),block(b)%dim(3),Ai,Aj,Ak)
            
            write(u,'(8I8)')block(b)%id,Ai,Aj,Ak,f,mm,p,block(b)%face(f)%center(m,n)%bc%definition

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

              case(4,22)
                do i = 1, block(b)%face(f)%center(m,n)%bc%cp_nproperties
                  write(u,'(E14.5)',advance='no') block(b)%face(f)%center(m,n)%bc%cp_properties(mm,p,i)
                enddo
                write(u,'(A)') ''
              
              case(10)
                write(u,'(E14.5,A1)') block(b)%face(f)%center(m,n)%bc%cp_properties(mm,p,1)
              
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
    enddo

  end subroutine write_cdp_bc_file


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
        write(*,*) 'ERROR: mesh file is not readable'
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
        write(*,*) 'ERROR: mesh file is not readable'
        stop
      endif
    endif

    if (error/=0) &
      stop ("ERROR: mesh reading failed")

  end subroutine read_mesh


  subroutine write_solfile(phase,inblock)
    use variables, only: nrans, outpath
    use ATLAS_high_level, only: ATLAS_block
    use phase_module
    implicit none
    type(phase_type), intent(in)   :: phase
    type(ATLAS_block), intent(in)  :: inblock(:)
    type(ATLAS_block), allocatable :: block(:)
    integer :: b, nb, s, ap, nsc, cnt

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
    integer:: error, b

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
    use TOM, only: meshtype
    implicit none
    type(phase_type), intent(in)       :: phase(:)
    character(len=*), intent(in)       :: ICformat
    type(ATLAS_block), intent(in)      :: block(:)
    type(orion_data)                   :: orion
    type(obj_material)                 :: mat
    character(len=llen)                :: localpath_vtk, localpath
    integer(I4P)                       :: E_IO, b, s, nb, cnt, nsc, p, ap
    integer(I4P)                       :: m, g, nnn
    character(len=10*llen)             :: varnames, filename
    character(len=llen)                :: name_
    logical                            :: thereis

    localpath = outpath

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
          if (meshtype == 1) then
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
              varnames = trim(varnames)//' "rp'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              varnames = trim(varnames)//' "up'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              varnames = trim(varnames)//' "vp'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              varnames = trim(varnames)//' "wp'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              if (neuler==1) then
                varnames = trim(varnames)//' "Pp'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              endif
              varnames = trim(varnames)//' "Tp'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
              varnames = trim(varnames)//' "np'//trim(str(.true.,m))//trim(str(.true.,g))//'"'
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
            orion%block(cnt)%mesh(1:2,i,j,0) = block(b)%node(i,j,k)%c(1:2)
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
          if (meshtype == 1) then
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


  subroutine read_idealgas_properties(prefix, sp)
    use species
    use strings, only: parse
    use Lib_Tecplot
    implicit none
    character(len=*), intent(in):: prefix
    type(obj_species), intent(inout) :: sp
    integer           :: ios, i, n, unitfile, start, Ti1, Ti2, dummy_i, dummy1, dummy23
    character(256)    :: wholestring, args(2)
    character(512)    :: wmfile, thermofile(2)
    type(ORION_data)  :: orion

    open(newunit=unitFile,file=trim(prefix)//'phase.txt',status='old',iostat=ios)
    if (ios/=0) then
      write(*,*) '[WARNING] phase file '//trim(prefix)//'phase.txt'//' not found'
      return
    endif
    ios = 0; n = -1
    read(unitfile,*)!skip first line
    do while(ios==0)
      read(unitFile,'(A)',iostat=ios) wholestring
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

  ! File 2: thermo
    ios = tec_read_points_multivars(orion,4,trim(prefix)//'thermo.dat')
    if (ios/=0) then
      write(*,*) '[WARNING] thermo file, '//trim(prefix)//'thermo.dat'//' not found'
      return
    endif
    dummy1  = lbound(orion%block(1)%mesh, dim=2)
    dummy23 = lbound(orion%block(1)%mesh, dim=3)
    Ti1 = nint(orion%block(1)%mesh(1,dummy1,dummy23,dummy23))
    Ti2 = Ti1 + ubound(orion%block(1)%mesh, dim=2) - dummy1
    start = Ti1
    if (Ti1==1) Ti1 = 0
    allocate(sp%cp(1:sp%n,Ti1:Ti2))
    allocate(sp%dcp(1:sp%n,Ti1:Ti2))
    allocate(sp%h(1:sp%n,Ti1:Ti2))
    allocate(sp%s(1:sp%n,Ti1:Ti2))
    dummy23 = lbound(orion%block(1)%vars, dim=3)
    do i = 1, sp%n
      sp%cp(i,start:Ti2) = orion%block(i)%vars(1,:,dummy23,dummy23)
      sp%h(i,start:Ti2) = orion%block(i)%vars(2,:,dummy23,dummy23)
      sp%s(i,start:Ti2) = orion%block(i)%vars(3,:,dummy23,dummy23)
      sp%dcp(i,start:Ti2) = orion%block(i)%vars(4,:,dummy23,dummy23)
    enddo
    if (Ti1 == 0) then
      sp%cp(:,0) = sp%cp(:,1)
      sp%h(:,0) = 0.d0
      sp%s(:,0) = sp%s(:,1)
      sp%dcp(:,0) = sp%dcp(:,1)
    endif

  end subroutine read_idealgas_properties


  subroutine read_cdp_properties(prefix, mat)
    use material_module
    use strings, only: parse
    use Lib_Tecplot
    implicit none
    character(len=*), intent(in):: prefix
    type(obj_material), intent(inout) :: mat
    integer :: n, ios, Ti1, Ti2, unitfile
    character(len=30) :: wholestring, args(2)
    type(orion_data) :: orion

    open(newunit=unitFile,file=trim(prefix)//'phase.txt',status='old',iostat=ios)
    if (ios/=0) return!error stop ("Error reading phase file")
    ios = 0; n = -1
    read(unitfile,*)!skip first line
    do while(ios==0)
      read(unitFile,'(A)',iostat=ios) wholestring
      n = n + 1
    enddo
    mat%n = n
    allocate(mat%name(1:n))
    allocate(mat%npCP(1:n))
    rewind(unitFile)
    read(unitfile,*)!skip first line
    do i = 1, n
      read(unitFile,'(A)') wholestring
      call parse(wholestring,' ',args)
      mat%name(i) = trim(adjustl(args(1)))
      read(args(2),*,iostat=ios) mat%npCP(i)
    end do
    close(unitFile)

    ios = tec_read_points_multivars(orion,3,trim(prefix)//'properties.dat')
    if (ios/=0) return!error stop ("Error reading ideal-gas thermo file")
    Ti1 = nint(orion%block(1)%mesh(1,1,1,1))
    Ti2 = Ti1 + orion%block(1)%Ni - 1
    allocate(mat%cp(1:mat%n,Ti1:Ti2))
    allocate(mat%rho(1:mat%n,Ti1:Ti2))
    allocate(mat%h(1:mat%n,Ti1:Ti2))
    do i = 1, mat%n
      mat%cp(i,Ti1:Ti2) = orion%block(i)%vars(1,1:orion%block(1)%Ni,1,1)
      mat%rho(i,Ti1:Ti2) = orion%block(i)%vars(2,:,1,1)
      mat%h(i,Ti1:Ti2) = orion%block(i)%vars(3,:,1,1)
    enddo

  end subroutine read_cdp_properties


  subroutine read_phase(phase)
    use strings, only: parse
    use phase_module, only: phase_type
    implicit none
    type(phase_type), allocatable, intent(out) :: phase(:)
    character(len=128) :: filename, stringa(2)
    integer :: m, i, num_files, u, ios, num_mat
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
          elseif (index(type,'solid')>0) then
            phase(i)%type = 'SP'
          elseif (index(type,'ideal-gas')>0) then
            phase(i)%type = 'IG'
          else
            write(*,*) 'Error: unknown phase type'
            stop
          endif
          close(u)
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


  subroutine coarse_mesh ( fine, coarse )
    use Lib_ORION_data

    implicit none
    type(ORION_data), intent(in)    :: fine
    type(ORION_data), intent(inout) :: coarse
    ! Local
    integer :: b, nb, Ni, Nj, Nk, i, j, k, i2, j2, k2


    nb = size( fine % block )
    if ( allocated ( coarse % block )) deallocate (coarse % block)
    allocate ( coarse % block( nb ) )
    
    do b = 1, nb
      Ni = fine % block(b)%Ni /2
      Nj = fine % block(b)%Nj /2
      Nk = fine % block(b)%Nk /2
      Nk = Max ( 1, Nk ) ! 2D case
      coarse % block(b) % Ni = Ni
      coarse % block(b) % Nj = Nj
      coarse % block(b) % Nk = Nk
      if ( allocated ( coarse % block(b) % mesh )) deallocate (coarse % block(b) % mesh)
      allocate( coarse%block(b)%mesh(1:3,0:Ni,0:Nj,0:Nk) )

      do k = 0, fine % block(b)%Nk, 2-Mod(fine % block(b)%Nk,2)
      do j = 0, fine % block(b)%Nj, 2
      do i = 0, fine % block(b)%Ni, 2
          
          i2 = i / 2
          j2 = j / 2
          k2 = k / 2
    
          if ( fine % block(b)%Nk == 1 ) then ! 2D
            k2 = k
          end if
    
          coarse%block(b)%mesh(1:3,i2,j2,k2) = fine%block(b)%mesh(1:3,i,j,k)
        
        enddo; enddo; enddo

    enddo

  end subroutine coarse_mesh


  subroutine check_multigrid ( orion, MGL )
    use Lib_ORION_data

    implicit none
    type(ORION_data), intent(in)    :: orion
    integer, intent(in)             :: MGL
    ! Local
    integer :: b, rap, check


    rap = 2**(MGL-1)

    do b = 1, size( orion % block )

      check = 0

      if ( Mod ( orion % block(b) % Ni, rap ) == 0 ) check = check + 1
      if ( Mod ( orion % block(b) % Nj, rap ) == 0 ) check = check + 1
      if ( Mod ( orion % block(b) % Nk, rap ) == 0 .or. orion % block(b) % Nk == 1 ) check = check + 1

      if ( check < 3 ) then
        write(*,*) ' Error in check_multigrid, block: ', b
        stop
      endif

    enddo

  end subroutine check_multigrid

end module ATLAS_IO
