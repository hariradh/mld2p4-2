!!$
!!$ 
!!$                           MLD2P4  version 2.0
!!$  MultiLevel Domain Decomposition Parallel Preconditioners Package
!!$             based on PSBLAS (Parallel Sparse BLAS version 3.0)
!!$  
!!$  (C) Copyright 2008,2009,2010,2010,2012
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
subroutine mld_s_diag_solver_apply(alpha,sv,x,beta,y,desc_data,trans,work,info)
  
  use psb_base_mod
  use mld_s_diag_solver, mld_protect_name => mld_s_diag_solver_apply
  implicit none 
  type(psb_desc_type), intent(in)           :: desc_data
  class(mld_s_diag_solver_type), intent(in) :: sv
  real(psb_spk_), intent(inout)             :: x(:)
  real(psb_spk_), intent(inout)             :: y(:)
  real(psb_spk_),intent(in)                 :: alpha,beta
  character(len=1),intent(in)               :: trans
  real(psb_spk_),target, intent(inout)      :: work(:)
  integer, intent(out)                      :: info

  integer    :: n_row,n_col
  real(psb_spk_), pointer :: ww(:), aux(:), tx(:),ty(:)
  integer    :: ictxt,np,me,i, err_act
  character          :: trans_
  character(len=20)  :: name='s_diag_solver_apply'

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

  n_row = desc_data%get_local_rows()
  n_col = desc_data%get_local_cols()

  if (trans_ == 'C') then 
    if (beta == szero) then 

      if (alpha == szero) then 
        y(1:n_row) = szero
      else if (alpha == sone) then 
        do i=1, n_row
          y(i) = (sv%d(i)) * x(i)
        end do
      else if (alpha == -sone) then 
        do i=1, n_row
          y(i) = -(sv%d(i)) * x(i)
        end do
      else
        do i=1, n_row
          y(i) = alpha * (sv%d(i)) * x(i)
        end do
      end if

    else if (beta == sone) then 

      if (alpha == szero) then 
        !y(1:n_row) = szero
      else if (alpha == sone) then 
        do i=1, n_row
          y(i) = (sv%d(i)) * x(i) + y(i)
        end do
      else if (alpha == -sone) then 
        do i=1, n_row
          y(i) = -(sv%d(i)) * x(i)  + y(i)
        end do
      else
        do i=1, n_row
          y(i) = alpha * (sv%d(i)) * x(i) + y(i)
        end do
      end if

    else if (beta == -sone) then 

      if (alpha == szero) then 
        y(1:n_row) = -y(1:n_row)        
      else if (alpha == sone) then 
        do i=1, n_row
          y(i) = (sv%d(i)) * x(i) - y(i)
        end do
      else if (alpha == -sone) then 
        do i=1, n_row
          y(i) = -(sv%d(i)) * x(i)  - y(i)
        end do
      else
        do i=1, n_row
          y(i) = alpha * (sv%d(i)) * x(i) - y(i)
        end do
      end if

    else

      if (alpha == szero) then 
        y(1:n_row) = beta *y(1:n_row)        
      else if (alpha == sone) then 
        do i=1, n_row
          y(i) = (sv%d(i)) * x(i) + beta*y(i)
        end do
      else if (alpha == -sone) then 
        do i=1, n_row
          y(i) = -(sv%d(i)) * x(i)  + beta*y(i)
        end do
      else
        do i=1, n_row
          y(i) = alpha * (sv%d(i)) * x(i) + beta*y(i)
        end do
      end if

    end if

  else if (trans_ /= 'C') then 

    if (beta == szero) then 

      if (alpha == szero) then 
        y(1:n_row) = szero
      else if (alpha == sone) then 
        do i=1, n_row
          y(i) = sv%d(i) * x(i)
        end do
      else if (alpha == -sone) then 
        do i=1, n_row
          y(i) = -sv%d(i) * x(i)
        end do
      else
        do i=1, n_row
          y(i) = alpha * sv%d(i) * x(i)
        end do
      end if

    else if (beta == sone) then 

      if (alpha == szero) then 
        !y(1:n_row) = szero
      else if (alpha == sone) then 
        do i=1, n_row
          y(i) = sv%d(i) * x(i) + y(i)
        end do
      else if (alpha == -sone) then 
        do i=1, n_row
          y(i) = -sv%d(i) * x(i)  + y(i)
        end do
      else
        do i=1, n_row
          y(i) = alpha * sv%d(i) * x(i) + y(i)
        end do
      end if

    else if (beta == -sone) then 

      if (alpha == szero) then 
        y(1:n_row) = -y(1:n_row)        
      else if (alpha == sone) then 
        do i=1, n_row
          y(i) = sv%d(i) * x(i) - y(i)
        end do
      else if (alpha == -sone) then 
        do i=1, n_row
          y(i) = -sv%d(i) * x(i)  - y(i)
        end do
      else
        do i=1, n_row
          y(i) = alpha * sv%d(i) * x(i) - y(i)
        end do
      end if

    else

      if (alpha == szero) then 
        y(1:n_row) = beta *y(1:n_row)        
      else if (alpha == sone) then 
        do i=1, n_row
          y(i) = sv%d(i) * x(i) + beta*y(i)
        end do
      else if (alpha == -sone) then 
        do i=1, n_row
          y(i) = -sv%d(i) * x(i)  + beta*y(i)
        end do
      else
        do i=1, n_row
          y(i) = alpha * sv%d(i) * x(i) + beta*y(i)
        end do
      end if

    end if

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

end subroutine mld_s_diag_solver_apply
