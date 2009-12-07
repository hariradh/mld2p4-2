!!$
!!$ 
!!$                           MLD2P4  version 2.0
!!$  MultiLevel Domain Decomposition Parallel Preconditioners Package
!!$             based on PSBLAS (Parallel Sparse BLAS version 3.0)
!!$  
!!$  (C) Copyright 2008,2009, 2010
!!$
!!$                      Salvatore Filippone  University of Rome Tor Vergata
!!$                      Alfredo Buttari      University of Rome Tor Vergata
!!$                      Pasqua D'Ambra       ICAR-CNR, Naples
!!$                      Daniela di Serafino  Second University of Naples
!!$ 
!!$  Redistribution and use in source and binary forms, with or without
!!$  modification, are permitted provided that the following conditions
!!$  are met:
!!$    1. Redistributions of source code must retain the above copyright
!!$       notice, this list of conditions and the following disclaimer.
!!$    2. Redistributions in binary form must reproduce the above copyright
!!$       notice, this list of conditions, and the following disclaimer in the
!!$       documentation and/or other materials provided with the distribution.
!!$    3. The name of the MLD2P4 group or the names of its contributors may
!!$       not be used to endorse or promote products derived from this
!!$       software without specific written permission.
!!$ 
!!$  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
!!$  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
!!$  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
!!$  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE MLD2P4 GROUP OR ITS CONTRIBUTORS
!!$  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
!!$  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
!!$  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
!!$  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
!!$  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
!!$  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
!!$  POSSIBILITY OF SUCH DAMAGE.
!!$ 
!!$
!
!
!
!
!
!

module mld_d_ilu_solver

  use mld_d_prec_type

  type, extends(mld_d_base_solver_type) :: mld_d_ilu_solver_type
    type(psb_d_sparse_mat)      :: l, u
    real(psb_dpk_), allocatable :: d(:)
    integer                     :: fact_type, fill_in
    real(psb_dpk_)              :: thresh
  contains
    procedure, pass(sv) :: build => d_ilu_solver_bld
    procedure, pass(sv) :: apply => d_ilu_solver_apply
    procedure, pass(sv) :: free  => d_ilu_solver_free
    procedure, pass(sv) :: seti  => d_ilu_solver_seti
    procedure, pass(sv) :: setc  => d_ilu_solver_setc
    procedure, pass(sv) :: setr  => d_ilu_solver_setr
    procedure, pass(sv) :: descr => d_ilu_solver_descr
    procedure, pass(sv) :: sizeof => d_ilu_solver_sizeof
  end type mld_d_ilu_solver_type


  private :: d_ilu_solver_bld, d_ilu_solver_apply, &
       &  d_ilu_solver_free,   d_ilu_solver_seti, &
       &  d_ilu_solver_setc,   d_ilu_solver_setr,&
       &  d_ilu_solver_descr,  d_ilu_solver_sizeof


  interface mld_ilu0_fact
    subroutine mld_dilu0_fact(ialg,a,l,u,d,info,blck,upd)
      use psb_base_mod, only : psb_d_sparse_mat, psb_dpk_
      integer, intent(in)                 :: ialg
      integer, intent(out)                :: info
      type(psb_d_sparse_mat),intent(in)    :: a
      type(psb_d_sparse_mat),intent(inout) :: l,u
      type(psb_d_sparse_mat),intent(in), optional, target :: blck
      character, intent(in), optional      :: upd
      real(psb_dpk_), intent(inout)     ::  d(:)
    end subroutine mld_dilu0_fact
  end interface

  interface mld_iluk_fact
    subroutine mld_diluk_fact(fill_in,ialg,a,l,u,d,info,blck)
      use psb_base_mod, only : psb_d_sparse_mat, psb_dpk_
      integer, intent(in)                  :: fill_in,ialg
      integer, intent(out)                 :: info
      type(psb_d_sparse_mat),intent(in)    :: a
      type(psb_d_sparse_mat),intent(inout) :: l,u
      type(psb_d_sparse_mat),intent(in), optional, target :: blck
      real(psb_dpk_), intent(inout)        ::  d(:)
    end subroutine mld_diluk_fact
  end interface

  interface mld_ilut_fact
    subroutine mld_dilut_fact(fill_in,thres,a,l,u,d,info,blck)
      use psb_base_mod, only : psb_d_sparse_mat, psb_dpk_
      integer, intent(in)                  :: fill_in
      real(psb_dpk_), intent(in)           :: thres
      integer, intent(out)                 :: info
      type(psb_d_sparse_mat),intent(in)    :: a
      type(psb_d_sparse_mat),intent(inout) :: l,u
      type(psb_d_sparse_mat),intent(in), optional, target :: blck
      real(psb_dpk_), intent(inout)        ::  d(:)
    end subroutine mld_dilut_fact
  end interface

  character(len=15), parameter, private :: &
       &  fact_names(0:3)=(/'none          ','ILU(n)        ',&
       &  'MILU(n)       ','ILU(t,n)      '/)


