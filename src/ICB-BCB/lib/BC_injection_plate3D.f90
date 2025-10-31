module BC_build_plate
  use ATLAS_high_level
  use finer, only: file_ini
  implicit none

  type, abstract :: plate_file_type
    character(len=256)   :: name
    integer              :: length
    integer, allocatable :: id(:) 
  end type plate_file_type

  type, extends(plate_file_type) :: real_plate_type
    real(8), allocatable :: center(:,:)
    real(8), allocatable :: radius(:)
  end type real_plate_type

  type, extends(plate_file_type) :: KAFFS_plate_type  
    character(len=256)   :: Plateshape
    integer, allocatable :: inj_row(:) 
    real(8), allocatable :: phase_row(:)
    character(3)         :: Side
  end type 

   real(8), parameter             :: pi=4.0*atan(1.0)
   real(8), allocatable           :: Atot(:)

contains

    subroutine Build_Sectors(plate_file,face,A_face,Inj_phi_R,dir)
      implicit none
      class(KAFFS_plate_type), intent(inout) :: plate_file
      type(obj_face), intent(in)         :: face
      integer, intent(in)                :: dir(:)
      real(8), intent(in)                :: A_face
      real(8), allocatable               :: Inj_phi_R(:,:)
      real(8)                            :: Aplate, A_per_inj, Ak, phamin, phamax, pha
      real(8), allocatable               :: Rmin(:),Rmax(:),Dpha(:)
      integer                            :: injid, mj,spare,ncheck,ncount, ninj, m, n



      if (plate_file%Plateshape=='Round'.or.plate_file%Plateshape=='round') then
        !Round chamber 3D
        injid = 0
        ninj = sum(plate_file%inj_row(:))
        A_per_inj = A_face/ninj
        allocate(Rmin(plate_file%length),Rmax(plate_file%length),Dpha(plate_file%length))
        allocate(Inj_phi_R(4,ninj))
        do m = 1,plate_file%length
          Ak = plate_file%inj_row(m) * A_per_inj
          !Creating radial sectors (Rmax,Rmin)
          if (m==1) then
            Rmin(m) = 0
            Rmax(m) = sqrt(Ak/pi)
          elseif (m==plate_file%length) then
            Rmax(m) = sqrt(A_face/pi)
            Rmin(m) = sqrt(Rmax(m)**2 - Ak/pi)
          else
            Rmin(m) = Rmax(m-1)
            Rmax(m) = sqrt(Rmin(m)**2 + Ak/pi)
          endif
            !Creating angular sectors (Phimax,Phimin)
          Dpha(m) = 2*pi/(plate_file%inj_row(m))

          do mj = 1,plate_file%inj_row(m)
            injid = injid + 1 
            if (plate_file%inj_row(m)==1) then 
              phamin = 0.0
              phamax = 2*pi
            else
              pha = plate_file%phase_row(m) + (mj-1)*Dpha(m)
              phamin = pha - Dpha(m)*0.5
              phamax = pha + Dpha(m)*0.5
                if (phamin<0) then
                    phamin = phamin + 2*pi
                endif
                if (phamin>2*pi) then
                    phamin = phamin - 2*pi
                endif
                if (phamax<0) then
                    phamin = phamin + 2*pi
                endif
                if (phamax>2*pi) then
                    phamin = phamin - 2*pi
                endif
            endif
              !Rmax
              Inj_phi_R(1, injid) = Rmax(m)
              !Rmin
              Inj_phi_R(2, injid) = Rmin(m)
              !Phimax
              Inj_phi_R(3, injid) = phamax
              !Phimin
              Inj_phi_R(4, injid) = phamin
              
          enddo
        enddo
      elseif (plate_file%Plateshape=='Square'.or.plate_file%Plateshape=='square') then
         !Squared plate
          ! Injectors are supposed lined-up on the longest side/direction of the rectangular engine
          ! Each injector has two index along such direction. We just have to check if n-min(inj) <n< n-max(inj) or m-min(inj) <m< m-max(inj)
        ninj = sum(plate_file%inj_row(:))
        allocate(Inj_phi_R(4,ninj))
        A_per_inj = A_face/ninj
        injid = 1
        !Looking for the longest side of the chamber plate
        if (abs(face%center(1,face%Nn)%c(dir(2))-face%center(1,1)%c(dir(2)))>abs(face%center(face%Nm,1)%c(dir(1))-face%center(1,1)%c(dir(1)))) then
          !Nn is the longest
          plate_file%Side = 'n'
          spare = (real(face%Nn)/real(ninj) - floor(real(face%Nn)/real(ninj)))*ninj
          ncount = 1
          ncheck = 0
          do n = 1,face%Nn
              do m = 1,face%Nm
                  !Skip
              enddo
              if (n<(floor(real(face%Nn)/real(ninj))*(injid)+ncheck)) then
                if (n==1) then
                Inj_phi_R(1,injid) = 1 
                endif
                Inj_phi_R(2,injid) = n
              else
                if (ncount==2.and.ncheck<spare) then
                  Inj_phi_R(2,injid) = n
                  ncount = 0
                  ncheck = ncheck + 1
                else
                  Inj_phi_R(2,injid) = n
                  ncount = ncount + 1
                  injid = injid + 1
                  Inj_phi_R(1,injid) = n+1
                endif
              endif
          enddo
              Inj_phi_R(1,ninj) = face%Nn
        else
          !Nm is the longest
          plate_file%Side = 'm'
          spare = (real(face%Nm)/real(ninj) - floor(real(face%Nm)/real(ninj)))*ninj
          ncount = 0
          ncheck = 0
          do m = 1,face%Nm
              do n = 1,face%Nn
                !Skip
              enddo
            if (m<(floor(real(face%Nm)/real(ninj))*(injid)+ncheck)) then
            
            if (m==1) then
            Inj_phi_R(1,injid) = 1 
            endif
            Inj_phi_R(2,injid) = m
            else
            if (ncount==2.and.ncheck<spare) then
                Inj_phi_R(2,injid) = m
                ncount = 0
                ncheck = ncheck + 1
            else
                Inj_phi_R(2,injid) = m
                ncount = ncount + 1
                injid = injid + 1
                Inj_phi_R(1,injid) = m+1
            endif
            endif
          enddo
          Inj_phi_R(2,ninj) = face%Nm
        endif
      endif
    end subroutine Build_Sectors

    subroutine Injector_mapping(plate_file,here,Inj_phi_R,n,m,face,A_inj,type_,dir,ini_o)
        implicit none
        class(KAFFS_plate_type), intent(inout) :: plate_file
        type(file_ini), intent(inout)      :: ini_o
        type(obj_face), intent(inout)      :: face
        integer, intent(in)                :: n, m, type_, dir(:)
        real(8), intent(in)                :: here(2)
        real(8), intent(inout)             :: A_inj(:)
        REAL(8), intent(in)                :: Inj_phi_R(:,:)
        real(8)                            :: rinj, anginj, angmin, angmax
        integer                            :: ninj, cnt_bc


        if (plate_file%Plateshape=='Round'.or.plate_file%Plateshape=='round') then
          do ninj = 1,size(Inj_phi_R(1,:))
            !Distance from the center of the plate
            rinj = sqrt(here(1)**2 + here(2)**2)
            ! Associated angle
            anginj = atan2(here(2),here(1))

            if (anginj<0) anginj = anginj + 2*pi
            angmin = Inj_phi_R(4,ninj);
            angmax = Inj_phi_R(3,ninj);
            if (angmin>angmax) then
            angmin = angmin-2*pi
            if (anginj>pi) then
                anginj = anginj - 2*pi
            endif
            endif

            !Check if : Rmin(inj)  <r-cell< Rmax(inj)  .and. Anglemin(inj)  < angle-cell < Anglemax(inj) 
            if ((Inj_phi_R(2,ninj) <= rinj) .and. (Inj_phi_R(1,ninj) >= rinj) .and. (angmin <= anginj) .and. (angmax >= anginj)) then
                cnt_bc = cnt_bc + 1
                face%center(m,n)%bc%definition = type_
                A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area  
                call ini_o%add(section_name='cell', option_name='id_inj', val= ninj) 
                exit
            else
            if (ninj==size(Inj_phi_R(1,:))) then
                stop 'Plate is not fully covered, cell is missing an injector'
            endif
            endif
          enddo
          
        elseif (plate_file%Plateshape=='Square'.or.plate_file%Plateshape=='square') then
          !Squared plate
          ! Injectors are supposed lined-up on the longest side/direction of the rectangular engine
          ! Each injector has two index along such direction. We just have to check if n-min(inj) <n< n-max(inj) or m-min(inj) <m< m-max(inj)
          do ninj = 1,size(Inj_phi_R(1,:))
            if (plate_file%Side=='n') then

              if (Inj_phi_R(1,ninj)<=n .and. Inj_phi_R(2,ninj)>=n) then
                cnt_bc = cnt_bc + 1
                face%center(m,n)%bc%definition = type_
                A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area  
                call ini_o%add(section_name='cell', option_name='id_inj', val= ninj) 
              endif
            elseif (plate_file%Side=='m') then

              if (Inj_phi_R(1,ninj)<=m .and. Inj_phi_R(2,ninj)>=m)  then
                cnt_bc = cnt_bc + 1
                face%center(m,n)%bc%definition = type_
                A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area  
                call ini_o%add(section_name='cell', option_name='id_inj', val= ninj) 
              endif
            endif
          enddo
        endif

    end subroutine Injector_mapping

    subroutine Full_plate_2D(plate_file, face, n, m ,dir, Inj_phi_R,type_,A_inj,z_input,ini_o)
        class(KAFFS_plate_type), intent(inout) :: plate_file
        type(file_ini), intent(inout)          :: ini_o
        type(obj_face), intent(inout)          :: face
        integer, intent(in)                    :: dir(:)
        integer, intent(in)                    :: type_, n ,m
        real(8), intent(in)                    :: z_input
        real(8), intent(inout)                 :: A_inj(:)
        REAL(8), allocatable                   :: Inj_phi_R(:,:)
        integer                                :: ninj, cnt_bc
        integer                                :: injid, mj, spare, ncheck, ncount, mm, nn
    
       
        ninj = sum(plate_file%inj_row(:))
        allocate(Inj_phi_R(4,ninj))
        ! Injectors are supposed lined-up on the longest side/direction of the rectangular engine
        ! Each injector has two index along such direction. We just have to check if n-min(inj) <n< n-max(inj) or m-min(inj) <m< m-max(inj)
         if (abs(face%center(1,face%Nn)%c(dir(1))-face%center(1,1)%c(dir(1)))>abs(face%center(face%Nm,1)%c(dir(1))-face%center(1,1)%c(dir(1)))) then
         spare = (real(face%Nn)/real(ninj) - floor(real(face%Nn)/real(ninj)))*ninj
         injid  = 1
         ncount = 1
         ncheck = 0
         plate_file%Side = 'n'
         do nn = 1,face%Nn
           do mm = 1,face%Nm
             !skip
           enddo
            if (nn<(floor(real(face%Nn)/real(ninj))*(injid)+ncheck)) then
              if (nn==1) then
              Inj_phi_R(1,injid) = 1 
              endif
              Inj_phi_R(2,injid) = nn
            else
              if (ncount==2.and.ncheck<spare) then
                Inj_phi_R(2,injid) = nn
                ncount = 0
                ncheck = ncheck + 1
              else
                Inj_phi_R(2,injid) = nn
                ncount = ncount + 1
                injid = injid + 1
                Inj_phi_R(1,injid) = nn+1
              endif
            endif
          enddo
         else
         plate_file%Side = 'm'
         spare = (real(face%Nm)/real(ninj) - floor(real(face%Nm)/real(ninj)))*ninj
         ncount = 0
         ncheck = 0
         do mm = 1,face%Nm
           do nn = 1,face%Nn
             !skip
           enddo
           if (mm<(floor(real(face%Nm)/real(ninj))*(injid)+ncheck)) then
             if (mm==1) then
             Inj_phi_R(1,injid) = 1 
             endif
             Inj_phi_R(2,injid) = mm
           else
             if (ncount==2.and.ncheck<spare) then
               Inj_phi_R(2,injid) = mm
               ncount = 0
               ncheck = ncheck + 1
             else
               Inj_phi_R(2,injid) = mm
               ncount = ncount + 1
               injid = injid + 1
               Inj_phi_R(1,injid) = mm+1
             endif
             endif
           enddo
         endif
       
        do ninj = 1,size(Inj_phi_R(1,:))
        if (plate_file%Side=='n') then
            if (Inj_phi_R(1,ninj)<=n .and. Inj_phi_R(2,ninj)>=n) then
              cnt_bc = cnt_bc + 1
              face%center(m,n)%bc%definition = type_
              A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area * z_input  
              call ini_o%add(section_name='cell', option_name='id_inj', val= ninj) 
            endif
        elseif (plate_file%Side=='m') then
            if (Inj_phi_R(1,ninj)<=m .and. Inj_phi_R(2,ninj)>=m)  then
              cnt_bc = cnt_bc + 1
              face%center(m,n)%bc%definition = type_
              A_inj(ninj) = A_inj(ninj) + face%center(m,n)%area * z_input
              call ini_o%add(section_name='cell', option_name='id_inj', val= ninj) 
            endif
        endif
        enddo
    end subroutine Full_plate_2D

end module BC_build_plate