! 
!   
!                             MLD2P4  version 2.1
!    MultiLevel Domain Decomposition Parallel Preconditioners Package
!               based on PSBLAS (Parallel Sparse BLAS version 3.5)
!    
!    (C) Copyright 2008, 2010, 2012, 2015, 2017 
!  
!        Salvatore Filippone    Cranfield University, UK
!        Pasqua D'Ambra         IAC-CNR, Naples, IT
!        Daniela di Serafino    University of Campania "L. Vanvitelli", Caserta, IT
!   
!    Redistribution and use in source and binary forms, with or without
!    modification, are permitted provided that the following conditions
!    are met:
!      1. Redistributions of source code must retain the above copyright
!         notice, this list of conditions and the following disclaimer.
!      2. Redistributions in binary form must reproduce the above copyright
!         notice, this list of conditions, and the following disclaimer in the
!         documentation and/or other materials provided with the distribution.
!      3. The name of the MLD2P4 group or the names of its contributors may
!         not be used to endorse or promote products derived from this
!         software without specific written permission.
!   
!    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
!    ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
!    TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
!    PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE MLD2P4 GROUP OR ITS CONTRIBUTORS
!    BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
!    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
!    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
!    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
!    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
!    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
!    POSSIBILITY OF SUCH DAMAGE.
!   
!    
! File: mld_d_pde2d.f90
!
! Program: mld_d_pde2d
! This sample program solves a linear system obtained by discretizing a
! PDE with Dirichlet BCs. 
! 
!
! The PDE is a general second order equation in 2d
!
!   a1 dd(u)  a2 dd(u)   b1 d(u)   b2 d(u) 
! -   ------ -  ------   -----  +  ------  + c u = f
!      dxdx     dydy        dx       dy    
!
! with Dirichlet boundary conditions
!   u = g 
!
!  on the unit square  0<=x,y<=1.
!
!
! Note that if b1=b2=c=0., the PDE is the  Laplace equation.
!
! In this sample program the index space of the discretized
! computational domain is first numbered sequentially in a standard way, 
! then the corresponding vector is distributed according to a BLOCK
! data distribution.
!
module mld_d_pde2d_mod
contains

  !
  ! functions parametrizing the differential equation 
  !  
  function b1(x,y)
    use psb_base_mod, only : psb_dpk_,done,dzero
    real(psb_dpk_) :: b1
    real(psb_dpk_), intent(in) :: x,y
    b1=dzero
  end function b1
  function b2(x,y)
    use psb_base_mod, only : psb_dpk_,done,dzero
    real(psb_dpk_) ::  b2
    real(psb_dpk_), intent(in) :: x,y
    b2=dzero
  end function b2
  function c(x,y)
    use psb_base_mod, only : psb_dpk_,done,dzero
    real(psb_dpk_) ::  c
    real(psb_dpk_), intent(in) :: x,y
    c=dzero
  end function c
  function a1(x,y)
    use psb_base_mod, only : psb_dpk_,done,dzero
    real(psb_dpk_) ::  a1   
    real(psb_dpk_), intent(in) :: x,y
    a1=done
  end function a1
  function a2(x,y)
    use psb_base_mod, only : psb_dpk_,done,dzero
    real(psb_dpk_) ::  a2
    real(psb_dpk_), intent(in) :: x,y
    a2=done
  end function a2
  function g(x,y)
    use psb_base_mod, only : psb_dpk_, done, dzero
    real(psb_dpk_) ::  g
    real(psb_dpk_), intent(in) :: x,y
    g = dzero
    if (x == done) then
      g = done
    else if (x == dzero) then 
      g = exp(-y**2)
    end if
  end function g
end module mld_d_pde2d_mod

