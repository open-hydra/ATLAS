module bc_builder_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64

  implicit none


contains


  subroutine build_BC(phase,sini,blocks)
    use ir_precision
    use strings,             only: parse
    use bcb_config_mod,      only: bcb_block_config_t, bcb_face_setup_t, &
                                   load_bcb_block_config, load_bcb_face_setup
    use finer,               only: file_ini
    use phase_mod,           only: phase_t
    use grid_mod,            only: mesh_cfg
    use io_phase_mod,        only: read_idealgas_properties, read_dp_properties
    use bc_block_mod
    use bc_cell_builder_mod, only: build_face
    use bc_names_mod
    implicit none
    type(phase_t),  intent(in)    :: phase(:)
    type(BC_block), intent(inout) :: blocks(:)
    type(file_ini), intent(in)    :: sini
    ! Local variables
    integer                       :: n_blocks_phase(size(phase))
    integer                       :: ff, n, m, p, b
    character(len=:), allocatable :: option_pairs(:)
    character(len=4)              :: ind, dirID
    character(len=30)             :: wholestring, args(3), phase_name
    logical                       :: multipatch=.false.
    type(file_ini)                :: faceini, patchini
    integer                       :: error
    character(len=7)              :: patchdirection
    character(len=50)             :: patchname, section_name
    real(8)                       :: patchrange(4)
    type(bcb_block_config_t)      :: block_cfg
    type(bcb_face_setup_t)        :: face_cfg

    n_blocks_phase = 0
    patchrange = 0.d0


    ! Loop over each block
    do b = 1, size(blocks)
      section_name = 'BCB-Block'//trim(str(.true.,b))   
      associate(blk => blocks(b))

      call load_bcb_block_config(sini, section_name, blk%nfaces, block_cfg)

      do while (sini%loop(section_name=section_name, option_pairs=option_pairs))
        call faceini%add(section_name=section_name, option_name=option_pairs(1), val=option_pairs(2))
      enddo

      ! Look for phases solved in block b
      wholestring = block_cfg%phase
      if (.not. block_cfg%has_phase) then
        allocate(blk%associated_phase(1:size(phase)))
        blk%associated_phase = phase
      else
        call parse(wholestring,' ',args)
        p = count(args /= '')
        allocate(blk%associated_phase(1:p))
        blk%associated_phase%name = args(1:p)
        do m = 1, p
          do n = 1, size(phase)
            if (blk%associated_phase(m)%name==phase(n)%name) &
              blk%associated_phase(m) = phase(n)
          enddo
        enddo
      endif

      ! Loop over each phase and check if the associated phase name of the current block matches the phase name.
      ! If a match is found, increment the count of blocks for that phase and assign the block ID accordingly.
      do p = 1, size(phase)
        do m = 1, size(blk%associated_phase)
          if (blk%associated_phase(m)%name==phase(p)%name) then
            n_blocks_phase(p) = n_blocks_phase(p)+1
            blk%id = n_blocks_phase(p)
          endif
        enddo
      enddo

      ! Read phase properties (if any)
      do p = 1, size(blk%associated_phase)
        if (blk%associated_phase(p)%name=='') then
          phase_name = ''
        else
          phase_name = trim(blk%associated_phase(p)%name)//'-'
        endif
        if (blk%associated_phase(p)%type=='IG') then
          call read_idealgas_properties(trim(phase_name),blk%associated_phase(p)%species)
        endif
        if (blk%associated_phase(p)%type=='DP') then
          call read_dp_properties(trim(phase_name),blk%associated_phase(p)%material)
        endif
        if (.not.allocated(blk%associated_phase(p)%species%massf)) &
        allocate(blk%associated_phase(p)%species%massf(1:blk%associated_phase(p)%species%n))
        blk%associated_phase(p)%species%massf = 1d-20
        if (.not.allocated(blk%associated_phase(p)%material%npcp)) blk%associated_phase(p)%material%n = 0
      enddo
    
      ! Look for faces bc definition
      do ff = 1, blk%nfaces

        multipatch = .false.
        blk%face(ff)%bc%name = trim(block_cfg%face_names(ff))
        error = merge(0, 1, len_trim(blk%face(ff)%bc%name) > 0)

        if (error/=0) then
          ! Check if mesh is 2Dplane or 2Daxi
          if (mesh_cfg%delthe==0.d0 .and. mesh_cfg%meshType == 2) then
            blk%face(ff)%bc%name = 'null'
            blk%face(ff)%bc%definition = 'null'
            error = 0
          elseif (mesh_cfg%delthe>0.d0 .and. mesh_cfg%meshType == 2) then
            blk%face(ff)%bc%name = 'axisymmetric'
            blk%face(ff)%bc%definition = 'axisymmetric'
            error = 0
          endif
          
          if (ff<=2 .and. mesh_cfg%meshType/=-1) then
            write(*,'(A,I2,A,I2)')'[ERROR] Missing face entry for face ', ff, ' in block ', b
            stop
          endif

        else

          call load_bcb_face_setup(sini, trim(blk%face(ff)%bc%name), face_cfg)
          multipatch = face_cfg%multipatch

          do while (sini%loop(section_name=trim(blk%face(ff)%bc%name), option_pairs=option_pairs))
            call faceini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
          enddo

          blk%face(ff)%bc%definition = face_cfg%definition
        endif

        ! Face-related INI source
        call faceini%free
        call faceini%add(section_name='face')
        do while (sini%loop(section_name=trim(blk%face(ff)%bc%name), option_pairs=option_pairs))
          call faceini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
        enddo

        ! BC building depending on specific case
        if (multipatch) then
          
          ! Multipatch BCs
          patchdirection = face_cfg%direction
          if (face_cfg%has_direction) then
            write(*,*)' Face n. = ', ff, ' -> ', trim(blk%face(ff)%bc%name), ' = multipatch'
            do p = 1, face_cfg%patch_count
              patchname = face_cfg%patches(p)%name
              patchrange = face_cfg%patches(p)%range
              call patchini%free
              call patchini%add(section_name='face')
              call patchini%add(section_name='face', option_name='name', val=patchname)
              do while (sini%loop(section_name=patchname, option_pairs=option_pairs))
                call patchini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
              enddo
              call patchini%add(section_name='face', option_name='direction', val=patchdirection)
              call patchini%add(section_name='face', option_name='range', val=patchrange)
              do m = 1, size(blk%associated_phase)
                call build_face(b,ff,blk%face(ff),patchini,blk%associated_phase(m))
              enddo
            enddo
          endif
        
        else
          ! Single patch with/without varying properties BCs
          call faceini%get(section_name='face', option_name='direction', val=dirID, error=error)
          if (error==0) then
            write(*,*)' Face n. = ', ff, ' -> ', trim(blk%face(ff)%bc%name), ' = single patch with varying properties'
            do m = 1, size(blk%associated_phase)
              call build_face(b,ff,blk%face(ff),faceini,blk%associated_phase(m))
            enddo
          else
            write(*,*)' Face n. = ', ff, ' -> ', trim(blk%face(ff)%bc%name), ' = single patch'
            do m = 1, size(blk%associated_phase)
              call blk%face(ff)%bc%build(faceini,'face',blk%associated_phase(m))
            enddo
            call broadcast_uniform_bc(blk%face(ff))
          endif
        endif

      enddo
      write(*,*)
      endassociate
    enddo
  end subroutine build_BC


  !> Copy face-level uniform BC properties to every cell center.
  subroutine broadcast_uniform_bc(face)
    use bc_block_mod, only: obj_face
    implicit none
    type(obj_face), intent(inout) :: face
    integer :: m, n

    !$omp parallel private(m,n)
    !$omp do collapse(2)
    do n = 1, face%Nn
      do m = 1, face%Nm

        associate( this => face%center(m,n) )

        ! General
        this%bc%name               = face%bc%name
        this%bc%definition         = face%bc%definition

        ! Connection
        this%bc%ci_n               = face%bc%ci_n
        this%bc%gp_id              = face%bc%gp_id
        this%bc%ci_properties      = face%bc%ci_properties
        this%bc%adj_assigned       = .false.
        this%bc%connection         = face%bc%connection

        ! IG
        this%bc%ig_id              = face%bc%ig_id
        if (face%bc%ig_n>0) then
          this%bc%ig_n             = face%bc%ig_n
          allocate(this%bc%ig_properties(1:face%bc%ig_n))
          this%bc%ig_properties    = face%bc%ig_properties
          if (allocated(face%bc%ig_time)) then
            this%bc%ig_time_file   = face%bc%ig_time_file
            this%bc%ig_time        = face%bc%ig_time
          endif
          if (face%bc%ig_species%n>0) then
            this%bc%ig_species%n     = face%bc%ig_species%n
            allocate(this%bc%ig_species%massf(1:face%bc%ig_species%n))
            this%bc%ig_species%massf = face%bc%ig_species%massf
          endif
        endif

        ! SP
        this%bc%sp_id              = face%bc%sp_id
        if (face%bc%sp_n>0) then
          this%bc%sp_n             = face%bc%sp_n
          allocate(this%bc%sp_properties(1:face%bc%sp_n))
          this%bc%sp_properties    = face%bc%sp_properties
          if (allocated(face%bc%sp_time)) then
            this%bc%sp_time_file   = face%bc%sp_time_file
            this%bc%sp_time        = face%bc%sp_time
          endif
        endif

        ! DP
        this%bc%dp_id              = face%bc%dp_id
        if (face%bc%dp_n>0) then
          this%bc%dp_n             = face%bc%dp_n
          allocate(this%bc%dp_properties(1:size(face%bc%dp_properties,1),1:size(face%bc%dp_properties,2),1:face%bc%dp_n))
          this%bc%dp_properties    = face%bc%dp_properties
        endif

        endassociate

      enddo
    enddo
    !$omp end parallel

  end subroutine broadcast_uniform_bc

end module bc_builder_mod
