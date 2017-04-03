!!$
!!$ 
!!$                           MLD2P4  version 2.1
!!$  MultiLevel Domain Decomposition Parallel Preconditioners Package
!!$             based on PSBLAS (Parallel Sparse BLAS version 3.4)
!!$  
!!$  (C) Copyright 2008, 2010, 2012, 2015, 2017 
!!$
!!$      Salvatore Filippone    Cranfield University
!!$      Ambra Abdullahi Hassan University of Rome Tor Vergata
!!$      Alfredo Buttari        CNRS-IRIT, Toulouse
!!$      Pasqua D'Ambra         ICAR-CNR, Naples
!!$      Daniela di Serafino    University of Campania "L. Vanvitelli", Caserta
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
! File: mld_z_gs_solver_mod.f90
!
! Module: mld_z_gs_solver_mod
!
!  This module defines: 
!  - the mld_z_gs_solver_type data structure containing the ingredients
!    for a local Gauss-Seidel iteration. We provide Forward GS (FWGS) and
!    backward GS (BWGS). The iterations are local to a process (they operate
!    on the block diagonal). Combined with a Jacobi smoother will generate a
!    hybrid-Gauss-Seidel solver, i.e. Gauss-Seidel within each process, Jacobi
!    among the processes. 
!
!
module mld_z_gs_solver

  use mld_z_base_solver_mod

  type, extends(mld_z_base_solver_type) :: mld_z_gs_solver_type
    type(psb_zspmat_type)      :: l, u
    integer(psb_ipk_)          :: sweeps
    real(psb_dpk_)             :: eps
  contains
    procedure, pass(sv) :: dump    => mld_z_gs_solver_dmp
    procedure, pass(sv) :: ccheck  => d_gs_solver_check
    procedure, pass(sv) :: clone   => mld_z_gs_solver_clone
    procedure, pass(sv) :: build   => mld_z_gs_solver_bld
    procedure, pass(sv) :: cnv     => mld_z_gs_solver_cnv
    procedure, pass(sv) :: apply_v => mld_z_gs_solver_apply_vect
    procedure, pass(sv) :: apply_a => mld_z_gs_solver_apply
    procedure, pass(sv) :: free    => d_gs_solver_free
    procedure, pass(sv) :: seti    => d_gs_solver_seti
    procedure, pass(sv) :: setc    => d_gs_solver_setc
    procedure, pass(sv) :: setr    => d_gs_solver_setr
    procedure, pass(sv) :: cseti   => d_gs_solver_cseti
    procedure, pass(sv) :: csetc   => d_gs_solver_csetc
    procedure, pass(sv) :: csetr   => d_gs_solver_csetr
    procedure, pass(sv) :: descr   => d_gs_solver_descr
    procedure, pass(sv) :: default => d_gs_solver_default
    procedure, pass(sv) :: sizeof  => d_gs_solver_sizeof
    procedure, pass(sv) :: get_nzeros => d_gs_solver_get_nzeros
    procedure, nopass   :: get_fmt    => d_gs_solver_get_fmt
    procedure, nopass   :: is_iterative => d_gs_solver_is_iterative
  end type mld_z_gs_solver_type

  type, extends(mld_z_gs_solver_type) :: mld_z_bwgs_solver_type
  contains
    procedure, pass(sv) :: build    => mld_z_bwgs_solver_bld
    procedure, pass(sv) :: apply_v  => mld_z_bwgs_solver_apply_vect
    procedure, pass(sv) :: apply_a  => mld_z_bwgs_solver_apply
    procedure, nopass   :: get_fmt  => z_bwgs_solver_get_fmt
    procedure, pass(sv) :: descr    => z_bwgs_solver_descr
  end type mld_z_bwgs_solver_type


  private :: z_gs_solver_bld, z_gs_solver_apply, &
       &  z_gs_solver_free,   z_gs_solver_seti, &
       &  z_gs_solver_setc,   z_gs_solver_setr,&
       &  z_gs_solver_descr,  z_gs_solver_sizeof, &
       &  z_gs_solver_default, z_gs_solver_dmp, &
       &  z_gs_solver_apply_vect, z_gs_solver_get_nzeros, &
       &  z_gs_solver_get_fmt, z_gs_solver_check,&
       &  z_gs_solver_is_iterative, &
       &  z_bwgs_solver_get_fmt, z_bwgs_solver_descr


  interface 
    subroutine mld_z_gs_solver_apply_vect(alpha,sv,x,beta,y,desc_data,&
         & trans,work,info,init,initu)
      import :: psb_desc_type, mld_z_gs_solver_type, psb_z_vect_type, psb_dpk_, &
           & psb_zspmat_type, psb_z_base_sparse_mat, psb_z_base_vect_type, psb_ipk_
      implicit none 
      type(psb_desc_type), intent(in)             :: desc_data
      class(mld_z_gs_solver_type), intent(inout) :: sv
      type(psb_z_vect_type),intent(inout)         :: x
      type(psb_z_vect_type),intent(inout)         :: y
      complex(psb_dpk_),intent(in)                    :: alpha,beta
      character(len=1),intent(in)                   :: trans
      complex(psb_dpk_),target, intent(inout)         :: work(:)
      integer(psb_ipk_), intent(out)                :: info
      character, intent(in), optional                :: init
      type(psb_z_vect_type),intent(inout), optional   :: initu
    end subroutine mld_z_gs_solver_apply_vect
    subroutine mld_z_bwgs_solver_apply_vect(alpha,sv,x,beta,y,desc_data,&
         & trans,work,info,init,initu)
      import :: psb_desc_type, mld_z_bwgs_solver_type, psb_z_vect_type, psb_dpk_, &
           & psb_zspmat_type, psb_z_base_sparse_mat, psb_z_base_vect_type, psb_ipk_
      implicit none 
      type(psb_desc_type), intent(in)             :: desc_data
      class(mld_z_bwgs_solver_type), intent(inout) :: sv
      type(psb_z_vect_type),intent(inout)         :: x
      type(psb_z_vect_type),intent(inout)         :: y
      complex(psb_dpk_),intent(in)                    :: alpha,beta
      character(len=1),intent(in)                   :: trans
      complex(psb_dpk_),target, intent(inout)         :: work(:)
      integer(psb_ipk_), intent(out)                :: info
      character, intent(in), optional                :: init
      type(psb_z_vect_type),intent(inout), optional   :: initu
    end subroutine mld_z_bwgs_solver_apply_vect
  end interface

  interface 
    subroutine mld_z_gs_solver_apply(alpha,sv,x,beta,y,desc_data,trans,work,info,init,initu)
      import :: psb_desc_type, mld_z_gs_solver_type, psb_z_vect_type, psb_dpk_, &
           & psb_zspmat_type, psb_z_base_sparse_mat, psb_z_base_vect_type, psb_ipk_
      implicit none 
      type(psb_desc_type), intent(in)      :: desc_data
      class(mld_z_gs_solver_type), intent(inout) :: sv
      complex(psb_dpk_),intent(inout)         :: x(:)
      complex(psb_dpk_),intent(inout)         :: y(:)
      complex(psb_dpk_),intent(in)            :: alpha,beta
      character(len=1),intent(in)           :: trans
      complex(psb_dpk_),target, intent(inout) :: work(:)
      integer(psb_ipk_), intent(out)        :: info
      character, intent(in), optional       :: init
      complex(psb_dpk_),intent(inout), optional :: initu(:)
    end subroutine mld_z_gs_solver_apply
    subroutine mld_z_bwgs_solver_apply(alpha,sv,x,beta,y,desc_data,&
         & trans,work,info,init,initu)
      import :: psb_desc_type, mld_z_bwgs_solver_type, psb_z_vect_type, psb_dpk_, &
           & psb_zspmat_type, psb_z_base_sparse_mat, psb_z_base_vect_type, psb_ipk_
      implicit none 
      type(psb_desc_type), intent(in)      :: desc_data
      class(mld_z_bwgs_solver_type), intent(inout) :: sv
      complex(psb_dpk_),intent(inout)         :: x(:)
      complex(psb_dpk_),intent(inout)         :: y(:)
      complex(psb_dpk_),intent(in)            :: alpha,beta
      character(len=1),intent(in)           :: trans
      complex(psb_dpk_),target, intent(inout) :: work(:)
      integer(psb_ipk_), intent(out)        :: info
      character, intent(in), optional       :: init
      complex(psb_dpk_),intent(inout), optional :: initu(:)
    end subroutine mld_z_bwgs_solver_apply
  end interface

  interface 
    subroutine mld_z_gs_solver_bld(a,desc_a,sv,upd,info,b,amold,vmold,imold)
      import :: psb_desc_type, mld_z_gs_solver_type, psb_z_vect_type, psb_dpk_, &
           & psb_zspmat_type, psb_z_base_sparse_mat, psb_z_base_vect_type,&
           & psb_ipk_, psb_i_base_vect_type
      implicit none 
      type(psb_zspmat_type), intent(in), target           :: a
      Type(psb_desc_type), Intent(in)                     :: desc_a 
      class(mld_z_gs_solver_type), intent(inout)         :: sv
      character, intent(in)                               :: upd
      integer(psb_ipk_), intent(out)                      :: info
      type(psb_zspmat_type), intent(in), target, optional :: b
      class(psb_z_base_sparse_mat), intent(in), optional  :: amold
      class(psb_z_base_vect_type), intent(in), optional   :: vmold
      class(psb_i_base_vect_type), intent(in), optional   :: imold
    end subroutine mld_z_gs_solver_bld
    subroutine mld_z_bwgs_solver_bld(a,desc_a,sv,upd,info,b,amold,vmold,imold)
      import :: psb_desc_type, mld_z_bwgs_solver_type, psb_z_vect_type, psb_dpk_, &
           & psb_zspmat_type, psb_z_base_sparse_mat, psb_z_base_vect_type,&
           & psb_ipk_, psb_i_base_vect_type
      implicit none 
      type(psb_zspmat_type), intent(in), target           :: a
      Type(psb_desc_type), Intent(in)                     :: desc_a 
      class(mld_z_bwgs_solver_type), intent(inout)         :: sv
      character, intent(in)                               :: upd
      integer(psb_ipk_), intent(out)                      :: info
      type(psb_zspmat_type), intent(in), target, optional :: b
      class(psb_z_base_sparse_mat), intent(in), optional  :: amold
      class(psb_z_base_vect_type), intent(in), optional   :: vmold
      class(psb_i_base_vect_type), intent(in), optional   :: imold
    end subroutine mld_z_bwgs_solver_bld
  end interface

  interface 
    subroutine mld_z_gs_solver_cnv(sv,info,amold,vmold,imold)
      import :: mld_z_gs_solver_type, psb_dpk_, &
           & psb_z_base_sparse_mat, psb_z_base_vect_type,&
           & psb_ipk_, psb_i_base_vect_type
      implicit none 
      class(mld_z_gs_solver_type), intent(inout)         :: sv
      integer(psb_ipk_), intent(out)                      :: info
      class(psb_z_base_sparse_mat), intent(in), optional  :: amold
      class(psb_z_base_vect_type), intent(in), optional   :: vmold
      class(psb_i_base_vect_type), intent(in), optional   :: imold
    end subroutine mld_z_gs_solver_cnv
  end interface
  
  interface 
    subroutine mld_z_gs_solver_dmp(sv,ictxt,level,info,prefix,head,solver)
      import :: psb_desc_type, mld_z_gs_solver_type, psb_z_vect_type, psb_dpk_, &
           & psb_zspmat_type, psb_z_base_sparse_mat, psb_z_base_vect_type, &
           & psb_ipk_
      implicit none 
      class(mld_z_gs_solver_type), intent(in) :: sv
      integer(psb_ipk_), intent(in)              :: ictxt
      integer(psb_ipk_), intent(in)              :: level
      integer(psb_ipk_), intent(out)             :: info
      character(len=*), intent(in), optional     :: prefix, head
      logical, optional, intent(in)              :: solver
    end subroutine mld_z_gs_solver_dmp
  end interface
  
  interface
    subroutine mld_z_gs_solver_clone(sv,svout,info)
      import :: psb_desc_type, psb_zspmat_type,  psb_z_base_sparse_mat, &
           & psb_z_vect_type, psb_z_base_vect_type, psb_dpk_, &
           & mld_z_base_solver_type, mld_z_gs_solver_type, psb_ipk_
      Implicit None
      
      ! Arguments
      class(mld_z_gs_solver_type), intent(inout)               :: sv
      class(mld_z_base_solver_type), allocatable, intent(inout) :: svout
      integer(psb_ipk_), intent(out)              :: info
    end subroutine mld_z_gs_solver_clone
  end interface

