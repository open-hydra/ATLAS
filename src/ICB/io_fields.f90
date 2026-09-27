module io_fields_mod
  use Lib_ORION_data
  use IR_Precision

  implicit none

  character(len=18), parameter :: outpath = 'fromATLAStoSolver/'

contains


  ! read_tec_file has no caller in ATLAS (the readers go through ORION); it is kept.
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
    type(mesh_config_type) :: scfg
    integer          :: error
    integer          :: i, j, k, b

    IOfield%tec%format = 'ascii'
    error = tec_read_structured_multiblock( orion=IOfield, filename=trim(file) )

    ! Secondary mesh: classify locally, do not overwrite the global mesh_cfg
    call import_nodes(input=IOfield,output=varblocks,cfg=scfg)
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


  !> Read an old solution (VTK/Tecplot) into IC blocks for interpolation.
  !>
  !> The SOURCE mesh is classified locally (`scfg`): the global mesh_cfg keeps
  !> describing the TARGET mesh, from which write_vtk_tec picks the output
  !> layout. The velocity-component count of the file follows the source mesh
  !> type (pure-2D file -> u v ; otherwise u v w), exactly as write_vtk_tec
  !> and the solvers (Q2D: no w ; MOSE/ARES: always w) lay the bands out.
  !> The caller supplies the authoritative structural count via `n`:
  !>   IG -> number of species ; CD -> number of dispersed populations.
  !> Mandatory bands:   IG  [rho(1:n)] [u v (w)] [p]      RF  [p] [u v (w)] [h]
  !> Everything after them (soot, passive scalars, turbulence, T, gamma, R,
  !> mil, kl, mit, ...) is scanned BY NAME: the turbulence bands are adopted
  !> into ATLAS's own slots (see detect_turbulence), the rest is ignored.
  subroutine read_vtk_tec (phase_type,filename,blk,n,src_cfg)
    use Lib_VTK
    use Lib_Tecplot
    use Lib_ORION_data
    use global_mod, only: llen
    use ic_block_mod
    use grid_mod,   only: mesh_config_type
    use read_mesh_mod, only: has_ext_series
    implicit none
    character(len=2), intent(in)     :: phase_type
    integer, intent(in), optional    :: n
    character(len=llen), intent(in)  :: filename
    type(IC_block), allocatable, intent(inout) :: blk(:)
    type(mesh_config_type), intent(out), optional :: src_cfg
    ! Local
    type(Orion_Data) :: IOfield
    type(mesh_config_type) :: scfg
    integer:: error, b, s, m
    integer :: n_species, nnn, nvel, nvars, nmand, ncoord
    integer :: nrans_src, slot_band(7)

    ! The extension (suffix, as in read_mesh) picks the reader; a .szplt needs a TecIO build:
    ! without the guard ORION's own stop returned 0 and no IC was written.
    error = 1
    if (has_ext_series(trim(filename),'.tec')) then
      IOfield%tec%format = 'ascii'
      error = tec_read_structured_multiblock(orion=IOfield,filename=trim(filename))
    elseif (has_ext_series(trim(filename),'.szplt')) then
#if defined(TECIO)
      IOfield%tec%format = 'binary'
      error = tec_read_structured_multiblock(orion=IOfield,filename=trim(filename))
#else
      write(*,*) "[ERROR] old-solution '"//trim(filename)//"' is a binary Tecplot file, but this ATLAS build"// &
        " was configured without TecIO (USE_TECIO=false)"
      stop 1
