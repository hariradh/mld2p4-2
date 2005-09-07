subroutine psb_dbldaggrmat(a,desc_a,p,info)
  use psb_serial_mod
  use psb_prec_type
  use psb_descriptor_type
  use psb_spmat_type
  use psb_tools_mod
  use psb_psblas_mod
  use psb_error_mod
  implicit none

  type(psb_dspmat_type), intent(in), target :: a
  type(psb_dbaseprec), intent(inout)        :: p
  type(psb_desc_type), intent(in)           :: desc_a
  integer, intent(out)                      :: info

  logical, parameter :: aggr_dump=.false.
  integer ::icontxt,nprow,npcol,me,mycol, err_act
  character(len=20) :: name, ch_err
  name='psb_dbldaggrmat'
  info=0
  call psb_erractionsave(err_act)

  icontxt=desc_a%matrix_data(psb_ctxt_)
  call blacs_gridinfo(icontxt,nprow,npcol,me,mycol)

  select case (p%iprcparm(smth_kind_))
  case (no_smth_) 

    call raw_aggregate(info)

    if(info /= 0) then
      call psb_errpush(4010,name,a_err='raw_aggregate')
      goto 9999
    end if
    if (aggr_dump) call psb_csprt(90+me,p%av(ac_),head='% Raw aggregate.')

  case(smth_omg_,smth_biz_) 

    call smooth_aggregate(info)

    if(info /= 0) then
      call psb_errpush(4010,name,a_err='smooth_aggregate')
      goto 9999
    end if
  case default
    call psb_errpush(4010,name,a_err=name)
    goto 9999

  end select

  call psb_erractionrestore(err_act)
  return

9999 continue
  call psb_erractionrestore(err_act)
  if (err_act.eq.act_abort) then
    call psb_error()
    return
  end if
  return