program mld_d_pde2d
  use psb_base_mod
  use mld_prec_mod
  use psb_krylov_mod
  use psb_util_mod
  use data_input
  use mld_d_pde2d_mod
  implicit none

  ! input parameters
  character(len=20) :: kmethd, ptype
  character(len=5)  :: afmt
  integer(psb_ipk_) :: idim

  ! miscellaneous 
  real(psb_dpk_) :: t1, t2, tprec, thier, tslv

  ! sparse matrix and preconditioner
  type(psb_dspmat_type) :: a
  type(mld_dprec_type)  :: prec
  ! descriptor
  type(psb_desc_type)   :: desc_a
  ! dense vectors
  type(psb_d_vect_type) :: x,b,r
  ! parallel environment
  integer(psb_ipk_) :: ictxt, iam, np

  ! solver parameters
  integer(psb_ipk_)        :: iter, itmax,itrace, istopc, irst, nlv
  integer(psb_long_int_k_) :: amatsize, precsize, descsize
  real(psb_dpk_)   :: err, resmx, resmxp

  ! Krylov solver data
  type solverdata
    character(len=40)  :: kmethd      ! Krylov solver
    integer(psb_ipk_)  :: istopc      ! stopping criterion
    integer(psb_ipk_)  :: itmax       ! maximum number of iterations
    integer(psb_ipk_)  :: itrace      ! tracing
    integer(psb_ipk_)  :: irst        ! restart
    real(psb_dpk_)     :: eps         ! stopping tolerance
  end type solverdata
  type(solverdata)       :: s_choice

  ! preconditioner data
  type precdata

    ! preconditioner type
    character(len=40)  :: descr       ! verbose description of the prec
    character(len=10)  :: ptype       ! preconditioner type

    integer(psb_ipk_)  :: outer_sweeps ! number of outer sweeps: sweeps for 1-level,
                                       ! AMG cycles for ML
    ! general AMG data
    character(len=16)  :: mlcycle      ! AMG cycle type
    integer(psb_ipk_)  :: maxlevs     ! maximum number of levels in AMG preconditioner

    ! AMG aggregation
    character(len=16)  :: aggr_prol    ! aggregation type: SMOOTHED, NONSMOOTHED
    character(len=16)  :: par_aggr_alg    ! parallel aggregation algorithm: DEC, SYMDEC
    character(len=16)  :: aggr_ord    ! ordering for aggregation: NATURAL, DEGREE
    character(len=16)  :: aggr_filter ! filtering: FILTER, NO_FILTER
    real(psb_dpk_)     :: mncrratio  ! minimum aggregation ratio
    real(psb_dpk_), allocatable :: athresv(:) ! smoothed aggregation threshold vector
    integer(psb_ipk_)  :: thrvsz      ! size of threshold vector
    real(psb_dpk_)     :: athres      ! smoothed aggregation threshold
    integer(psb_ipk_)  :: csize       ! minimum size of coarsest matrix

    ! AMG smoother or pre-smoother; also 1-lev preconditioner
    character(len=16)  :: smther      ! (pre-)smoother type: BJAC, AS
    integer(psb_ipk_)  :: jsweeps     ! (pre-)smoother / 1-lev prec. sweeps
    integer(psb_ipk_)  :: novr        ! number of overlap layers
    character(len=16)  :: restr       ! restriction over application of AS
    character(len=16)  :: prol        ! prolongation over application of AS
    character(len=16)  :: solve       ! local subsolver type: ILU, MILU, ILUT,
                                      ! UMF, MUMPS, SLU, FWGS, BWGS, JAC
    integer(psb_ipk_)  :: fill        ! fill-in for incomplete LU factorization
    real(psb_dpk_)     :: thr         ! threshold for ILUT factorization

    ! AMG post-smoother; ignored by 1-lev preconditioner
    character(len=16)  :: smther2     ! post-smoother type: BJAC, AS
    integer(psb_ipk_)  :: jsweeps2    ! post-smoother sweeps
    integer(psb_ipk_)  :: novr2       ! number of overlap layers
    character(len=16)  :: restr2      ! restriction  over application of AS
    character(len=16)  :: prol2       ! prolongation over application of AS
    character(len=16)  :: solve2      ! local subsolver type: ILU, MILU, ILUT,
                                      ! UMF, MUMPS, SLU, FWGS, BWGS, JAC
    integer(psb_ipk_)  :: fill2       ! fill-in for incomplete LU factorization
    real(psb_dpk_)     :: thr2        ! threshold for ILUT factorization

    ! coarsest-level solver
    character(len=16)  :: cmat        ! coarsest matrix layout: REPL, DIST
    character(len=16)  :: csolve      ! coarsest-lev solver: BJAC, SLUDIST (distr.
                                      ! mat.); UMF, MUMPS, SLU, ILU, ILUT, MILU
                                      ! (repl. mat.)
    character(len=16)  :: csbsolve    ! coarsest-lev local subsolver: ILU, ILUT,
                                      ! MILU, UMF, MUMPS, SLU
    integer(psb_ipk_)  :: cfill       ! fill-in for incomplete LU factorization
    real(psb_dpk_)     :: cthres      ! threshold for ILUT factorization
    integer(psb_ipk_)  :: cjswp       ! sweeps for GS or JAC coarsest-lev subsolver

  end type precdata
  type(precdata)       :: p_choice

  ! other variables
  integer(psb_ipk_)  :: info, i, k
  character(len=20)  :: name,ch_err

  info=psb_success_


  call psb_init(ictxt)
  call psb_info(ictxt,iam,np)

  if (iam < 0) then 
    ! This should not happen, but just in case
    call psb_exit(ictxt)
    stop
  endif
  if(psb_get_errstatus() /= 0) goto 9999
  name='mld_d_pde2d'
  call psb_set_errverbosity(itwo)
  !
  ! Hello world
  !
  if (iam == psb_root_) then 
    write(*,*) 'Welcome to MLD2P4 version: ',mld_version_string_
    write(*,*) 'This is the ',trim(name),' sample program'
  end if

  !
  !  get parameters
  !
  call get_parms(ictxt,afmt,idim,s_choice,p_choice)

  !
  !  allocate and fill in the coefficient matrix, rhs and initial guess 
  !
  call psb_barrier(ictxt)
  t1 = psb_wtime()
  call psb_gen_pde2d(ictxt,idim,a,b,x,desc_a,afmt,&
       & a1,a2,b1,b2,c,g,info)  
  call psb_barrier(ictxt)
  t2 = psb_wtime() - t1
  if(info /= psb_success_) then
    info=psb_err_from_subroutine_
    ch_err='psb_gen_pde2d'
    call psb_errpush(info,name,a_err=ch_err)
    goto 9999
  end if

  if (iam == psb_root_) &
       & write(psb_out_unit,'("Overall matrix creation time : ",es12.5)')t2
  if (iam == psb_root_) &
       & write(psb_out_unit,'(" ")')
  !
  ! initialize the preconditioner
  !
  call prec%init(p_choice%ptype,info)
  select case(trim(psb_toupper(p_choice%ptype)))
  case ('NONE','NOPREC')
    ! Do nothing, keep defaults

  case ('JACOBI','GS','FWGS','FBGS')
    ! 1-level sweeps from "outer_sweeps"
    call prec%set('smoother_sweeps', p_choice%outer_sweeps, info)
    
  case ('BJAC')
    call prec%set('smoother_sweeps', p_choice%jsweeps, info)
    call prec%set('sub_solve',       p_choice%solve,   info)
    call prec%set('sub_fillin',      p_choice%fill,    info)
    call prec%set('sub_iluthrs',     p_choice%thr,     info)

  case('AS')
    call prec%set('smoother_sweeps', p_choice%jsweeps, info)
    call prec%set('sub_ovr',         p_choice%novr,    info)
    call prec%set('sub_restr',       p_choice%restr,   info)
    call prec%set('sub_prol',        p_choice%prol,    info)
    call prec%set('sub_solve',       p_choice%solve,   info)
    call prec%set('sub_fillin',      p_choice%fill,    info)
    call prec%set('sub_iluthrs',     p_choice%thr,     info)
    
  case ('ML') 
    ! multilevel preconditioner

    call prec%set('ml_cycle',        p_choice%mlcycle,    info)
    call prec%set('outer_sweeps',    p_choice%outer_sweeps,info)
    if (p_choice%csize>0)&
         & call prec%set('min_coarse_size', p_choice%csize,      info)
    if (p_choice%mncrratio>1)&
         & call prec%set('min_cr_ratio',   p_choice%mncrratio, info)
    if (p_choice%maxlevs>0)&
         & call prec%set('max_levs',    p_choice%maxlevs,    info)
    if (p_choice%athres >= dzero) &
         & call prec%set('aggr_thresh',     p_choice%athres,  info)
    if (p_choice%thrvsz>0) then
      do k=1,min(p_choice%thrvsz,size(prec%precv)-1)
        call prec%set('aggr_thresh',     p_choice%athresv(k),  info,ilev=(k+1))
      end do
    end if

    call prec%set('aggr_prol',       p_choice%aggr_prol,   info)
    call prec%set('par_aggr_alg',    p_choice%par_aggr_alg,   info)
    call prec%set('aggr_ord',        p_choice%aggr_ord,   info)
    call prec%set('aggr_filter',     p_choice%aggr_filter,info)


    call prec%set('smoother_type',   p_choice%smther,     info)
    call prec%set('smoother_sweeps', p_choice%jsweeps,    info)
    call prec%set('sub_ovr',         p_choice%novr,       info)
    call prec%set('sub_restr',       p_choice%restr,      info)
    call prec%set('sub_prol',        p_choice%prol,       info)
    call prec%set('sub_solve',       p_choice%solve,      info)
    call prec%set('sub_fillin',      p_choice%fill,       info)
    call prec%set('sub_iluthrs',     p_choice%thr,        info)

    if (psb_toupper(p_choice%smther2) /= 'NONE') then
      call prec%set('smoother_type',   p_choice%smther2,   info,pos='post')
      call prec%set('smoother_sweeps', p_choice%jsweeps2,  info,pos='post')
      call prec%set('sub_ovr',         p_choice%novr2,     info,pos='post')
      call prec%set('sub_restr',       p_choice%restr2,    info,pos='post')
      call prec%set('sub_prol',        p_choice%prol2,     info,pos='post')
      call prec%set('sub_solve',       p_choice%solve2,    info,pos='post')
      call prec%set('sub_fillin',      p_choice%fill2,     info,pos='post')
      call prec%set('sub_iluthrs',     p_choice%thr2,      info,pos='post')
    end if

    if (psb_toupper(p_choice%csolve) /= 'DEFLT') then 
      call prec%set('coarse_solve',    p_choice%csolve,    info)
      if (psb_toupper(p_choice%csolve) == 'BJAC') &
           &  call prec%set('coarse_subsolve', p_choice%csbsolve,  info)
      call prec%set('coarse_mat',      p_choice%cmat,      info)
      call prec%set('coarse_fillin',   p_choice%cfill,     info)
      call prec%set('coarse_iluthrs',  p_choice%cthres,    info)
      call prec%set('coarse_sweeps',   p_choice%cjswp,     info)
    end if

  end select
  
  ! build the preconditioner
  call psb_barrier(ictxt)
  t1 = psb_wtime()
  call prec%hierarchy_build(a,desc_a,info)
  thier = psb_wtime()-t1
  if (info /= psb_success_) then
    call psb_errpush(psb_err_from_subroutine_,name,a_err='mld_hierarchy_bld')
    goto 9999
  end if
  call psb_barrier(ictxt)
  t1 = psb_wtime()
  call prec%smoothers_build(a,desc_a,info)
  tprec = psb_wtime()-t1
  if (info /= psb_success_) then
    call psb_errpush(psb_err_from_subroutine_,name,a_err='mld_smoothers_bld')
    goto 9999
  end if

  call psb_amx(ictxt, thier)
  call psb_amx(ictxt, tprec)

  if(iam == psb_root_) then
    write(psb_out_unit,'(" ")')
    write(psb_out_unit,'("Preconditioner: ",a)') trim(p_choice%descr)
    write(psb_out_unit,'("Preconditioner time: ",es12.5)')thier+tprec
    write(psb_out_unit,'(" ")')
  end if

  !
  ! iterative method parameters 
  !
  call psb_barrier(ictxt)
  t1 = psb_wtime()
  call psb_krylov(s_choice%kmethd,a,prec,b,x,s_choice%eps,&
       & desc_a,info,itmax=s_choice%itmax,iter=iter,err=err,itrace=s_choice%itrace,&
       & istop=s_choice%istopc,irst=s_choice%irst)
  call psb_barrier(ictxt)
  tslv = psb_wtime() - t1

  call psb_amx(ictxt,tslv)

  if(info /= psb_success_) then
    info=psb_err_from_subroutine_
    ch_err='solver routine'
    call psb_errpush(info,name,a_err=ch_err)
    goto 9999
  end if

  call psb_barrier(ictxt)
  tslv = psb_wtime() - t1
  call psb_amx(ictxt,tslv)

  ! compute residual norms
  call psb_geall(r,desc_a,info)
  call r%zero()
  call psb_geasb(r,desc_a,info)
  call psb_geaxpby(done,b,dzero,r,desc_a,info)
  call psb_spmm(-done,a,x,done,r,desc_a,info)
  resmx  = psb_genrm2(r,desc_a,info)
  resmxp = psb_geamax(r,desc_a,info)

  amatsize = a%sizeof()
  descsize = desc_a%sizeof()
  precsize = prec%sizeof()
  call psb_sum(ictxt,amatsize)
  call psb_sum(ictxt,descsize)
  call psb_sum(ictxt,precsize)
  call prec%descr(info)
  if (iam == psb_root_) then 
    write(psb_out_unit,'("Computed solution on ",i8," processors")')   np
    write(psb_out_unit,'("Krylov method                      : ",a)')  trim(s_choice%kmethd)
    write(psb_out_unit,'("Preconditioner                     : ",a)')  trim(p_choice%descr)
    write(psb_out_unit,'("Iterations to convergence          : ",i12)')   iter
    write(psb_out_unit,'("Relative error estimate on exit    : ",es12.5)') err
    write(psb_out_unit,'("Number of levels in hierarchy      : ",i12)')    prec%get_nlevs()
    write(psb_out_unit,'("Time to build hierarchy            : ",es12.5)') thier
    write(psb_out_unit,'("Time to build smoothers            : ",es12.5)') tprec
    write(psb_out_unit,'("Total time for preconditioner      : ",es12.5)') tprec+thier
    write(psb_out_unit,'("Time to solve system               : ",es12.5)') tslv
    write(psb_out_unit,'("Time per iteration                 : ",es12.5)') tslv/iter
    write(psb_out_unit,'("Total time                         : ",es12.5)') tslv+tprec+thier
    write(psb_out_unit,'("Residual 2-norm                    : ",es12.5)') resmx
    write(psb_out_unit,'("Residual inf-norm                  : ",es12.5)') resmxp
    write(psb_out_unit,'("Total memory occupation for A      : ",i12)') amatsize
    write(psb_out_unit,'("Total memory occupation for DESC_A : ",i12)') descsize
    write(psb_out_unit,'("Total memory occupation for PREC   : ",i12)') precsize
    write(psb_out_unit,'("Storage format for A               : ",a  )') a%get_fmt()
    write(psb_out_unit,'("Storage format for DESC_A          : ",a  )') desc_a%get_fmt()

  end if

  !  
  !  cleanup storage and exit
  !
  call psb_gefree(b,desc_a,info)
  call psb_gefree(x,desc_a,info)
  call psb_spfree(a,desc_a,info)
  call prec%free(info)
  call psb_cdfree(desc_a,info)
  if(info /= psb_success_) then
    info=psb_err_from_subroutine_
    ch_err='free routine'
    call psb_errpush(info,name,a_err=ch_err)
    goto 9999
  end if
  call psb_exit(ictxt)
  stop

