!>@brief Carve the ORION grid (and its solution field, if present) into pieces.
!>
!> The split is exact: node planes on a cut are duplicated in both neighbours,
!> cell data is partitioned without duplication and without interpolation, so a
!> decomposed restart carries the original solution bit for bit.
module split_grid_mod
  use Lib_ORION_data
  use IR_Precision, only: R8P, str
  use decomposition_mod
  implicit none
  private

  public :: split_grid

contains

  !> Build `out` from `inp` following the decomposition. Parent blocks are freed
  !> as soon as all their pieces are extracted, so the peak memory stays close to
  !> one copy of the grid rather than two.
  subroutine split_grid(dec, inp, out)
    type(decomposition_t), intent(in)    :: dec
    type(orion_data),      intent(inout) :: inp
    type(orion_data),      intent(inout) :: out
    ! Local
    integer :: p, b, nd, nv, i, j, k, v
    integer :: lo(3), hi(3), dm(3)
    logical :: has_vars

    if (allocated(out%block)) deallocate(out%block)
    allocate(out%block(dec%npieces))

    out%solutiontime = inp%solutiontime
    out%tec          = inp%tec
    out%vtk          = inp%vtk
    out%p3d          = inp%p3d
    if (allocated(inp%varnames)) then
      allocate(out%varnames(size(inp%varnames)))
      out%varnames = inp%varnames
    endif

    do b = 1, dec%nparent

      has_vars = allocated(inp%block(b)%vars)
      nd = size(inp%block(b)%mesh, 1)
      nv = 0
      if (has_vars) nv = size(inp%block(b)%vars, 1)

      do p = dec%pfirst(b), dec%plast(b)

        lo = dec%piece(p)%lo
        hi = dec%piece(p)%hi
        dm = hi - lo + 1

        out%block(p)%Ni = dm(1)
        out%block(p)%Nj = dm(2)
        out%block(p)%Nk = dm(3)
        out%block(p)%name = piece_name(b, p)

        ! Nodes: cells lo..hi are bounded by nodes lo-1..hi
        allocate(out%block(p)%mesh(1:nd, 0:dm(1), 0:dm(2), 0:dm(3)))
        do k = 0, dm(3)
          do j = 0, dm(2)
            do i = 0, dm(1)
              out%block(p)%mesh(1:nd,i,j,k) = &
                inp%block(b)%mesh(1:nd, lo(1)-1+i, lo(2)-1+j, lo(3)-1+k)
            enddo
          enddo
        enddo

        if (has_vars) then
          allocate(out%block(p)%vars(1:nv, 1:dm(1), 1:dm(2), 1:dm(3)))
          do k = 1, dm(3)
            do j = 1, dm(2)
              do i = 1, dm(1)
                do v = 1, nv
                  out%block(p)%vars(v,i,j,k) = &
                    inp%block(b)%vars(v, lo(1)-1+i, lo(2)-1+j, lo(3)-1+k)
                enddo
              enddo
            enddo
          enddo
        endif

      enddo

      ! Parent no longer needed
      if (allocated(inp%block(b)%mesh)) deallocate(inp%block(b)%mesh)
      if (allocated(inp%block(b)%vars)) deallocate(inp%block(b)%vars)

    enddo

  end subroutine split_grid


  !> Zone names are generated, never inherited: ORION's ASCII Tecplot reader
  !> leaves obj_block%name undefined, and the writer emits it unquoted into the
  !> ZONE header, so a stale value corrupts the output file.
  pure function piece_name(b, p) result(nm)
    integer, intent(in) :: b, p
    character(len=128)  :: nm
    character(len=16)   :: sb, sp

    write(sb,'(I0)') b
    write(sp,'(I0)') p
    nm = 'B'//trim(sp)//'-of-'//trim(sb)

  end function piece_name

end module split_grid_mod