contains

  subroutine d_ilu_solver_apply(alpha,sv,x,beta,y,desc_data,trans,work,info)
    use psb_base_mod
    type(psb_desc_type), intent(in)      :: desc_data
    class(mld_d_ilu_solver_type), intent(in) :: sv
    real(psb_dpk_),intent(in)            :: x(:)
    real(psb_dpk_),intent(inout)         :: y(:)
    real(psb_dpk_),intent(in)            :: alpha,beta
    character(len=1),intent(in)          :: trans
    real(psb_dpk_),target, intent(inout) :: work(:)
    integer, intent(out)                 :: info

    integer    :: n_row,n_col
    real(psb_dpk_), pointer :: ww(:), aux(:), tx(:),ty(:)
    integer    :: ictxt,np,me,i, err_act
    character          :: trans_
    character(len=20)  :: name='d_ilu_solver_apply'

    call psb_erractionsave(err_act)

    info = 0

    trans_ = psb_toupper(trans)
    select case(trans_)
    case('N')
    case('T','C')
    case default
      call psb_errpush(40,name)
      goto 9999
    end select

    n_row = psb_cd_get_local_rows(desc_data)
    n_col = psb_cd_get_local_cols(desc_data)

    if (n_col <= size(work)) then 
      ww => work(1:n_col)
      if ((4*n_col+n_col) <= size(work)) then 
        aux => work(n_col+1:)
      else
        allocate(aux(4*n_col),stat=info)
        if (info /= 0) then 
          info=4025
          call psb_errpush(info,name,i_err=(/4*n_col,0,0,0,0/),&
               & a_err='real(psb_dpk_)')
          goto 9999      
        end if
      endif
    else
      allocate(ww(n_col),aux(4*n_col),stat=info)
      if (info /= 0) then 
        info=4025
        call psb_errpush(info,name,i_err=(/5*n_col,0,0,0,0/),&
             & a_err='real(psb_dpk_)')
        goto 9999      
      end if
    endif

    select case(trans_)
    case('N')
      call psb_spsm(done,sv%l,x,dzero,ww,desc_data,info,&
           & trans=trans_,scale='L',diag=sv%d,choice=psb_none_,work=aux)

      if (info == 0) call psb_spsm(alpha,sv%u,ww,beta,y,desc_data,info,&
           & trans=trans_,scale='U',choice=psb_none_, work=aux)

    case('T','C')
      call psb_spsm(done,sv%u,x,dzero,ww,desc_data,info,&
           & trans=trans_,scale='L',diag=sv%d,choice=psb_none_,work=aux)
      if (info == 0) call psb_spsm(alpha,sv%l,ww,beta,y,desc_data,info,&
           & trans=trans_,scale='U',choice=psb_none_,work=aux)
    case default
      call psb_errpush(4001,name,a_err='Invalid TRANS in ILU subsolve')
      goto 9999
    end select


    if (info /= 0) then

      call psb_errpush(4001,name,a_err='Error in subsolve')
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

  end subroutine d_ilu_solver_apply

  subroutine d_ilu_solver_bld(a,desc_a,sv,upd,info,b)

    use psb_base_mod

    Implicit None

    ! Arguments
    type(psb_d_sparse_mat), intent(in), target  :: a
    Type(psb_desc_type), Intent(in)             :: desc_a 
    class(mld_d_ilu_solver_type), intent(inout) :: sv
    character, intent(in)                       :: upd
    integer, intent(out)                        :: info
    type(psb_d_sparse_mat), intent(in), target, optional  :: b
    ! Local variables
    integer :: n_row,n_col, nrow_a, nztota
    real(psb_dpk_), pointer :: ww(:), aux(:), tx(:),ty(:)
    integer :: ictxt,np,me,i, err_act, debug_unit, debug_level
    character(len=20)  :: name='d_ilu_solver_bld', ch_err
    
    info=0
    call psb_erractionsave(err_act)
    debug_unit  = psb_get_debug_unit()
    debug_level = psb_get_debug_level()
    ictxt       = psb_cd_get_context(desc_a)
    call psb_info(ictxt, me, np)
    if (debug_level >= psb_debug_outer_) &
         & write(debug_unit,*) me,' ',trim(name),' start'


    n_row  = psb_cd_get_local_rows(desc_a)

    if (psb_toupper(upd) == 'F') then 
      nrow_a = a%get_nrows()
      nztota = a%get_nzeros()
      if (present(b)) then 
        nztota = nztota + b%get_nzeros()
      end if

      call sv%l%csall(n_row,n_row,info,nztota)
      if (info == 0) call sv%u%csall(n_row,n_row,info,nztota)
      if(info/=0) then
        info=4010
        ch_err='psb_sp_all'
        call psb_errpush(info,name,a_err=ch_err)
        goto 9999
      end if

      if (allocated(sv%d)) then 
        if (size(sv%d) < n_row) then 
          deallocate(sv%d)
        endif
      endif
      if (.not.allocated(sv%d)) then 
        allocate(sv%d(n_row),stat=info)
        if (info /= 0) then 
          call psb_errpush(4010,name,a_err='Allocate')
          goto 9999      
        end if

      endif


      select case(sv%fact_type)

      case (mld_ilu_t_)
        !
        ! ILU(k,t)
        !
        select case(sv%fill_in)

        case(:-1) 
          ! Error: fill-in <= -1
          call psb_errpush(30,name,i_err=(/3,sv%fill_in,0,0,0/))
          goto 9999

        case(0:)
          ! Fill-in >= 0
          call mld_ilut_fact(sv%fill_in,sv%thresh,&
               & a, sv%l,sv%u,sv%d,info,blck=b)
        end select
        if(info/=0) then
          info=4010
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
          call psb_errpush(30,name,i_err=(/3,sv%fill_in,0,0,0/))
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
        if (info/=0) then
          info=4010
          ch_err='mld_iluk_fact'
          call psb_errpush(info,name,a_err=ch_err)
          goto 9999
        end if

      case default
        ! If we end up here, something was wrong up in the call chain. 
        call psb_errpush(4000,name)
        goto 9999

      end select
    else
      ! Here we should add checks for reuse of L and U.
      ! For the time being just throw an error. 
      info = 31
      call psb_errpush(info, name, i_err=(/3,0,0,0,0/),a_err=upd)
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
  end subroutine d_ilu_solver_bld


  subroutine d_ilu_solver_seti(sv,what,val,info)

    use psb_base_mod

    Implicit None

    ! Arguments
    class(mld_d_ilu_solver_type), intent(inout) :: sv 
    integer, intent(in)                    :: what 
    integer, intent(in)                    :: val
    integer, intent(out)                   :: info
    Integer :: err_act
    character(len=20)  :: name='d_ilu_solver_seti'

    info = 0 
    call psb_erractionsave(err_act)

    select case(what) 
    case(mld_sub_solve_) 
      sv%fact_type = val
    case(mld_sub_fillin_)
      sv%fill_in   = val
    case default
      write(0,*) name,': Error: invalid WHAT'