9999 continue
  call psb_error(ictxt)

contains
  !
  ! get iteration parameters from standard input
  !
  !
  ! get iteration parameters from standard input
  !
  subroutine get_parms(icontxt,afmt,idim,solve,prec)

    use psb_base_mod
    implicit none

    integer(psb_ipk_)   :: icontxt, idim
    character(len=*)    :: afmt
    type(solverdata)    :: solve
    type(precdata)      :: prec
    integer(psb_ipk_)   :: iam, nm, np

    call psb_info(icontxt,iam,np)

    if (iam == psb_root_) then
      ! read input data
      !
      call read_data(afmt,psb_inp_unit)            ! matrix storage format
      call read_data(idim,psb_inp_unit)            ! Discretization grid size
      ! Krylov solver data
      call read_data(solve%kmethd,psb_inp_unit)    ! Krylov solver
      call read_data(solve%istopc,psb_inp_unit)    ! stopping criterion
      call read_data(solve%itmax,psb_inp_unit)     ! max num iterations
      call read_data(solve%itrace,psb_inp_unit)    ! tracing
      call read_data(solve%irst,psb_inp_unit)      ! restart
      call read_data(solve%eps,psb_inp_unit)       ! tolerance
      ! preconditioner type
      call read_data(prec%descr,psb_inp_unit)      ! verbose description of the prec
      call read_data(prec%ptype,psb_inp_unit)      ! preconditioner type
      call read_data(prec%outer_sweeps,psb_inp_unit) ! number of 1lev/outer sweeps
      ! general AMG data
      call read_data(prec%mlcycle,psb_inp_unit)     ! AMG cycle type
      call read_data(prec%maxlevs,psb_inp_unit)    ! max number of levels in AMG prec
      call read_data(prec%csize,psb_inp_unit)       ! min size coarsest mat
      ! aggregation
      call read_data(prec%aggr_prol,psb_inp_unit)    ! aggregation type
      call read_data(prec%par_aggr_alg,psb_inp_unit)    ! parallel aggregation alg
      call read_data(prec%aggr_ord,psb_inp_unit)    ! ordering for aggregation
      call read_data(prec%aggr_filter,psb_inp_unit) ! filtering
      call read_data(prec%mncrratio,psb_inp_unit)  ! minimum aggregation ratio
      call read_data(prec%thrvsz,psb_inp_unit)      ! size of aggr thresh vector
      if (prec%thrvsz > 0) then
        call psb_realloc(prec%thrvsz,prec%athresv,info)
        call read_data(prec%athresv,psb_inp_unit)   ! aggr thresh vector
      else
        read(psb_inp_unit,*)                        ! dummy read to skip a record
      end if
      call read_data(prec%athres,psb_inp_unit)      ! smoothed aggr thresh
      ! AMG smoother (or pre-smoother) / 1-lev preconditioner
      call read_data(prec%smther,psb_inp_unit)     ! smoother type
      call read_data(prec%jsweeps,psb_inp_unit)    ! (pre-)smoother / 1-lev prec sweeps
      call read_data(prec%novr,psb_inp_unit)       ! number of overlap layers
      call read_data(prec%restr,psb_inp_unit)      ! restriction  over application of AS
      call read_data(prec%prol,psb_inp_unit)       ! prolongation over application of AS
      call read_data(prec%solve,psb_inp_unit)      ! local subsolver
      call read_data(prec%fill,psb_inp_unit)       ! fill-in for incomplete LU
      call read_data(prec%thr,psb_inp_unit)        ! threshold for ILUT
      ! AMG post-smoother
      call read_data(prec%smther2,psb_inp_unit)     ! smoother type
      call read_data(prec%jsweeps2,psb_inp_unit)    ! (post-)smoother sweeps
      call read_data(prec%novr2,psb_inp_unit)       ! number of overlap layers
      call read_data(prec%restr2,psb_inp_unit)      ! restriction  over application of AS
      call read_data(prec%prol2,psb_inp_unit)       ! prolongation over application of AS
      call read_data(prec%solve2,psb_inp_unit)      ! local subsolver
      call read_data(prec%fill2,psb_inp_unit)       ! fill-in for incomplete LU
      call read_data(prec%thr2,psb_inp_unit)        ! threshold for ILUT
      ! coasest-level solver
      call read_data(prec%csolve,psb_inp_unit)      ! coarsest-lev solver
      call read_data(prec%csbsolve,psb_inp_unit)    ! coarsest-lev subsolver
      call read_data(prec%cmat,psb_inp_unit)        ! coarsest mat layout
      call read_data(prec%cfill,psb_inp_unit)       ! fill-in for incompl LU
      call read_data(prec%cthres,psb_inp_unit)      ! Threshold for ILUT
      call read_data(prec%cjswp,psb_inp_unit)       ! sweeps for GS/JAC subsolver
    end if

    call psb_bcast(icontxt,afmt)
    call psb_bcast(icontxt,idim)

    call psb_bcast(icontxt,solve%kmethd)
    call psb_bcast(icontxt,solve%istopc)
    call psb_bcast(icontxt,solve%itmax)
    call psb_bcast(icontxt,solve%itrace)
    call psb_bcast(icontxt,solve%irst)
    call psb_bcast(icontxt,solve%eps)

    call psb_bcast(icontxt,prec%descr)
    call psb_bcast(icontxt,prec%ptype)

    ! broadcast first (pre-)smoother / 1-lev prec data
    call psb_bcast(icontxt,prec%smther)      ! actually not needed for 1-lev precs
    call psb_bcast(icontxt,prec%jsweeps)
    call psb_bcast(icontxt,prec%novr)
    call psb_bcast(icontxt,prec%restr)
    call psb_bcast(icontxt,prec%prol)
    call psb_bcast(icontxt,prec%solve)
    call psb_bcast(icontxt,prec%fill)
    call psb_bcast(icontxt,prec%thr)

    ! broadcast (other) AMG parameters
    if (psb_toupper(prec%ptype) == 'ML') then

      call psb_bcast(icontxt,prec%mlcycle)
      call psb_bcast(icontxt,prec%outer_sweeps)
      call psb_bcast(icontxt,prec%maxlevs)

      call psb_bcast(icontxt,prec%smther2)
      call psb_bcast(icontxt,prec%jsweeps2)
      call psb_bcast(icontxt,prec%novr2)
      call psb_bcast(icontxt,prec%restr2)
      call psb_bcast(icontxt,prec%prol2)
      call psb_bcast(icontxt,prec%solve2)
      call psb_bcast(icontxt,prec%fill2)
      call psb_bcast(icontxt,prec%thr2)

      call psb_bcast(icontxt,prec%aggr_prol)
      call psb_bcast(icontxt,prec%par_aggr_alg)
      call psb_bcast(icontxt,prec%aggr_ord)
      call psb_bcast(icontxt,prec%aggr_filter)
      call psb_bcast(icontxt,prec%mncrratio)
      call psb_bcast(ictxt,prec%thrvsz)
      if (prec%thrvsz > 0) then
        if (iam /= psb_root_) call psb_realloc(prec%thrvsz,prec%athresv,info)
        call psb_bcast(ictxt,prec%athresv)
      end if
      call psb_bcast(ictxt,prec%athres)

      call psb_bcast(icontxt,prec%csize)
      call psb_bcast(icontxt,prec%cmat)
      call psb_bcast(icontxt,prec%csolve)
      call psb_bcast(icontxt,prec%csbsolve)
      call psb_bcast(icontxt,prec%cfill)
      call psb_bcast(icontxt,prec%cthres)
      call psb_bcast(icontxt,prec%cjswp)

    end if

  end subroutine get_parms

end program mld_d_pde2d