contains

  subroutine d_gs_solver_default(sv)

    Implicit None

    ! Arguments
    class(mld_z_gs_solver_type), intent(inout) :: sv

    sv%sweeps = ione
    sv%eps    = dzero
    
    return
  end subroutine d_gs_solver_default

  subroutine d_gs_solver_check(sv,info)

    Implicit None

    ! Arguments
    class(mld_z_gs_solver_type), intent(inout) :: sv
    integer(psb_ipk_), intent(out)                :: info
    integer(psb_ipk_) :: err_act
    character(len=20) :: name='d_gs_solver_check'

    call psb_erractionsave(err_act)
    info = psb_success_

    call mld_check_def(sv%sweeps,&
         & 'GS Sweeps',ione,is_int_positive)

    if (info /= psb_success_) goto 9999
    
    call psb_erractionrestore(err_act)
    return

9999 call psb_error_handler(err_act)
    return

  end subroutine d_gs_solver_check


  subroutine d_gs_solver_seti(sv,what,val,info)

    Implicit None

    ! Arguments
    class(mld_z_gs_solver_type), intent(inout) :: sv 
    integer(psb_ipk_), intent(in)                 :: what 
    integer(psb_ipk_), intent(in)                 :: val
    integer(psb_ipk_), intent(out)                :: info
    integer(psb_ipk_)  :: err_act
    character(len=20)  :: name='d_gs_solver_seti'

    info = psb_success_
    call psb_erractionsave(err_act)

    select case(what) 
    case(mld_solver_sweeps_) 
      sv%sweeps = val
    case default
      call sv%mld_z_base_solver_type%set(what,val,info)
    end select

    call psb_erractionrestore(err_act)
    return