!!$      info = -2
    end select

    call psb_erractionrestore(err_act)
    return

9999 continue
    call psb_erractionrestore(err_act)
    if (err_act == psb_act_abort_) then
      call psb_error()
      return
    end if
    return
  end subroutine d_ilu_solver_seti

  subroutine d_ilu_solver_setc(sv,what,val,info)

    use psb_base_mod

    Implicit None

    ! Arguments
    class(mld_d_ilu_solver_type), intent(inout) :: sv
    integer, intent(in)                    :: what 
    character(len=*), intent(in)           :: val
    integer, intent(out)                   :: info
    Integer :: err_act, ival
    character(len=20)  :: name='d_ilu_solver_setc'

    info = 0 
    call psb_erractionsave(err_act)


    call mld_stringval(val,ival,info)
    if (info == 0) call sv%set(what,ival,info)
    if (info /= 0) then
      info = 4010
      call psb_errpush(info, name)
      goto 9999
    end if

    call psb_erractionrestore(err_act)
    return

9999 continue
    call psb_erractionrestore(err_act)
    if (err_act == psb_act_abort_) then
      call psb_error()
      return
    end if
    return
  end subroutine d_ilu_solver_setc
  
  subroutine d_ilu_solver_setr(sv,what,val,info)

    use psb_base_mod

    Implicit None

    ! Arguments
    class(mld_d_ilu_solver_type), intent(inout) :: sv 
    integer, intent(in)                    :: what 
    real(psb_dpk_), intent(in)             :: val
    integer, intent(out)                   :: info
    Integer :: err_act
    character(len=20)  :: name='d_ilu_solver_setr'

    call psb_erractionsave(err_act)
    info = 0

    select case(what)
    case(mld_sub_iluthrs_) 
      sv%thresh = val
    case default
      write(0,*) name,': Error: invalid WHAT'
