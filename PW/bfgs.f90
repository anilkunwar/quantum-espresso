!
! Copyright (C) 2001 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!-----------------------------------------------------------------------
subroutine bfgs
  !-----------------------------------------------------------------------
  ! ionic relaxation through broyden-fletcher-goldfarb-shanno minimization
  ! this version saves data at each iteration
  !
  ! etxcc is added to the energy in order to have consistency with forces
  !
#include "machine.h"
  use pwcom
#ifdef __PARA
  use para
#endif
  implicit none

  integer :: iunit          ! unit for filebfgs
  integer :: nat1,        & ! number of moving atoms
             nat3,        & ! 3 times the above
             nax3,        & ! 3 times the total number of atoms (nat)
             na, i          ! counters
  real(kind=DP), allocatable :: &
             hessm1 (:,:),& ! current estimate of hessian^-1
             dtau (:,:),  & ! direction (versor) for line minimization
             oldforce (:,:) ! gradient along minimization direction
  real(kind=DP) :: &
             detot,       & ! forces at previous line minimum (LM)
             deold,       & ! as above at previous LM
             eold,        & ! energy at previous LM
             xold,        & ! position along dtau at previous LM
             x,           & ! present position along dtau
             xnew           ! next position along dtau

  logical :: exst,       & ! test variable on existence of filebfgs
             minimum_ok    ! true if linmin found a good line minimum

  real(kind=DP) :: DDOT


#ifdef __PARA
  include 'mpif.h'
  integer :: root, errcode
  !
  ! only one node does the calculation in the parallel case
  !

  if (me.eq.1.and.mypool.eq.1) then
#endif
     allocate ( hessm1(3*nat,3*nat), dtau(3,nat), oldforce(3,nat) )
     !
     iunit = 4
     nat1 = nat - fixatom
     if (nat1.lt.1.or.nat.eq.1) then
        call errore ('bfgs', 'not enough atoms to move', - 1)
        conv_ions = .true.
        goto 100
     endif
     nax3 = 3 * nat
     nat3 = 3 * nat1
     conv_ions = .false.
     !
     call seqopn (iunit, 'filebfgs', 'unformatted', exst)
     !
     if (.not.exst) then
        !
        ! file 'filebfgs' not found: starting iteration
        !
        close (unit = iunit, status = 'delete')
        minimum_ok = .false.
        call estimate (hessm1, nax3, nat, nat3)
        write (6, '(/5x,"EPSE = ",e9.2,"    EPSF = ",e9.2, &
             &"    UPSCALE = ",f6.2)') epse, epsf, upscale
     else
        !
        ! file 'filebfgs' found: restart from preceding iterations
        !
        read (iunit) minimum_ok, xnew, starting_scf_threshold, &
             starting_diag_threshold
        read (iunit) dtau
        read (iunit) hessm1
        read (iunit) xold, eold, deold, oldforce
        close (unit = iunit, status = 'keep')

     endif