9999 call psb_error_handler(err_act)
    return
  end subroutine d_gs_solver_seti

  subroutine d_gs_solver_setc(sv,what,val,info)

    Implicit None

    ! Arguments
    class(mld_z_gs_solver_type), intent(inout) :: sv
    integer(psb_ipk_), intent(in)                 :: what 
    character(len=*), intent(in)                  :: val
    integer(psb_ipk_), intent(out)                :: info
    integer(psb_ipk_)  :: err_act, ival
    character(len=20)  :: name='d_gs_solver_setc'

    info = psb_success_
    call psb_erractionsave(err_act)


    ival =  sv%stringval(val)
    if (ival >= 0) then 
      call sv%set(what,ival,info)
    end if
      
    if (info /= psb_success_) then
      info = psb_err_from_subroutine_
      call psb_errpush(info, name)
      goto 9999
    end if

    call psb_erractionrestore(err_act)
    return

9999 call psb_error_handler(err_act)
    return
  end subroutine d_gs_solver_setc
  
  subroutine d_gs_solver_setr(sv,what,val,info)

    Implicit None

    ! Arguments
    class(mld_z_gs_solver_type), intent(inout) :: sv 
    integer(psb_ipk_), intent(in)                 :: what 
    real(psb_dpk_), intent(in)                     :: val
    integer(psb_ipk_), intent(out)                :: info
    integer(psb_ipk_)  :: err_act
    character(len=20)  :: name='d_gs_solver_setr'

    call psb_erractionsave(err_act)
    info = psb_success_

    select case(what) 
    case(mld_solver_eps_) 
      sv%eps = val
    case default
      call sv%mld_z_base_solver_type%set(what,val,info)
    end select

    call psb_erractionrestore(err_act)
    return