contains

  subroutine raw_aggregate(info)
    use psb_prec_type
    use psb_const_mod
    use psb_psblas_mod
    use psb_error_mod
    implicit none

    include 'mpif.h'
    integer, intent(out)   :: info
    type(psb_dspmat_type), pointer :: bg 
    type(psb_dspmat_type)          :: b, tmp
    integer, pointer :: nzbr(:), idisp(:)
    integer :: icontxt, nrow, nglob, ncol, ntaggr, nzbg, ip, ndx,&
         & naggr, np, myprow, mypcol, nprows, npcols,nzt,irs,jl,nzl,nlr,&
         & icomm,naggrm1, mtype, i, j, err_act
    name='raw_aggregate'
    info=0
    call psb_erractionsave(err_act)

    bg => p%av(ac_)

    icontxt = desc_a%matrix_data(psb_ctxt_)
    call blacs_gridinfo(icontxt,nprows,npcols,myprow,mypcol)
    np = nprows*npcols
    nglob = desc_a%matrix_data(m_)
    nrow  = desc_a%matrix_data(psb_n_row_)
    ncol  = desc_a%matrix_data(psb_n_col_)

    naggr  = p%nlaggr(myprow+1)
    ntaggr = sum(p%nlaggr)
    allocate(nzbr(np), idisp(np),stat=info)

    if (info /= 0) then 
      call psb_errpush(4010,name,a_err='Allocate')
      goto 9999      
    end if

    naggrm1=sum(p%nlaggr(1:myprow))

    if (p%iprcparm(coarse_mat_) == mat_repl_) then
      do i=1, nrow
        p%mlia(i) = p%mlia(i) + naggrm1
      end do
      call psb_halo(p%mlia,desc_a,info)

      if(info /= 0) then
        call psb_errpush(4010,name,a_err='psb_halo')
        goto 9999
      end if
    end if


    call psb_spinfo(nztotreq,a,nzt,info)

    if(info /= 0) then
      call psb_errpush(4010,name,a_err='spinfo')
      goto 9999
    end if

    call psb_spall(b,nzt,info)
    if(info /= 0) then
      call psb_errpush(4010,name,a_err='spall')
      goto 9999
    end if

    b%infoa(upd_) = 6
    b%fida = 'COO'
    b%m=a%m
    b%k=a%k
    if (.false.) then 
      call psb_csdp(a,b,info)
      if(info /= 0) then
        info=4010
        ch_err='psb_csdp'
        call psb_errpush(info,name,a_err=ch_err)
        goto 9999
      end if
      call psb_spinfo(nztotreq,b,nzt,info)
      if(info /= 0) then
        info=4010
        ch_err='psb_spinfo'
        call psb_errpush(info,name,a_err=ch_err)
        goto 9999
      end if
      do i=1, nzt 
        b%ia1(i) = p%mlia(b%ia1(i))
        b%ia2(i) = p%mlia(b%ia2(i))
      enddo

    else
      ! Ok, this is extremely dirty because we use pointers from 
      ! one sparse matrix into another. But it gives us something 
      ! in term of performance
      jl = 0
      do i=1,a%m,50
        nlr = min(a%m-i+1,50)
        call psb_spgtrow(i,a,b,info,append=.true.,iren=p%mlia,lrw=i+nlr-1)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='spgtrow')
          goto 9999
        end if

        call psb_spinfo(nztotreq,b,nzl,info)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='spinfo')
          goto 9999
        end if
        nzl = nzl - jl 
        tmp%fida  = 'COO'
        tmp%infoa(nnz_) = nzl
        tmp%aspk => b%aspk(jl+1:jl+nzl)
        tmp%ia1 => b%ia1(jl+1:jl+nzl)
        tmp%ia2 => b%ia2(jl+1:jl+nzl)
        call psb_fixcoo(tmp,info)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psb_fixcoo')
          goto 9999
        end if
        nzl = tmp%infoa(nnz_)
        b%infoa(nnz_) = jl+nzl
        jl = jl + nzl
      enddo
    end if


    call psb_fixcoo(b,info)
    if(info /= 0) then
      call psb_errpush(4010,name,a_err='fixcoo')
      goto 9999
    end if

    irs = b%infoa(nnz_)
    call psb_spreall(b,irs,info)
    if(info /= 0) then
      call psb_errpush(4010,name,a_err='spreall')
      goto 9999
    end if
    b%m = naggr
    b%k = naggr

    if (p%iprcparm(coarse_mat_) == mat_repl_) then 

      call psb_dscrep(ntaggr,icontxt,p%desc_data,info)

      nzbr(:) = 0
      nzbr(myprow+1) = irs
      call igsum2d(icontxt,'All',' ',np,1,nzbr,np,-1,-1)
      nzbg = sum(nzbr)
      call psb_spall(ntaggr,ntaggr,bg,nzbg,info)
      if(info /= 0) then
        call psb_errpush(4010,name,a_err='spall')
        goto 9999
      end if

      call blacs_get(icontxt,10,icomm )
      do ip=1,np
        idisp(ip) = sum(nzbr(1:ip-1))
      enddo
      ndx = nzbr(myprow+1) 

      call mpi_allgatherv(b%aspk,ndx,mpi_double_precision,bg%aspk,nzbr,idisp,&
           & mpi_double_precision,icomm,info)
      call mpi_allgatherv(b%ia1,ndx,mpi_integer,bg%ia1,nzbr,idisp,&
           & mpi_integer,icomm,info)
      call mpi_allgatherv(b%ia2,ndx,mpi_integer,bg%ia2,nzbr,idisp,&
           & mpi_integer,icomm,info)
      if(info /= 0) then
        info=-1
        call psb_errpush(info,name)
        goto 9999
      end if

      bg%m = ntaggr
      bg%k = ntaggr
      bg%infoa(nnz_) = nzbg
      bg%fida='COO'
      bg%descra='G'
      call psb_fixcoo(bg,info)
      if(info /= 0) then
        call psb_errpush(4010,name,a_err='fixcoo')
        goto 9999
      end if

      call psb_spfree(b,info)
      if(info /= 0) then
        call psb_errpush(4010,name,a_err='spfree')
        goto 9999
      end if

    else if (p%iprcparm(coarse_mat_) == mat_distr_) then 

      call psb_dscdec(naggr,icontxt,p%desc_data,info)
      call psb_spclone(b,bg,info)
      if(info /= 0) then
        call psb_errpush(4010,name,a_err='spclone')
        goto 9999
      end if
      call psb_spfree(b,info)
      if(info /= 0) then
        call psb_errpush(4010,name,a_err='spfree')
        goto 9999
      end if

    else 

      write(0,*) 'Unknown p%iprcparm(coarse_mat) in aggregate_sp',p%iprcparm(coarse_mat_)
    end if


    deallocate(nzbr,idisp)

    call psb_erractionrestore(err_act)
    return

