!>@brief Rewrite a MOSE boundary-condition file for a decomposed mesh.
!>
!> MOSE stores one BC record per boundary *cell* (MOSE_IO_BC::Read_BCfile), so
!> splitting a block is a pure index transformation:
!>
!>   * a boundary cell that stays on the parent's boundary keeps its record —
!>     only the block id and the local indices change, plus, for connection and
!>     chimera records, the donor block/indices;
!>   * a boundary cell that lands on a new internal cut gets a fresh type-101
!>     record pointing at the neighbouring piece.
!>
!> Because connectivity is per cell, a cut in one block does not have to be
!> matched by a cut in its neighbour: T-junctions resolve themselves.
!>
!> The file is regenerated in the canonical ATLAS order (block, face, n, m) that
!> MOSE_Mod_GhostExchange relies on to build contiguous face groups.
module split_bc_mod
  use decomposition_mod
  implicit none
  private

  public :: split_bc_level

  integer, parameter :: I8      = selected_int_kind(18)
  integer, parameter :: MAXLINE = 8192
  integer, parameter :: OBUFLEN = 4*1024*1024

  ! ── Image of the input file ────────────────────────────────────────────────
  character(len=:), allocatable :: buf
  integer(I8), allocatable      :: lstart(:), lend(:)
  integer(I8)                   :: nlines = 0

  ! ── Parsed records ─────────────────────────────────────────────────────────
  integer, allocatable :: rec_hdr(:)    !< line index of the record header
  integer, allocatable :: rec_np(:)     !< number of property lines that follow
  integer, allocatable :: rec_type(:)   !< ATLAS BC id
  integer, allocatable :: ord2rec(:)    !< canonical boundary-cell ordinal -> record
  integer              :: nrec = 0

  ! ── Buffered output ────────────────────────────────────────────────────────
  character(len=OBUFLEN) :: obuf
  integer                :: opos  = 0
  integer                :: ounit = 0

  character(len=1), parameter :: NL = achar(10)
  character(len=1), parameter :: CR = achar(13)

