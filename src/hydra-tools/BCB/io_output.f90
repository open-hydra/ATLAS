module io_write_bc_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64
  use Lib_ORION_data
  use IR_Precision
  implicit none
  private
  public:: write_ig_bc
  public:: write_sp_bc
  public:: write_dp_bc

  integer:: unitfile
  character(len=18), parameter :: outpath = 'fromATLAStoSolver/'

  contains
  
  subroutine write_ig_bc(name,blk)
    use bc_block_mod, only: BC_block
    use grid_mod, only: fmn2ijk, mesh_cfg
    implicit none
    character(len=*), intent(in) :: name
    type(BC_block),   intent(in) :: blk(:)
    character(len=len(name))     :: name_
    integer                      :: i, j, s, p, b, f, m, n, mend(6), nend(6)
    integer                      :: Ai, Aj, Ak, ii, jj, kk
    integer                      :: print_id
    logical                      :: match

    call execute_command_line('mkdir -p '//trim(outpath))

    if (trim(name)=='') then
      name_ = name
    else
      name_ = trim(name)//'-'
    endif

    match = .false.
    do b = 1, size(blk)
      do p = 1, size(blk(b)%associated_phase(:))
        if (index(trim(name),trim(blk(b)%associated_phase(p)%name))>0) match = .true.
      enddo
    enddo

    if (match) then
        open(newunit=unitfile,FILE=outpath//trim(name_)//'bc.txt',action='write')
    else
      return
    endif

    do b = 1, size(blk)
      match = .false.
      do p = 1, size(blk(b)%associated_phase(:))
        if (index(trim(name),trim(blk(b)%associated_phase(p)%name))>0) match = .true.
      enddo
      if (.not.match) cycle
      mend(1:2) = blk(b)%dim(2); nend(1:2) = blk(b)%dim(3)
      mend(3:4) = blk(b)%dim(1); nend(3:4) = blk(b)%dim(3)
      mend(5:6) = blk(b)%dim(1); nend(5:6) = blk(b)%dim(2)
      do f = 1, blk(b)%nfaces
        do n = 1, nend(f)
          do m = 1, mend(f)

            associate ( this => blk(b)%face(f)%center(m,n)%bc )

            call fmn2ijk(f,m,n,blk(b)%dim(1),blk(b)%dim(2),blk(b)%dim(3),Ai,Aj,Ak)

            if (this % gp_id/=0) then
              print_id = this % gp_id
            else
              print_id = this % ig_id
            endif

            if     (mesh_cfg%meshType==-1) then
              write(unitfile,'(4I8)') blk(b) % id, Ai, f, print_id
            elseif (mesh_cfg%meshType==-2) then
              write(unitfile,'(5I8)') blk(b) % id, Ai, Aj, f, print_id
            else
              write(unitfile,'(6I8)') blk(b) % id, Ai, Aj, Ak, f, print_id
            endif

            select case (this % gp_id)
            case(101, 201)
              do i = 1, this % ci_n
                write(unitfile,'(I8)',advance='no') this % ci_properties(i)
              enddo
              do i = 1, size(this % connection)
                write(unitfile,'(I8)',advance='no') this % connection(i)
              enddo
              write(unitfile,'(A)') ''

            case(102)
              call write_chimera(blk(b)%face(f), f, Ai, Aj, Ak)

            end select


            select case (print_id)
            ! 300-series -> wall | 500-series -> Special boundary conditions (e.g., SRM grain)
            case(301:309, 501)
              do i = 1, this % ig_n
                write(unitfile,'(E16.6,A1)',advance='no') this % ig_properties(i),','
              enddo
              write(unitfile,'(A)') ''
            
            ! 400-series -> inlet/outlet with time variation
            case(401:420)
              do i = 1, this % ig_n
                if (this % IG_time(i)) then
                  write(unitfile,'(X,A,A1)',advance='no') trim(this % IG_time_file(i)),','
                elseif (this % ig_properties(i) > 1000_R8) then
                  write(unitfile,'(A)',advance='no') 'normal,'
                else
                  write(unitfile,'(E16.6,A1)',advance='no') this % ig_properties(i),','
                endif
              enddo
              write(unitfile,'(A)') ''
              
            end select

            endassociate

          enddo
        enddo
      enddo
    enddo

    close(unitfile)

  end subroutine write_ig_bc


  subroutine write_sp_bc(name,blk)
    use bc_block_mod, only: BC_block
    use grid_mod, only: fmn2ijk, mesh_cfg
    implicit none
    character(len=*), intent(in) :: name
    type(BC_block),   intent(in) :: blk(:)
    character(len=len(name))     :: name_
    integer                      :: i, j, s, p, b, f, m, n, mend(6), nend(6)
    integer                      :: Ai, Aj, Ak, ii, jj, kk
    integer                      :: print_id
    logical                      :: match

    call execute_command_line('mkdir -p '//trim(outpath))

    if (trim(name)=='') then
      name_ = name
    else
      name_ = trim(name)//'-'
    endif

    match = .false.
    do b = 1, size(blk)
      do p = 1, size(blk(b)%associated_phase(:))
        if (index(trim(name),trim(blk(b)%associated_phase(p)%name))>0) match = .true.
      enddo
    enddo

    if (match) then
        open(newunit=unitfile,FILE=outpath//trim(name_)//'bc.txt',action='write')
    else
      return
    endif

    do b = 1, size(blk)
      match = .false.
      do p = 1, size(blk(b)%associated_phase(:))
        if (index(trim(name),trim(blk(b)%associated_phase(p)%name))>0) match = .true.
      enddo
      if (.not.match) cycle
      mend(1:2) = blk(b)%dim(2); nend(1:2) = blk(b)%dim(3)
      mend(3:4) = blk(b)%dim(1); nend(3:4) = blk(b)%dim(3)
      mend(5:6) = blk(b)%dim(1); nend(5:6) = blk(b)%dim(2)
      do f = 1, blk(b)%nfaces
        do n = 1, nend(f)
          do m = 1, mend(f)

            associate ( this => blk(b)%face(f)%center(m,n)%bc )

            call fmn2ijk(f,m,n,blk(b)%dim(1),blk(b)%dim(2),blk(b)%dim(3),Ai,Aj,Ak)

            if (this % gp_id/=0) then
              print_id = this % gp_id
            else
              print_id = this % sp_id
            endif


            if     (mesh_cfg%meshType==-1) then
              write(unitfile,'(4I8)') blk(b) % id, Ai, f, print_id
            elseif (mesh_cfg%meshType==-2) then
              write(unitfile,'(5I8)') blk(b) % id, Ai, Aj, f, print_id
            else
              write(unitfile,'(6I8)') blk(b) % id, Ai, Aj, Ak, f, print_id
            endif

            select case (this % gp_id)
            ! 100-series -> connection | 200-series -> periodic
            case(101, 201)
              do i = 1, this % ci_n
                write(unitfile,'(I8)',advance='no') this % ci_properties(i)
              enddo
              do i = 1, size(this % connection)
                write(unitfile,'(I8)',advance='no') this % connection(i)
              enddo
              write(unitfile,'(A)') ''

            end select


            select case (print_id)
            ! 300-series -> wall
            case(301:309)
              do i = 1, this % sp_n
                write(unitfile,'(E16.6,A1)',advance='no') this % sp_properties(i),','
              enddo
              write(unitfile,'(A)') ''
              
            end select

            endassociate

          enddo
        enddo
      enddo
    enddo

    close(unitfile)

  end subroutine write_sp_bc


  subroutine write_dp_bc(name,blk)
    use bc_block_mod, only: BC_block
    use grid_mod, only: fmn2ijk, mesh_cfg
    implicit none
    character(len=*), intent(in) :: name
    type(BC_block),   intent(in) :: blk(:)
    character(len=len(name))     :: name_
    integer                      :: i, j, b, mm, p, f, m, n, mend(6), nend(6), pCD
    integer                      :: print_id
    integer                      :: Ai, Aj, Ak, ii, jj, kk
    logical                      :: match

    call execute_command_line('mkdir -p '//trim(outpath))

    if (trim(name)=='') then
      name_ = name
    else
      name_ = trim(name)//'-'
    endif

    match = .false.
    do b = 1, size(blk)
      do p = 1, size(blk(b)%associated_phase(:))
        if (index(trim(name),trim(blk(b)%associated_phase(p)%name))>0) match = .true.
      enddo
    enddo

    if (match) then
      open(newunit=unitfile,FILE=outpath//trim(name_)//'bc.txt',action='write')
    else
      return
    endif

    do b = 1, size(blk)
      match = .false.
      do p = 1, size(blk(b)%associated_phase(:))
        if (index(trim(name),trim(blk(b)%associated_phase(p)%name))>0) then
          match = .true.
          pCD = p
        endif
      enddo
      if (.not.match) cycle
      mend(1:2) = blk(b)%dim(2); nend(1:2) = blk(b)%dim(3)
      mend(3:4) = blk(b)%dim(1); nend(3:4) = blk(b)%dim(3)
      mend(5:6) = blk(b)%dim(1); nend(5:6) = blk(b)%dim(2)
      do mm = 1, blk(b)%associated_phase(pCD)%material%n
        do p = 1, blk(b)%associated_phase(pCD)%material%npCP(mm)
          do f = 1, blk(b)%nfaces
            do n = 1, nend(f)
              do m = 1, mend(f)

                associate ( this => blk(b)%face(f)%center(m,n)%bc )

                call fmn2ijk(f,m,n,blk(b)%dim(1),blk(b)%dim(2),blk(b)%dim(3),Ai,Aj,Ak)

                if (this % gp_id/=0) then
                  print_id = this % gp_id
                else
                  print_id = this % dp_id
                endif

                if     (mesh_cfg%meshType==-1) then
                  write(unitfile,'(4I8)') blk(b) % id, Ai, f, print_id
                elseif (mesh_cfg%meshType==-2) then
                  write(unitfile,'(5I8)') blk(b) % id, Ai, Aj, f, print_id
                else
                  write(unitfile,'(6I8)') blk(b) % id, Ai, Aj, Ak, f, print_id
                endif

                select case (this % gp_id)
                ! 100-series -> connection | 200-series -> periodic
                case(101, 201)
                  do i = 1, this % ci_n
                    write(unitfile,'(I8)',advance='no') this % ci_properties(i)
                  enddo
                  do i = 1, size(this % connection)
                    write(unitfile,'(I8)',advance='no') this % connection(i)
                  enddo
                  write(unitfile,'(A)') ''

                end select

                select case (this % dp_id)
                ! 400-series -> inlet/outlet
                case(401:403)
                  do i = 1, size(blk(b)%face(f)%center(m,n)%bc%dp_properties,3)
                    if (blk(b)%face(f)%center(m,n)%bc%dp_properties(mm,p,i) > 1000.0_R8) then
                      write(unitfile,'(A)',advance='no') ' normal'
                    else
                      write(unitfile,'(E14.5)',advance='no') blk(b)%face(f)%center(m,n)%bc%dp_properties(mm,p,i)
                    endif
                  enddo
                  write(unitfile,'(A)') ''

                end select

                endassociate
              enddo
            enddo
          enddo
        enddo
      enddo
    enddo

  end subroutine write_dp_bc


  subroutine write_chimera(face, f, Ai, Aj, Ak)
    use bc_block_mod, only: obj_face
    implicit none
    type(obj_face), intent(in) :: face
    integer,        intent(in) :: f, Ai, Aj, Ak
    ! Local
    integer :: g, ii, jj, kk, i, j, nchi

    do g = 1, 2
      select case(f)
        case(1)
          ii = Ai-g; jj = Aj; kk = Ak
        case(2)
          ii = Ai+g; jj = Aj; kk = Ak
        case(3)
          jj = Aj-g; ii = Ai; kk = Ak
        case(4)
          jj = Aj+g; ii = Ai; kk = Ak
        case(5)
          kk = Ak-g; ii = Ai; jj = Aj
        case(6)
          kk = Ak+g; ii = Ai; jj = Aj
      end select     

      nchi = 0
      if (allocated(face%cell(ii,jj,kk)%chimerainfo)) then
        nchi = size(face%cell(ii,jj,kk)%chimerainfo,1)
      endif
      write(unitfile,'(I8)',advance='no') nchi
    
    enddo

    write(unitfile,'(A)') ''

    do g = 1, 2
      select case(f)
        case(1)
          ii = Ai-g; jj = Aj; kk = Ak
        case(2)
          ii = Ai+g; jj = Aj; kk = Ak
        case(3)
          jj = Aj-g; ii = Ai; kk = Ak
        case(4)
          jj = Aj+g; ii = Ai; kk = Ak
        case(5)
          kk = Ak-g; ii = Ai; jj = Aj
        case(6)
          kk = Ak+g; ii = Ai; jj = Aj
      end select     

      if (.not.allocated(face%cell(ii,jj,kk)%chimerainfo)) cycle
      do i = 1, size(face%cell(ii,jj,kk)%chimerainfo,1)
        write(unitfile,'(4I8)',advance='no') (nint(face%cell(ii,jj,kk)%chimerainfo(i,j)),j=1,4)
        write(unitfile,'(E20.10)') face%cell(ii,jj,kk)%chimerainfo(i,5)
      enddo
    
    enddo

  end subroutine write_chimera

end module io_write_bc_mod
