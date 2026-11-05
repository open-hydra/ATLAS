module bc_builder_mod
  use, intrinsic :: iso_fortran_env, only : I4 => int32, R8 => real64

  implicit none


contains


  subroutine build_BC(phase,sini,blocks)
    use ir_precision
    use strings,             only: parse
    use bcb_config_mod,      only: bcb_block_config_t, bcb_face_setup_t, load_bcb_block_config, load_bcb_face_setup
    use input_keys_mod,      only: input_keys_check_section
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
    type(file_ini), intent(inout) :: sini
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
            stop 1
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
        call faceini%add(section_name='face', option_name='face', val=ff)
        do while (sini%loop(section_name=trim(blk%face(ff)%bc%name), option_pairs=option_pairs))
          call faceini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
        enddo

        ! BC building depending on specific case
        if (multipatch) then
          
          ! Multipatch BCs. A cell is built by the first patch whose range holds it (patch_of); one left
          ! with no patch lies in none of the ranges (check_face_coverage, after the connection search)
          patchdirection = face_cfg%direction
          allocate(blk%face(ff)%patch_of(blk%face(ff)%Nm, blk%face(ff)%Nn))
          blk%face(ff)%patch_of = 0
          if (face_cfg%has_direction) then
            write(*,*)' Face n. = ', ff, ' -> ', trim(blk%face(ff)%bc%name), ' = multipatch'
            do p = 1, face_cfg%patch_count
              patchname = face_cfg%patches(p)%name
              patchrange = face_cfg%patches(p)%range
              call input_keys_check_section(sini, trim(patchname), 'section')
              call patchini%free
              call patchini%add(section_name='face')
              call patchini%add(section_name='face', option_name='name', val=patchname)
              call patchini%add(section_name='face', option_name='face', val=ff)   ! the face of the patch (line-file mapping)
              do while (sini%loop(section_name=patchname, option_pairs=option_pairs))
                call patchini%add(section_name='face', option_name=option_pairs(1), val=option_pairs(2))
              enddo
              call patchini%add(section_name='face', option_name='direction', val=patchdirection)
              call patchini%add(section_name='face', option_name='range', val=patchrange)
              do m = 1, size(blk%associated_phase)
                call build_face(b,ff,blk%face(ff),patchini,blk%associated_phase(m),sini,patch=p)
              enddo
            enddo
          endif
        
        else
          ! Single patch with/without varying properties BCs
          call faceini%get(section_name='face', option_name='direction', val=dirID, error=error)
          if (error==0) then
            write(*,*)' Face n. = ', ff, ' -> ', trim(blk%face(ff)%bc%name), ' = single patch with varying properties'
            do m = 1, size(blk%associated_phase)
              call build_face(b,ff,blk%face(ff),faceini,blk%associated_phase(m),sini)
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


  !> Stop on face cells that no declaration has given a BC, once the connections and the chimera
  !> search have claimed theirs:
  !> - a cell of a multipatch face that lies in none of the ranges of its patches would be written 0
  !>   (null), a code for a face with no BC at all (cells that BC-force-connect has made 101/103 are
  !>   claimed);
  !> - a cell of a face declared 'chimera' with BC-chimera = false keeps 100, the placeholder of a
  !>   connection or chimera face before its search, which no solver reads (the cells that coincide with
  !>   a cell of another block are made connections, 101/103).
  subroutine check_face_coverage(blocks, chimeraon)
    use grid_mod,     only: mesh_cfg
    use bc_block_mod
    use bc_names_mod, only: MARKER_Chim
    implicit none
    type(BC_block), intent(in) :: blocks(:)
    logical,        intent(in) :: chimeraon
    integer :: b, f, m, n, nbad, mfirst, nfirst
    logical :: failed

    failed = .false.
    do b = 1, size(blocks)
      do f = 1, blocks(b)%nfaces
        associate (face => blocks(b)%face(f))
        if (allocated(face%patch_of)) then
          nbad = 0
          do n = 1, face%Nn
            do m = 1, face%Nm
              if (face%patch_of(m,n) == 0 .and. face%center(m,n)%bc%gp_id == 0) then
                nbad = nbad + 1
                if (nbad == 1) then; mfirst = m; nfirst = n; endif
              endif
            enddo
          enddo
          if (nbad > 0) then
            write(*,'(*(g0))') '[ERROR] block ', blocks(b)%id, ' face ', f, &
              ' ([', trim(face%bc%name), ']): ', nbad, ' of its ', face%Nm*face%Nn, &
              ' cells lie in none of the ranges of its patches and would be written 0 (no BC)'
            call say_first_cell(face, mfirst, nfirst)
            write(*,'(A)') '        make the ranges of the patches cover the whole face'
            failed = .true.
          endif
        endif
        if (.not. chimeraon) then
          nbad = 0
          do n = 1, face%Nn
            do m = 1, face%Nm
              if (trim(face%center(m,n)%bc%definition) == trim(MARKER_Chim) .and. &
                  face%center(m,n)%bc%gp_id == 100) then
                nbad = nbad + 1
                if (nbad == 1) then; mfirst = m; nfirst = n; endif
              endif
            enddo
          enddo
          if (nbad > 0) then
            write(*,'(*(g0))') '[ERROR] block ', blocks(b)%id, ' face ', f, &
              ' ([', trim(face%bc%name), ']) is declared chimera, but BC-chimera = false: ', nbad, &
              ' of its cells match no cell of another block and would be written 100, a code no solver reads'
            call say_first_cell(face, mfirst, nfirst)
            write(*,'(A)') '        set BC-chimera = true in [ATLAS-Parameters], or give the face another type'
            failed = .true.
          endif
        endif
        endassociate
      enddo
    enddo
    if (failed) stop 1

  contains

    subroutine say_first_cell(face, m, n)
      type(obj_face), intent(in) :: face
      integer,        intent(in) :: m, n
      if (mesh_cfg%meshType > 0) then
        write(*,'(A,I0,A,I0,A,3(ES12.5,A))') '        the first is cell (', m, ', ', n, ') of the face, at (', &
          face%center(m,n)%c(1), ', ', face%center(m,n)%c(2), ', ', face%center(m,n)%c(3), ')'
      else
        write(*,'(A,I0,A,I0,A,2(ES12.5,A))') '        the first is cell (', m, ', ', n, ') of the face, at (', &
          face%center(m,n)%c(1), ', ', face%center(m,n)%c(2), ')'
      endif
    end subroutine say_first_cell

  end subroutine check_face_coverage


  !> Copy face-level uniform BC properties to every cell center.
  subroutine broadcast_uniform_bc(face)
    use bc_block_mod, only: obj_face
    implicit none
    type(obj_face), intent(inout) :: face
    integer :: m, n

    ! the cell is spelled out: an associate opened inside a parallel region on a type with
    ! allocatable components crashes under ifx (see compute_face_centers)
    !$omp parallel private(m,n)
    !$omp do collapse(2)
    do n = 1, face%Nn
      do m = 1, face%Nm

        ! General
        face%center(m,n)%bc%name               = face%bc%name
        face%center(m,n)%bc%definition         = face%bc%definition

        ! Connection
        face%center(m,n)%bc%ci_n               = face%bc%ci_n
        face%center(m,n)%bc%gp_id              = face%bc%gp_id
        face%center(m,n)%bc%ci_properties      = face%bc%ci_properties
        face%center(m,n)%bc%adj_assigned       = .false.
        face%center(m,n)%bc%connection         = face%bc%connection
        face%center(m,n)%bc%ci_ks              = face%bc%ci_ks

        ! IG
        face%center(m,n)%bc%ig_id              = face%bc%ig_id
        if (face%bc%ig_n>0) then
          face%center(m,n)%bc%ig_n             = face%bc%ig_n
          allocate(face%center(m,n)%bc%ig_properties(1:face%bc%ig_n))
          face%center(m,n)%bc%ig_properties    = face%bc%ig_properties
          if (allocated(face%bc%ig_time)) then
            face%center(m,n)%bc%ig_time        = face%bc%ig_time
            ! every builder now allocates ig_time_file next to ig_time; the guard keeps the copy
            ! defined for any record built elsewhere
            if (allocated(face%bc%ig_time_file)) face%center(m,n)%bc%ig_time_file = face%bc%ig_time_file
          endif
          if (face%bc%ig_species%n>0) then
            face%center(m,n)%bc%ig_species%n     = face%bc%ig_species%n
            allocate(face%center(m,n)%bc%ig_species%massf(1:face%bc%ig_species%n))
            face%center(m,n)%bc%ig_species%massf = face%bc%ig_species%massf
          endif
        endif

        ! SP
        face%center(m,n)%bc%sp_id              = face%bc%sp_id
        if (face%bc%sp_n>0) then
          face%center(m,n)%bc%sp_n             = face%bc%sp_n
          allocate(face%center(m,n)%bc%sp_properties(1:face%bc%sp_n))
          face%center(m,n)%bc%sp_properties    = face%bc%sp_properties
          if (allocated(face%bc%sp_time)) then
            face%center(m,n)%bc%sp_time_file   = face%bc%sp_time_file
            face%center(m,n)%bc%sp_time        = face%bc%sp_time
          endif
        endif

        ! DP: one slot per dispersed phase; intrinsic assignment deep-copies every
        ! slot with its allocatable components (id, n, properties, distribution, ds)
        if (allocated(face%bc%dp)) then
          face%center(m,n)%bc%dp               = face%bc%dp
        endif

      enddo
    enddo
    !$omp end parallel

  end subroutine broadcast_uniform_bc

end module bc_builder_mod
