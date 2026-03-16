!> Direction string parsing: maps character direction IDs
!> (x/y/z/r/t/i/j/k) to integer direction indices (1-8).
!> Shared by BC cell_builder and IC builder.
module direction_mod
  implicit none
  private
  public :: parse_direction

contains

  !> Parse a direction string into an array of integer direction indices.
  !> Returns the number of directions found in ndir and whether any
  !> index-based directions (i/j/k) were present.
  subroutine parse_direction(dirID, dir, ndir, index_based)
    character(len=*), intent(in)  :: dirID
    integer, allocatable, intent(out) :: dir(:)
    integer, intent(out)          :: ndir
    logical, intent(out)          :: index_based
    logical :: found(8)
    integer :: i

    index_based = .false.
    ndir = len_trim(dirID)
    allocate(dir(1:ndir))
    found = .false.

    do i = 1, ndir
      if (index(dirID,'x')/=0 .and. .not.found(1)) then
        dir(i) = 1; found(1)=.true.
      elseif (index(dirID,'y')/=0 .and. .not.found(2)) then
        dir(i) = 2; found(2)=.true.
      elseif (index(dirID,'z')/=0 .and. .not.found(3)) then
        dir(i) = 3; found(3)=.true.
      elseif (index(dirID,'r')/=0 .and. .not.found(4)) then
        dir(i) = 4; found(4)=.true.
      elseif (index(dirID,'t')/=0 .and. .not.found(5)) then
        dir(i) = 5; found(5)=.true.
      elseif (index(dirID,'i')/=0 .and. .not.found(6)) then
        dir(i) = 6; found(6)=.true.; index_based=.true.
      elseif (index(dirID,'j')/=0 .and. .not.found(7)) then
        dir(i) = 7; found(7)=.true.; index_based=.true.
      elseif (index(dirID,'k')/=0 .and. .not.found(8)) then
        dir(i) = 8; found(8)=.true.; index_based=.true.
      endif
    enddo
  end subroutine parse_direction

end module direction_mod
