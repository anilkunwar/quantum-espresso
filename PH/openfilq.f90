!
! Copyright (C) 2001-2004 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!----------------------------------------------------------------------------
SUBROUTINE openfilq()
  !----------------------------------------------------------------------------
  !
  ! ... This subroutine opens all the files necessary for the phononq
  ! ... calculation.
  !
  USE kinds,          ONLY : DP
  USE control_flags, ONLY : modenum
  USE units_ph,       ONLY : iuwfc, iudwf, iubar, iucom, iudvkb3, &
                             iudrhous, iuebar, iudrho, iudyn, iudvscf, &
                             lrwfc, lrdwf, lrbar, lrcom, lrdvkb3, &
                             lrdrhous, lrebar, lrdrho, lint3paw, iuint3paw
  USE io_files,       ONLY : tmp_dir, diropn
  USE control_ph,     ONLY : epsil, zue, ext_recover, trans, elph, lgamma, &
                             tmp_dir_phq, start_irr, last_irr, xmldyn
  USE save_ph,        ONLY : tmp_dir_save
  USE ions_base,      ONLY : nat
  USE qpoint,         ONLY : nksq
  USE output,         ONLY : fildyn, fildvscf
  USE wvfct,          ONLY : nbnd, npwx
  USE grid_dimensions,ONLY : nr1x, nr2x, nr3x, nrxx
  USE lsda_mod,       ONLY : nspin
  USE uspp,           ONLY : nkb, okvan
  USE uspp_param,     ONLY : nhm
  USE io_files,       ONLY : prefix, iunigk
  USE noncollin_module, ONLY : npol, nspin_mag
  USE paw_variables,  ONLY : okpaw
  USE control_flags,  ONLY : twfcollect
  USE mp_global,      ONLY : me_pool
  USE io_global,      ONLY : ionode
  USE ramanm, ONLY: lraman, elop, iuchf, iud2w, iuba2, lrchf, lrd2w, lrba2
  !
  IMPLICIT NONE
  !
  INTEGER :: ios
  ! integer variable for I/O control
  CHARACTER (len=256) :: filint
  ! the name of the file
  LOGICAL :: exst
  ! logical variable to check file existe
  !
  REAL(DP) :: edum(1,1), wdum(1,1)
  INTEGER :: ndr, ierr
  !
  !
  IF (LEN_TRIM(prefix) == 0) CALL errore ('openfilq', 'wrong prefix', 1)
  !
  !     There are six direct access files to be opened in the tmp area
  !
  !     The file with the wavefunctions. In the lgamma case reads those
  !     written by pw.x. In the other cases those calculated by ph.x
  !
  tmp_dir=tmp_dir_phq
  IF (lgamma.AND.modenum==0) tmp_dir=tmp_dir_save
  iuwfc = 20
  lrwfc = 2 * nbnd * npwx * npol
  CALL diropn (iuwfc, 'wfc', lrwfc, exst)
  IF (.NOT.exst) THEN
     CALL errore ('openfilq', 'file '//trim(prefix)//'.wfc not found', 1)
  END IF
  !
  ! From now on all files are written with the _ph prefix
  !
  tmp_dir=tmp_dir_phq
  !
  !    The file with deltaV_{bare} * psi
  !
  iubar = 21
  lrbar = 2 * nbnd * npwx * npol
  CALL diropn (iubar, 'bar', lrbar, exst)
  IF (ext_recover.AND..NOT.exst) &
     CALL errore ('openfilq','file '//trim(prefix)//'.bar not found', 1)
  !
  !    The file with the solution delta psi
  !
  iudwf = 22
  lrdwf = 2 * nbnd * npwx * npol
  CALL diropn (iudwf, 'dwf', lrdwf, exst)
  IF (ext_recover.AND..NOT.exst) &
     CALL errore ('openfilq','file '//trim(prefix)//'.dwf not found', 1)
  !
  !   open a file with the static change of the charge
  !
  IF (okvan) THEN
     iudrhous = 25
     lrdrhous = 2 * nrxx * nspin_mag
     CALL diropn (iudrhous, 'prd', lrdrhous, exst)
     IF (ext_recover.AND..NOT.exst) &
        CALL errore ('openfilq','file '//trim(prefix)//'.prd not found', 1)
  ENDIF
  !
  !  Optional file(s) containing Delta\rho (opened and written in solve_e
  !  and solve_linter). Used for third-order calculations.
  !
  iudrho = 23
  lrdrho = 2 * nr1x * nr2x * nr3x * nspin_mag
  !
  !
  !   Here the sequential files
  !
  !   The igk at a given k (and k+q if q!=0)
  !
  iunigk = 24
  IF (nksq > 1) CALL seqopn (iunigk, 'igk', 'unformatted', exst)
  !
  !   a formatted file which contains the dynamical matrix in cartesian
  !   coordinates is opened in the current directory

  !   ... by the first node only, other nodes write on unit 6 (i.e./dev/null
  !   exception: electron-phonon calculation from saved data
  !  (iudyn is read, not written, by all nodes)
  !
  IF ( ( .NOT. ionode ) .AND. (.NOT.elph.OR.trans) ) THEN
     iudyn = 6
     GOTO 400
  ENDIF

  IF (((trans.AND.(start_irr/=0.OR.last_irr/=0)).OR.elph).AND..NOT.xmldyn) THEN
     iudyn = 26
     OPEN (unit=iudyn, file=fildyn, status='unknown', err=100, iostat=ios)
100  CALL errore ('openfilq', 'opening file'//fildyn, ABS (ios) )
     REWIND (iudyn)
  ELSE
     iudyn=0
  ENDIF
  !
  !   An optional file for electron-phonon calculations containing deltaVscf
  !
400 IF (fildvscf.NE.' ') THEN
     iudvscf = 27
     IF ( me_pool == 0 ) THEN
        CALL diropn (iudvscf, fildvscf, lrdrho, exst)
        IF (okpaw) THEN
           filint=TRIM(fildvscf)//'_paw'
           lint3paw = 2 * nhm * nhm * 3 * nat * nspin_mag
           iuint3paw=34
           CALL diropn (iuint3paw, filint, lint3paw, exst)
        ENDIF
     END IF
  END IF
  !
  !    In the USPP case we need two files for the Commutator, the first is
  !    given by filbar and a second which just contains P_c x |psi>,
  !    which is required for the calculation of the Born effective carges
  !
  IF (okvan .AND. (epsil .OR. zue)) THEN
     iucom = 28
     lrcom = 2 * nbnd * npwx * npol
     CALL diropn (iucom, 'com', lrcom, exst)
     IF (ext_recover.AND..NOT.exst) &
         CALL errore ('openfilq', 'file '//trim(prefix)//'.com not found', 1)
  !
  !    In the USPP case we also need a file in  order to store derivatives
  !    of kb projectors
  !
     iudvkb3 = 29
     lrdvkb3 = 2 * npwx * nkb * 3
     CALL diropn (iudvkb3, 'dvkb3', lrdvkb3, exst)
     IF (ext_recover.AND..NOT.exst) &
         CALL errore ('openfilq', 'file '//trim(prefix)//'.dvkb3 not found', 1)
  ENDIF
  IF (epsil .OR. zue) THEN
     iuebar = 30
     lrebar = 2 * nbnd * npwx * npol
     CALL diropn (iuebar, 'ebar', lrebar, exst)
     IF (ext_recover.AND..NOT.exst) &
        CALL errore ('openfilq','file '//trim(prefix)//'.ebar not found', 1)
  ENDIF
  !
  !    files used by raman calculation
  !
  IF (lraman .OR.elop) THEN
     iuchf = 31
     lrchf = 2 * nbnd * npwx * npol
     CALL diropn (iuchf, 'cwf', lrchf, exst)

     iud2w = 32
     lrd2w = 2 * nbnd * npwx * npol
     CALL diropn (iud2w, 'd2w', lrd2w, exst)

     iuba2 = 33
     lrba2 = 2 * nbnd * npwx * npol
     CALL diropn(iuba2, 'ba2', lrba2, exst)
  ENDIF

  RETURN
  !
END SUBROUTINE openfilq
