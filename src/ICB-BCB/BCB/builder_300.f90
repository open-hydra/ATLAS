submodule (bc_mod) bc_wall_mod

  implicit none

contains

  module procedure build_wall_fluid
    implicit none
    real(R8) :: q, T, ks, qrad, eps
    integer  :: eq, eT, eks, eqrad, eeps

    self % ig_species % n = 0

    q = 0._R8; T = 0._R8; ks = 0._R8; qrad = 0._R8; eps = 0._R8

    call sourceini%get(section_name=section, option_name='q',     val=q,    error=eq)
    call sourceini%get(section_name=section, option_name='T',     val=T,    error=eT)
    call sourceini%get(section_name=section, option_name='ks',    val=ks,   error=eks)
    call sourceini%get(section_name=section, option_name='qrad',  val=qrad, error=eqrad)
    call sourceini%get(section_name=section, option_name='eps',   val=eps,  error=eeps)

    ! Heat flux and roughness (if 0, smooth wall)
    if (eq==0._R8 .and. (eT+eqrad)/=0._R8) then
      self % ig_n = 2
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_id = 301
      self % ig_properties(1:2) = [q, ks]
    
    ! Temperature and roughness (if 0, smooth wall)
    elseif (eT==0._R8 .and. (eq+eqrad)/=0._R8) then
      self % ig_n = 2
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_id = 302
      self % ig_properties(1:2) = [T, ks]

    ! Temperature, radiative heat flux, and roughness (if 0, smooth wall)
    elseif (eT==0._R8 .and. eqrad==0._R8 .and. eq/=0._R8) then
      self % ig_n = 3
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_id = 303
      self % ig_properties(1:3) = [T, qrad, ks]

    ! Radiative heat flux, and roughness (if 0, smooth wall)
    elseif (eqrad==0._R8 .and. (eT+eq)/=0._R8) then
      self % ig_n = 2
      allocate(self % ig_properties(1:self % ig_n))
      self % ig_id = 304
      self % ig_properties(1:2) = [qrad, ks]

    ! Eulerian symmetry
    else
      self % ig_n = 0
      self % ig_id = 300

    endif

  end procedure build_wall_fluid


  module procedure build_wall_solid
    implicit none
    real(R8) :: q, T, qrad, h, Tref, eps
    integer  :: eq, eT, eqrad, eh, eTref, eeps

    q = 0._R8; T = 0._R8; qrad = 0._R8; h = 0._R8; Tref = 0._R8; eps = 0._R8

    call sourceini%get(section_name=section, option_name='q',     val=q,    error=eq)
    call sourceini%get(section_name=section, option_name='T',     val=T,    error=eT)
    call sourceini%get(section_name=section, option_name='qrad',  val=qrad, error=eqrad)
    call sourceini%get(section_name=section, option_name='hconv', val=h,    error=eh)
    call sourceini%get(section_name=section, option_name='Tref',  val=Tref, error=eTref)
    call sourceini%get(section_name=section, option_name='eps',   val=eps,  error=eeps)

    ! Heat flux
    if (eq==0 .and. (eT+eqrad)/=0) then
      self % sp_n = 1
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 301
      self % sp_properties(1) = q
    
    ! Temperature
    elseif (eT==0 .and. (eq+eqrad)/=0) then
      self % sp_n = 1
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 302
      self % sp_properties(1) = T

    ! Convection coefficient, reference temperature, and radiative heat flux
    elseif (eh==0 .and. eqrad==0 .and. eTref==0) then
      self % sp_n = 3
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 303
      self % sp_properties(1:3) = [h, Tref, qrad]

    ! Radiative heat flux
    elseif (eeps==0 .and. (eq+eqrad)/=0) then
      self % sp_n = 1
      if (.not.allocated(self % sp_properties)) allocate(self % sp_properties(1:self % sp_n))

      self % sp_id = 304
      self % sp_properties(1) = eps

    endif

  end procedure build_wall_solid

end submodule bc_wall_mod