!!$      info = -2
!!$      goto 9999
    end select

    call psb_erractionrestore(err_act)
    return

9999 continue
    call psb_erractionrestore(err_act)
    if (err_act == psb_act_abort_) then
      call psb_error()
      return
    end if
    return
  end subroutine d_ilu_solver_setr

  subroutine d_ilu_solver_free(sv,info)

    use psb_base_mod

    Implicit None

    ! Arguments
    class(mld_d_ilu_solver_type), intent(inout) :: sv
    integer, intent(out)                       :: info
    Integer :: err_act
    character(len=20)  :: name='d_ilu_solver_free'

    call psb_erractionsave(err_act)
    info = 0
    
    if (allocated(sv%d)) then 
      deallocate(sv%d,stat=info)
      if (info /= 0) then 
        info = 4000
        call psb_errpush(info,name)
        goto 9999 
      end if
    end if
    call sv%l%free()
    call sv%u%free()

    call psb_erractionrestore(err_act)
    return

9999 continue
    call psb_erractionrestore(err_act)
    if (err_act == psb_act_abort_) then
      call psb_error()
      return
    end if
    return
  end subroutine d_ilu_solver_free

  subroutine d_ilu_solver_descr(sv,info,iout)

    use psb_base_mod

    Implicit None

    ! Arguments
    class(mld_d_ilu_solver_type), intent(inout) :: sv
    integer, intent(out)                         :: info
    integer, intent(in), optional                :: iout

    ! Local variables
    integer      :: err_act
    integer      :: ictxt, me, np
    character(len=20), parameter :: name='mld_d_ilu_solver_descr'
    integer :: iout_

    call psb_erractionsave(err_act)
    info = 0
    if (present(iout)) then 
      iout_ = iout 
    else
      iout_ = 6
    endif
    
    write(iout_,*) '  Incomplete factorization solver: ',&
           &  fact_names(sv%fact_type)
    select case(sv%fact_type)
    case(mld_ilu_n_,mld_milu_n_)      
      write(iout_,*) '  Fill level:',sv%fill_in
    case(mld_ilu_t_)         
      write(iout_,*) '  Fill level:',sv%fill_in
      write(iout_,*) '  Fill threshold :',sv%thresh
    end select

    call psb_erractionrestore(err_act)
    return

9999 continue
    call psb_erractionrestore(err_act)
    if (err_act == psb_act_abort_) then
      call psb_error()
      return
    end if
    return
  end subroutine d_ilu_solver_descr

  function d_ilu_solver_sizeof(sv) result(val)
    use psb_base_mod
    implicit none 
    ! Arguments
    class(mld_d_ilu_solver_type), intent(inout) :: sv
    integer(psb_long_int_k_) :: val
    integer             :: i

    val = 2*psb_sizeof_int + psb_sizeof_dp
    if (allocated(sv%d)) val = val + psb_sizeof_dp * size(sv%d)
    val = val + psb_sizeof(sv%l)
    val = val + psb_sizeof(sv%u)

    return
  end function d_ilu_solver_sizeof

end module mld_d_ilu_solver
