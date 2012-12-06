!!$
!!$ 
!!$                           MLD2P4  version 2.0
!!$  MultiLevel Domain Decomposition Parallel Preconditioners Package
!!$             based on PSBLAS (Parallel Sparse BLAS version 3.0)
!!$  
!!$  (C) Copyright 2008,2009,2010,2012
!!$
!!$                      Salvatore Filippone  University of Rome Tor Vergata
!!$                      Alfredo Buttari      CNRS-IRIT, Toulouse
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
! File: mld_s_onelev_mod.f90
!
! Module: mld_s_onelev_mod
!
!  This module defines: 
!  - the mld_s_onelev_type data structure containing one level
!    of a multilevel  preconditioner and related
!    data structures;
!
!  It contains routines for
!  - Building and applying; 
!  - checking if the preconditioner is correctly defined;
!  - printing a	description of the preconditioner;
!  - deallocating the preconditioner data structure.  
!

module mld_s_onelev_mod

  use mld_base_prec_type
  use mld_s_base_smoother_mod
  use psb_base_mod, only : psb_sspmat_type, psb_s_vect_type, psb_s_base_vect_type, &
       & psb_slinmap_type, psb_spk_,  psb_ipk_, psb_long_int_k_, psb_desc_type
  !
  !
  ! Type: mld_Tonelev_type.
  !
  !  It is the data type containing the necessary items for the	current
  !  level (essentially, the smoother, the current-level matrix
  !  and the restriction and prolongation operators).
  !
  !  type mld_Tonelev_type
  !    class(mld_T_base_smoother_type), allocatable :: sm
  !    type(mld_RTml_parms)            :: parms 
  !    type(psb_Tspmat_type)           :: ac
  !    type(psb_Tesc_type)             :: desc_ac
  !    type(psb_Tspmat_type), pointer  :: base_a    => null() 
  !    type(psb_Tesc_type), pointer    :: base_desc => null() 
  !    type(psb_Tlinmap_type)          :: map
  !  end type mld_Tonelev_type
  !
  !  Note that psb_Tpk denotes the kind of the real data type to be chosen
  !  according to single/double precision version of MLD2P4.
  !
  !   sm           -  class(mld_T_base_smoother_type), allocatable
  !                   The current level preconditioner (aka smoother).
  !   parms        -  type(mld_RTml_parms)
  !                   The parameters defining the multilevel strategy.
  !   ac           -  The local part of the current-level matrix, built by
  !                   coarsening the previous-level matrix.
  !   desc_ac      -  type(psb_desc_type).
  !                   The communication descriptor associated to the matrix
  !                   stored in ac.
  !   base_a       -  type(psb_Tspmat_type), pointer.
  !                   Pointer (really a pointer!) to the local part of the current 
  !                   matrix (so we have a unified treatment of residuals).
  !                   We need this to avoid passing explicitly the current matrix
  !                   to the routine which applies the preconditioner.
  !   base_desc    -  type(psb_desc_type), pointer.
  !                   Pointer to the communication descriptor associated to the
  !                   matrix pointed by base_a.
  !   map          -  Stores the maps (restriction and prolongation) between the
  !                   vector spaces associated to the index spaces of the previous
  !                   and current levels.
  !
  !   Methods:  
  !     Most methods follow the encapsulation hierarchy: they take whatever action
  !     is appropriate for the current object, then call the corresponding method for
  !     the contained object.
  !     As an example: the descr() method prints out a description of the
  !     level. It starts by invoking the descr() method of the parms object,
  !     then calls the descr() method of the smoother object. 
  !
  !    descr      -   Prints a description of the object.
  !    default    -   Set default values
  !    dump       -   Dump to file object contents
  !    set        -   Sets various parameters; when a request is unknown
  !                   it is passed to the smoother object for further processing.
  !    check      -   Sanity checks.
  !    sizeof     -   Total memory occupation in bytes
  !    get_nzeros -   Number of nonzeros 
  !
  !
  type mld_s_onelev_type
    class(mld_s_base_smoother_type), allocatable :: sm
    type(mld_sml_parms)             :: parms 
    type(psb_sspmat_type)           :: ac
    type(psb_desc_type)             :: desc_ac
    type(psb_sspmat_type), pointer  :: base_a    => null() 
    type(psb_desc_type), pointer    :: base_desc => null() 
    type(psb_slinmap_type)          :: map
  contains
    procedure, pass(lv) :: descr   => mld_s_base_onelev_descr
    procedure, pass(lv) :: default => s_base_onelev_default
    procedure, pass(lv) :: free    => mld_s_base_onelev_free
    procedure, pass(lv) :: nullify => s_base_onelev_nullify
    procedure, pass(lv) :: check => mld_s_base_onelev_check
    procedure, pass(lv) :: dump  => mld_s_base_onelev_dump
    procedure, pass(lv) :: seti  => mld_s_base_onelev_seti
    procedure, pass(lv) :: setr  => mld_s_base_onelev_setr
    procedure, pass(lv) :: setc  => mld_s_base_onelev_setc
    generic, public     :: set   => seti, setr, setc
    procedure, pass(lv) :: sizeof => s_base_onelev_sizeof
    procedure, pass(lv) :: get_nzeros => s_base_onelev_get_nzeros
  end type mld_s_onelev_type

  type mld_s_onelev_node
    type(mld_s_onelev_type) :: item
    type(mld_s_onelev_node), pointer :: prev=>null(), next=>null()
  end type mld_s_onelev_node

  private :: s_base_onelev_default, s_base_onelev_sizeof, &
       &  s_base_onelev_nullify, s_base_onelev_get_nzeros



  interface 
    subroutine mld_s_base_onelev_descr(lv,il,nl,info,iout)
      import :: psb_sspmat_type, psb_s_vect_type, psb_s_base_vect_type, &
           & psb_slinmap_type, psb_spk_, mld_s_onelev_type, &
           & psb_ipk_, psb_long_int_k_, psb_desc_type
      Implicit None
      ! Arguments
      class(mld_s_onelev_type), intent(in) :: lv
      integer(psb_ipk_), intent(in)                 :: il,nl
      integer(psb_ipk_), intent(out)                :: info
      integer(psb_ipk_), intent(in), optional       :: iout
    end subroutine mld_s_base_onelev_descr
  end interface
  
  interface 
    subroutine mld_s_base_onelev_free(lv,info)
      import :: psb_sspmat_type, psb_s_vect_type, psb_s_base_vect_type, &
           & psb_slinmap_type, psb_spk_, mld_s_onelev_type, &
           & psb_ipk_, psb_long_int_k_, psb_desc_type
      implicit none 
      
      class(mld_s_onelev_type), intent(inout) :: lv
      integer(psb_ipk_), intent(out)                :: info
    end subroutine mld_s_base_onelev_free
  end interface
  
  interface 
    subroutine mld_s_base_onelev_check(lv,info)
      import :: psb_sspmat_type, psb_s_vect_type, psb_s_base_vect_type, &
           & psb_slinmap_type, psb_spk_, mld_s_onelev_type, &
           & psb_ipk_, psb_long_int_k_, psb_desc_type
      Implicit None
      ! Arguments
      class(mld_s_onelev_type), intent(inout) :: lv 
      integer(psb_ipk_), intent(out)            :: info
    end subroutine mld_s_base_onelev_check
  end interface
  
  interface 
    subroutine mld_s_base_onelev_seti(lv,what,val,info)
      import :: psb_sspmat_type, psb_s_vect_type, psb_s_base_vect_type, &
           & psb_slinmap_type, psb_spk_, mld_s_onelev_type, &
           & psb_ipk_, psb_long_int_k_, psb_desc_type
      Implicit None
      
      ! Arguments
      class(mld_s_onelev_type), intent(inout) :: lv 
      integer(psb_ipk_), intent(in)             :: what 
      integer(psb_ipk_), intent(in)             :: val
      integer(psb_ipk_), intent(out)            :: info
    end subroutine mld_s_base_onelev_seti
  end interface
  
  interface 
    subroutine mld_s_base_onelev_setc(lv,what,val,info)
      import :: psb_sspmat_type, psb_s_vect_type, psb_s_base_vect_type, &
           & psb_slinmap_type, psb_spk_, mld_s_onelev_type, &
           & psb_ipk_, psb_long_int_k_, psb_desc_type
      Implicit None
      ! Arguments
      class(mld_s_onelev_type), intent(inout) :: lv 
      integer(psb_ipk_), intent(in)             :: what 
      character(len=*), intent(in)              :: val
      integer(psb_ipk_), intent(out)            :: info
    end subroutine mld_s_base_onelev_setc
  end interface
  
  interface 
    subroutine mld_s_base_onelev_setr(lv,what,val,info)
      import :: psb_sspmat_type, psb_s_vect_type, psb_s_base_vect_type, &
           & psb_slinmap_type, psb_spk_, mld_s_onelev_type, &
           & psb_ipk_, psb_long_int_k_, psb_desc_type
      Implicit None
      
      class(mld_s_onelev_type), intent(inout) :: lv 
      integer(psb_ipk_), intent(in)             :: what 
      real(psb_spk_), intent(in)                 :: val
      integer(psb_ipk_), intent(out)            :: info
    end subroutine mld_s_base_onelev_setr
  end interface

  interface 
    subroutine mld_s_base_onelev_dump(lv,level,info,prefix,head,ac,rp,smoother,solver)
      import :: psb_sspmat_type, psb_s_vect_type, psb_s_base_vect_type, &
           & psb_slinmap_type, psb_spk_, mld_s_onelev_type, &
           & psb_ipk_, psb_long_int_k_, psb_desc_type
      implicit none 
      class(mld_s_onelev_type), intent(in) :: lv
      integer(psb_ipk_), intent(in)          :: level
      integer(psb_ipk_), intent(out)         :: info
      character(len=*), intent(in), optional :: prefix, head
      logical, optional, intent(in)    :: ac, rp, smoother, solver
    end subroutine mld_s_base_onelev_dump
  end interface
  
  interface mld_move_alloc
    module procedure  mld_s_onelev_move_alloc
  end interface
  