contains

  !> Split the BC file of one multigrid level.
  !> level 1 is the fine grid; level L works on dimensions divided by 2**(L-1).
  subroutine split_bc_level(dec, level, infile, outfile, ierr)
    type(decomposition_t), intent(inout) :: dec
    integer,               intent(in)    :: level
    character(len=*),      intent(in)    :: infile, outfile
    integer,               intent(out)   :: ierr
    ! Local
    integer :: s, b, p, d, f, m, n, r, t, c
    integer :: nm, nn, li, lj, lk, pi, pj, pk, pm, pn, ord, side, dir
    integer :: qi, qj, qk, ti, tj, tk, q, nb1, nb2, ncut, nused, nwritten, nrec_in
    integer :: don(4), cn(9)
    integer, allocatable :: ldim(:,:), llo(:,:), lhi(:,:)
    integer, allocatable :: obase(:), fbase(:,:), pnm(:,:), pnn(:,:)
    integer :: pd(3)
    real(8) :: vf
    character(len=MAXLINE) :: line

    ierr = 0
    s = 2**(level-1)

    ! ── Level-scaled parent dimensions and piece ranges ──────────────────────
    allocate(ldim(3,dec%nparent))
    allocate(llo(3,dec%npieces), lhi(3,dec%npieces))

    do b = 1, dec%nparent
      do d = 1, 3
        if (dec%pdim(d,b) == 1) then
          ldim(d,b) = 1
        else
          if (mod(dec%pdim(d,b), s) /= 0) then
            write(*,'(A,I0,A,I0,A,I0)') ' [ERROR] block ', b, ' dimension ', dec%pdim(d,b), &
              ' is not divisible by the multigrid ratio ', s
            ierr = 1; return
          endif
          ldim(d,b) = max(1, dec%pdim(d,b)/s)
        endif
      enddo
    enddo

    do p = 1, dec%npieces
      b = dec%piece(p)%parent
      do d = 1, 3
        if (ldim(d,b) == dec%pdim(d,b)) then
          llo(d,p) = dec%piece(p)%lo(d)
          lhi(d,p) = dec%piece(p)%hi(d)
        else
          llo(d,p) = (dec%piece(p)%lo(d) - 1)/s + 1
          lhi(d,p) = dec%piece(p)%hi(d)/s
        endif
      enddo
    enddo

    ! ── Canonical ordinal layout of the *input* file ─────────────────────────
    allocate(obase(dec%nparent), fbase(NFACES,dec%nparent))
    allocate(pnm(NFACES,dec%nparent), pnn(NFACES,dec%nparent))
    ord = 0
    do b = 1, dec%nparent
      obase(b) = ord
      do f = 1, NFACES
        call face_extent(f, ldim(:,b), nm, nn)
        pnm(f,b)   = nm
        pnn(f,b)   = nn
        fbase(f,b) = ord - obase(b)
        ord = ord + nm*nn
      enddo
    enddo

    call read_and_index(infile, ierr)
    if (ierr /= 0) return

    call parse_records(dec, ldim, obase, fbase, pnm, ord, ierr)
    if (ierr /= 0) then
      call cleanup(); return
    endif
    nrec_in = nrec

    ! ── Write the decomposed file ────────────────────────────────────────────
    open(newunit=ounit, file=outfile, access='stream', form='unformatted', &
         action='write', status='replace', iostat=ierr)
    if (ierr /= 0) then
      write(*,'(A)') ' [ERROR] cannot open '//trim(outfile)
      call cleanup(); return
    endif
    opos = 0

    ncut = 0; nused = 0; nwritten = 0

    do p = 1, dec%npieces
      b     = dec%piece(p)%parent
      pd(1) = lhi(1,p) - llo(1,p) + 1
      pd(2) = lhi(2,p) - llo(2,p) + 1
      pd(3) = lhi(3,p) - llo(3,p) + 1

      do f = 1, NFACES
        call face_extent(f, pd, nm, nn)
        dir  = face_dir(f)
        side = face_side(f)

        do n = 1, nn
          do m = 1, nm

            call fmn2ijk(f, m, n, pd, li, lj, lk)
            pi = llo(1,p) + li - 1
            pj = llo(2,p) + lj - 1
            pk = llo(3,p) + lk - 1

            if (on_parent_boundary(side, dir, p, b)) then

              ! ── Inherited boundary cell ─────────────────────────────────
              call ijk2mn(f, pi, pj, pk, pm, pn)
              ord = obase(b) + fbase(f,b) + (pn-1)*pnm(f,b) + pm
              r   = ord2rec(ord)
              if (r == 0) then
                write(*,'(A,4(X,I0))') ' [ERROR] missing BC record for (block,i,j,k):', b, pi, pj, pk
                ierr = 1; call finish(); return
              endif
              t = rec_type(r)
              nused = nused + 1

              call put_header(p, li, lj, lk, f, t)

              select case(t)

              case(101, 103, 201)
                call get_line(rec_hdr(r)+1, line)
                read(line,*,iostat=ierr) cn(1:9)
                if (ierr /= 0) then
                  write(*,'(A,I0)') ' [ERROR] malformed connection record at line ', rec_hdr(r)+1
                  call finish(); return
                endif
                call remap_cell(dec, ldim, llo, s, cn(1), cn(2), cn(3), cn(4), q, qi, qj, qk, ierr)
                if (ierr /= 0) then
                  write(*,'(A,4(X,I0))') ' [ERROR] connection donor outside the mesh:', cn(1:4)
                  call finish(); return
                endif
                write(line,'(9I8)') q, qi, qj, qk, cn(5), cn(6), cn(7), cn(8), cn(9)
                call put(trim(line)//NL)

              case(102)
                call get_line(rec_hdr(r)+1, line)
                read(line,*,iostat=ierr) nb1, nb2
                if (ierr /= 0) then
                  write(*,'(A,I0)') ' [ERROR] malformed chimera header at line ', rec_hdr(r)+1
                  call finish(); return
                endif
                write(line,'(2I8)') nb1, nb2
                call put(trim(line)//NL)
                do c = 1, nb1+nb2
                  call get_line(rec_hdr(r)+1+c, line)
                  read(line,*,iostat=ierr) don(1:4), vf
                  if (ierr /= 0) then
                    write(*,'(A,I0)') ' [ERROR] malformed chimera donor at line ', rec_hdr(r)+1+c
                    call finish(); return
                  endif
                  call remap_cell(dec, ldim, llo, s, don(1), don(2), don(3), don(4), q, qi, qj, qk, ierr)
                  if (ierr /= 0) then
                    write(*,'(A,4(X,I0))') ' [ERROR] chimera donor outside the mesh:', don(1:4)
                    call finish(); return
                  endif
                  write(line,'(4I8,E20.10)') q, qi, qj, qk, vf
                  call put(trim(line)//NL)
                enddo

              case default
                do c = 1, rec_np(r)
                  call put_raw(rec_hdr(r)+c)
                enddo

              end select

            else

              ! ── New internal cut: connect to the neighbouring piece ──────
              call neighbour_cell(dir, side, pi, pj, pk, ti, tj, tk)
              call remap_cell(dec, ldim, llo, s, b, ti, tj, tk, q, qi, qj, qk, ierr)
              if (ierr /= 0) then
                write(*,'(A,4(X,I0))') ' [ERROR] cut-plane neighbour not found:', b, pi, pj, pk
                call finish(); return
              endif
              call put_header(p, li, lj, lk, f, 101)
              write(line,'(9I8)') q, qi, qj, qk, face_opposite(f), 1, 0, 0, 1
              call put(trim(line)//NL)
              ncut = ncut + 1

            endif

            nwritten = nwritten + 1

          enddo
        enddo
      enddo
    enddo

    call finish()

    if (nused /= nrec_in) then
      write(*,'(A,I0,A,I0,A)') ' [ERROR] consumed ', nused, ' of ', nrec_in, ' input BC records'
      ierr = 1; return
    endif

    write(*,'(A,I0,A,I0,A,I0,A)') '   level '//itoa(level)//': ', nwritten, ' records (', &
      nused, ' inherited, ', ncut, ' new cut-plane connections)'

  contains

    logical function on_parent_boundary(sd, dr, pp, bb) result(res)
      integer, intent(in) :: sd, dr, pp, bb
      if (sd == 1) then
        res = (llo(dr,pp) == 1)
      else
        res = (lhi(dr,pp) == ldim(dr,bb))
      endif
    end function on_parent_boundary

    subroutine finish()
      call flush_out()
      if (ounit /= 0) then
        close(ounit); ounit = 0
      endif
      call cleanup()
    end subroutine finish

  end subroutine split_bc_level


  !> Cell just outside face (dir,side) of the current cell.
  pure subroutine neighbour_cell(dir, side, i, j, k, oi, oj, ok)
    integer, intent(in)  :: dir, side, i, j, k
    integer, intent(out) :: oi, oj, ok
    integer :: step

    step = 1
    if (side == 1) step = -1

    oi = i; oj = j; ok = k
    select case(dir)
    case(1);      oi = i + step
    case(2);      oj = j + step
    case default; ok = k + step
    end select

  end subroutine neighbour_cell


  !> Map a cell given in *parent* level-indices to the piece that owns it and
  !> the corresponding piece-local level indices. Indices outside the parent
  !> (ghost cells of a chimera donor list) are clamped for the lookup, so the
  !> returned local index stays the matching ghost of the owning piece.
  subroutine remap_cell(dec, ldim, llo, s, b, i, j, k, q, oi, oj, ok, ierr)
    type(decomposition_t), intent(inout) :: dec
    integer, intent(in)  :: ldim(:,:), llo(:,:), s, b, i, j, k
    integer, intent(out) :: q, oi, oj, ok, ierr
    integer :: ci, cj, ck, fi, fj, fk

    ierr = 0
    q = 0
    if (b < 1 .or. b > dec%nparent) then
      ierr = 1; return
    endif

    ci = min(max(i, 1), ldim(1,b))
    cj = min(max(j, 1), ldim(2,b))
    ck = min(max(k, 1), ldim(3,b))

    fi = lvl2fine(ci, ldim(1,b), dec%pdim(1,b), s)
    fj = lvl2fine(cj, ldim(2,b), dec%pdim(2,b), s)
    fk = lvl2fine(ck, ldim(3,b), dec%pdim(3,b), s)

    q = dec_locate(dec, b, fi, fj, fk)
    if (q == 0) then
      ierr = 1; return
    endif

    oi = i - llo(1,q) + 1
    oj = j - llo(2,q) + 1
    ok = k - llo(3,q) + 1

  end subroutine remap_cell


  !> First fine cell index covered by a coarse cell index.
  pure integer function lvl2fine(idx, ldim_, fdim_, s) result(f)
    integer, intent(in) :: idx, ldim_, fdim_, s
    if (ldim_ == fdim_) then
      f = idx
    else
      f = (idx-1)*s + 1
    endif
  end function lvl2fine


  !─────────────────────────────────────────────────────────────────────────────
  ! Input file handling

  subroutine read_and_index(infile, ierr)
    character(len=*), intent(in)  :: infile
    integer,          intent(out) :: ierr
    integer     :: u
    integer(I8) :: fsize, pos, il, count_lines
    logical     :: ex

    ierr = 0
    inquire(file=infile, exist=ex, size=fsize)
    if (.not. ex) then
      write(*,'(A)') ' [ERROR] BC file not found: '//trim(infile)
      ierr = 1; return
    endif

    allocate(character(len=fsize) :: buf)
    open(newunit=u, file=infile, access='stream', form='unformatted', &
         action='read', status='old', iostat=ierr)
    if (ierr /= 0) then
      write(*,'(A)') ' [ERROR] cannot open '//trim(infile)
      return
    endif
    read(u) buf
    close(u)

    ! Count lines
    count_lines = 0
    pos = 1
    do while (pos <= fsize)
      il = index(buf(pos:), NL)
      if (il == 0) then
        count_lines = count_lines + 1
        exit
      endif
      count_lines = count_lines + 1
      pos = pos + il
    enddo

    allocate(lstart(count_lines), lend(count_lines))
    nlines = 0
    pos    = 1
    do while (pos <= fsize)
      il = index(buf(pos:), NL)
      nlines = nlines + 1
      lstart(nlines) = pos
      if (il == 0) then
        lend(nlines) = fsize
        exit
      endif
      lend(nlines) = pos + il - 2
      pos = pos + il
    enddo

    ! Strip a trailing CR of DOS line endings
    do il = 1, nlines
      if (lend(il) >= lstart(il)) then
        if (buf(lend(il):lend(il)) == CR) lend(il) = lend(il) - 1
      endif
    enddo

  end subroutine read_and_index


  subroutine parse_records(dec, ldim, obase, fbase, pnm, ntot, ierr)
    type(decomposition_t), intent(in)  :: dec
    integer,               intent(in)  :: ldim(:,:), obase(:), fbase(:,:), pnm(:,:), ntot
    integer,               intent(out) :: ierr
    integer     :: h(6), np, nb1, nb2, pm, pn, ord
    integer(I8) :: il
    character(len=MAXLINE) :: line

    ierr = 0
    allocate(rec_hdr(nlines), rec_np(nlines), rec_type(nlines))
    allocate(ord2rec(ntot))
    ord2rec = 0
    nrec = 0

    il = 1
    do while (il <= nlines)

      if (lend(il) < lstart(il)) then
        il = il + 1; cycle
      endif
      call get_line(int(il), line)
      if (len_trim(line) == 0) then
        il = il + 1; cycle
      endif

      read(line,*,iostat=ierr) h(1:6)
      if (ierr /= 0) then
        write(*,'(A,I0,A)') ' [ERROR] cannot read a BC header (b i j k f type) at line ', il, ':'
        write(*,'(A)')      '         '//trim(line)
        if (nrec > 0) then
          write(*,'(A,I0,A)') '         the previous record has BC id ', rec_type(nrec), &
            ' - if that id carries a property line MDB did not expect,'
          write(*,'(A)')      '         the BC file uses ids this MOSE version no longer supports'
        else
          write(*,'(A)')      '         MDB supports 3-D meshes only (2-D files carry 5 fields per header)'
        endif
        return
      endif

      np = nprop_lines(h(6))
      if (h(6) == 102) then
        call get_line(int(il)+1, line)
        read(line,*,iostat=ierr) nb1, nb2
        if (ierr /= 0) then
          write(*,'(A,I0)') ' [ERROR] malformed chimera header at line ', il+1
          return
        endif
        np = 1 + nb1 + nb2
      endif

      nrec           = nrec + 1
      rec_hdr(nrec)  = int(il)
      rec_np(nrec)   = np
      rec_type(nrec) = h(6)

      ! Canonical ordinal of this boundary cell
      if (h(1) < 1 .or. h(1) > dec%nparent) then
        write(*,'(A,I0,A,I0)') ' [ERROR] BC record at line ', il, ' refers to block ', h(1)
        ierr = 1; return
      endif
      if (.not. consistent_face(h(5), h(2), h(3), h(4), ldim(:,h(1)))) then
        write(*,'(A,I0,A)') ' [ERROR] BC record at line ', il, &
          ' has indices inconsistent with its face: grid and BC file do not match'
        ierr = 1; return
      endif
      call ijk2mn(h(5), h(2), h(3), h(4), pm, pn)
      ord = obase(h(1)) + fbase(h(5),h(1)) + (pn-1)*pnm(h(5),h(1)) + pm
      if (ord < 1 .or. ord > ntot) then
        write(*,'(A,I0)') ' [ERROR] BC record out of range at line ', il
        ierr = 1; return
      endif
      if (ord2rec(ord) /= 0) then
        write(*,'(A,I0)') ' [ERROR] duplicate BC record at line ', il
        ierr = 1; return
      endif
      ord2rec(ord) = nrec

      il = il + 1 + np
    enddo

    if (nrec /= ntot) then
      write(*,'(A,I0,A,I0,A)') ' [ERROR] BC file holds ', nrec, ' records but the grid needs ', &
        ntot, ' - grid and BC file do not match'
      ierr = 1; return
    endif

  end subroutine parse_records


  !> Number of property lines following a header, matching the dispatch of
  !> MOSE_IO_BC::Check_BC exactly.
  pure integer function nprop_lines(t) result(np)
    integer, intent(in) :: t
    select case(t)
    case(101, 103, 201, 301:309, 401:408, 410, 420, 501:502)
      np = 1
    case(102)
      np = 1      ! caller replaces this with 1 + ni(1) + ni(2)
    case default
      np = 0
    end select
  end function nprop_lines


  pure logical function consistent_face(f, i, j, k, dim) result(res)
    integer, intent(in) :: f, i, j, k, dim(3)
    select case(f)
    case(1);      res = (i == 1)
    case(2);      res = (i == dim(1))
    case(3);      res = (j == 1)
    case(4);      res = (j == dim(2))
    case(5);      res = (k == 1)
    case(6);      res = (k == dim(3))
    case default; res = .false.
    end select
  end function consistent_face


  subroutine get_line(il, line)
    integer,                intent(in)  :: il
    character(len=MAXLINE), intent(out) :: line
    integer(I8) :: a, b

    line = ''
    if (il < 1 .or. il > nlines) return
    a = lstart(il)
    b = lend(il)
    if (b < a) return
    if (b - a + 1 > MAXLINE) b = a + MAXLINE - 1
    line = buf(a:b)

  end subroutine get_line


  !─────────────────────────────────────────────────────────────────────────────
  ! Buffered output

  subroutine put_header(b, i, j, k, f, t)
    integer, intent(in) :: b, i, j, k, f, t
    character(len=64) :: line
    write(line,'(6I8)') b, i, j, k, f, t
    call put(trim(line)//NL)
  end subroutine put_header


  !> Copy input line `il` to the output verbatim.
  subroutine put_raw(il)
    integer, intent(in) :: il
    if (il < 1 .or. il > nlines) return
    if (lend(il) < lstart(il)) then
      call put(NL)
    else
      call put(buf(lstart(il):lend(il))//NL)
    endif
  end subroutine put_raw


  subroutine put(s)
    character(len=*), intent(in) :: s
    if (opos + len(s) > OBUFLEN) call flush_out()
    obuf(opos+1:opos+len(s)) = s
    opos = opos + len(s)
  end subroutine put


  subroutine flush_out()
    if (opos > 0 .and. ounit /= 0) write(ounit) obuf(1:opos)
    opos = 0
  end subroutine flush_out


  subroutine cleanup()
    if (allocated(buf))      deallocate(buf)
    if (allocated(lstart))   deallocate(lstart)
    if (allocated(lend))     deallocate(lend)
    if (allocated(rec_hdr))  deallocate(rec_hdr)
    if (allocated(rec_np))   deallocate(rec_np)
    if (allocated(rec_type)) deallocate(rec_type)
    if (allocated(ord2rec))  deallocate(ord2rec)
    nlines = 0
    nrec   = 0
  end subroutine cleanup


  pure function itoa(n) result(s)
    integer, intent(in) :: n
    character(len=12)   :: b
    character(len=:), allocatable :: s
    write(b,'(I0)') n
    s = trim(adjustl(b))
  end function itoa

end module split_bc_mod