9999 call psb_error_handler(err_act)
    return
  end subroutine d_gs_solver_setr

  subroutine d_gs_solver_cseti(sv,what,val,info)

    Implicit None

    ! Arguments
    class(mld_z_gs_solver_type), intent(inout) :: sv 
    character(len=*), intent(in)                  :: what 
    integer(psb_ipk_), intent(in)                 :: val
    integer(psb_ipk_), intent(out)                :: info
    integer(psb_ipk_)  :: err_act
    character(len=20)  :: name='d_gs_solver_cseti'

    info = psb_success_
    call psb_erractionsave(err_act)

    select case(psb_toupper(what))
    case('SOLVER_SWEEPS')
      sv%sweeps = val      
    case default
      call sv%mld_z_base_solver_type%set(what,val,info)
    end select

    call psb_erractionrestore(err_act)
    return

9999 call psb_error_handler(err_act)
    return
  end subroutine d_gs_solver_cseti

  subroutine d_gs_solver_csetc(sv,what,val,info)

    Implicit None

    ! Arguments
    class(mld_z_gs_solver_type), intent(inout) :: sv
    character(len=*), intent(in)                  :: what 
    character(len=*), intent(in)                  :: val
    integer(psb_ipk_), intent(out)                :: info
    integer(psb_ipk_)  :: err_act, ival
    character(len=20)  :: name='d_gs_solver_csetc'

    info = psb_success_
    call psb_erractionsave(err_act)


    ival =  sv%stringval(val)
    if (ival >= 0) then 
      call sv%set(what,ival,info)
    end if
      
    if (info /= psb_success_) then
      info = psb_err_from_subroutine_
      call psb_errpush(info, name)
      goto 9999
    end if

    call psb_erractionrestore(err_act)
    return