contains
  !
  ! Function returning the size of the mld_prec_type data structure
  ! in bytes or in number of nonzeros of the operator(s) involved. 
  !

  function s_base_onelev_get_nzeros(lv) result(val)
    implicit none 
    class(mld_s_onelev_type), intent(in) :: lv
    integer(psb_long_int_k_) :: val
    integer(psb_ipk_)        :: i
    val = 0
    if (allocated(lv%sm)) &
         &  val =  lv%sm%get_nzeros()
  end function s_base_onelev_get_nzeros

  function s_base_onelev_sizeof(lv) result(val)
    implicit none 
    class(mld_s_onelev_type), intent(in) :: lv
    integer(psb_long_int_k_) :: val
    integer(psb_ipk_)        :: i
    
    val = 0
    val = val + lv%desc_ac%sizeof()
    val = val + lv%ac%sizeof()
    val = val + lv%map%sizeof() 
    if (allocated(lv%sm))  val = val + lv%sm%sizeof()
  end function s_base_onelev_sizeof


  subroutine s_base_onelev_nullify(lv)
    implicit none 

    class(mld_s_onelev_type), intent(inout) :: lv

    nullify(lv%base_a) 
    nullify(lv%base_desc) 

  end subroutine s_base_onelev_nullify

  !
  ! Multilevel defaults: 
  !  multiplicative vs. additive ML framework;
  !  Smoothed decoupled aggregation with zero threshold; 
  !  distributed coarse matrix;
  !  damping omega  computed with the max-norm estimate of the
  !  dominant eigenvalue;
  !  two-sided smoothing (i.e. V-cycle) with 1 smoothing sweep;
  !

  subroutine s_base_onelev_default(lv)

    Implicit None

    ! Arguments
    class(mld_s_onelev_type), intent(inout) :: lv 

    lv%parms%sweeps          = 1
    lv%parms%sweeps_pre      = 1
    lv%parms%sweeps_post     = 1
    lv%parms%ml_type         = mld_mult_ml_
    lv%parms%aggr_alg        = mld_dec_aggr_
    lv%parms%aggr_kind       = mld_smooth_prol_
    lv%parms%coarse_mat      = mld_distr_mat_
    lv%parms%smoother_pos    = mld_twoside_smooth_
    lv%parms%aggr_omega_alg  = mld_eig_est_
    lv%parms%aggr_eig        = mld_max_norm_
    lv%parms%aggr_filter     = mld_no_filter_mat_
    lv%parms%aggr_omega_val  = szero
    lv%parms%aggr_thresh     = szero
    
    if (allocated(lv%sm)) call lv%sm%default()

    return

  end subroutine s_base_onelev_default


  subroutine mld_s_onelev_move_alloc(a, b,info)
    use psb_base_mod
    implicit none
    type(mld_s_onelev_type), intent(inout) :: a, b
    integer(psb_ipk_), intent(out) :: info 
    
    call b%free(info)
    b%parms  = a%parms
    call move_alloc(a%sm,b%sm)
    if (info == psb_success_) call psb_move_alloc(a%ac,b%ac,info) 
    if (info == psb_success_) call psb_move_alloc(a%desc_ac,b%desc_ac,info) 
    if (info == psb_success_) call psb_move_alloc(a%map,b%map,info) 
    b%base_a    => a%base_a
    b%base_desc => a%base_desc
    
  end subroutine mld_s_onelev_move_alloc

end module mld_s_onelev_mod
