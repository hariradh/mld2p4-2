subroutine mld_c_jac_smoother_apply(alpha,sm,x,beta,y,desc_data,trans,sweeps,work,info)
  
  use psb_base_mod
  use mld_c_jac_smoother, mld_protect_name => mld_c_jac_smoother_apply
  implicit none 
  type(psb_desc_type), intent(in)      :: desc_data
  class(mld_c_jac_smoother_type), intent(in) :: sm
  complex(psb_spk_),intent(inout)         :: x(:)
  complex(psb_spk_),intent(inout)         :: y(:)
  complex(psb_spk_),intent(in)            :: alpha,beta
  character(len=1),intent(in)          :: trans
  integer, intent(in)                  :: sweeps
  complex(psb_spk_),target, intent(inout) :: work(:)
  integer, intent(out)                 :: info

  integer    :: n_row,n_col
  complex(psb_spk_), pointer :: ww(:), aux(:), tx(:),ty(:)
  integer    :: ictxt,np,me,i, err_act
  character          :: trans_
  character(len=20)  :: name='c_jac_smoother_apply'

  call psb_erractionsave(err_act)

  info = psb_success_

  trans_ = psb_toupper(trans)
  select case(trans_)
  case('N')
  case('T','C')
  case default
    call psb_errpush(psb_err_iarg_invalid_i_,name)
    goto 9999
  end select

  if (.not.allocated(sm%sv)) then 
    info = 1121
    call psb_errpush(info,name)
    goto 9999
  end if

  n_row = desc_data%get_local_rows()
  n_col = desc_data%get_local_cols()

  if (n_col <= size(work)) then 
    ww => work(1:n_col)
    if ((4*n_col+n_col) <= size(work)) then 
      aux => work(n_col+1:)
    else
      allocate(aux(4*n_col),stat=info)
      if (info /= psb_success_) then 
        info=psb_err_alloc_request_
        call psb_errpush(info,name,i_err=(/4*n_col,0,0,0,0/),&
             & a_err='complex(psb_spk_)')
        goto 9999      
      end if
    endif
  else
    allocate(ww(n_col),aux(4*n_col),stat=info)
    if (info /= psb_success_) then 
      info=psb_err_alloc_request_
      call psb_errpush(info,name,i_err=(/5*n_col,0,0,0,0/),&
           & a_err='complex(psb_spk_)')
      goto 9999      
    end if
  endif

  if ((sweeps == 1).or.(sm%nnz_nd_tot==0)) then 

    call sm%sv%apply(alpha,x,beta,y,desc_data,trans_,aux,info) 

    if (info /= psb_success_) then
      call psb_errpush(psb_err_internal_error_,&
           & name,a_err='Error in sub_aply Jacobi Sweeps = 1')
      goto 9999
    endif

  else if (sweeps  > 1) then 

    !
    !
    ! Apply multiple sweeps of a block-Jacobi solver
    ! to compute an approximate solution of a linear system.
    !
    !
    allocate(tx(n_col),ty(n_col),stat=info)
    if (info /= psb_success_) then 
      info=psb_err_alloc_request_
      call psb_errpush(info,name,i_err=(/2*n_col,0,0,0,0/),&
           & a_err='complex(psb_spk_)')
      goto 9999      
    end if

    tx = czero
    ty = czero
    do i=1, sweeps
      !
      ! Compute Y(j+1) = D^(-1)*(X-ND*Y(j)), where D and ND are the
      ! block diagonal part and the remaining part of the local matrix
      ! and Y(j) is the approximate solution at sweep j.
      !
      ty(1:n_row) = x(1:n_row)
      call psb_spmm(-cone,sm%nd,tx,cone,ty,desc_data,info,work=aux,trans=trans_)

      if (info /= psb_success_) exit

      call sm%sv%apply(cone,ty,czero,tx,desc_data,trans_,aux,info) 

      if (info /= psb_success_) exit
    end do

    if (info == psb_success_) call psb_geaxpby(alpha,tx,beta,y,desc_data,info)

    if (info /= psb_success_) then 
      info=psb_err_internal_error_
      call psb_errpush(info,name,a_err='subsolve with Jacobi sweeps > 1')
      goto 9999      
    end if

    deallocate(tx,ty,stat=info)
    if (info /= psb_success_) then 
      info=psb_err_internal_error_
      call psb_errpush(info,name,a_err='final cleanup with Jacobi sweeps > 1')
      goto 9999      
    end if

  else

    info = psb_err_iarg_neg_
    call psb_errpush(info,name,&
         & i_err=(/2,sweeps,0,0,0/))
    goto 9999

  endif


  if (n_col <= size(work)) then 
    if ((4*n_col+n_col) <= size(work)) then 
    else
      deallocate(aux)
    endif
  else
    deallocate(ww,aux)
  endif

  call psb_erractionrestore(err_act)
  return

9999 continue
  call psb_erractionrestore(err_act)
  if (err_act == psb_act_abort_) then
    call psb_error()
    return
  end if
  return

end subroutine mld_c_jac_smoother_apply