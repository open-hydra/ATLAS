submodule (bc_mod) ig_inflow_outflow_mod
  use bcb_config_mod,         only: bcb_ig_boundary_config_t, load_bcb_ig_boundary_config, bcb_unwrapped_config_t, load_bcb_unwrapped_config
  use phase_mod,              only: phase_t, species_t, define_composition, T02T, p02p, nozzle_thresholds
  use unwrapped_to_3D_mod,    only: map_unwrapped_to_3D
  use input_keys_mod,         only: input_keys_strict
  use composition_check_mod,  only: check_composition
  implicit none

  ! Registry of the unwrapped->3D mappings already written in this run. One
  ! mapping writes the requested face of EVERY block into its time-file, so
  ! the file content depends only on (line-file, face, strip-j-face, center):
  ! an exact repeat (same section on another block, or on another MG level)
  ! is skipped, while the same time-file requested with a different key is
  ! refused, because one file cannot hold two mappings.
  type :: unwrapped_done_t
    type(bcb_unwrapped_config_t) :: cfg
    character(len=256)           :: outfile = ''
  end type unwrapped_done_t
  type(unwrapped_done_t), allocatable :: unwrapped_done(:)
  ! L4 (per-type honoured keys) under strict-keys = false: one WARNING per (bc, key), the
  ! builder runs once per face cell
  character(len=128), allocatable :: warned_keys(:)

