! ---------------------------------------------------------------------
!
!  -- PSSBLAS routine (version 1.0) --
!
!  ---------------------------------------------------------------------
!/
subroutine psb_dscdec(nloc, icontxt, desc_a, info)

  !  Purpose
  !  =======
  !  
  !  Allocate special descriptor for decoupled index space 
  ! 
  !
  !
  ! INPUT
  !======
  ! NLOC         : (Local Input) Integer 
  !                    Number of local indices 
  !                    required.
  !
  ! ICONTXT      : (Global Input)Integer BLACS context for an NPx1 grid 
  !                required.
  !
  ! OUTPUT
  !=========
  ! desc_a   : TYPEDESC
  ! desc_a OUTPUT FIELDS:
  !
  ! MATRIX_DATA   : Pointer to integer Array 
  !                contains some
  !               local and global information about matrix:
  !
  !  NOTATION        STORED IN		     EXPLANATION
  !  ------------ ---------------------- -------------------------------------
  !  DEC_TYPE        MATRIX_DATA[DEC_TYPE_]   Decomposition type, temporarly is
  !                      setted to 1( matrix not yet assembled)
  !  M 	             MATRIX_DATA[M_]          Total number of equations
  !  N 	             MATRIX_DATA[N_]          Total number of variables
  !  N_ROW           MATRIX_DATA[N_ROW_]      Number of local equations
  !  N_COL           MATRIX_DATA[N_COL_]      Number of local columns (see below)
  !  CTXT_A          MATRIX_DATA[CTXT_]     The BLACS context handle, 
  !                                         indicating
  !	  			            the global context of the operation
  !					    on the matrix.
  !					    The context itself is global.
  !
  !  GLOB_TO_LOC     Array of dimension equal to number of global 
  !                  rows/cols (MATRIX_DATA[M_]). On exit,
  !                  for all global indices either:
  !                  1. The index belongs to the current process; the entry
  !                     is set to the next free local row index.
  !                  2. The index belongs to process P (0<=P<=NP-1); the entry 
  !                     is set to 
  !                     -(NP+P+1)
  !
  !  LOC_TO_GLOB     An array of dimension equal to number of local cols N_COL
  !                  i.e. all columns of the matrix such that there is at least
  !                  one nonzero entry within the local row range. At the time 
  !                  this routine is called N_COL cannot be know, so we set 
  !                  N_COL=N_ROW, and dimension this vector on N_ROW plus an 
  !                  estimate. On exit the vector elements are set
  !                  to the index of the corresponding entry in GLOB_TO_LOC, or  
  !                  to -1 for indices I>N_ROW.
  !
  !
  !  HALO_INDEX      Not touched here, as it depends on the matrix pattern
  !
  !  OVRLAP_INDEX    On exit from this routine, the overlap indices are stored in
  !                  triples (Proc, 1, Index), similar to the assembled format 
  !                  but neither optimized, nor deadlock free. 
  !                  List is terminated with -1
  !
  !  OVRLAP_ELEM     On exit from this routine, just a list of pairs (index,#p).
  !                  List is terminated with -1.
  !                  
  !
  ! END OF desc_a OUTPUT FIELDS
  !
  !

  use psb_descriptor_type
  use psb_serial_mod
  use psb_const_mod
  use psb_error_mod
  implicit None
  !....Parameters...
  Integer, intent(in)               :: nloc,icontxt
  integer, intent(out)              :: info
  Type(psb_desc_type), intent(out)  :: desc_a

  !locals
  Integer              :: counter,i,j,nprow,npcol,me,mypcol,&
       & loc_row,err,loc_col,nprocs,n,itmpov, k,&
       & l_ov_ix,l_ov_el,idx, flag_, err_act,m, ip
  Integer              :: INT_ERR(5),TEMP(1),EXCH(2)
  Real(Kind(1.d0))     :: REAL_ERR(5)
  Integer, Parameter   :: IONE=1, ITWO=2,ROOT=0
  Integer, Pointer     :: temp_ovrlap(:), ov_idx(:), ov_el(:)
  integer, allocatable :: nlv(:)
  logical, parameter   :: debug=.false.
  character(len=20)    :: name, ch_err

  info=0
  err=0
  name = 'psb_dscdec'

  call blacs_gridinfo(icontxt, nprow, npcol, me, mypcol)
  if (debug) write(*,*) 'psb_dscall: ',nprow,npcol,me,mypcol
  !     ....verify blacs grid correctness..
  if (npcol /= 1) then
     info = 2030
     int_err(1) = npcol
     call psb_errpush(info,name,i_err=int_err)
     goto 9999
  endif

  n = nloc
  !... check nloc and n parameters....
  if (nloc < 1) then
    info = 10
    int_err(1) = 1
    int_err(2) = nloc
  else if (n < 1) then
    info = 10
    int_err(1) = 2
    int_err(2) = n
  endif

  if (info /= 0) then 
     call psb_errpush(info,name,i_err=int_err)
     goto 9999
  end if

  if (debug) write(*,*) 'psb_dscall:  doing global checks'  
  !global check on m and n parameters

  allocate(nlv(0:nprow-1))
  nlv(:)  = 0
  nlv(me) = nloc
  
  call igsum2d(icontxt,'All',' ',nprow,1,nlv,nprow,-1,-1)
  m = sum(nlv)

  

  call psb_nullify_desc(desc_a)


  !count local rows number
  ! allocate work vector
  allocate(desc_a%glob_to_loc(m),desc_a%matrix_data(psb_mdata_size_),&
       &   desc_a%loc_to_glob(nloc),desc_a%lprm(1),&
       &   desc_a%ovrlap_index(1),desc_a%ovrlap_elem(1),&
       &   desc_a%halo_index(1),desc_a%bnd_elem(1),stat=info)
  if (info /= 0) then     
    info=2025
    int_err(1)=m
    call psb_errpush(info,name,i_err=int_err)
    goto 9999
  endif


  
  j = 1
  do ip=0, nprow-1
    if (ip==me) then 
      do i=1, nlv(ip) 
        desc_a%glob_to_loc(j) = i
        desc_a%loc_to_glob(i) = j
        j = j + 1
      enddo
    else
      do i=1, nlv(ip) 
        desc_a%glob_to_loc(j) = -(nprow+ip+1)
        j = j + 1
      enddo
    endif
  enddo 



  desc_a%lprm(:)         = 0
  desc_a%halo_index(:)   = -1
  desc_a%bnd_elem(:)     = -1
  desc_a%ovrlap_index(:) = -1
  desc_a%ovrlap_elem(:)  = -1


  desc_a%matrix_data(psb_m_)        = m
  desc_a%matrix_data(psb_n_)        = m
  desc_a%matrix_data(psb_n_row_)  = nloc
  desc_a%matrix_data(psb_n_col_)  = nloc
  desc_a%matrix_data(psb_dec_type_) = psb_desc_asb_
  desc_a%matrix_data(psb_ctxt_)     = icontxt
  call blacs_get(icontxt,10,desc_a%matrix_data(psb_mpi_c_))

  call psb_erractionrestore(err_act)
  return
  
9999 continue
  call psb_erractionrestore(err_act)
  if (err_act.eq.act_abort) then
     call psb_error(icontxt)
     return
  end if
  return
  
end subroutine psb_dscdec
