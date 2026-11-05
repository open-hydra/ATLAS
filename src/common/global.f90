module global_mod
  implicit none

  logical            :: verbose = .false.
  integer, parameter :: llen = 256

  !> The directory the tools write into, in the case directory: its files go into the INPUT/ of a
  !> solver run (figaro moves them), never written there directly, where they would replace the
  !> solver's own inputs. GPB writes the phase files there too, and BCB, ICB and MDB read them
  !> from there when the case directory has none of the same name (phase_dir).
  character(len=*), parameter :: outpath = 'fromATLAStoSolver/'

contains

  !> The directory the files of the phase of *prefix* ('' or '<name>-') are read from: the case
  !> directory when <prefix>phase.txt is there (a phase file written by hand, or copied there), else
  !> fromATLAStoSolver/ when GPB wrote it there. Its thermo.dat or properties.dat is read from the
  !> same directory.
  function phase_dir(prefix) result(dir)
    character(len=*), intent(in)  :: prefix
    character(len=:), allocatable :: dir
    logical :: found

    dir = ''
    inquire(file=trim(prefix)//'phase.txt', exist=found)
    if (found) return
    inquire(file=outpath//trim(prefix)//'phase.txt', exist=found)
    if (found) dir = outpath
  end function phase_dir

end module global_mod