contains

  module procedure build_inflow_outflow_ig
    use grid_mod, only: mesh_cfg, MESH_PURE_2D
    implicit none
    type(bcb_ig_boundary_config_t) :: cfg
    real(R8) :: p0, T0, h0, mach, T, g, un, alpha, beta, p, rel_fac, Ae_At, rt, psup, psub
    real(R8) :: a1_a3
    real(R8) :: mit, kappa, omega, rhoRij
    integer  :: dim, start, nrans, tlo, thi
    logical  :: no_angles_rec
    real(R8) :: ceah0, ceaT0, ceap0
    character(len=32) :: p0_time_file, p_time_file, time_file
    logical :: periodic

    self % ig_species = phase % species
    if (.not.allocated(self % ig_species % massf)) allocate(self % ig_species % massf(1:self % ig_species % n))
    self % ig_species % massf = 1d-20

    call load_bcb_ig_boundary_config(sourceini, section, cfg)

    mach         = cfg%mach
    p0           = cfg%p0
    T0           = cfg%T0
    h0           = cfg%h0
    T            = cfg%T
    g            = cfg%g
    un           = cfg%velocity%un
    alpha        = cfg%velocity%alpha
    beta         = cfg%velocity%beta
    p            = cfg%p
    rel_fac      = cfg%rel_fac
    Ae_At        = cfg%Ae_At
    psub         = cfg%psub
    psup         = cfg%psup
    a1_a3        = cfg%a1_a3
    p0_time_file = cfg%p0_time_file
    p_time_file  = cfg%p_time_file
    time_file    = cfg%time_file
    periodic     = cfg%periodic
    mit          = cfg%turbulence%mit
    kappa        = cfg%turbulence%kappa
    omega        = cfg%turbulence%omega
    rhoRij       = cfg%turbulence%rhoRij
    nrans        = cfg%turbulence%nrans
    ! A Reynolds-stress inlet (nrans = 7) on a pure-2D (x,y) mesh is read by Q2D only, whose Reynolds-stress
    ! inlet reads 5 bands (rho*R11, R22, R33, R12, omega; R13 = R23 = 0 in the plane): the 7-band 3-D
    ! layout would leave omega := R13 and two tokens unread. Same meshType gate as BC 408/410/421.
    if (nrans == 7 .and. mesh_cfg%meshType == MESH_PURE_2D) nrans = 5

    ! Assign species mass fractions; pre-init so intent(inout) args are never sNaN
    CEAT0 = 0.0_R8; CEAp0 = 0.0_R8; CEAh0 = 0.0_R8
    call define_composition(sourceini, self%ig_species, CEAT0, CEAp0, CEAh0)
    ! L6 (composition sum): y<species> keys must sum to 1 (renormalised within 1e-3, refused beyond)
    call check_composition(sourceini, section, self%ig_species, 'section ['//trim(self%name)//']', &
                           required = (self%definition == 'inlet' .and. trim(time_file) == 'none'))

    ! L6: with g and without Ae_At / a1-a3, the nozzle trio is all or nothing, and an
    ! explicit p0 next to g selects neither the mass-flux inlet (403: g, T0; the p0 would be lost)
    ! nor the nozzle (420: g, psub, psup): both were dispatched silently as 401/403.
    if (g /= 0.0_R8 .and. Ae_At == 0.0_R8 .and. a1_a3 == 0.0_R8) then
      if ((psub /= 0.0_R8) .neqv. (psup /= 0.0_R8)) then
        write(*,'(A)') '[ERROR] '//trim(self%name)//' (nozzle inlet, BC 420): g, psub and psup must be given together'// &
                       ' (missing '//trim(merge('psup', 'psub', psub /= 0.0_R8))//')'
        stop 1
      endif
      if (psub == 0.0_R8 .and. p0 /= 0.0_R8) then
        write(*,'(A)') '[ERROR] '//trim(self%name)//' (inlet): g together with an explicit p0 selects neither the mass-flux'// &
                       ' inlet (403: g, T0) nor the nozzle (420: g, psub, psup): remove p0, or give psub and psup'
        stop 1
      endif
    endif

    ! The CEA stagnation pressure is only a default: an explicit p0 always wins,
    ! nozzle inlets included. Mass-flux inlets (403/404: g without the nozzle
    ! thresholds) take no p0, otherwise they would be dispatched as 401.
    if (p0==0_R8 .and. (g==0_R8 .or. Ae_At/=0_R8 .or. (psub/=0_R8 .and. psup/=0_R8))) p0 = CEAp0
    if (T0==0_R8 .and. T==0_R8) T0 = CEAT0

    if (h0/=0_R8 .and. self%ig_species%n==1) then
      ! T0 is looked up in the species enthalpy table: without thermo.dat it is unallocated and the
      ! old message blamed the enthalpy range
      if (.not. allocated(self%ig_species%h)) then
        write(*,'(A)') '[ERROR] '//trim(self%name)//' ('//trim(self%definition)//'): h0 requires the species thermo table'// &
                       ' (thermo.dat not found): give T0 instead'
        stop 1
      endif
      T0 = h02T0(h0, self%ig_species%h, lbound(self%ig_species%h, dim=2))
    else
      h0 = CEAh0
    endif

    ! Dispatch: the BC code follows from which keys are set. a1-a3 selects the
    ! Borda injector (421); Ae_At or the g+psub+psup trio the nozzle (420).
    no_angles_rec = .false.
    if ( a1_a3 /= 0_R8 ) then
      call borda
    elseif ( Ae_At /= 0_R8 .or. (g /= 0_R8 .and. psup /= 0_R8 .and. psub /= 0_R8) ) then
      call nozzle
    else
      call standard
    endif
  

    if (self % definition=='inlet' .and. self % ig_id /= 410) then

      if (no_angles_rec) then
        ! Angle-free record (BC 421): the solver injects along the face normal
        ! by construction, so rel_fac follows the physical properties directly.
        self%ig_properties(dim) = rel_fac
        self % ig_properties(dim+1:dim+self % ig_species % n) = self % ig_species % massf
        start = dim + self%ig_species%n
      else
        ! Inflow direction
        self%ig_properties(dim) = alpha
        self%ig_properties(dim+1) = beta

        ! Relaxation factor
        self%ig_properties(dim+2) = rel_fac

        ! Mass fractions
        self % ig_properties(dim+2+1:dim+2+self % ig_species % n) = self % ig_species % massf

        start = dim + 2 + self%ig_species%n
      endif

      ! Turbulence. : a zero band written under a turbulence model is reported (it was written
      ! in silence); ICB refuses the same initial field under an omega model and the
      ! same refusal on the inlet record is deliberately not applied here (WARNING only)
      if     (nrans==1) then
        self%ig_properties(start+1) = mit
        if (mit <= 0._R8) call warn_turbulence_zero('mit', 'Spalart-Allmaras (nrans = 1)', 'mit')
      elseif (nrans==2) then
        self%ig_properties(start+1) = kappa
        self%ig_properties(start+2) = omega
        if (kappa <= 0._R8 .or. omega <= 0._R8) &
          call warn_turbulence_zero('kappa or omega', 'k-omega (nrans = 2)', 'kappa and omega')
      elseif (nrans==7 .or. nrans==5) then
        ! 7 bands (3-D solvers): R11 R22 R33 R12 R13 R23 omega; 5 bands (Q2D, pure-2D mesh): R11 R22 R33 R12 omega
        self%ig_properties(start+1:start+3) = rhoRij
        self%ig_properties(start+4:start+nrans-1) = 1d-8
        self%ig_properties(start+nrans) = omega
        if (rhoRij <= 0._R8 .or. omega <= 0._R8) &
          call warn_turbulence_zero('rhoRij or omega', 'Reynolds-stress (nrans = 7)', 'rhoRij and omega')
      endif

    elseif (self % definition=='outlet') then

      ! Relaxation factor
      self%ig_properties(2) = rel_fac

    endif

  contains

    ! A deck T0 / T outside the loaded thermo table on a record that carries it as given
    subroutine warn_table_range(what, val)
      implicit none
      character(len=*), intent(in) :: what
      real(R8), intent(in)         :: val
      integer :: lo, hi
      if (.not. allocated(self%ig_species%cp)) return
      lo = lbound(self%ig_species%cp, dim=2) + 1; hi = ubound(self%ig_species%cp, dim=2) - 1
      if (val < real(lo, R8) .or. val > real(hi, R8)) &
        write(*,'(A,I0,A,ES12.5,A,I0,A,I0,A)') '[WARNING] '//trim(self%name)//' ('//trim(self%definition)//', BC ', &
          self%ig_id, '): '//what//' = ', val, ' K lies outside the temperature range of thermo.dat [', lo, ', ', hi, &
          '] K: the solvers clamp their cp/h lookups there'
    end subroutine warn_table_range

    subroutine standard()
      implicit none
      logical :: expanded   ! the record's T comes from an expansion checked above

      expanded = .false.
      ! L5: a negative stagnation or static state is never a valid record (a 401 with
      ! p0 = -3e6 used to be written with exit status 0)
      if (T0 < 0.0_R8 .or. p0 < 0.0_R8 .or. T < 0.0_R8 .or. p < 0.0_R8) then
        write(*,'(A)') '[ERROR] '//trim(self%name)//' ('//trim(self%definition)//'): T0, p0, T and p must be positive'
        stop 1
      endif

      ! Inflow | p0, T0 (mach = 0: otherwise the documented supersonic inlet 405 given by mach, p0 and
      ! T0 was shadowed by this branch and written as a 401 without the Mach number)
      if     (p0/=0_R8     .and. T0/=0_R8 .and. p==0._R8 .and. mach==0._R8 .and. p0_time_file=='none' .and. self%definition=='inlet') then
        self % ig_id = 401
        dim = 3
        call setup_bc_inlet(ip0=2)
        self % ig_properties(1:2) = [T0, p0]

      ! Inflow | p0(t), T0
      elseif (p0_time_file/='none' .and. self%definition=='inlet') then
        if (T0==0_R8) then
          write(*,*) '[ERROR] T0 must be specified when using p0-time-file'
          stop 1
        endif
        self % ig_id = 402
        self % time_varying = .true.
        dim = 3
        call setup_bc_inlet(ip0=2)
        self % ig_properties(1) = T0

      ! Subsonic inflow | g, T0
      elseif ( g/=0_R8     .and. T0/=0_R8 .and. self%definition=='inlet') then
        self % ig_id = 403
        dim = 3
        call setup_bc_inlet(ip0=0)
        self % ig_properties(1:2) = [T0, g]

      ! Subsonic inflow | g, T
      elseif ( g/=0_R8     .and.  T/=0_R8 .and. self%definition=='inlet') then
        self % ig_id = 404
        dim = 3
        call setup_bc_inlet(ip0=0)
        self % ig_properties(1:2) = [T, g]

      ! Supersonic inflow | M, p0, T0
      elseif ( mach/=0._R8 .and. p0/=0_R8 .and. T0/=0._R8 .and. self%definition=='inlet') then
        self % ig_id = 405
        call check_honoured_keys(405)   ! L4 before the thermo guard below (p and T given next to p0 and T0)
        dim = 4
        call setup_bc_inlet(ip0=0)
        ! The static state comes from the species cp/h tables (T02T, p02p): without thermo.dat
        ! read_idealgas_properties leaves them unallocated (same guard as Ae_At)
        if (.not. allocated(self%ig_species%cp) .or. .not. allocated(self%ig_species%h)) then
          write(*,'(A)') '[ERROR] '//trim(self%name)//' (supersonic inlet, BC 405): mach with p0 and T0 requires the'// &
                         ' species thermo table (thermo.dat not found): give p and T instead'
          stop 1
        endif
        ! T02T and p02p interpolate the tables between the static state and T0 (the solvers'
        ! table lookup reads ubound-1 at most): a T0 outside [lbound+1, ubound-1] is refused as the 420
        ! kernel refuses its T0; the static T of the expansion outside it is reported (the
        ! rule shared with the ICB expansions), never clamped in silence (T = -336 K was written)
        tlo = lbound(self%ig_species%cp, dim=2) + 1; thi = ubound(self%ig_species%cp, dim=2) - 1
        if (T0 < real(tlo, R8) .or. T0 > real(thi, R8)) then
          write(*,'(A,ES12.5,A,I0,A,I0,A)') '[ERROR] '//trim(self%name)//' (supersonic inlet, BC 405): T0 = ', T0, &
            ' K lies outside the temperature range of thermo.dat [', tlo, ', ', thi, '] K'
          stop 1
        endif
        T = T02T(T0,mach,self%ig_species)
        if (T < real(tlo, R8) .or. T > real(thi, R8)) then
          write(*,'(A,ES12.5,A,ES12.5,A,I0,A,I0,A)') '[WARNING] '//trim(self%name)//' (supersonic inlet, BC 405): the static T = ', &
            T, ' K of the expansion from T0 at mach = ', mach, ' lies outside the temperature range of thermo.dat [', &
            tlo, ', ', thi, '] K: the solvers clamp their cp/h lookups there (extend the table, or give p and T)'
        endif
        expanded = .true.
        p = p02p(p0,T0,T,self%ig_species)   ! exact isentrope on the tables (variable-cp form of the p0, T0 inlet)
        self % ig_properties(1:3) = [mach, T, p]

      ! Supersonic inflow | M, p, T
      elseif ( mach/=0._R8 .and.  p/=0_R8 .and. T/=0._R8 .and. self%definition=='inlet') then
        self % ig_id = 405
        dim = 4
        call setup_bc_inlet(ip0=0)
        self % ig_properties(1:3) = [mach, T, p]

      ! Pressure outflow | p
      elseif (self%definition=='outlet') then
        self % ig_id = 406
        dim = 1
        call setup_bc_outlet(ip=1)
        self % ig_properties(1) = p
        call check_honoured_keys(406)
        return

      ! Inflow/outflow | p0, T0, p
      elseif (p0/=0_R8     .and. T0/=0_R8 .and. p/=0._R8 .and. self%definition=='inlet') then
        self % ig_id = 407
        dim = 4
        call setup_bc_inlet(ip0=2)
        self % ig_properties(1:3) = [T0, p0, p]

      ! Subsonic inflow | un, T
      elseif (un/=0._R8 .and. T/=0._R8 .and. self%definition=='inlet') then
        call refuse_on_2d_mesh(self, 408, 'normal-velocity inlet', 'use a 3D mesh or another inlet type')
        self % ig_id = 408
        dim = 3
        call setup_bc_inlet(ip0=0)
        self % ig_properties(1:2) = [T, un]

      ! Full state specification with time-varying properties
      elseif ( time_file/='none') then
        call refuse_on_2d_mesh(self, 410, 'time-file inlet', 'use a 3D mesh or another inlet type')
        ! Load and apply unwrapped mapping if configured
        call apply_unwrapped_to_3D(sourceini, time_file, section)
        self % ig_id = 410
        self % ig_n = 2
        self % time_varying = .true.
        allocate(self % ig_properties(1:self % ig_n))
        allocate(self % ig_time(1:self % ig_n))
        allocate(self % ig_time_file(1:self % ig_n))
        self % ig_properties = 0.0_R8
        self % IG_time = .true.
        self % IG_time_file(1) = time_file
        self % IG_time_file(2) = 'one-shot'
        if (periodic) self % IG_time_file(2) = 'periodic'
      
      else
        write(*,*) '[ERROR] insufficient or inconsistent inflow properties specified.'
        write(*,*) '        Please check input file and documentation.'
        stop 1

      endif
      call check_honoured_keys(self % ig_id)

      ! (family rule): a deck T0 or T that a record carries as given (401-404, 405 by p and T, 407,
      ! 408) outside the loaded thermo table is reported, as ICB reports its written field (state-range check): the
      ! solvers clamp their cp/h lookups there. The expanding paths (405 by p0 and T0, 420) refuse their
      ! T0 before this point and report their static T above; L4 (check_honoured_keys) refuses first.
      if (.not. expanded .and. self%definition == 'inlet') then
        if (T0 /= 0.0_R8) call warn_table_range('T0', T0)
        if (T  /= 0.0_R8) call warn_table_range('T', T)
      endif

    end subroutine standard


    !> The inlet record carries a zero turbulence band under a model (the solver starts the
    !> inlet without turbulence; under an omega model the same field is refused by ICB)
    subroutine warn_turbulence_zero(what, model, keys)
      implicit none
      character(len=*), intent(in) :: what, model, keys
      write(*,'(A)') '[WARNING] '//trim(self%name)//' ('//trim(self%definition)//'): '//what//' = 0 written into the'// &
        ' inlet record under '//model//': the inlet carries no turbulence (give '//keys//'; ICB refuses'// &
        ' the same initial field under an omega model)'
    end subroutine warn_turbulence_zero

    ! L4 (honoured-keys table per inlet type): a key of the 4xx family that the resolved record cannot carry (a
    ! selector of a sibling inlet type, or a field the record has no slot for: composition and turbulence
    ! on an outlet or on a time-file inlet) is refused under strict-keys and reported once otherwise. One
    ! table for every type (420 and 421 included: their own messages above fire first for their historical
    ! cases). Ae_At = 0 and a1-a3 = 0 are their documented "not given" defaults: absent keys here.
    ! u, v, w and p-time-file are documented but no BC record carries them (406 is written with p and rf
    ! only): a WARNING whatever strict-keys, the deck runs as upstream.
    subroutine check_honoured_keys(id)
      implicit none
      integer, intent(in) :: id
      character(len=:), allocatable :: option_pairs(:), key, why, msg
      logical :: ok, selector

      do while (sourceini%loop(section_name=section, option_pairs=option_pairs))
        key = trim(option_pairs(1))
        if (key == 'Ae_At' .and. Ae_At == 0.0_R8) cycle   ! 0 = not given
        if (key == 'a1-a3' .and. a1_a3 == 0.0_R8) cycle   ! 0 = not given
        if (.not. family_key(key, id, ok, selector)) cycle
        if (ok) cycle
        if (any(key == [character(len=11) :: 'u', 'v', 'w', 'p-time-file'])) then
          if (key == 'p-time-file') then
            why = 'no BC record carries a static-pressure series (the outlet 406 is written with p and rf only):'// &
                  ' the key has no effect'
          else
            why = 'no BC record carries a velocity component (the inlet direction is given by alpha and beta):'// &
                  ' the key has no effect'
          endif
          call warn_once('key '//key//' of section ['//trim(self%name)//']: '//why)
          cycle
        endif
        if (key == 'h0' .and. self%ig_species%n /= 1) then
          why = 'h0 needs a single-species phase (a mixture takes its stagnation enthalpy from eq-CEA-file): give T0'
        elseif (selector .and. self%definition == 'outlet') then   ! wording for the outlet
          why = 'it selects an inlet type, the outlet record (BC '//trim(id_txt(id))//') has no field for it'
        elseif (selector) then
          why = 'it selects another inlet type, BC '//trim(id_txt(id))//' ignores it'
        else
          why = 'the record of BC '//trim(id_txt(id))//' has no field for it'
        endif
        msg = 'key '//key//' of section ['//trim(self%name)//']: not honoured by BC '//trim(id_txt(id))// &
              ' ('//trim(self%definition)//'): '//why
        if (input_keys_strict()) then
          write(*,'(A)') '[ERROR] '//msg
          stop 1
        endif
        call warn_once(msg)
      enddo
    end subroutine check_honoured_keys

    !> One [WARNING] per (section, key): the builder runs once per cell of a varying face.
    subroutine warn_once(msg)
      implicit none
      character(len=*), intent(in) :: msg
      integer :: i
      if (.not. allocated(warned_keys)) allocate(warned_keys(0))
      do i = 1, size(warned_keys)
        if (trim(warned_keys(i)) == trim(self%name)//'/'//key_of(msg)) return
      enddo
      warned_keys = [character(len=128) :: warned_keys, trim(self%name)//'/'//key_of(msg)]
      write(*,'(A)') '[WARNING] '//msg
    end subroutine warn_once

    !> The key named by a diagnostic 'key <k> of section ...'.
    function key_of(msg) result(k)
      implicit none
      character(len=*), intent(in)  :: msg
      character(len=:), allocatable :: k
      integer :: e
      e = index(msg, ' of section ')
      k = msg(5:max(5, e-1))
    end function key_of

    !> The per-type table: .false. for a key outside the 4xx family (not checked here);
    !> ok = the record of `id` carries the key; selector = the key selects an inlet type.
    logical function family_key(key, id, ok, selector) result(infamily)
      implicit none
      character(len=*), intent(in) :: key
      integer, intent(in)          :: id
      logical, intent(out)         :: ok, selector
      logical :: tail   ! records with a composition/turbulence tail: every inlet but 410

      infamily = .true.; selector = .true.
      tail = id /= 406 .and. id /= 410
      select case (key)
      case ('p0');            ok = any(id == [401, 405, 407, 420, 421])
      ! T0 and h0 are carried by the p0-T0 form of 405 only (405 given by mach, p and T has no
      ! stagnation state); h0 is converted to T0 for a single species only, a mixture takes its
      ! stagnation enthalpy from eq-CEA-file and a deck h0 was overwritten in silence
      case ('T0');            ok = any(id == [401, 402, 403, 407, 420, 421]) .or. (id == 405 .and. p0 /= 0._R8)
      case ('h0');            ok = (any(id == [401, 402, 403, 407, 420, 421]) .or. (id == 405 .and. p0 /= 0._R8)) &
                                   .and. self%ig_species%n == 1
      case ('p0-time-file');  ok = id == 402
      case ('g');             ok = any(id == [403, 404, 420])
      ! p and T are carried by the mach-p-T form of 405 only: next to p0 and T0 the static state is computed
      ! (T02T, p02p) and a deck p or T was dropped in silence
      case ('T');             ok = any(id == [404, 408]) .or. (id == 405 .and. p0 == 0._R8)
      case ('mach');          ok = id == 405
      case ('p');             ok = any(id == [406, 407]) .or. (id == 405 .and. p0 == 0._R8)
      case ('un');            ok = id == 408
      case ('time-file', 'line-file')
        ok = id == 410
      case ('periodic', 'center', 'strip-j-face', 'axis', 'n-repeat')   ! options of a 410 record: they select nothing
        ok = id == 410; selector = .false.
      case ('Ae_At', 'psub', 'psup'); ok = id == 420
      case ('a1-a3');         ok = id == 421
      case ('alpha', 'beta'); ok = tail .and. id < 420; selector = .false.
      case ('rf');            ok = id /= 410; selector = .false.
      case ('mit', 'kappa', 'omega', 'rhoRij', 'nrans', 'eq-OG', 'eq-CEA-file', 'eq-CEA-section')
        ok = tail; selector = .false.
      case ('u', 'v', 'w', 'p-time-file')
        ok = .false.; selector = .false.
      case default
        infamily = .false.; ok = .true.; selector = .false.
        if (len(key) > 1) then
          if (key(1:1) == 'y' .and. index(key, '-') == 0) then   ! y<species>
            infamily = .true.; ok = tail
          endif
        endif
      end select
    end function family_key

    function id_txt(id) result(txt)
      implicit none
      integer, intent(in) :: id
      character(len=8) :: txt
      write(txt, '(I0)') id
    end function id_txt

    
    subroutine setup_bc_inlet(ip0, no_angles)
      implicit none
      integer, intent(in) :: ip0
      logical, intent(in), optional :: no_angles
      ! Local
      integer :: n_angles

      ! Records without direction fields (alpha, beta), e.g. BC 421.
      no_angles_rec = .false.
      if (present(no_angles)) no_angles_rec = no_angles
      n_angles = 2
      if (no_angles_rec) n_angles = 0

      self % ig_n = dim + n_angles + self % ig_species % n + nrans
      allocate(self % ig_properties(1:self % ig_n))
      allocate(self % ig_time(1:self % ig_n))
      allocate(self % ig_time_file(1:self % ig_n))
      self % ig_properties = 0.0_R8
      self % IG_time = .false.
      self % IG_time_file = 'none'
      if (self % time_varying) then
        self % IG_time(ip0) = .true.
        self % IG_time_file(ip0) = p0_time_file
      endif

    end subroutine setup_bc_inlet


    subroutine setup_bc_outlet(ip)
      implicit none
      integer, intent(in) :: ip
      
      self % ig_n = 2
      allocate(self % ig_properties(1:self % ig_n))
      allocate(self % ig_time(1:self % ig_n))
      allocate(self % ig_time_file(1:self % ig_n))
      self % ig_properties = 0.0_R8
      self % IG_time = .false.
      self % IG_time_file = 'none'
      if (self % time_varying) then
        self % IG_time(ip) = .true.
        self % IG_time_file(ip) = p_time_file
      endif

    end subroutine setup_bc_outlet


    subroutine nozzle
      implicit none
      integer :: ierr

      ! BC 420 is an inlet, and both solvers that read it (MOSE, Q2D) inject
      ! along the face normal by construction: a prescribed angle cannot be
      ! honoured and the record carries no alpha/beta fields.
      if (self % definition /= 'inlet') then
        write(*,*) '[ERROR] Ae_At / g+psub+psup (injector nozzle, BC 420) are inlet properties'
        stop 1
      endif
      if (alpha /= huge(0.0_R8) .or. beta /= huge(0.0_R8)) then
        write(*,*) '[ERROR] nozzle inlet (BC 420): alpha/beta cannot be honoured, the solvers'
        write(*,*) '        inject along the face normal (the record has no angle fields)'
        stop 1
      endif
      ! BC 420 is a steady record: both solver readers take p0 as a scalar.
      if (p0_time_file /= 'none' .or. time_file /= 'none') then
        write(*,*) '[ERROR] nozzle inlet (BC 420) does not support p0-time-file or time-file'
        stop 1
      endif
      ! L4: every other key the 420 record cannot carry (mach, p, un, T, p-time-file, ...), before
      ! the stagnation state is judged (a T next to a CEA T0 is named, not hidden by "T0 = 0")
      call check_honoured_keys(420)
      ! Stagnation state: consumed right below by the Ae_At path; on the
      ! g+psub+psup path p0 bounds the subsonic regime of the solvers.
      if (T0 <= 0.0_R8 .or. p0 <= 0.0_R8) then
        write(*,*) '[ERROR] nozzle inlet (BC 420) requires positive T0 and p0 (or eq-CEA-file)'
        stop 1
      endif

      if (Ae_At/=0._R8) then

        if (Ae_At < 1.0d0) then
          write(*,*) '[ERROR] Ae_At must be >= 1.0'
          stop 1
        endif
        ! The thresholds are computed on the species cp/h tables
        ! (read_idealgas_properties only warns when thermo.dat is missing and
        ! leaves them unallocated).
        if (.not. allocated(self%ig_species%cp)) then
          write(*,*) '[ERROR] Ae_At requires the species thermo table (thermo.dat not found)'
          stop 1
        endif
        ! Linear interpolation on the 1 K grid reads idint(T) and idint(T)+1
        ! for every T of the expansion, from the coldest node up to T0. The
        ! solvers' table lookup (FLINT) clamps every T to ubound-1 before
        ! interpolating, so T0 must not exceed ubound-1:
        ! above it their h0 and cp differ from the interpolated values here.
        if (T0 < real(lbound(self%ig_species%cp, dim=2) + 1, R8) .or. &
            T0 > real(ubound(self%ig_species%cp, dim=2) - 1, R8)) then
          write(*,*) '[ERROR] Ae_At: T0 lies outside the temperature range of thermo.dat'
          stop 1
        endif
        if (g /= 0.0_R8 .or. psub /= 0.0_R8 .or. psup /= 0.0_R8) then
          write(*,*) '[WARNING] Ae_At given: g, psub, psup of the deck are recomputed from it'
        endif

        ! Thresholds on the tabulated-cp isentrope from (T0, p0), with the
        ! discrete arithmetic of the solvers' nozzle kernels (MOSE/Q2D: linear
        ! interpolation of cp and h on the 1 K grid, trapezoidal isentrope):
        ! g = G*/Ae_At, G* = max rho*u along the expansion (sonic throat);
        ! psub = exit pressure of the just-choked subsonic solution and psup =
        ! design supersonic exit pressure, the two roots of rho*u = g, each
        ! bracketed on its monotone branch.
        call nozzle_thresholds(T0, p0, Ae_At, self%ig_species, psub, psup, g, ierr)
        if (ierr == 1) then
          write(*,*) '[ERROR] Ae_At: no sonic throat inside the temperature range of thermo.dat'
          stop 1
        elseif (ierr /= 0) then
          write(*,*) '[ERROR] Ae_At: supersonic exit temperature below the range of thermo.dat'
          write(*,*) '        (the solver kernels need cp and h down to that state: extend the table)'
          stop 1
        endif

      else

        ! Explicit thresholds. Solver regimes (MOSE/Q2D BC_Inflow_Nozzle) on the
        ! boundary-cell pressure: [psub,p0) subsonic from (T0,p0) | [psup,psub)
        ! choked, g | below psup supersonic, g. All three exist only if
        ! 0 < psup <= psub < p0 (Q2D refuses the record otherwise, MOSE loses
        ! the choked band silently).
        if (.not. (psup > 0.0_R8 .and. psup <= psub .and. psub < p0)) then
          write(*,*) '[ERROR] nozzle inlet (BC 420) requires 0 < psup <= psub < p0'
          write(*,*) '        psup =', psup, ' psub =', psub, ' p0 =', p0
          stop 1
        endif
        if (g <= 0.0_R8) then
          write(*,*) '[ERROR] nozzle inlet (BC 420) requires a positive mass flux g'
          stop 1
        endif
        ! Coherence of the trio with the tabulated isentrope from (T0, p0), only
        ! when the species table is loaded (the explicit trio does not need it).
        if (allocated(self%ig_species%cp)) call check_explicit_trio()

      endif

      ! Record as read by MOSE and Q2D (IO_BC, case 420):
      !   T0, p0, psub, psup, g, rel_fac, massf(1:ns), turb(1:nrans)
      ! dim = index of the first tail field, as in standard(): 5 properties + 1.
      self%ig_id = 420
      dim = 6
      call setup_bc_inlet(ip0=0, no_angles=.true.)
      self % ig_properties(1:5) = [T0, p0, psub, psup, g]

    end subroutine nozzle

    ! Explicit g+psub+psup trio against the isentrope from (T0, p0) with the
    ! discrete arithmetic of the Ae_At path (nozzle_thresholds, phase.f90):
    ! G* = choked mass flux (Ae_At = 1), equivalent area ratio Ae_At = G*/g and
    ! the isentropic psub/psup of that ratio. WARNING only: the deck values may
    ! be experimental, but beyond G* the solver kernel has no root and a
    ! trio far from the isentrope is worth a look.
    subroutine check_explicit_trio
      implicit none
      real(R8) :: Gstar, psub_eq, psup_eq, g_eq, Ae_At_eq
      integer  :: ierr

      if (T0 < real(lbound(self%ig_species%cp, dim=2) + 1, R8) .or. &
          T0 > real(ubound(self%ig_species%cp, dim=2) - 1, R8)) then
        write(*,'(A)') ' [WARNING] nozzle inlet (BC 420): T0 lies outside the temperature range of thermo.dat,'
        write(*,'(A)') '           the coherence of g, psub, psup with (T0, p0) is not checked'
        return
      endif
      call nozzle_thresholds(T0, p0, 1.0_R8, self%ig_species, psub_eq, psup_eq, Gstar, ierr)
      if (ierr /= 0) then
        write(*,'(A)') ' [WARNING] nozzle inlet (BC 420): no sonic throat inside the temperature range of thermo.dat,'
        write(*,'(A)') '           the coherence of g, psub, psup with (T0, p0) is not checked'
        return
      endif
      if (g > Gstar) then
        write(*,'(A)') ' [WARNING] nozzle inlet (BC 420): the requested mass flux exceeds the choked value G* of (T0,p0):'
        write(*,'(A)') '           the mass-flux equation has no root for this (T0, p0)'
        write(*,'(A,ES12.5,A,ES12.5,A)') '           g = ', g, '  G* = ', Gstar, ' kg m-2 s-1'
        return
      endif
      Ae_At_eq = Gstar / g
      call nozzle_thresholds(T0, p0, Ae_At_eq, self%ig_species, psub_eq, psup_eq, g_eq, ierr)
      if (ierr /= 0) then
        write(*,'(A)') ' [WARNING] nozzle inlet (BC 420): the isentropic psub/psup of (T0, p0, g) could not be computed'
        write(*,'(A)') '           (supersonic exit temperature below the range of thermo.dat): coherence not checked'
        return
      endif
      if (abs(psub - psub_eq) > 0.05_R8 * psub_eq .or. abs(psup - psup_eq) > 0.05_R8 * psup_eq) then
        write(*,'(A)') ' [WARNING] nozzle inlet (BC 420): psub/psup of the deck differ by more than 5 % from the'
        write(*,'(A)') '           isentropic values of (T0, p0, g), equivalent area ratio Ae_At = G*/g:'
        write(*,'(A,ES12.5,A,ES12.5)') '           deck psub = ', psub, '  isentropic psub = ', psub_eq
        write(*,'(A,ES12.5,A,ES12.5)') '           deck psup = ', psup, '  isentropic psup = ', psup_eq
        write(*,'(A,ES12.5)')          '           Ae_At = ', Ae_At_eq
      endif

    end subroutine check_explicit_trio


    ! Borda sudden-expansion choked injector, BC 421 (Q2D only). Selected by a
    ! nonzero a1-a3 = A1/A3, injector throat area over boundary-face area, in
    ! (0, 1]. Record as read by Q2D (IO_BC, case 421):
    !   T0, p0, A1_A3, rel_fac, massf(1:ns), turb(1:nrans)
    ! Injection is face-normal by construction: no alpha/beta fields.
    subroutine borda
      use grid_mod, only: mesh_cfg
      implicit none

      if (self % definition /= 'inlet') then
        write(*,*) '[ERROR] a1-a3 (Borda injector, BC 421) is an inlet property'
        stop 1
      endif
      ! Only Q2D implements BC 421, and it reads the pure-2D deck format
      ! (5-integer headers, x-y mesh file): every other mesh type is refused.
      if (mesh_cfg%meshType /= MESH_PURE_2D) then
        write(*,*) '[ERROR] a1-a3 (Borda injector, BC 421) requires a 2D mesh (x,y file):'
        write(*,*) '        only the Q2D solver implements BC 421'
        stop 1
      endif
      if ( Ae_At /= 0_R8 .or. psub /= 0_R8 .or. psup /= 0_R8 .or. g /= 0_R8 .or. &
           mach /= 0_R8 .or. p /= 0_R8 .or. un /= 0_R8 .or. T /= 0_R8 .or. &
           alpha /= huge(0.0_R8) .or. beta /= huge(0.0_R8) .or. &
           p0_time_file /= 'none' .or. p_time_file /= 'none' .or. time_file /= 'none' ) then
        write(*,*) '[ERROR] ambiguous inlet: a1-a3 (Borda injector, BC 421) admits only'
        write(*,*) '        T0 and p0 (or eq-CEA-file), rf and composition/turbulence keys;'
        write(*,*) '        injection is face-normal (no alpha/beta)'
        stop 1
      endif
      if (a1_a3 <= 0.0_R8 .or. a1_a3 > 1.0_R8) then
        write(*,*) '[ERROR] a1-a3 must lie in (0, 1] (injector throat to face area ratio A1/A3)'
        stop 1
      endif
      call check_honoured_keys(421)
      ! L5: a negative T0 or p0 is refused (an equality test with 0 let it through)
      if (T0 <= 0.0_R8 .or. p0 <= 0.0_R8) then
        write(*,*) '[ERROR] Borda injector (a1-a3, BC 421) requires positive T0 and p0 (or eq-CEA-file)'
        stop 1
      endif

      self % ig_id = 421
      dim = 4
      call setup_bc_inlet(ip0=0, no_angles=.true.)
      self % ig_properties(1:3) = [T0, p0, a1_a3]

    end subroutine borda

  end procedure build_inflow_outflow_ig


  ! Compute T starting from h
  ! T0 of a single-species stagnation enthalpy h0 on the 1 K enthalpy table (linear
  ! interpolation between the two nodes that bracket h0). before this form the loop started at the
  ! first node and read h(1, lbound-1) (out of bounds: ifx DEBUG abort, RELEASE garbage), the
  ! interpolation formula was wrong and an h0 outside the table left T0 undefined.
  function h02T0(h0, h, start) result(T0)
    implicit none
    real(8), intent(in) :: h0
    integer, intent(in) :: start
    real(8), intent(in) :: h(:,start:)
    real(8) :: T0
    integer :: i
    T0 = -1.0d0
    do i = lbound(h, dim=2) + 1, ubound(h, dim=2)
      if (h0<=h(1,i) .and. h0>h(1,i-1)) then
        T0 = dble(i-1) + (h0 - h(1,i-1)) / (h(1,i) - h(1,i-1))
        exit
      endif
    enddo
    if (T0 < 0.0d0) then
      write(*,'(A,ES12.5,A)') '[ERROR] h0 = ', h0, ' J/kg lies outside the enthalpy range of thermo.dat: no T0 for it'
      stop 1
    endif
  end function h02T0


  function T02h0(T0, h, s) result(h0)
    implicit none
    real(8), intent(in) :: T0
    real(8), intent(in) :: h(:,:)
    integer, intent(in) :: s
    real(8) :: h0
    integer :: i
    h0 = 0.0d0
    do i = lbound(h, dim=2) + 1, ubound(h, dim=2)
      if (T0<=i .and. T0>i-1) then
        h0 = (T0-dble(i-1))*(h(s,i)-(h(s,i-1))) + (h(s,i-1))
        exit
      endif
    enddo
  end function T02h0

  subroutine apply_unwrapped_to_3D(sourceini, outfile, section)
    implicit none
    type(file_ini), intent(in) :: sourceini
    character(len=*), intent(in) :: outfile
    character(len=*), intent(in) :: section
    ! Local variables
    type(bcb_unwrapped_config_t) :: local_cfg
    type(unwrapped_done_t)       :: entry
    integer :: i

    ! Load complete configuration
    call load_bcb_unwrapped_config(sourceini, section, local_cfg)

    ! The mapping is optional for BC 410: a plain time-file section (no
    ! line-file key) is user data and passes through untouched.
    if (.not. local_cfg%has_linefile) return

    if (.not. allocated(unwrapped_done)) allocate(unwrapped_done(0))
    do i = 1, size(unwrapped_done)
      if (trim(outfile) /= trim(unwrapped_done(i)%outfile)) cycle
      if (same_unwrapped_key(local_cfg, unwrapped_done(i)%cfg)) return
      write(*,'(A)') '[ERROR] time-file '//trim(outfile)//' was already written from line-file '// &
                     trim(unwrapped_done(i)%cfg%linefile)//' with a different face/center/strip-j-face/axis/n-repeat:'
      write(*,'(A)') '        one time-file cannot hold two mappings, give each mapping its own time-file'
      stop 1
    enddo

    if (.not. local_cfg%has_center) then
      write(*,*) '[ERROR] Missing center in input (x y z)'
      stop 1
    endif

    ! Execute unwrapped to 3D mapping
    call map_unwrapped_to_3D(local_cfg%linefile, outfile, local_cfg%face, local_cfg%strip_j_face, local_cfg%center, &
                             local_cfg%axis, local_cfg%n_repeat)
    entry%cfg = local_cfg
    entry%outfile = outfile
    unwrapped_done = [unwrapped_done, entry]

  end subroutine apply_unwrapped_to_3D

  pure logical function same_unwrapped_key(a, b)
    type(bcb_unwrapped_config_t), intent(in) :: a, b
    same_unwrapped_key = trim(a%linefile) == trim(b%linefile) .and. a%face == b%face .and. &
                         a%strip_j_face == b%strip_j_face .and. all(a%center == b%center) .and. &
                         a%axis == b%axis .and. a%n_repeat == b%n_repeat
  end function same_unwrapped_key

      ! if (present(SRMswitch)) then
      !   m = size(self_properties)
      !   self_properties(m-2) = (csAl*sum(self_cp_properties(m,1:npCP,2)*(volRatio*T0-Tsat))+ sum((1d0-self_cp_properties(m,1:npCP,2)*volRatio))*self_properties(m-2)- sum(self_cp_properties(m,1:npCP,2)*(1d0-volRatio))*Qal)/(1d0-sum(self_cp_properties(m,1:npCP,2)))
      !   if (all(self_cp_properties(:,:,1)==0.d0)) then
      !     krho = sum( self_cp_properties(:,:,2) )
      !   else
      !     write(*,*) 'ERROR: you should not fix the condensed-phase mass flux when using the SRM grain BC (14)'
      !     stop
      !   endif
      !   self_properties(m-6) = self_properties(m-6)*(1.d0-krho)
      ! endif

  ! L4: the x,y (pure-2D) deck format is read by Q2D only, which does not implement BC 408
  ! (normal-velocity inlet), BC 410 (time-file inlet) nor BC 501 (manifold): refused here instead of
  ! at the solver start (same meshType gate as the Borda injector 421 and the RSM tail).
  module subroutine refuse_on_2d_mesh(self, id, what, advice)
    use grid_mod, only: mesh_cfg, MESH_PURE_2D
    implicit none
    class(bc_t),      intent(in) :: self
    integer,          intent(in) :: id
    character(len=*), intent(in) :: what
    character(len=*), intent(in) :: advice
    character(len=8)             :: txt
    if (mesh_cfg%meshType /= MESH_PURE_2D) return
    write(txt,'(I0)') id
    write(*,'(A)') '[ERROR] '//trim(self%name)//' ('//what//', BC '//trim(txt)//'): a 2D mesh (x,y file) is read'// &
                   ' by Q2D, which does not implement BC '//trim(txt)//': '//advice
    stop 1
  end subroutine refuse_on_2d_mesh

end submodule ig_inflow_outflow_mod