9999 call psb_error_handler(err_act)
    return
  end subroutine d_gs_solver_csetc
  
  subroutine d_gs_solver_csetr(sv,what,val,info)

    Implicit None

    ! Arguments
    class(mld_z_gs_solver_type), intent(inout) :: sv 
    character(len=*), intent(in)                  :: what 
    real(psb_dpk_), intent(in)                     :: val
    integer(psb_ipk_), intent(out)                :: info
    integer(psb_ipk_)  :: err_act
    character(len=20)  :: name='d_gs_solver_csetr'

    call psb_erractionsave(err_act)
    info = psb_success_

    select case(psb_toupper(what))
    case('SOLVER_EPS') 
      sv%eps = val
    case default
      call sv%mld_z_base_solver_type%set(what,val,info)
    end select


    call psb_erractionrestore(err_act)
    return

9999 call psb_error_handler(err_act)
    return
  end subroutine d_gs_solver_csetr

  subroutine d_gs_solver_free(sv,info)

    Implicit None

    ! Arguments
    class(mld_z_gs_solver_type), intent(inout) :: sv
    integer(psb_ipk_), intent(out)                :: info
    integer(psb_ipk_)  :: err_act
    character(len=20)  :: name='d_gs_solver_free'

    call psb_erractionsave(err_act)
    info = psb_success_

    call sv%l%free()
    call sv%u%free()

    call psb_erractionrestore(err_act)
    return

