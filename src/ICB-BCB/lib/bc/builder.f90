module build_BC_mod
  use ir_precision
  use finer, only: file_ini
  use phase_module, only: phase_type
  use ATLAS_high_level
  use lib_bc
  use cell_builder_mod, only: build_cell
  implicit none
  private
  public:: build_BC

  real(8), allocatable :: Atot(:)

  contains

  subroutine build_BC(phase,sini,blocks)
    use ATLAS_Mod_Grid, only: mesh_cfg
    use variables, only: cfg
    use strings, only: parse
    use ATLAS_read_phase, only: read_idealgas_properties, read_cdp_properties
    implicit none
    type(phase_type), intent(in)     :: phase(:)
    type(ATLAS_block), intent(inout) :: blocks(:)
    type(file_ini), intent(in)       :: sini
    !> Local variables
    integer                        :: n_blocks_phase(size(phase))
    logical                        :: cell_dependent, multipatch=.false.
    type(file_ini)                 :: faceini, patchini
    integer                        :: error, error_patch=0
    character(len=:), allocatable  :: option_pairs(:)
    character(len=4)               :: ind, dirID
    character(len=7)               :: patchdirection
    character(len=50)              :: patchname, section_name
    integer                        :: ff, n, m, p, b
    real(8)                        :: patchrange(4)
    character(len=30)              :: wholestring, args(3), phase_name, nametemp

    n_blocks_phase = 0
    !Calcolo l'area intera di ogni faccia (considerando tutti i blocchi)
    allocate(Atot(blocks(1)%nfaces))
    Atot = 0.0
    do  b = 1, size(blocks)
      do ff = 1, size(blocks(b)%face(:))
        do n = 1, blocks(b)%face(ff)%Nn
            do m = 1, blocks(b)%face(ff)%Nm
                Atot(ff) = Atot(ff) + blocks(b)%face(ff)%center(m,n)%area
            enddo
        enddo
      enddo
    enddo

    ! Loop over each block
    do b = 1, size(blocks)
      section_name = 'BCB-Block'//trim(str(.true.,b))   
      associate(block => blocks(b))

      do while (sini%loop(section_name=section_name, option_pairs=option_pairs))
        call faceini%add(section_name=section_name, option_name=option_pairs(1), val=option_pairs(2))
      enddo

      ! Look for phases solved in block b
      call sini%get(section_name=section_name, option_name='phase', val=wholestring, error=error)
      if (error/=0) then
        allocate(block%associated_phase(1:size(phase)))
        block%associated_phase = phase
      else
        call parse(wholestring,' ',args)
        p = count(args /= '')
        allocate(block%associated_phase(1:p))
        block%associated_phase%name = args(1:p)
        do m = 1, p
          do n = 1, size(phase)
            if (block%associated_phase(m)%name==phase(n)%name) &
              block%associated_phase(m) = phase(n)
          enddo
        enddo
      endif

      ! Loop over each phase and check if the associated phase name of the current block matches the phase name.
      ! If a match is found, increment the count of blocks for that phase and assign the block ID accordingly.
      do p = 1, size(phase)
        do m = 1, size(block%associated_phase)
          if (block%associated_phase(m)%name==phase(p)%name) then
            n_blocks_phase(p) = n_blocks_phase(p)+1
            block%id = n_blocks_phase(p)
          endif
        enddo
      enddo

      ! Read phase properties (if any)
      do p = 1, size(block%associated_phase)
        if (block%associated_phase(p)%name=='') then
          phase_name = ''
        else
          phase_name = trim(block%associated_phase(p)%name)//'-'
        endif
        if (block%associated_phase(p)%type=='IG') then
          call read_idealgas_properties(trim(phase_name),block%associated_phase(p)%species)
        endif
        if (block%associated_phase(p)%type=='CD') then
          call read_cdp_properties(trim(phase_name),block%associated_phase(p)%material)
        endif
        if (.not.allocated(block%associated_phase(p)%species%massf)) &
        allocate(block%associated_phase(p)%species%massf(1:block%associated_phase(p)%species%n))
        block%associated_phase(p)%species%massf = 1d-20
        if (.not.allocated(block%associated_phase(p)%material%npcp)) block%associated_phase(p)%material%n = 0
      enddo
    
      ! Look for faces bc definition
      do ff = 1, block%nfaces

        call sini%get(section_name=section_name, option_name='face'//trim(str(.true.,ff)), &
                                                              val=block%face(ff)%bc%name, error=error)

        if (error/=0) then
          if (ff<=2 .and. mesh_cfg%meshType/=1) then
            write(*,*)'[ERROR] Missing face entry for face ', ff, ' in block ', b
            stop
          else
            if (mesh_cfg%delthe==0.d0 .or. mesh_cfg%meshType == 1) then
              block%face(ff)%bc%name = 'null'
              block%face(ff)%bc%definition = 0
            else
              block%face(ff)%bc%name = 'axisymmetric'
              block%face(ff)%bc%definition = 2
            endif
            error = 0
          endif
        else
          do while (sini%loop(section_name=trim(block%face(ff)%bc%name), option_pairs=option_pairs))
            call faceini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
            if (index(option_pairs(1),'patch')>0) multipatch=.true.
          enddo
          call sini%get(section_name=trim(block%face(ff)%bc%name), option_name='type', &
                        val=block%face(ff)%bc%definition, error=error)
        endif

        ! Face-related INI source
        multipatch = .false.
        call faceini%free
        call faceini%add(section_name='face')
        do while (sini%loop(section_name=trim(block%face(ff)%bc%name), option_pairs=option_pairs))
          call faceini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
        
          if (index(option_pairs(1),'patch')>0) multipatch=.true.
        enddo
        if (error/=0 .and. .not.multipatch) then
          write(*,*)'[ERROR] Missing type entry for face ', ff, ' in block ', b
          stop
        endif

        ! BC building depending on specific case
        if (multipatch) then
          
          ! Multipatch BCs
          call sini%get(section_name=block%face(ff)%bc%name, option_name='direction', &
                        val=patchdirection, error=error)
          if (error==0) then
            write(*,*)' Face n. = ', ff, ' -> ', trim(block%face(ff)%bc%name), ' = multipatch'
            p = 0
            do
              p = p+1; write(ind,'(I4)') p
              call sini%get(section_name=block%face(ff)%bc%name, option_name='patch'//adjustl(ind), &
                                                val=patchname, error=error_patch)
              if (error_patch/=0) exit
              call sini%get(section_name=block%face(ff)%bc%name, option_name='range'//adjustl(ind), &
                                                val=patchrange, error=error)
              call patchini%free
              call patchini%add(section_name='face')
              do while (sini%loop(section_name=patchname, option_pairs=option_pairs))
                call patchini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
              enddo
              call patchini%add(section_name='face', option_name='range', val=patchrange)
              call patchini%add(section_name='face', option_name='direction', val=patchdirection)
              do m = 1, size(block%associated_phase)
                call build_cell(b,ff,block%face(ff),cfg%nrans,patchini,block%associated_phase(m),Atot(ff))
              enddo
            enddo
          endif
        
        else
          ! Single patch with/without varying properties BCs
          cell_dependent = .false.
          call faceini%get(section_name='face', option_name='direction', val=dirID, error=error)
          if (error==0) cell_dependent=.true.
          if (cell_dependent) then
            write(*,*)' Face n. = ', ff, ' -> ', trim(block%face(ff)%bc%name), ' = single patch with varying properties'
            do m = 1, size(block%associated_phase)
              call build_cell(b,ff,block%face(ff),cfg%nrans,faceini,block%associated_phase(m),Atot(ff))
            enddo
          else
            write(*,*)' Face n. = ', ff, ' -> ', trim(block%face(ff)%bc%name), ' = single patch'
            do m = 1, size(block%associated_phase)
              call block%face(ff)%bc%build(cfg%nrans,faceini,'face',block%associated_phase(m))
            enddo
            !$omp parallel private(m,n)
            !$omp do collapse(2)
            do n = 1, block%face(ff)%Nn
              do m = 1, block%face(ff)%Nm
                allocate(block%face(ff)%center(m,n)%bc%properties(1:block%face(ff)%bc%nproperties))
                block%face(ff)%center(m,n)%bc%adj_assigned = .false.
                block%face(ff)%center(m,n)%bc%nproperties = block%face(ff)%bc%nproperties
                block%face(ff)%center(m,n)%bc%connection = block%face(ff)%bc%connection
                block%face(ff)%center(m,n)%bc%definition = block%face(ff)%bc%definition
                block%face(ff)%center(m,n)%bc%properties = block%face(ff)%bc%properties
                block%face(ff)%center(m,n)%bc%IG_time_properties = block%face(ff)%bc%IG_time_properties
                block%face(ff)%center(m,n)%bc%IG_time_BC = block%face(ff)%bc%IG_time_BC
                block%face(ff)%center(m,n)%bc%species%n = block%face(ff)%bc%species%n
                if (block%face(ff)%bc%species%n>0) &
                  block%face(ff)%center(m,n)%bc%species%massf = block%face(ff)%bc%species%massf
                if (allocated(block%face(ff)%bc%cp_properties)) then
                  allocate(block%face(ff)%center(m,n)%bc%cp_properties &
                                          (size(block%face(ff)%bc%cp_properties,1),size(block%face(ff)%bc%cp_properties,2),size(block%face(ff)%bc%cp_properties,3)))
                  block%face(ff)%center(m,n)%bc%cp_nproperties = block%face(ff)%bc%cp_nproperties
                  block%face(ff)%center(m,n)%bc%cp_properties = block%face(ff)%bc%cp_properties
                endif
              enddo
            enddo
            !$omp end parallel
          endif
        endif

      enddo
      write(*,*)
      endassociate
    enddo
  end subroutine build_BC

end module build_BC_mod
