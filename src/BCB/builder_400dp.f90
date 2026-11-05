submodule (bc_mod) dp_inflow_outflow_mod
  use bcb_config_mod, only: bcb_dp_boundary_config_t, load_bcb_dp_boundary_config
  use phase_mod, only: phase_t
  implicit none

contains

  !> Inlet/outlet of ONE dispersed phase into its own slot self % dp(k) (k from bc_t % dp_slot).
  !> The payload arrays are sized from THIS phase (materials x populations), so two phases with
  !> different population counts no longer share one allocation. The id is decided once for the
  !> phase, so the header of every copy matches its payload.
  module procedure build_inflow_outflow_dp
    implicit none
    integer :: m, npCP
    type(bcb_dp_boundary_config_t) :: cfg

    self % dp(k) % n = 7
    if (allocated(self % dp(k) % properties))   deallocate(self % dp(k) % properties)
    if (allocated(self % dp(k) % distribution)) deallocate(self % dp(k) % distribution)
    if (allocated(self % dp(k) % ds))           deallocate(self % dp(k) % ds)
    allocate(self % dp(k) % properties(1:phase % material % n,1:maxval(phase % material % npCP(:)),1:self % dp(k) % n))
    allocate(self % dp(k) % distribution(1:phase % material % n,1:maxval(phase % material % npCP(:))))
    allocate(self % dp(k) % ds(1:phase % material % n,1:maxval(phase % material % npCP(:))))

    self % dp(k) % properties   = 1.0_R8
    self % dp(k) % distribution = 'none'
    self % dp(k) % ds           = 0.0_R8
    self % dp(k) % krho_sum     = 0.0_R8
    self % dp(k) % krho_min     = 0.0_R8
    self % dp(k) % gp_sum       = 0.0_R8
    self % dp(k) % gp_min       = 0.0_R8
    self % dp(k) % g_fixed      = 0.0_R8
    self % dp(k) % mixed        = .false.

    call load_bcb_dp_boundary_config(sourceini, section, phase, cfg)

    ! One id for the phase: every (material, population) copy of the table is written under it.
    ! gp is one key for all materials; 402 needs a nonzero velocity magnitude in every population.
    if (.not. cfg%materials(1)%has_gp) then
      self % dp(k) % id = 401
    elseif (all([(all(cfg%materials(m)%velocity_magnitude /= 0.0_R8), m = 1, phase % material % n)])) then
      self % dp(k) % id = 402
    else
      self % dp(k) % id = 403
    endif
    if (self % definition == 'outlet')      self % dp(k) % id = 400

    do m = 1, phase % material % n
      npCP = phase % material % npCP(m)

      if (self % dp(k) % id == 401) then
        self % dp(k) % properties(m,1:npCP,1) = cfg%materials(m)%krho
        self % dp(k) % properties(m,1:npCP,2) = cfg%materials(m)%kV
        self % dp(k) % properties(m,1:npCP,5) = cfg%materials(m)%kT
        self % dp(k) % krho_sum = self % dp(k) % krho_sum + sum(cfg%materials(m)%krho(1:npCP))
        self % dp(k) % krho_min = min(self % dp(k) % krho_min, minval(cfg%materials(m)%krho(1:npCP)))

      elseif (self % dp(k) % id == 402) then
        self % dp(k) % properties(m,1:npCP,1) = cfg%materials(m)%gp
        self % dp(k) % properties(m,1:npCP,2) = cfg%materials(m)%velocity_magnitude
        self % dp(k) % properties(m,1:npCP,5) = cfg%materials(m)%Tp
        self % dp(k) % gp_sum = self % dp(k) % gp_sum + sum(cfg%materials(m)%gp(1:npCP))
        self % dp(k) % gp_min = min(self % dp(k) % gp_min, minval(cfg%materials(m)%gp(1:npCP)))

      elseif (self % dp(k) % id == 403) then
        self % dp(k) % properties(m,1:npCP,1) = cfg%materials(m)%gp
        self % dp(k) % properties(m,1:npCP,2) = cfg%materials(m)%kV
        self % dp(k) % properties(m,1:npCP,5) = cfg%materials(m)%Tp
        self % dp(k) % gp_sum = self % dp(k) % gp_sum + sum(cfg%materials(m)%gp(1:npCP))
        self % dp(k) % gp_min = min(self % dp(k) % gp_min, minval(cfg%materials(m)%gp(1:npCP)))

      else
        self % dp(k) % id = 400

      endif

      self % dp(k) % properties(m,1:npCP,3) = cfg%materials(m)%alphap
      self % dp(k) % properties(m,1:npCP,4) = cfg%materials(m)%betap
      self % dp(k) % properties(m,1:npCP,6) = cfg%materials(m)%rp
      self % dp(k) % properties(m,1:npCP,7) = cfg%materials(m)%sigmap
      self % dp(k) % distribution(m,1:npCP) = cfg%materials(m)%distribution(1:npCP)
      self % dp(k) % ds(m,1:npCP)           = cfg%materials(m)%ds

    enddo

  end procedure build_inflow_outflow_dp


  !> The mixture rule of the 401 inlet across the dispersed phases of the cell, once every phase of the block is built
  !> on it (builder_block, correct_grain_flows). krho_tot, the sum of krho over every (material, population) of every
  !> 401 record of the cell, and G, the sum of gp over every (material, population) of every 402/403 record, are the
  !> cell's: each 401 record carries krho/(1 - krho_tot) in place of krho, and G after ds, and the solvers inject
  !> krho/(1 - krho_tot) (mdot_gas + G A) per (material, population), the gas flow not in G. A krho sum of 1 or more (an
  !> infinite or negative flow), a negative krho or a negative gp stops BCB with the cell's section.
  module procedure mix_dp_inlets
    implicit none
    real(R8) :: krho_tot, g_tot
    character(len=24) :: txt
    integer :: k

    if (.not. allocated(self % dp)) return
    krho_tot = 0.0_R8
    g_tot = 0.0_R8
    do k = 1, size(self % dp)
      select case (self % dp(k) % id)
      case (401)
        if (self % dp(k) % mixed) return
        krho_tot = krho_tot + self % dp(k) % krho_sum
        if (self % dp(k) % krho_min < 0.0_R8) call refuse('a negative krho of the dispersed phase '// &
                                                          trim(self % dp(k) % phase_name))
      case (402, 403)
        g_tot = g_tot + self % dp(k) % gp_sum
        if (self % dp(k) % gp_min < 0.0_R8) call refuse('a negative gp of the dispersed phase '// &
                                                        trim(self % dp(k) % phase_name))
      end select
    enddo
    if (.not. (krho_tot < 1.0_R8)) then
      write(txt,'(ES12.5)') krho_tot
      call refuse('the krho of the dispersed phases of the cell sum to '//trim(adjustl(txt))// &
                  ', 1 or more (an infinite or negative flow)')
    endif

    do k = 1, size(self % dp)
      if (self % dp(k) % id /= 401) cycle
      self % dp(k) % properties(:,:,1) = self % dp(k) % properties(:,:,1) / (1.0_R8 - krho_tot)
      self % dp(k) % g_fixed = g_tot
      self % dp(k) % mixed = .true.
    enddo

  contains

    subroutine refuse(what)
      implicit none
      character(len=*), intent(in) :: what
      write(*,'(A)') '[ERROR] section ['//trim(self % name)//'] (inlet of the dispersed phases, BC 401): '//what
      stop 1
    end subroutine refuse

  end procedure mix_dp_inlets

end submodule dp_inflow_outflow_mod
