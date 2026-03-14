module ATLAS_write_bc
  use Lib_ORION_data
  use IR_Precision
  implicit none
  private
  public:: write_idealgas_bc_file
  public:: write_cdp_bc_file

  integer:: unitfile

  contains
  
  subroutine write_idealgas_bc_file(name,block,level)
    use variables
    use ATLAS_high_level, only: ATLAS_block
    use ATLAS_Mod_Grid, only: fmn2ijk, meshtype
    implicit none
    character(len=*), intent(in)  :: name
    type(ATLAS_block), intent(in) :: block(:)
    integer, intent(in)           :: level
    character(len=len(name))      :: name_
    integer                       :: i, j, s, p, b, f, m, n, mend(6), nend(6)
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
            if (meshtype==1 .and. print_def /= 0) then
              write(unitfile,'(4I8)')block(b)%id,Ai,f,print_def
            elseif (meshtype==-2) then
              write(unitfile,'(5I8)')block(b)%id,Ai,Aj,f,print_def
            else
              write(unitfile,'(6I8)')block(b)%id,Ai,Aj,Ak,f,print_def
            endif

            select case (print_def)

              case(1,1000)
                if (meshType == -2) then
                  do i = 1, block(b)%face(f)%center(m,n)%bc%nproperties-2-nrans-1
                    write(unitfile,'(I8)',advance='no') nint(block(b)%face(f)%center(m,n)%bc%properties(i))
                  enddo
                else
                  do i = 1, block(b)%face(f)%center(m,n)%bc%nproperties-2-nrans
                    write(unitfile,'(I8)',advance='no') nint(block(b)%face(f)%center(m,n)%bc%properties(i))
                  enddo
                endif
                do i = 1, size(block(b)%face(f)%center(m,n)%bc%connection)
                  write(unitfile,'(I8)',advance='no') block(b)%face(f)%center(m,n)%bc%connection(i)
                enddo
                write(unitfile,'(A)') ''

              case(2,3,11)

              case(999)
                if (meshType /= 1) then
                  write(unitfile,'(I8)',advance='no') nint(block(b)%face(f)%center(m,n)%bc%properties(1))
                  write(unitfile,'(I8)',advance='no') nint(block(b)%face(f)%center(m,n)%bc%properties(2))
                  write(unitfile,'(A)') ''
                endif

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
    use ATLAS_Mod_Grid, only: fmn2ijk
    implicit none
    character(len=*), intent(in)  :: name
    type(ATLAS_block), intent(in) :: block(:)
    character(len=len(name))      :: name_
    integer                       :: i, j, b, mm, p, f, m, n, mend(6), nend(6), pCD
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

              case(4,14,22)
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

end module ATLAS_write_bc
