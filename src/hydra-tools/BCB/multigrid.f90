module io_multigrid_mod
  use Lib_ORION_data
  implicit none
  private
  public:: coarse_mesh, check_multigrid

contains

  subroutine coarse_mesh ( fine, coarse )
    use Lib_ORION_data
    implicit none
    type(orion_data), intent(in)    :: fine
    type(orion_data), intent(inout) :: coarse
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
    
        ! 2D
        if ( fine % block(b)%Nk == 1 ) k2 = k
    
        coarse%block(b)%mesh(1:3,i2,j2,k2) = fine%block(b)%mesh(1:3,i,j,k)
        
      enddo; enddo; enddo

    enddo

  end subroutine coarse_mesh


  subroutine check_multigrid ( orion, MGL )
    use Lib_ORION_data
    implicit none
    type(orion_data), intent(in)    :: orion
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

end module io_multigrid_mod