9999 continue
    call psb_erractionrestore(err_act)
    if (err_act.eq.act_abort) then
      call psb_error()
      return
    end if
    return

  end subroutine raw_aggregate



  subroutine smooth_aggregate(info)
    use psb_serial_mod
    use psb_tools_mod
    use psb_error_mod
    implicit none 
    include 'mpif.h'

    integer, intent(out)   :: info

    type(psb_dspmat_type), pointer :: bg 
    type(psb_dspmat_type)          :: b
    integer, pointer :: nzbr(:), idisp(:), ivall(:)
    integer :: icontxt, nrow, nglob, ncol, ntaggr, nzbg, ip, ndx,&
         & naggr, np, myprow, mypcol, nprows, npcols,&
         & icomm, naggrm1,naggrp1,mtype,i,j,err_act,k,nzl,itemp(1),jtemp(1)
    type(psb_dspmat_type), pointer  :: am1,am2
    type(psb_dspmat_type) :: am3,am4
    logical       :: ml_global_nmb

    logical, parameter :: test_dump=.false.
    integer, parameter :: ncmax=16
    real(kind(1.d0))   :: omega, anorm, tmp, dg
    real(kind(1.d0)), parameter :: one=1.0d0, zero=0.0d0
    character(len=20) :: name, ch_err


    name='smooth_aggregate'
    info=0
    call psb_erractionsave(err_act)

    icontxt = desc_a%matrix_data(psb_ctxt_)
    call blacs_gridinfo(icontxt,nprows,npcols,myprow,mypcol)

    bg => p%av(ac_)

    am2 => p%av(sm_pr_t_)
    am1 => p%av(sm_pr_)


    np    = nprows*npcols
    nglob = desc_a%matrix_data(m_)
    nrow  = desc_a%matrix_data(psb_n_row_)
    ncol  = desc_a%matrix_data(psb_n_col_)

    naggr  = p%nlaggr(myprow+1)
    ntaggr = sum(p%nlaggr)

    allocate(nzbr(np), idisp(np),stat=info)


    naggrm1 = sum(p%nlaggr(1:myprow))
    naggrp1 = sum(p%nlaggr(1:myprow+1))

    ml_global_nmb = ( (p%iprcparm(smth_kind_) == smth_omg_).or.&
         & ( (p%iprcparm(smth_kind_) == smth_biz_).and.&
         &    (p%iprcparm(coarse_mat_) == mat_repl_)) ) 


    if (ml_global_nmb) then 
      p%mlia(1:nrow) = p%mlia(1:nrow) + naggrm1
      call psb_halo(p%mlia,desc_a,info)

      if(info /= 0) then
        call psb_errpush(4010,name,a_err='f90_pshalo')
        goto 9999
      end if
    end if

    if (aggr_dump) then 
      open(30+me)
      write(30+me,*) '% Aggregation map'
      do i=1,ncol
        write(30+me,*) i,p%mlia(i)
      end do
      close(30+me)
    end if

    ! naggr: number of local aggregates
    ! nrow: local rows. 
    ! 
    allocate(p%dorig(nrow),stat=info)
    if (info/=0) then 
      write(0,*) 'Error from allocation',info
    endif

    ! Get diagonal D
    call psb_spgtdiag(a,p%dorig,info)
    if(info /= 0) then
      call psb_errpush(4010,name,a_err='spgtdiag')
      goto 9999
    end if

    where (p%dorig /= zero) 
      p%dorig = one / p%dorig
    elsewhere
      p%dorig = one
    end where


    ! 1. Allocate Ptilde in sparse matrix form 
    call psb_spall(am4,ncol,info)
    if(info /= 0) then
      call psb_errpush(4010,name,a_err='spall')
      goto 9999
    end if

    if (ml_global_nmb) then 
      do i=1,ncol
        am4%aspk(i) = one
        am4%ia1(i)  = i
        am4%ia2(i)  = p%mlia(i)  
      end do
      am4%infoa(nnz_) = ncol
    else
      do i=1,nrow
        am4%aspk(i) = one
        am4%ia1(i)  = i
        am4%ia2(i)  = p%mlia(i)  
      end do
      am4%infoa(nnz_) = nrow
    endif
    am4%fida='COO'
    am4%m=ncol

    if (ml_global_nmb) then 
      am4%k=ntaggr
    else 
      am4%k=naggr
    endif


    if (test_dump)  call &
         & csprt(20+me,am4,head='% Operator Ptilde.',ivr=desc_a%loc_to_glob)


    call psb_ipcoo2csr(am4,info)
    if(info /= 0) then
      call psb_errpush(4010,name,a_err='ipcoo2csr')
      goto 9999
    end if

    call psb_spclone(a,am3,info)
    if(info /= 0) then
      call psb_errpush(4010,name,a_err='spclone')
      goto 9999
    end if

    !
    ! WARNING: the cycles below assume that AM3 does have 
    ! its diagonal elements stored explicitly!!! 
    ! Should we swicth to something safer? 
    !
    call psb_spscal(am3,p%dorig,info)
    if(info /= 0) goto 9999

    if (p%iprcparm(om_choice_) == lib_choice_) then 

      if (p%iprcparm(smth_kind_) == smth_biz_) then 

        ! 
        ! This only works with CSR.
        !
        anorm = 0.d0
        do i=1,am3%m
          tmp = 0.d0 
          do j=am3%ia2(i),am3%ia2(i+1)-1
            if (am3%ia1(j) <= am3%m) then 
              tmp = tmp + dabs(am3%aspk(j))
            endif
            if (am3%ia1(j) == i ) then 
              dg = dabs(am3%aspk(j))
            end if
          end do
          anorm = max(anorm,tmp/dg) 
        enddo

        call dgamx2d(icontxt,'All',' ',1,1,anorm,1,itemp,jtemp,-1,-1,-1)     
      else
        anorm = f90_psnrmi(am3,desc_a,info)
      endif
      omega = 4.d0/(3.d0*anorm)
      p%dprcparm(smooth_omega_) = omega 

    else if (p%iprcparm(om_choice_) == user_choice_) then 

      omega = p%dprcparm(smooth_omega_) 

    else if (p%iprcparm(om_choice_) /= user_choice_) then 
      write(0,*) me,'Error: invalid choice for OMEGA in blaggrmat?? ',&
           &   p%iprcparm(om_choice_)    
    end if


    if (am3%fida=='CSR') then 
      do i=1,am3%m
        do j=am3%ia2(i),am3%ia2(i+1)-1
          if (am3%ia1(j) == i) then 
            am3%aspk(j) = one - omega*am3%aspk(j) 
          else
            am3%aspk(j) = - omega*am3%aspk(j) 
          end if
        end do
      end do
    else  if (am3%fida=='COO') then 
      do j=1,am3%infoa(nnz_) 
        if (am3%ia1(j) /= am3%ia2(j)) then 
          am3%aspk(j) = - omega*am3%aspk(j) 
        else
          am3%aspk(j) = one - omega*am3%aspk(j) 
        endif
      end do
    else
      write(0,*) 'Missing implementation of I sum' 
      call psb_errpush(4010,name)
      goto 9999
    end if

    if (test_dump) call csprt(40+me,am3,head='% (I-wDA)',ivr=desc_a%loc_to_glob,&
         & ivc=desc_a%loc_to_glob)    
    !
    ! Symbmm90 does the allocation for its result.
    ! 
    ! am1 = (i-wDA)Ptilde
    ! Doing it this way means to consider diag(Ai)
    ! 
    !
    call symbmm90(am3,am4,am1)
    call numbmm90(am3,am4,am1)


    call psb_spfree(am4,info)
    if(info /= 0) then
      call psb_errpush(4010,name,a_err='spfree')
      goto 9999
    end if

    if (ml_global_nmb) then 
      !
      ! Now we have to gather the halo of am1, and add it to itself
      ! to multiply it by A,
      !
      call psb_csrovr(am1,desc_a,am4,info,clcnv=.false.)

      if(info /= 0) then
        call psb_errpush(4010,name,a_err='psb_csrovr')
        goto 9999
      end if

      call psb_rwextd(ncol,am1,info,b=am4)      
      if(info /= 0) then
        call psb_errpush(4010,name,a_err='psb_rwextd')
        goto 9999
      end if

      call psb_spfree(am4,info)
      if(info /= 0) then
        call psb_errpush(4010,name,a_err='psb_spfree')
        goto 9999
      end if

    else 

      call psb_rwextd(ncol,am1,info)
      if(info /= 0) then
        call psb_errpush(4010,name,a_err='rwextd')
        goto 9999
      end if
    endif

    if (test_dump) &
         & call psb_csprt(60+me,am1,head='% (I-wDA)Pt',ivr=desc_a%loc_to_glob)    

    call symbmm90(a,am1,am3)
    call numbmm90(a,am1,am3)

    if  (p%iprcparm(smth_kind_) == smth_omg_) then 
      call psb_transp(am1,am2,fmt='COO')
      nzl = am2%infoa(nnz_)
      i=0
      !
      ! Now we have to fix this.  The only rows of B that are correct 
      ! are those corresponding to "local" aggregates, i.e. indices in p%mlia(:)
      !
      do k=1, nzl
        if ((naggrm1 < am2%ia1(k)) .and.(am2%ia1(k) <= naggrp1)) then
          i = i+1
          am2%aspk(i) = am2%aspk(k)
          am2%ia1(i)  = am2%ia1(k)
          am2%ia2(i)  = am2%ia2(k)
        end if
      end do

      am2%infoa(nnz_) = i
      call psb_ipcoo2csr(am2,info)
    else
      call psb_transp(am1,am2)
    endif

    if  (p%iprcparm(smth_kind_) == smth_omg_) then 
      ! am2 = ((i-wDA)Ptilde)^T
      call psb_csrovr(am3,desc_a,am4,info,clcnv=.false.)

      if(info /= 0) then
        call psb_errpush(4010,name,a_err='psb_csrovr')
        goto 9999
      end if
      call psb_rwextd(ncol,am3,info,b=am4)      
      if(info /= 0) then
        call psb_errpush(4010,name,a_err='psb_rwextd')
        goto 9999
      end if
      call psb_spfree(am4,info)
      if(info /= 0) then
        call psb_errpush(4010,name,a_err='psb_spfree')
        goto 9999
      end if

    else if  (p%iprcparm(smth_kind_) == smth_biz_) then 

      call psb_rwextd(ncol,am3,info)
      if(info /= 0) then
        call psb_errpush(4010,name,a_err='psb_rwextd')
        goto 9999
      end if
    endif

    call symbmm90(am2,am3,b)
    call numbmm90(am2,am3,b)

