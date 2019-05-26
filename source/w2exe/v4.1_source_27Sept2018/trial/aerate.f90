
  SUBROUTINE AERATE
  USE GLOBAL;USE MAIN; USE KINETIC; USE TRANS; USE SCREENC
  IMPLICIT NONE
  REAL, ALLOCATABLE, DIMENSION (:) ::  DZMULTA,SMASS,ATIMON,ATIMOFF,CUMDOMASS
  REAL, ALLOCATABLE, DIMENSION (:,:) ::  DZMULT
  INTEGER, ALLOCATABLE, DIMENSION (:) ::   IASEG,KTOPA,KBOTA,IPRB,KPRB
  REAL, ALLOCATABLE, DIMENSION (:) :: DOOFF,DOON
  REAL, ALLOCATABLE, DIMENSION (:) :: ACTUAL_MASS
  LOGICAL, ALLOCATABLE, DIMENSION (:) :: AERATEO2
  INTEGER NAER, NLAYERS, KTOP,KBOT
  CHARACTER(16) :: CONAER
  SAVE
  
  ALLOCATE(DZMULT(KMX,IMX))
   DZMULT=1.0
   OPEN(AERATEFN,FILE='W2_AERATE.NPT',STATUS='OLD')
   READ (AERATEFN,'(//I8,A16)')NAER,CONAER

     IF(NAER.EQ.0)NAER=1    
     ALLOCATE(DZMULTA(NAER),IASEG(NAER),KTOPA(NAER),KBOTA(NAER),SMASS(NAER),ATIMON(NAER),ATIMOFF(NAER),DOOFF(NAER),DOON(NAER),IPRB(NAER),KPRB(NAER),ACTUAL_MASS(NAER),AERATEO2(NAER),CUMDOMASS(NAER))
     DZMULTA=0.0; ACTUAL_MASS=0.0; CUMDOMASS=0.0
     READ(AERATEFN,1013)
1013 FORMAT(/)
      DO I=1,NAER
        READ(AERATEFN,'(I8,I8,I8,F8.0,F8.0,F8.0,3F8.0,2I8)')IASEG(I),KTOPA(I),KBOTA(I),SMASS(I),ATIMON(I),ATIMOFF(I),DZMULTA(I),DOOFF(I),DOON(I),IPRB(I),KPRB(I)
      END DO

	CLOSE(AERATEFN)

IF(RESTART_IN)THEN
  OPEN(AERATEFN,FILE=CONAER,POSITION='APPEND')
        JDAY1=0.0
        REWIND (AERATEFN)
        READ   (AERATEFN,'(//)')
        DO WHILE (JDAY1 < JDAY)
          READ (AERATEFN,'(F9.0)',END=106) JDAY1
        END DO
        BACKSPACE (AERATEFN)
        106     JDAY1=0.0
ELSE
  OPEN(AERATEFN,FILE=CONAER,STATUS='UNKNOWN')
  WRITE(AERATEFN,'(A,I3,A)')'OUTPUT FILE FOR AERATION INPUT WITH',NAER,' INPUT(S).'
  WRITE(AERATEFN,'(A114)')'JDAY,INSTMASSRATE#1(KGO2/D),CUMMASS#1(KGO2),DOPROBE#1(MG/L),INSTMASSRATE#2(KGO2/D),CUMMASS#2(KGO2),DOPROBE#2(MG/L)'
ENDIF
  DZMULT=1.0  ! ALWAYS RESET MIXING COEFFICIENT FOR AERATION SW IPC 2/01/01
 RETURN
 
 ENTRY DZAERATE   ! FROM W2_ MAIN CODE
    DO I=1,NAER
    DZ(KTOPA(I):KBOTA(I),IASEG(I))=DZ(KTOPA(I):KBOTA(I),IASEG(I))*DZMULT(KTOPA(I):KBOTA(I),IASEG(I))
    ENDDO   
 RETURN
    
 ENTRY AERATEMASS   ! FROM WQ_CONSTITUENTS

! SECTION FOR HYPOLIMNETIC AERATION 
 DZMULT=1.0   ! ALWAYS RESET TO 1.0 IN CASE NO AERATION
              DO II=1,NAER
                IF(JDAY.GE.ATIMON(II).AND.JDAY.LE.ATIMOFF(II))THEN

           ! FIND BRANCH AND WATERBODY FOR ISEG
                  DO JJB=1,NBR
                    IF(BR_INACTIVE(JJB))CYCLE  ! SW 6/12/2017
                    IF(IASEG(II).GE.US(JJB).AND.IASEG(II).LE.DS(JJB))THEN
                      EXIT
                    END IF
                  END DO

                  IF(JJB.EQ.JB)THEN   ! IF THIS BRANCH DOESN'T HAVE AERATION SKIP IT

                    KTOP=MAX(KTWB(JW),KTOPA(II))
                    KBOT=MIN(KB(IASEG(II)),KBOTA(II))

                    NLAYERS=KBOT-KTOP+1

                    AERATEO2(II)=.TRUE.

                    IF(O2(KPRB(II),IPRB(II)).GT.DOON(II).AND.O2(KPRB(II),IPRB(II)).GT.DOOFF(II))THEN
                      AERATEO2(II)=.FALSE.
                      ACTUAL_MASS(II)=0.0
                    END IF

                    IF(AERATEO2(II))THEN
                      ACTUAL_MASS(II)=SMASS(II)  ! SW 12/28/01
                      CUMDOMASS(II)=CUMDOMASS(II)+SMASS(II)*DLT/86400.
                      DO K=KTOP,KBOT
            
                        DZMULT(K,IASEG(II))=DZMULTA(II)   ! THIS MEANS THE INCREASE IN DZ IS LAGGED ONE TIME STEP
                        CSSB(K,IASEG(II),NDO)=CSSB(K,IASEG(II),NDO)+SMASS(II)/(86.4*REAL(NLAYERS))
! UNITS OF SMASS ARE IN KG/DAY
! TYPICAL UNITS OF CSSB: (MG/L)*(M3/S) TO OONVERT MULTIPLY BY (1KG/10^6MG)*(1000L/1M3)*(86400S/DAY)==86.4
                        
                      END DO          
                    END IF
                  END IF
                ELSE
                AERATEO2(II)=.FALSE.
                ACTUAL_MASS(II)=0.0
                END IF
                
              END DO

RETURN

ENTRY AERATEOUTPUT     ! FROM W2_MAIN CODE

        WRITE(AERATEFN,'(F9.3,<NAER>(1X,E12.3,1X,E12.3,1X,F8.3))')JDAY,(ACTUAL_MASS(II),CUMDOMASS(II),O2(KPRB(II),IPRB(II)),II=1,NAER)

RETURN
ENTRY DEALLOCATE_AERATE
DEALLOCATE(DZMULTA,IASEG,KTOPA,KBOTA,SMASS,ATIMON,ATIMOFF,DOOFF,DOON,IPRB,KPRB,ACTUAL_MASS,AERATEO2,CUMDOMASS)
DEALLOCATE(DZMULT)
CLOSE(AERATEFN)
RETURN
END