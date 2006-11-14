!!$ 
!!$ 
!!$                    MD2P4
!!$    Multilevel Domain Decomposition Parallel Preconditioner Package for PSBLAS
!!$                      for 
!!$              Parallel Sparse BLAS  v2.0
!!$    (C) Copyright 2006 Salvatore Filippone    University of Rome Tor Vergata
!!$                       Alfredo Buttari        University of Rome Tor Vergata
!!$                       Daniela Di Serafino    II University of Naples
!!$                       Pasqua D'Ambra         ICAR-CNR                      
!!$ 
!!$  Redistribution and use in source and binary forms, with or without
!!$  modification, are permitted provided that the following conditions
!!$  are met:
!!$    1. Redistributions of source code must retain the above copyright
!!$       notice, this list of conditions and the following disclaimer.
!!$    2. Redistributions in binary form must reproduce the above copyright
!!$       notice, this list of conditions, and the following disclaimer in the
!!$       documentation and/or other materials provided with the distribution.
!!$    3. The name of the MD2P4 group or the names of its contributors may
!!$       not be used to endorse or promote products derived from this
!!$       software without specific written permission.
!!$ 
!!$  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
!!$  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
!!$  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
!!$  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE MD2P4 GROUP OR ITS CONTRIBUTORS
!!$  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
!!$  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
!!$  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
!!$  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
!!$  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
!!$  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
!!$  POSSIBILITY OF SUCH DAMAGE.
!!$ 
!!$  
subroutine psb_dprecset(p,ptype,info,iv,rs,rv,ilev,nlev)

  use psb_serial_mod
  use psb_descriptor_type
  use psb_prec_type
  use psb_string_mod
  implicit none
  type(psb_dprec_type), intent(inout)    :: p
  character(len=*), intent(in)           :: ptype
  integer, intent(out)                   :: info
  integer, optional, intent(in)          :: iv(:)
  integer, optional, intent(in)          :: nlev,ilev
  real(kind(1.d0)), optional, intent(in) :: rs
  real(kind(1.d0)), optional, intent(in) :: rv(:)

  character(len=len(ptype))              :: typeup
  integer                                :: isz, err, nlev_, ilev_, i

  info = 0

  if (present(ilev)) then 
    ilev_ = max(1, ilev)
  else
    ilev_ = 1 
  end if
  if (present(nlev)) then 
    if (allocated(p%baseprecv)) then 
      write(0,*) 'Warning: NLEV is ignored when P is already allocated'
    end if
    nlev_ = max(1, nlev)
  else
    nlev_ = 1 
  end if

  if (.not.allocated(p%baseprecv)) then 
    allocate(p%baseprecv(nlev_),stat=err)
  else
    nlev_ = size(p%baseprecv)
  endif

  if ((ilev_<1).or.(ilev_ > nlev_)) then 
    write(0,*) 'PRECSET ERRROR: ilev out of bounds'
    info = -1
    return
  endif

  if (.not.allocated(p%baseprecv(ilev_)%iprcparm)) then 
    call psb_realloc(ifpsz,p%baseprecv(ilev_)%iprcparm,info)
    if (info == 0) call psb_realloc(dfpsz,p%baseprecv(ilev_)%dprcparm,info)
    if (info /= 0) then 
      write(0,*) 'Info from realloc ',info
      return
    end if
    p%baseprecv(ilev_)%iprcparm(:) = 0
  end if

  select case(toupper(ptype(1:len_trim(ptype))))
  case ('NONE','NOPREC') 
    p%baseprecv(ilev_)%iprcparm(:)           = 0
    p%baseprecv(ilev_)%iprcparm(p_type_)     = noprec_
    p%baseprecv(ilev_)%iprcparm(f_type_)     = f_none_
    p%baseprecv(ilev_)%iprcparm(restr_)      = psb_none_
    p%baseprecv(ilev_)%iprcparm(prol_)       = psb_none_
    p%baseprecv(ilev_)%iprcparm(iren_)       = 0
    p%baseprecv(ilev_)%iprcparm(n_ovr_)      = 0
    p%baseprecv(ilev_)%iprcparm(jac_sweeps_) = 1

  case ('DIAG','DIAGSC')
    p%baseprecv(ilev_)%iprcparm(:)           = 0
    p%baseprecv(ilev_)%iprcparm(p_type_)     = diagsc_
    p%baseprecv(ilev_)%iprcparm(f_type_)     = f_none_
    p%baseprecv(ilev_)%iprcparm(restr_)      = psb_none_
    p%baseprecv(ilev_)%iprcparm(prol_)       = psb_none_
    p%baseprecv(ilev_)%iprcparm(iren_)       = 0 
    p%baseprecv(ilev_)%iprcparm(n_ovr_)      = 0
    p%baseprecv(ilev_)%iprcparm(jac_sweeps_) = 1

  case ('BJA','ILU') 
    p%baseprecv(ilev_)%iprcparm(:)            = 0
    p%baseprecv(ilev_)%iprcparm(p_type_)      = bja_
    p%baseprecv(ilev_)%iprcparm(f_type_)      = f_ilu_n_
    p%baseprecv(ilev_)%iprcparm(restr_)       = psb_none_
    p%baseprecv(ilev_)%iprcparm(prol_)        = psb_none_
    p%baseprecv(ilev_)%iprcparm(iren_)        = 0
    p%baseprecv(ilev_)%iprcparm(n_ovr_)       = 0
    p%baseprecv(ilev_)%iprcparm(ilu_fill_in_) = 0
    p%baseprecv(ilev_)%iprcparm(jac_sweeps_)  = 1

  case ('ASM','AS')
    p%baseprecv(ilev_)%iprcparm(:)            = 0
    ! Defaults first 
    p%baseprecv(ilev_)%iprcparm(p_type_)      = asm_
    p%baseprecv(ilev_)%iprcparm(f_type_)      = f_ilu_n_
    p%baseprecv(ilev_)%iprcparm(restr_)       = psb_halo_
    p%baseprecv(ilev_)%iprcparm(prol_)        = psb_none_
    p%baseprecv(ilev_)%iprcparm(iren_)        = 0
    p%baseprecv(ilev_)%iprcparm(n_ovr_)       = 1
    p%baseprecv(ilev_)%iprcparm(ilu_fill_in_) = 0
    p%baseprecv(ilev_)%iprcparm(jac_sweeps_)  = 1
    if (present(iv)) then 
      isz = size(iv) 
      if (isz >= 1) p%baseprecv(ilev_)%iprcparm(n_ovr_)  = iv(1)
      if (isz >= 2) p%baseprecv(ilev_)%iprcparm(restr_)  = iv(2)
      if (isz >= 3) p%baseprecv(ilev_)%iprcparm(prol_)   = iv(3)
      if (isz >= 4) p%baseprecv(ilev_)%iprcparm(f_type_) = iv(4) 
      ! Do not consider renum for the time being. 
