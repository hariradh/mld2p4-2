subroutine mld_z_ilu_solver_bld(a,desc_a,sv,upd,info,b,amold,vmold)
  

  use psb_base_mod
  use mld_z_ilu_solver, mld_protect_name => mld_z_ilu_solver_bld

  Implicit None

  ! Arguments
  type(psb_zspmat_type), intent(in), target           :: a
  Type(psb_desc_type), Intent(in)                     :: desc_a 
  class(mld_z_ilu_solver_type), intent(inout)         :: sv
  character, intent(in)                               :: upd
  integer, intent(out)                                :: info
  type(psb_zspmat_type), intent(in), target, optional :: b
  class(psb_z_base_sparse_mat), intent(in), optional  :: amold
  class(psb_z_base_vect_type), intent(in), optional   :: vmold
  ! Local variables
  integer :: n_row,n_col, nrow_a, nztota
!!$    complex(psb_dpk_), pointer :: ww(:), aux(:), tx(:),ty(:)
  integer :: ictxt,np,me,i, err_act, debug_unit, debug_level
  character(len=20)  :: name='z_ilu_solver_bld', ch_err

  info=psb_success_
  call psb_erractionsave(err_act)
  debug_unit  = psb_get_debug_unit()
  debug_level = psb_get_debug_level()
  ictxt       = desc_a%get_context()
  call psb_info(ictxt, me, np)
  if (debug_level >= psb_debug_outer_) &
       & write(debug_unit,*) me,' ',trim(name),' start'


  n_row  = desc_a%get_local_rows()

  if (psb_toupper(upd) == 'F') then 
    nrow_a = a%get_nrows()
    nztota = a%get_nzeros()
    if (present(b)) then 
      nztota = nztota + b%get_nzeros()
    end if

    call sv%l%csall(n_row,n_row,info,nztota)
    if (info == psb_success_) call sv%u%csall(n_row,n_row,info,nztota)
    if(info /= psb_success_) then
      info=psb_err_from_subroutine_
      ch_err='psb_sp_all'
      call psb_errpush(info,name,a_err=ch_err)
      goto 9999
    end if

    if (allocated(sv%d)) then 
      if (size(sv%d) < n_row) then 
        deallocate(sv%d)
      endif
    endif
    if (.not.allocated(sv%d))  allocate(sv%d(n_row),stat=info)

    if (info /= psb_success_) then 
      call psb_errpush(psb_err_from_subroutine_,name,a_err='Allocate')
      goto 9999      
    endif


    select case(sv%fact_type)

    case (mld_ilu_t_)
      !
      ! ILU(k,t)
      !
      select case(sv%fill_in)

      case(:-1) 
        ! Error: fill-in <= -1
        call psb_errpush(psb_err_input_value_invalid_i_,&
             & name,i_err=(/3,sv%fill_in,0,0,0/))
        goto 9999

      case(0:)
        ! Fill-in >= 0
        call mld_ilut_fact(sv%fill_in,sv%thresh,&
             & a, sv%l,sv%u,sv%d,info,blck=b)
      end select
      if(info /= psb_success_) then
        info=psb_err_from_subroutine_
        ch_err='mld_ilut_fact'
        call psb_errpush(info,name,a_err=ch_err)
        goto 9999
      end if

    case(mld_ilu_n_,mld_milu_n_) 
      !
      ! ILU(k) and MILU(k)
      !
      select case(sv%fill_in)
      case(:-1) 
        ! Error: fill-in <= -1
        call psb_errpush(psb_err_input_value_invalid_i_,&
             & name,i_err=(/3,sv%fill_in,0,0,0/))
        goto 9999
      case(0)
        ! Fill-in 0
        ! Separate implementation of ILU(0) for better performance.
        ! There seems to be a problem with the separate implementation of MILU(0),
        ! contained into mld_ilu0_fact. This must be investigated. For the time being,
        ! resort to the implementation of MILU(k) with k=0.
        if (sv%fact_type == mld_ilu_n_) then 
          call mld_ilu0_fact(sv%fact_type,a,sv%l,sv%u,&
               & sv%d,info,blck=b,upd=upd)
        else
          call mld_iluk_fact(sv%fill_in,sv%fact_type,&
               & a,sv%l,sv%u,sv%d,info,blck=b)
        endif
      case(1:)
        ! Fill-in >= 1
        ! The same routine implements both ILU(k) and MILU(k)
        call mld_iluk_fact(sv%fill_in,sv%fact_type,&
             & a,sv%l,sv%u,sv%d,info,blck=b)
      end select
      if (info /= psb_success_) then
        info=psb_err_from_subroutine_
        ch_err='mld_iluk_fact'
        call psb_errpush(info,name,a_err=ch_err)
        goto 9999
      end if

    case default
      ! If we end up here, something was wrong up in the call chain. 
      info = psb_err_input_value_invalid_i_
      call psb_errpush(psb_err_input_value_invalid_i_,name,&
           & i_err=(/3,sv%fact_type,0,0,0/))
      goto 9999

    end select
  else
    ! Here we should add checks for reuse of L and U.
    ! For the time being just throw an error. 
    info = 31
    call psb_errpush(info, name,&
         & i_err=(/3,0,0,0,0/),a_err=upd)
    goto 9999 

    !
    ! What is an update of a factorization??
    ! A first attempt could be to reuse EXACTLY the existing indices
    ! as if it was an ILU(0) (since, effectively, the sparsity pattern
    ! should not grow beyond what is already there).
    !  
    call mld_ilu0_fact(sv%fact_type,a,&
         & sv%l,sv%u,&
         & sv%d,info,blck=b,upd=upd)

  end if

  call sv%l%set_asb()
  call sv%l%trim()
  call sv%u%set_asb()
  call sv%u%trim()
  call sv%dv%bld(sv%d,mold=vmold)

  if (present(amold)) then 
    call sv%l%cscnv(info,mold=amold)
    call sv%u%cscnv(info,mold=amold)
  end if

  if (debug_level >= psb_debug_outer_) &
       & write(debug_unit,*) me,' ',trim(name),' end'

  call psb_erractionrestore(err_act)
  return

9999 continue
  call psb_erractionrestore(err_act)
  if (err_act == psb_act_abort_) then
    call psb_error()
    return
  end if
  return
end subroutine mld_z_ilu_solver_bld