#endif
    else
      write(*,*) "[ERROR] old-solution '"//trim(filename)//"': unknown extension (expected .tec or .szplt,"// &
        " optionally numbered: .tec.NNN / .szplt.NNN)"
      stop 1
    endif

    if (error/=0) then
      write(*,*) "[ERROR] reading "//trim(filename)
      stop 1
    endif

    allocate(blk(size(IOfield%block)))
    ! Classify the SOURCE mesh locally: the global mesh_cfg must keep describing
    ! the TARGET mesh (write_vtk_tec picks the output layout from it).
    call import_nodes(input=IOfield,output=blk,cfg=scfg)
    if (present(src_cfg)) src_cfg = scfg

    ! Layout of the source file: coordinates as stored in it, velocity
    ! components from the source mesh type (a pure-2D file carries no w).
    ncoord = size(IOfield%block(1)%mesh, 1)
    if (scfg%meshType == -2) then
      nvel = 2
    else
      nvel = 3
    endif
    nvars = 0
    if (allocated(IOfield%block(1)%vars)) nvars = size(IOfield%block(1)%vars, 1)

    if (phase_type=='IG') then
      ! Species count: the caller's (old-species), else inferred from the width
      if (present(n)) then
        n_species = n
      else
        n_species = nvars - nvel - 1 - blk(1)%nrans
      endif
      ! a pure-2D source may also carry the third velocity band (rho_i, u, v, w, p, the layout read
      ! for every source before the 2D layout was added): taken when the band after v is named w
      if (nvel == 2 .and. present(n)) then
        if (band_is_named(IOfield, ncoord, nvars, n_species + 3, 'w')) nvel = 3
      endif
      nmand = n_species + nvel + 1
      if (nvars < nmand) then
        write(*,*) "[ERROR] read_vtk_tec: '"//trim(filename)//"' provides ", nvars, &
          " field variables but ", nmand, " are required (", n_species, " species + ", nvel, &
          " velocity components + p)."
        write(*,*) "        Check that the old-species count matches the solution file."
        stop 1
      endif
      call check_mandatory_name(IOfield, ncoord, nvars, nmand, 'p', filename)
      call detect_turbulence(IOfield, ncoord, nmand, nvars, filename, nrans_src, slot_band)
      do b = 1, size(blk)
        blk(b)%nrans = nrans_src
        call blk(b)%compute_centers([0,0,0])
        call blk(b)%allocate(blk(b)%nrans,n_species,blk(b)%dim(1),blk(b)%dim(2),blk(b)%dim(3))
        if (size(IOfield%block(b)%vars)>0) then
          do s = 1, n_species
            blk(b)%ig%density(s,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(s,:,:,:)
          enddo
          blk(b)%ig%velocity = 0.0_R8P   ! w of a pure-2D source is zero
          blk(b)%ig%velocity(1:nvel,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = &
            IOfield%block(b)%vars(n_species+1:n_species+nvel,:,:,:)
          blk(b)%ig%pressure(1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(n_species+nvel+1,:,:,:)
          blk(b)%ig%turbprop = 0.0_R8P   ! slots the source does not provide (e.g. R13, R23 of a 2D code)
          do s = 1, blk(b)%nrans
            if (slot_band(s) > 0) blk(b)%ig%turbprop(s,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = &
              IOfield%block(b)%vars(slot_band(s),:,:,:)
          enddo
        endif
      end do
    
    elseif (phase_type=='SP') then
      do b = 1, size(blk)
        call blk(b)%compute_centers([0,0,0])
        call blk(b)%allocate(1,1,blk(b)%dim(1),blk(b)%dim(2),blk(b)%dim(3))
        ! the solid temperature goes where build_SP_field reads it (sp%temperature: it was stored in the
        ! gas temperature and the SP interpolation read an unallocated array)
        if (.not. allocated(blk(b)%sp%temperature)) allocate(blk(b)%sp%temperature(blk(b)%dim(1),blk(b)%dim(2),blk(b)%dim(3)))
        if (size(IOfield%block(b)%vars)>0) then
          blk(b)%sp%temperature(1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(1,:,:,:)
          blk(b)%sp%mID(1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(2,:,:,:)
        endif
      end do

    elseif (phase_type=='CD') then
      ! Each population has 6+blk(1)%neuler variables. Use the caller-supplied
      ! population count when available rather than dividing the raw variable
      ! count, which breaks if the file carries extra trailing variables.
      if (present(n)) then
        nnn = n
      else
        nnn = size(IOfield%block(1)%vars, 1) / (6 + blk(1)%neuler)
      endif
      if (size(IOfield%block(1)%vars, 1) < nnn*(6 + blk(1)%neuler)) then
        write(*,*) "[ERROR] read_vtk_tec: '"//trim(filename)//"' provides ", &
          size(IOfield%block(1)%vars, 1), " field variables but ", nnn*(6 + blk(1)%neuler), &
          " are required (", nnn, " populations x ", 6 + blk(1)%neuler, ")."
        write(*,*) "        Check that the dispersed-population count matches the solution file."
        stop 1
      endif
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
      ! Layout: [p] [velocity(nvel)] [h] <tail>, nvel from the SOURCE mesh type
      ! (ARES: p u v w h [turbulence] T rho sound ...).
      if (scfg%meshType == 10) nvel = 1   ! one velocity component (meshType 10: no reader sets it today)
      nmand = nvel + 2
      if (nvars < nmand) then
        write(*,*) "[ERROR] read_vtk_tec: '"//trim(filename)//"' provides ", nvars, &
          " field variables but ", nmand, " are required (p + ", nvel, " velocity + h)."
        stop 1
      endif
      call check_mandatory_name(IOfield, ncoord, nvars, nmand, 'h', filename)
      call detect_turbulence(IOfield, ncoord, nmand, nvars, filename, nrans_src, slot_band)
      do b = 1, size(blk)
        blk(b)%nrans = nrans_src
        call blk(b)%compute_centers([0,0,0])
        if (.not.allocated(blk(b)%rf%pressure)) then
          allocate(blk(b)%rf%velocity(1:3,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
          allocate(blk(b)%rf%pressure(1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
          allocate(blk(b)%rf%enthalpy(1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
          if (blk(b)%nrans>0) allocate(blk(b)%rf%turbprop(1:blk(b)%nrans,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
        endif
        if (size(IOfield%block(b)%vars) > 0) then
          blk(b)%rf%pressure   (1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(1,:,:,:)
          blk(b)%rf%velocity = 0.0_R8P   ! w of a pure-2D source is zero
          do s = 1, nvel
            blk(b)%rf%velocity(s,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(s+1,:,:,:)
          enddo
          blk(b)%rf%enthalpy   (1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = IOfield%block(b)%vars(nvel+2,:,:,:)
          if (blk(b)%nrans > 0) then
            blk(b)%rf%turbprop = 0.0_R8P
            do s = 1, blk(b)%nrans
              if (slot_band(s) > 0) blk(b)%rf%turbprop(s,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)) = &
                IOfield%block(b)%vars(slot_band(s),:,:,:)
            enddo
          endif
        endif
      enddo
    endif

  end subroutine read_vtk_tec


  !> When the file carries one trustworthy name per band, the last mandatory
  !> band (p for IG, h for RF) must be named so: a different name means the
  !> declared species count (old-species) does not match the file and the
  !> velocity/pressure bands would be shifted silently.
  !> .true. when the file carries one trustworthy name per band and band `band` is named `expected`
  !> (case-insensitive)
  logical function band_is_named(IOfield, ncoord, nvars, band, expected)
    use Lib_ORION_data
    implicit none
    type(Orion_Data), intent(in)  :: IOfield
    integer,          intent(in)  :: ncoord, nvars, band
    character(len=*), intent(in)  :: expected
    character(len=64) :: s
    integer :: i, ic
    band_is_named = .false.
    if (.not.allocated(IOfield%varnames)) return
    if (size(IOfield%varnames) /= ncoord + nvars .or. band < 1 .or. band > nvars) return
    s = adjustl(IOfield%varnames(ncoord + band))
    do i = 1, len_trim(s)
      ic = iachar(s(i:i))
      if (ic >= iachar('A') .and. ic <= iachar('Z')) s(i:i) = achar(ic + 32)
    enddo
    band_is_named = trim(s) == expected
  end function band_is_named


  subroutine check_mandatory_name(IOfield, ncoord, nvars, nmand, expected, filename)
    use Lib_ORION_data
    implicit none
    type(Orion_Data), intent(in)  :: IOfield
    integer,          intent(in)  :: ncoord, nvars, nmand
    character(len=*), intent(in)  :: expected, filename
    character(len=64) :: s
    integer :: i, ic
    if (.not.allocated(IOfield%varnames)) return
    if (size(IOfield%varnames) /= ncoord + nvars) return
    s = adjustl(IOfield%varnames(ncoord + nmand))
    do i = 1, len_trim(s)
      ic = iachar(s(i:i))
      if (ic >= iachar('A') .and. ic <= iachar('Z')) s(i:i) = achar(ic + 32)
    enddo
    ! the mandatory band may carry an alias (a solver writes pressure or enthalpy in full)
    if (trim(s) /= expected .and. .not. (expected == 'p' .and. (trim(s) == 'pressure' .or. trim(s) == 'press')) &
        .and. .not. (expected == 'h' .and. (trim(s) == 'enthalpy' .or. trim(s) == 'h0'))) then
      write(*,'(A,I0,A)') "[ERROR] read_vtk_tec: band ", nmand, " of '"//trim(filename)//"' is named '"// &
        trim(IOfield%varnames(ncoord + nmand))//"' but the declared layout expects '"//expected//"' there"// &
        merge(" (or pressure)", " (or enthalpy)", expected == 'p')//":"
      write(*,'(A)') "        the species count of the old-species file does not match the file, or its band layout"
      write(*,'(A)') "        differs from rho_i, u, v, [w,] "//expected//": the bands would be shifted."
      stop 1
    endif
  end subroutine check_mandatory_name


  !> Locate the turbulence bands among the tail bands nmand+1..nvars of a
  !> solution file BY NAME and map them onto ATLAS's own slots:
  !>   one SA-like name                -> nrans = 1 : [nu_tilde]
  !>   one k-like + one omega-like     -> nrans = 2 : [k, omega]
  !>   Reynolds stresses + one omega   -> nrans = 7 : [R11 R22 R33 R12 R13 R23 omega]
  !>                                      (components the code did not write,
  !>                                       e.g. R13/R23 of a 2D solver, stay 0)
  !> Any other tail band (soot, passive scalars, T, gamma, R, mil, kl, mit, ...)
  !> is ignored. Names are trusted only when the file carries exactly one name
  !> per coordinate and per band; otherwise (no names, unparsable names, .szplt)
  !> nothing is adopted and the tail is ignored with a notice.
  subroutine detect_turbulence(IOfield, ncoord, nmand, nvars, filename, nrans_src, slot_band)
    use Lib_ORION_data
    implicit none
    type(Orion_Data), intent(in)  :: IOfield
    integer,          intent(in)  :: ncoord, nmand, nvars
    character(len=*), intent(in)  :: filename
    integer,          intent(out) :: nrans_src, slot_band(7)
    integer :: s, kind_, nsa, nk, nom, nst, band_sa, band_k, band_om, stress_band(6)
    logical :: names_ok, dup

    nrans_src = 0
    slot_band = 0
    if (nvars <= nmand) return

    names_ok = allocated(IOfield%varnames)
    if (names_ok) names_ok = (size(IOfield%varnames) == ncoord + nvars)
    if (.not.names_ok) then
      write(*,*) " - read_vtk_tec: ignoring ", nvars - nmand, " trailing band(s) of '"//trim(filename)// &
        "': variable names unavailable or inconsistent with the data, turbulence not adopted"
      return
    endif

    nsa = 0; nk = 0; nom = 0; nst = 0; dup = .false.
    band_sa = 0; band_k = 0; band_om = 0; stress_band = 0
    do s = nmand + 1, nvars
      kind_ = turb_kind(IOfield%varnames(ncoord + s))
      select case (kind_)
      case (1);  nsa = nsa + 1; band_sa = s
      case (2);  nk  = nk  + 1; band_k  = s
      case (3);  nom = nom + 1; band_om = s
      case (11:16)
        nst = nst + 1
        if (stress_band(kind_-10) /= 0) dup = .true.
        stress_band(kind_-10) = s
      end select
    enddo

    if (nsa + nk + nom + nst == 0) then
      write(*,*) " - read_vtk_tec: ignoring ", nvars - nmand, " trailing band(s) of '"//trim(filename)// &
        "' (no turbulence variable among them)"
      return
    endif

    if (nst > 0 .and. nsa == 0 .and. nk == 0 .and. nom == 1 .and. .not.dup) then
      nrans_src = 7
      slot_band(1:6) = stress_band
      slot_band(7) = band_om
    elseif (nst == 0 .and. nsa == 0 .and. nk == 1 .and. nom == 1) then
      nrans_src = 2
      slot_band(1) = band_k
      slot_band(2) = band_om
    elseif (nst == 0 .and. nsa == 1 .and. nk == 0 .and. nom == 0) then
      nrans_src = 1
      slot_band(1) = band_sa
    else
      write(*,*) "[WARNING] read_vtk_tec: the turbulence variables of '"//trim(filename)// &
        "' do not form a supported set (SA / k-omega / Reynolds stresses): not adopted"
      write(*,*) "          names found after the mandatory bands:"
      do s = nmand + 1, nvars
        write(*,*) "            '"//trim(IOfield%varnames(ncoord + s))//"'"
      enddo
      return
    endif
    write(*,*) " - read_vtk_tec: adopting ", nrans_src, " turbulence band(s) of '"//trim(filename)//"' by name"
    if (nvars - nmand - count(slot_band > 0) > 0) &
      write(*,*) " - read_vtk_tec: ignoring ", nvars - nmand - count(slot_band > 0), &
        " other trailing band(s) (auxiliary variables)"
  end subroutine detect_turbulence


  !> Classify a solution-variable name: 0 = not a turbulence quantity,
  !> 1 = Spalart-Allmaras working variable (mi_t, mi_tilde, nut, mut, mu_t, nu_t,
  !> ...tilde...), 2 = turbulent kinetic energy (kappa, tke, k), 3 = omega
  !> (epsilon is a different quantity and is deliberately NOT mapped), 11..16 = Reynolds stresses R11 R22 R33 R12
  !> R13 R23 in MOSE/ARES/ATLAS spelling (ru'u' rv'v' rw'w' ru'v' ru'w' rv'w')
  !> or Q2D spelling (ruu rvv rww ruv ruw rvw). Case-insensitive.
  integer function turb_kind(rawname)
    character(len=*), intent(in) :: rawname
    character(len=len(rawname))  :: s, t
    integer :: i, ic, j

    s = ''
    do i = 1, len_trim(rawname)
      ic = iachar(rawname(i:i))
      if (ic >= iachar('A') .and. ic <= iachar('Z')) ic = ic + 32
      s(i:i) = achar(ic)
    enddo
    s = adjustl(s)
    t = ''   ! s without primes: ru'u' -> ruu
    j = 0
    do i = 1, len_trim(s)
      if (s(i:i) /= "'") then
        j = j + 1
        t(j:j) = s(i:i)
      endif
    enddo

    turb_kind = 0
    if (index(s, "mi_t") > 0 .or. index(s, "tilde") > 0 .or. &
        s == "nut" .or. s == "mut" .or. s == "mu_t" .or. s == "nu_t") then
      turb_kind = 1
    elseif (s == "kappa" .or. s == "tke" .or. s == "k") then
      turb_kind = 2
    elseif (s == "omega") then
      turb_kind = 3   ! epsilon/eps are NOT omega: a k-epsilon file is refused by detect_turbulence (k without omega)
    elseif (t == "ruu") then
      turb_kind = 11
    elseif (t == "rvv") then
      turb_kind = 12
    elseif (t == "rww") then
      turb_kind = 13
    elseif (t == "ruv") then
      turb_kind = 14
    elseif (t == "ruw") then
      turb_kind = 15
    elseif (t == "rvw") then
      turb_kind = 16
    endif
  end function turb_kind


  !> True if a solution variable name denotes a turbulence quantity.
  logical function is_turbulence_var(rawname)
    character(len=*), intent(in) :: rawname
    is_turbulence_var = turb_kind(rawname) /= 0
  end function is_turbulence_var


  !> the IC-format asks for a binary Tecplot file (.szplt) but the build has no
  !> TecIO: refused at configuration time (the writer below keeps the same guard).
  !> An unknown format never reaches here (registry row of IC-format, input_keys L3).
  subroutine check_ic_format_build(ICformat)
    use input_keys_mod, only: input_keys_format_ok
    implicit none
    character(len=*), intent(in) :: ICformat
    logical :: ok, binary_tec
    ok = input_keys_format_ok(ICformat, binary_tec)
    if (.not. ok) then
      write(*,'(A)') '[ERROR] key IC-format of section [ATLAS-Parameters]: value '//trim(ICformat)// &
                     ' is not a format (a family tec, tecplot or vtk with an optional mode binary, ascii or raw,'// &
                     ' joined by -, a blank or _)'
      stop 1
    endif
#if !defined(TECIO)
    if (binary_tec) then
      write(*,'(A)') '[ERROR] key IC-format of section [ATLAS-Parameters]: value '//trim(ICformat)// &
                     ' asks for a binary Tecplot file (.szplt) but this build has no TecIO'// &
                     ' (configure with -DUSE_TECIO=true, or use tec / vtk-binary)'
      stop 1
    endif
#endif
  end subroutine check_ic_format_build

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
    integer                            :: nrans_ref, neuler_ref, nq

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
          if (trim(phase(p)%name) == trim(blk(b)%associated_phase(ap)%name)) then
            nb = nb + 1
            if (phase(p)%type=='IG') nsc = blk(b)%associated_phase(ap)%species%n
            !> 'DP', not 'CD': read_phase.f90:210 sets phase%type='DP' for a condensed-dispersed
            !  phase, and builder.f90:66,200 agree. Comparing against 'CD' here left `mat` empty,
            !  so the varname and data loops below emitted nothing and the CD IC file came out
            !  holding only x/y/z.
            if (phase(p)%type=='DP') mat = blk(b)%associated_phase(ap)%material
            if (nb > 1 .and. blk(b)%nrans /= nrans_ref) then
              write(*,*) '[ERROR] write_vtk_tec: blocks of phase '//trim(phase(p)%name)// &
                ' carry different turbulence models (nrans ', nrans_ref, ' vs ', blk(b)%nrans, &
                '): the solution file would be inconsistent'
              stop 1
            endif
            nrans_ref  = blk(b)%nrans
            neuler_ref = blk(b)%neuler
          endif
        enddo
      enddo
      ! A phase listed by its phase file (ATLAS.sh lists every *phase.txt) and named in the phase key of no
      ! [ICB-Block] has nothing to write: nsc / mat below would be read undefined (CD/DP: SIGSEGV on gnu
      ! RELEASE) and the file would be written from orion%block(1) of an empty block array.
      if (nb == 0) then
        name_ = 'phase.txt'
        if (len_trim(phase(p)%name) > 0) name_ = trim(phase(p)%name)//'-phase.txt'
        write(*,'(A)') '[WARNING] key phase of section [ICB-Block*]: the phase of '//trim(name_)// &
          ' is built by no block: no initial field is written for it (name it in the phase key of a block to build it)'
        write(*,*)
        cycle
      endif
      if (nrans_ref /= 0 .and. nrans_ref /= 1 .and. nrans_ref /= 2 .and. nrans_ref /= 7) then
        write(*,*) '[ERROR] write_vtk_tec: unsupported turbulence band count nrans =', nrans_ref, &
          ' (1 = SA, 2 = k-omega, 7 = Reynolds stresses)'
        stop 1
      endif
      if (allocated(orion%block)) deallocate(orion%block)
      allocate(orion%block(1:nb))

      select case(phase(p)%type)
        case('IG')
          do s = 1, nsc
            varnames = trim(varnames)//' rho'//trim(str(.true.,s))
          enddo
          ! No mesh reader of ATLAS sets meshType = 10 (values: 3, 2, -2, 1), so this branch never runs; it is kept.
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
          elseif (nrans_ref==7 .and. mesh_cfg%meshType == -2) then
            ! pure-2D target: the Reynolds-stress state of Q2D has 5 bands; R13 and R23 are not part of it
            varnames = trim(varnames)//' ruu rvv rww ruv omega'
            write(*,*) ' - write_vtk_tec: 2D target, Reynolds stresses written in the Q2D 5-band layout (R13, R23 dropped)'
          elseif (nrans_ref==7) then
            varnames = trim(varnames)//' ru''u'' rv''v'' rw''w'' ru''v'' ru''w'' rv''w'' omega'
          endif
        case('DP')   ! see note at the `mat =` assignment above: the type string is 'DP'
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
          if (trim(phase(p)%name) == trim(blk(b)%associated_phase(ap)%name)) thereis = .true.
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
          ! No mesh reader of ATLAS sets meshType = 10 (values: 3, 2, -2, 1), so this branch never runs; it is kept.
          if (mesh_cfg%meshType == 10) then
            allocate(orion%block(cnt)%vars(1:nsc+2,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
            orion%block(cnt)%vars(1:nsc,:,:,:) = blk(b)%ig%density
            orion%block(cnt)%vars(nsc+1,:,:,:) = blk(b)%ig%velocity(1,:,:,:)
            orion%block(cnt)%vars(nsc+2,:,:,:) = blk(b)%ig%pressure
          elseif (mesh_cfg%meshType == -2) then
            nq = blk(b)%nrans
            if (nq == 7) nq = 5   ! Q2D RSM layout: ruu rvv rww ruv omega
            allocate(orion%block(cnt)%vars(1:nsc+3+nq,1:blk(b)%dim(1),1:blk(b)%dim(2),1:blk(b)%dim(3)))
            orion%block(cnt)%vars(1:nsc,:,:,:) = blk(b)%ig%density
            orion%block(cnt)%vars(nsc+1:nsc+2,:,:,:) = blk(b)%ig%velocity(1:2,:,:,:)
            orion%block(cnt)%vars(nsc+3,:,:,:) = blk(b)%ig%pressure
            if (blk(b)%nrans == 7) then
              orion%block(cnt)%vars(nsc+4:nsc+7,:,:,:) = blk(b)%ig%turbprop(1:4,:,:,:)
              orion%block(cnt)%vars(nsc+8,:,:,:)       = blk(b)%ig%turbprop(7,:,:,:)
            elseif (blk(b)%nrans>0) then
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

        case('DP')   ! see note at the `mat =` assignment above: the type string is 'DP'
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
          ! No mesh reader of ATLAS sets meshType = 10 (values: 3, 2, -2, 1), so this branch never runs; it is kept.
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
#if !defined(TECIO)
          write(*,'(A)') '[ERROR] IC-format = '//trim(ICformat)//': a binary Tecplot file (.szplt) needs a TecIO build'
          stop 1
#endif
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