!!$      if (isz >= 5) p%baseprecv(ilev_)%iprcparm(iren_) = iv(5)
    end if


  case ('ML', '2L', '2LEV')


    p%baseprecv(ilev_)%iprcparm(:)             = 0
    p%baseprecv(ilev_)%iprcparm(p_type_)       = bja_
    p%baseprecv(ilev_)%iprcparm(restr_)        = psb_none_
    p%baseprecv(ilev_)%iprcparm(prol_)         = psb_none_
    p%baseprecv(ilev_)%iprcparm(iren_)         = 0
    p%baseprecv(ilev_)%iprcparm(n_ovr_)        = 0
    p%baseprecv(ilev_)%iprcparm(ml_type_)      = mult_ml_prec_
    p%baseprecv(ilev_)%iprcparm(aggr_alg_)     = loc_aggr_
    p%baseprecv(ilev_)%iprcparm(smth_kind_)    = smth_omg_
    p%baseprecv(ilev_)%iprcparm(coarse_mat_)   = mat_distr_
    p%baseprecv(ilev_)%iprcparm(smth_pos_)     = post_smooth_
    p%baseprecv(ilev_)%iprcparm(glb_smth_)     = 1
    p%baseprecv(ilev_)%iprcparm(om_choice_)    = lib_choice_
    p%baseprecv(ilev_)%iprcparm(f_type_)       = f_ilu_n_
    p%baseprecv(ilev_)%iprcparm(ilu_fill_in_)  = 0
    p%baseprecv(ilev_)%dprcparm(smooth_omega_) = 4.d0/3.d0         
    p%baseprecv(ilev_)%iprcparm(jac_sweeps_)   = 1

    if (present(iv)) then 
      isz = size(iv)
      if (isz >= 1) p%baseprecv(ilev_)%iprcparm(ml_type_)      = iv(1)
      if (isz >= 2) p%baseprecv(ilev_)%iprcparm(aggr_alg_)     = iv(2) 
      if (isz >= 3) p%baseprecv(ilev_)%iprcparm(coarse_mat_)   = iv(3) 
      if (isz >= 4) p%baseprecv(ilev_)%iprcparm(smth_pos_)     = iv(4)
      if (isz >= 5) p%baseprecv(ilev_)%iprcparm(f_type_)       = iv(5)
      if (isz >= 6) p%baseprecv(ilev_)%iprcparm(jac_sweeps_)   = iv(6)
      if (isz >= 7) p%baseprecv(ilev_)%iprcparm(smth_kind_)    = iv(7) 
    end if

    if (present(rs)) then 
      p%baseprecv(ilev_)%iprcparm(om_choice_)    = user_choice_
      p%baseprecv(ilev_)%dprcparm(smooth_omega_) = rs      
    end if


  case default
    write(0,*) 'Unknown preconditioner type request "',ptype,'"'
    err = 2

  end select

  info = err

end subroutine psb_dprecset