9999 call psb_error_handler(err_act)
    return
  end subroutine d_gs_solver_free

  subroutine d_gs_solver_descr(sv,info,iout,coarse)

    Implicit None

    ! Arguments
    class(mld_z_gs_solver_type), intent(in) :: sv
    integer(psb_ipk_), intent(out)             :: info
    integer(psb_ipk_), intent(in), optional    :: iout
    logical, intent(in), optional       :: coarse

    ! Local variables
    integer(psb_ipk_)      :: err_act
    character(len=20), parameter :: name='mld_z_gs_solver_descr'
    integer(psb_ipk_) :: iout_

    call psb_erractionsave(err_act)
    info = psb_success_
    if (present(iout)) then 
      iout_ = iout 
    else
      iout_ = 6
    endif

    if (sv%eps<=dzero) then 
      write(iout_,*) '  Forward Gauss-Seidel iterative solver with  ',&
           &  sv%sweeps,' sweeps'
    else
      write(iout_,*) '  Forward Gauss-Seidel iterative solver with  tolerance',&
           &  sv%eps,' and maxit', sv%sweeps
    end if
    
    call psb_erractionrestore(err_act)
    return

9999 call psb_error_handler(err_act)
    return
  end subroutine d_gs_solver_descr

  function d_gs_solver_get_nzeros(sv) result(val)

    implicit none 
    ! Arguments
    class(mld_z_gs_solver_type), intent(in) :: sv
    integer(psb_long_int_k_) :: val
    integer(psb_ipk_)        :: i
    
    val = 0 
    val = val + sv%l%get_nzeros()
    val = val + sv%u%get_nzeros()

    return
  end function d_gs_solver_get_nzeros

  function d_gs_solver_sizeof(sv) result(val)

    implicit none 
    ! Arguments
    class(mld_z_gs_solver_type), intent(in) :: sv
    integer(psb_long_int_k_) :: val
    integer(psb_ipk_)        :: i

    val = psb_sizeof_int 
    val = val + sv%l%sizeof()
    val = val + sv%u%sizeof()

    return
  end function d_gs_solver_sizeof

  function d_gs_solver_get_fmt() result(val)
    implicit none 
    character(len=32)  :: val

    val = "Forward Gauss-Seidel solver"
  end function d_gs_solver_get_fmt


  !
  ! If this is true, then the solver needs a starting
  ! guess. Currently only handled in JAC smoother. 
  ! 
  function d_gs_solver_is_iterative() result(val)
    implicit none 
    logical  :: val

    val = .true.
  end function d_gs_solver_is_iterative
    
  subroutine z_bwgs_solver_descr(sv,info,iout,coarse)

    Implicit None

    ! Arguments
    class(mld_z_bwgs_solver_type), intent(in) :: sv
    integer(psb_ipk_), intent(out)             :: info
    integer(psb_ipk_), intent(in), optional    :: iout
    logical, intent(in), optional       :: coarse

    ! Local variables
    integer(psb_ipk_)      :: err_act
    character(len=20), parameter :: name='mld_z_bwgs_solver_descr'
    integer(psb_ipk_) :: iout_

    call psb_erractionsave(err_act)
    info = psb_success_
    if (present(iout)) then 
      iout_ = iout 
    else
      iout_ = 6
    endif

    if (sv%eps<=dzero) then 
      write(iout_,*) '  Backward Gauss-Seidel iterative solver with  ',&
           &  sv%sweeps,' sweeps'
    else
      write(iout_,*) '  Backward Gauss-Seidel iterative solver with  tolerance',&
           &  sv%eps,' and maxit', sv%sweeps
    end if
    
    call psb_erractionrestore(err_act)
    return

9999 call psb_error_handler(err_act)
    return
  end subroutine z_bwgs_solver_descr

  function z_bwgs_solver_get_fmt() result(val)
    implicit none 
    character(len=32)  :: val

    val = "Backward Gauss-Seidel solver"
  end function z_bwgs_solver_get_fmt

end module mld_z_gs_solver
