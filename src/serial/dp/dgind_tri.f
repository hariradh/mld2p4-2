      SUBROUTINE DGIND_TRI(M,N_BLOCKS,A,IA1,IA2,ARN,KA,IA,JA,
     +     LARN,LKA,LJA,IPERM,WORK, LWORK, IERROR)

      IMPLICIT NONE
      INCLUDE  'sparker.fh'

C     ... Scalar arguments ...

      INTEGER          M, LWORK,N_BLOCKS,LARN,LKA,LJA, IERROR

C     ... Array arguments ...

      DOUBLE PRECISION A(*), ARN(*), WORK(*)
      INTEGER          IA1(*), IA2(*), KA(*), 
     +     IA(3,*), IPERM(M), JA(*)
      
C     .... Local scalars ...
      INTEGER          I, J, BLOCK, ROW, COL, POINT_AR, POINT_JA,
     +     DIM_BLOCK, LIMIT
      LOGICAL          CSR
c     .. Local Arrays ..
      CHARACTER*20       NAME
      INTEGER            INT_VAL(5)

      NAME = 'DGIND_TRI\0'
      IERROR = 0
      CALL FCPSB_ERRACTIONSAVE(ERR_ACT)

      POINT_AR = 1
      POINT_JA = 0
      IERROR   = 0

      IF ((LARN.LT.POINT_AR).OR.(LKA.LT.POINT_AR)) THEN
         IERROR = 60
         INT_VAL(1) = 10
         INT_VAL(2) = POINT_AR
         INT_VAL(3) = LARN
         CALL FCPSB_ERRPUSH(IERROR,NAME,INT_VAL)
         GOTO 9999
      ENDIF

C     .... Invert Permutation Matrix...
      IF (IPERM(1).NE.0) THEN
         DO I = 1, M
            WORK(IPERM(I)) = I
         ENDDO
      ENDIF

      DO BLOCK = 1, N_BLOCKS
         COL = 1
         DIM_BLOCK = IA(1,BLOCK+1)-IA(1,BLOCK)
         LIMIT = INT(DIM_BLOCK*PERCENT)
         POINT_JA = POINT_JA+1
         IF (LJA.LT.POINT_JA) THEN
            IERROR = 60
            INT_VAL(1) = 12
            INT_VAL(2) = POINT_JA
            INT_VAL(3) = LJA
            CALL FCPSB_ERRPUSH(IERROR,NAME,INT_VAL)
            GOTO 9999
         ENDIF

         IA(2,BLOCK) = POINT_JA
         JA(POINT_JA) = POINT_AR
         CSR = .FALSE.
         
         IF (DIM_BLOCK.NE.0) THEN
C     ... If current block is not empty ...
C     ... For each Column belonging to Block ...
            DO WHILE(.TRUE.)
C     ... For each row belonging to the block BLOCK ...
               DO I = IA(1,BLOCK), IA(1,BLOCK+1)-1
                  IF (IPERM(1).EQ.0) THEN
                     ROW = I
                  ELSE
                     ROW = WORK(I)
                  ENDIF
                  
C     ... If the current row is too short ...
                  IF (IA2(ROW)+COL-1.GE.IA2(ROW+1)) THEN
C     ... Switch to CSR representation ...
                     IF (I.LE.IA(1,BLOCK)+LIMIT) THEN
                        CSR=.TRUE.
                        POINT_AR = POINT_AR - I + IA(1,BLOCK)
                        GOTO 998
                     ELSE
                        ARN(POINT_AR) = 0.D0
C     
C     The following statement assumes that we never get here with POINT_AR=1
C     
                        KA (POINT_AR) = KA(POINT_AR-1)

                        POINT_AR = POINT_AR+1
                        IF ((LARN.LT.POINT_AR).OR.(LKA.LT.POINT_AR))
     +                       THEN
                           IERROR = 60
                           INT_VAL(1) = 10
                           INT_VAL(2) = POINT_AR
                           INT_VAL(3) = LARN
                           CALL FCPSB_ERRPUSH(IERROR,NAME,INT_VAL)
                           GOTO 9999
                        ENDIF
                     ENDIF
                  ELSE
                     ARN(POINT_AR) = A(IA2(ROW)+COL-1)
                     KA (POINT_AR) = IPERM(IA1(IA2(ROW)+COL-1))

                     POINT_AR = POINT_AR+1
                     IF ((LARN.LT.POINT_AR).OR.(LKA.LT.POINT_AR)) THEN
                        IERROR = 60
                        INT_VAL(1) = 10
                        INT_VAL(2) = POINT_AR
                        INT_VAL(3) = LARN
                        CALL FCPSB_ERRPUSH(IERROR,NAME,INT_VAL)
                        GOTO 9999
                     ENDIF
                  ENDIF
               ENDDO

               IF (CSR) GOTO 998

               IF (LJA.LT.POINT_JA+COL) THEN
                  IERROR = 60
                  INT_VAL(1) = 12
                  INT_VAL(2) = POINT_JA
                  INT_VAL(3) = LJA
                  CALL FCPSB_ERRPUSH(IERROR,NAME,INT_VAL)
                  GOTO 9999
               ENDIF
               
               JA(POINT_JA+COL) = POINT_AR
               COL = COL+1
            ENDDO
 998        CONTINUE 

         ENDIF

         POINT_JA = POINT_JA+COL-1
         
         IF (LJA.LT.POINT_JA) THEN
            IERROR = 60
            INT_VAL(1) = 12
            INT_VAL(2) = POINT_JA
            INT_VAL(3) = LJA
            CALL FCPSB_ERRPUSH(IERROR,NAME,INT_VAL)
            GOTO 9999
         ENDIF

         IA(3,BLOCK) = POINT_JA
         
C     ... Start CSR Format ...
         
C     ... For each row belonging to the block BLOCK ...
         DO I = IA(1,BLOCK), IA(1,BLOCK+1)-1
            IF (IPERM(1).EQ.0) THEN
               ROW = I
            ELSE
               ROW = WORK(I)
            ENDIF

C     ... For each nnzero elements belonging to current row ...
            DO J = IA2(ROW)+COL-1, IA2(ROW+1)-1
               ARN(POINT_AR) = A(J)
               KA (POINT_AR) = IPERM(IA1(J))

               POINT_AR = POINT_AR+1
               IF ((LARN.LT.POINT_AR).OR.(LKA.LT.POINT_AR)) THEN
                  IERROR = 60
                  INT_VAL(1) = 10
                  INT_VAL(2) = POINT_AR
                  INT_VAL(3) = LARN
                  CALL FCPSB_ERRPUSH(IERROR,NAME,INT_VAL)
                  GOTO 9999
               ENDIF
            ENDDO

            POINT_JA = POINT_JA+1
            IF (LJA.LT.POINT_JA) THEN
               IERROR = 60
               INT_VAL(1) = 12
               INT_VAL(2) = POINT_JA
               INT_VAL(3) = LJA
               CALL FCPSB_ERRPUSH(IERROR,NAME,INT_VAL)
               GOTO 9999
            ENDIF
            
            JA(POINT_JA) = POINT_AR
         ENDDO
      ENDDO

      IA(2,N_BLOCKS+1) = POINT_JA

      CALL FCPSB_ERRACTIONRESTORE(ERR_ACT)
      RETURN

 9999 CONTINUE
      CALL FCPSB_ERRACTIONRESTORE(ERR_ACT)

      IF ( ERR_ACT .NE. 0 ) THEN 
         CALL FCPSB_SERROR()
         RETURN
      ENDIF

      RETURN
      END