20   continue
     if (exst.and..not.minimum_ok) then
        !
        ! Search for a new line minimum
        !
        x = xnew
        detot = - DDOT (nat3, force, 1, dtau, 1)
        !
        ! line minimization with 3rd order interpolation formula
        !
        call linmin (xold, eold, deold, x, etot + etxcc, detot, &
             xnew, minimum_ok)
        !
        ! xnew close to x: line minimization already achieved
        !
        if (abs ( (xnew - x) / x) .lt.0.05d0.and.minimum_ok) goto &
             20
             !
             ! new positions (hopefully close to the line minimum) :
             !
        call DAXPY (nat3, (xnew - x) / alat, dtau, 1, tau, 1)
        if (.not.minimum_ok) then
           !
           ! line minimum was not found take another step and reset
           ! the starting point of the line minimization to the present position
           !
           xold = x
           eold = etot + etxcc
           deold = detot
           call DCOPY (nat3, force, 1, oldforce, 1)

        endif
     else
        if (exst) then
           !
           ! We (hopefully) are at the line minimum: convergence check
           !
           conv_ions = eold- (etot + etxcc) .lt.epse
           do i = 1, 3
              do na = 1, nat1
                 conv_ions = conv_ions.and.abs (force (i, na) ) .lt.epsf
              enddo
           enddo
           !
           ! update the inverse hessian
           !
           ! set dtau to the true displacements from previous to present LM
           !
           call DSCAL (nat3, (xnew - xold), dtau, 1)
           call updathes (nax3, nat3, oldforce, force, hessm1, dtau)
        endif
        !
        ! find new minimization direction dtau
        !
        x = 0.d0
        minimum_ok = .false.
        call setv (nat3, 0.d0, dtau, 1)
        call DGEMV ('n', nat3, nat3, 1.d0, hessm1, nax3, force, 1, &
             0.d0, dtau, 1)
        xnew = sqrt (DDOT (nat3, dtau, 1, dtau, 1) )
        call DSCAL (nat3, 1.d0 / xnew, dtau, 1)
        !
        ! ... and the gradient along the minimization direction dtau
        !
        detot = - DDOT (nat3, force, 1, dtau, 1)
        !
        if (detot.gt.0.d0) then
           write (6, '("uphill direction! de/dx =",e10.4)') detot
           write (6, '("try steepest descent direction instead!")')
           call DCOPY (nat3, force, 1, dtau, 1)
           xnew = sqrt (DDOT (nat3, dtau, 1, dtau, 1) )
           call DSCAL (nat3, 1.d0 / xnew, dtau, 1)
           detot = - DDOT (nat3, force, 1, dtau, 1)
        endif
        !
        ! update atomic positions. NB: tau in units of alat!
        !
        call DAXPY (nat3, (xnew - x) / alat, dtau, 1, tau, 1)
        !
        ! save values of variables at line minimum for later use
        !
        xold = x
        eold = etot + etxcc
        deold = detot
        call DCOPY (nat3, force, 1, oldforce, 1)
        !
     endif
     !
     ! set appropriate (?) thresholds for self-consistency
     !
     if (imix.lt.0) then
        tr2 = (starting_scf_threshold * max (1.d0 / upscale, min (1.d0, &
             abs (xnew - x) / dtau_ref) ) ) **2
        ethr = starting_diag_threshold * max (1.d0 / upscale, min ( &
             1.d0, abs (xnew - x) / dtau_ref) ) **2
     else
        ethr = tr2 / nelec
        tr2 = starting_scf_threshold * &
                       max( 1.d0/upscale, abs(xnew-x)/dtau_ref )
     end if
     !
     ! report
     !
     if (conv_ions) then
        write (6, '(/5x,"BFGS: convergence achieved, Efinal=",f15.8)') etot
        write (6, '(/72("-")//5x,"Final estimate of positions")')
     else
        write (6, '(/72("-")//5x, &
             &"Search of equilibrium positions: iteration # ",i4, &
             &", scf threshold ",1pe8.2/)') istep, tr2
     endif
     if (ltaucry) write (6, '(/5x,"Cartesian coordinates")')
     do na = 1, nat
        write (6,'(a3,3x,3f14.9)') atm(ityp(na)), (tau(i,na), i=1,3)
     enddo
     if (ltaucry) then
        write (6, '(/5x,"In crystal coordinates")')
        call cryst_to_cart (nat, tau, bg, - 1)
        do na = 1, nat
           write (6,'(a3,3x,3f14.9)') atm(ityp(na)), (tau(i,na), i=1,3)
        enddo
        call cryst_to_cart (nat, tau, at, 1)

     endif
     write (6, '(/)')
     !
     ! save all quantities needed at the following iterations
     !
     if (.not.conv_ions) then
        call seqopn (iunit, 'filebfgs', 'unformatted', exst)
        write (iunit) minimum_ok, xnew, starting_scf_threshold, &
             starting_diag_threshold
        write (iunit) dtau
        write (iunit) hessm1
        write (iunit) xold, eold, deold, oldforce
        close (unit = iunit, status = 'keep')

     endif
     deallocate (hessm1,dtau,oldforce)

100  continue
#ifdef __PARA
  endif
  !
  ! broadcast calculated quantities to all nodes
  !
  root = 0
  call MPI_bcast (conv_ions, 1, MPI_LOGICAL, root, MPI_COMM_WORLD, errcode)
  call MPI_bcast (tau, 3 * nat, MPI_REAL8, root, MPI_COMM_WORLD, errcode)
  call MPI_bcast (ethr, 1, MPI_REAL8, root, MPI_COMM_WORLD, errcode)
  call MPI_bcast (tr2, 1, MPI_REAL8, root, MPI_COMM_WORLD, errcode)
#endif
  return
end subroutine bfgs