!!$    if (aggr_dump) call csprt(50+me,am1,head='% Operator PTrans.')
    call psb_spfree(am3,info)
    if(info /= 0) then
      call psb_errpush(4010,name,a_err='psb_spfree')
      goto 9999
    end if

    call psb_ipcsr2coo(b,info)
    if(info /= 0) then
      call psb_errpush(4010,name,a_err='ipcsr2coo')
      goto 9999
    end if

    call psb_fixcoo(b,info)      
    if(info /= 0) then
      call psb_errpush(4010,name,a_err='fixcoo')
      goto 9999
    end if


    if (test_dump) call psb_csprt(80+me,b,head='% Smoothed aggregate AC.')    

    select case(p%iprcparm(smth_kind_))

    case(smth_omg_) 

      select case(p%iprcparm(coarse_mat_))

      case(mat_distr_) 

        call psb_spclone(b,bg,info)
        if(info /= 0) goto 9999
        nzbg = bg%infoa(nnz_) 
        nzl =  bg%infoa(nnz_) 

        allocate(ivall(ntaggr))

        i = 1
        do ip=1,nprows
          do k=1, p%nlaggr(ip)
            ivall(i) = ip
            i = i + 1
          end do
        end do
        call psb_dscall(ntaggr,ivall,icontxt,p%desc_data,info,flag=1)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psb_dscall')
          goto 9999
        end if


        call psb_dscins(nzl,bg%ia1,bg%ia2,p%desc_data,info)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psb_dscins')
          goto 9999
        end if

        call psb_dscasb(p%desc_data,info)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psb_dscasb')
          goto 9999
        end if



        call psb_glob_to_loc(bg%ia1(1:nzl),p%desc_data,info,iact='I')
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psglob_to_loc')
          goto 9999
        end if


        call psb_glob_to_loc(bg%ia2(1:nzl),p%desc_data,info,iact='I')
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psglob_to_loc')
          goto 9999
        end if


        bg%m=p%desc_data%matrix_data(psb_n_row_)
        bg%k=p%desc_data%matrix_data(psb_n_col_)

        call psb_spfree(b,info)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psb_spfree')
          goto 9999
        end if


        deallocate(ivall,nzbr,idisp)

        ! Split BG=M+N  N off-diagonal part
        call psb_spall(bg%m,bg%k,p%av(ap_nd_),nzl,info)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psb_spall')
          goto 9999
        end if

        k=0
        do i=1,nzl
          if (bg%ia2(i)>bg%m) then 
            k = k + 1
            p%av(ap_nd_)%aspk(k) = bg%aspk(i)
            p%av(ap_nd_)%ia1(k) = bg%ia1(i)
            p%av(ap_nd_)%ia2(k) = bg%ia2(i)
          endif
        enddo
        p%av(ap_nd_)%infoa(nnz_) = k
        call psb_ipcoo2csr(p%av(ap_nd_),info)

        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psb_ipcoo2csr')
          goto 9999
        end if
        call igsum2d(icontxt,'All',' ',1,1,k,1,-1,-1)

        if (k == 0) then 
          ! If the off diagonal part is emtpy, there's no point 
          ! in doing multiple  Jacobi sweeps. This is certain 
          ! to happen when running on a single processor.
          p%iprcparm(jac_sweeps_) = 1
        end if


        if (np>1) then 
          call psb_spinfo(nztotreq,am1,nzl,info)
          call psb_glob_to_loc(am1%ia1(1:nzl),p%desc_data,info,'I')
          if(info /= 0) then
            call psb_errpush(4010,name,a_err='psb_glob_to_loc')
            goto 9999
          end if
        endif
        am1%k=p%desc_data%matrix_data(psb_n_col_)

        if (np>1) then 
          call psb_ipcsr2coo(am2,info)
          if(info /= 0) then
            call psb_errpush(4010,name,a_err='psb_ipcsr2coo')
            goto 9999
          end if

          nzl = am2%infoa(nnz_) 
          call psb_glob_to_loc(am2%ia1(1:nzl),p%desc_data,info,'I')
          if(info /= 0) then
            call psb_errpush(4010,name,a_err='psb_glob_to_loc')
            goto 9999
          end if

          call psb_ipcoo2csr(am2,info)
          if(info /= 0) then
            call psb_errpush(4010,name,a_err='psb_ipcoo2csr')
            goto 9999
          end if
        end if
        am2%m=p%desc_data%matrix_data(psb_n_col_)

      case(mat_repl_) 
        !
        !
        nzbr(:) = 0
        nzbr(myprow+1) = b%infoa(nnz_)

        call psb_dscrep(ntaggr,icontxt,p%desc_data,info)

        call igsum2d(icontxt,'All',' ',np,1,nzbr,np,-1,-1)
        nzbg = sum(nzbr)
        call psb_spall(ntaggr,ntaggr,bg,nzbg,info)
        if(info /= 0) goto 9999


        call blacs_get(icontxt,10,icomm )
        do ip=1,np
          idisp(ip) = sum(nzbr(1:ip-1))
        enddo
        ndx = nzbr(myprow+1) 

        call mpi_allgatherv(b%aspk,ndx,mpi_double_precision,bg%aspk,nzbr,idisp,&
             & mpi_double_precision,icomm,info)
        call mpi_allgatherv(b%ia1,ndx,mpi_integer,bg%ia1,nzbr,idisp,&
             & mpi_integer,icomm,info)
        call mpi_allgatherv(b%ia2,ndx,mpi_integer,bg%ia2,nzbr,idisp,&
             & mpi_integer,icomm,info)
        if(info /= 0) goto 9999


        bg%m = ntaggr
        bg%k = ntaggr
        bg%infoa(nnz_) = nzbg
        bg%fida='COO'
        bg%descra='G'
        call psb_fixcoo(bg,info)
        if(info /= 0) goto 9999
        call psb_spfree(b,info)
        if(info /= 0) goto 9999
        if (me==0) then 
          if (test_dump) call psb_csprt(80+me,bg,head='% Smoothed aggregate AC.')    
        endif

        deallocate(nzbr,idisp)

      case default 
        write(0,*) 'Inconsistent input in smooth_new_aggregate'
      end select


    case(smth_biz_) 

      select case(p%iprcparm(coarse_mat_))

      case(mat_distr_) 

        call psb_spclone(b,bg,info)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='spclone')
          goto 9999
        end if
        call psb_dscdec(naggr,icontxt,p%desc_data,info)

        call spfree(b,info)
        if(info /=  0) then
          call psb_errpush(4010,name,a_err='spfree')
          goto 9999
        end if


      case(mat_repl_) 
        !
        !
        nzbr(:) = 0
        nzbr(myprow+1) = b%infoa(nnz_)

        call psb_dscrep(ntaggr,icontxt,p%desc_data,info)


        call igsum2d(icontxt,'All',' ',np,1,nzbr,np,-1,-1)
        nzbg = sum(nzbr)
        call psb_spall(ntaggr,ntaggr,bg,nzbg,info)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psb_spall')
          goto 9999
        end if

        call blacs_get(icontxt,10,icomm )
        do ip=1,np
          idisp(ip) = sum(nzbr(1:ip-1))
        enddo
        ndx = nzbr(myprow+1) 

        call mpi_allgatherv(b%aspk,ndx,mpi_double_precision,bg%aspk,nzbr,idisp,&
             & mpi_double_precision,icomm,info)
        call mpi_allgatherv(b%ia1,ndx,mpi_integer,bg%ia1,nzbr,idisp,&
             & mpi_integer,icomm,info)
        call mpi_allgatherv(b%ia2,ndx,mpi_integer,bg%ia2,nzbr,idisp,&
             & mpi_integer,icomm,info)
        if(info /= 0) then
          info=-1
          call psb_errpush(info,name)
          goto 9999
        end if


        bg%m = ntaggr
        bg%k = ntaggr
        bg%infoa(nnz_) = nzbg
        bg%fida='COO'
        bg%descra='G'
        call psb_fixcoo(bg,info)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psb_fixcoo')
          goto 9999
        end if
        call psb_spfree(b,info)
        if(info /= 0) then
          call psb_errpush(4010,name,a_err='psb_spfree')
          goto 9999
        end if

      end select
      deallocate(nzbr,idisp)

    end select

    call psb_erractionrestore(err_act)
    return

9999 continue
    call psb_errpush(info,name)
    call psb_erractionrestore(err_act)
    if (err_act.eq.act_abort) then
      call psb_error()
      return
    end if
    return


  end subroutine smooth_aggregate



end subroutine psb_dbldaggrmat
