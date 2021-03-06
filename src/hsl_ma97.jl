export Ma97_Control, Ma97_Info, Ma97
export ma97_csc, ma97_coord,
       ma97_factorize, ma97_factorise,
       ma97_solve, ma97_solve!,
       ma97_inquire, ma97_enquire,
       ma97_alter,
       ma97_min_norm, ma97_least_squares
export Ma97Exception


"""Main control type for MA97.

Optional arguments:

* print_level: integer controling the verbosit level. Accepted values are:
    * <0: no printing
    * 0: errors and warnings only (default)
    * 1: errors, warnings and basic diagnostics
    * 2: errors, warning and full diagnostics
* unit_diagnostics: Fortran file unit for diagnostics (default: 6)
* unit_error: Fortran file unit for errors (default: 6)
* unit_warning: Fortran file unit for warnings (default: 6)
"""
type Ma97_Control

  "`f_arrays`=1 indicates that arrays are 1-based"
  f_arrays :: Cint

  "`action`=0 aborts factorization if matrix is singular"
  action :: Cint

  "two neighbors in the etree are merged if both involve < `nemin` eliminations"
  nemin :: Cint

  "factor by which memory is increased"
  multiplier :: Cdouble

  ordering :: Cint
  print_level :: Cint
  scaling :: Cint

  "tolerance under which a pivot is treated as zero"
  small :: Cdouble

  "relative pivot tolerance"
  u :: Cdouble

  unit_diagnostics :: Cint
  unit_error :: Cint
  unit_warning :: Cint

  "parallelism is used if `info.num_flops` ≥ `factor_min`"
  factor_min :: Clong

  "use level 3 BLAS for single right-hand side"
  solve_blas3 :: Cint

  "parallelism is used if `info.num_factor` ≥ `solve_min`"
  solve_min :: Clong

  "`solve_mf`=1 use a multifrontal forward solve instead of a supernodal solve"
  solve_mf :: Cint

  "tolerance for consistent equations"
  consist_tol :: Cdouble

  "spare integer storage currently unused"
  ispare :: Vector{Cint}

  "spare real storage currently unused"
  rspare :: Vector{Cdouble}

  function Ma97_Control(; print_level :: Int=0, unit_diagnostics :: Int=6, unit_error :: Int=6, unit_warning :: Int=6)
    control = new(0, 0, 0, 0.0, 0, 0, 0, 0.0,
                  0.0, 0, 0, 0, 0, 0, 0, 0, 0.0,
                  zeros(Cint, 5), zeros(Cdouble, 10))
    ccall((:ma97_default_control_d, libhsl_ma97), Void, (Ptr{Ma97_Control},), &control)
    control.f_arrays = 1  # Use 1-based indexing for arrays, avoiding copies.
    control.print_level = print_level
    control.unit_diagnostics = unit_diagnostics
    control.unit_error = unit_error
    control.unit_warning = unit_warning
    return control
  end
end


@compat const orderings97 = Dict{Symbol,Int}(
                              :user  => 0,
                              :amd   => 1,
                              :md    => 2,
                              :metis => 3,
                              :ma47  => 4,
                              :metis_or_amd_par => 5,
                              :metis_or_amd_ser => 6,
                              :mc80  => 7,
                              :matching_metis => 8,
                            )


@compat const ordering_names97 = Dict{Int,AbstractString}(
                                   0 => "user supplied or none",
                                   1 => "AMD",
                                   2 => "minimum degree",
                                   3 => "METIS",
                                   4 => "MA47",
                                   5 => "METIS or AMD parallel",
                                   6 => "METIS or AMD serial",
                                   7 => "matching with HSL_MC80",
                                   8 => "matching + METIS",
                                 )


@compat const matrix_types97 = Dict{Symbol,Int}(
                                 :real_spd   =>  3,  # real symmetric positive definite
                                 :real_indef =>  4,  # real symmetric indefinite
                                 :herm_pd    => -3,  # hermitian positive definite
                                 :herm_indef => -4,  # hermitian indefinite
                                 :cmpl_indef => -5,  # complex symmetric indefinite
                               )

@compat const jobs97 = Dict{Symbol,Int}(
                         :A    => 0,  # solve Ax = b
                         :PL   => 1,  # solve PLx = Sb
                         :D    => 2,  # solve Dx = b
                         :LPS  => 3,  # solve L'P'S⁻¹x = b
                         :DLPS => 4,  # solve DL'P'S⁻¹x = b
                       )


"Exception type raised in case of error."
type Ma97Exception <: Exception
  msg  :: AbstractString
  flag :: Int
end


"""Main info type for MA97. An `info` variable is used to collect
statistics on the analysis, factorization and solve.
"""
type Ma97_Info
  "exit status"
  flag :: Cint

  "exit status from MC68"
  flag68 :: Cint

  "exit status from MC77 (for scaling)"
  flag77 :: Cint

  "number of duplicate entries found and summed"
  matrix_dup :: Cint

  matrix_rank :: Cint

  "number of out-of-range entries found and discarded"
  matrix_outrange :: Cint

  "number of diagonal entries without a value"
  matrix_missing_diag :: Cint

  "maximum depth of assembly tree"
  maxdepth :: Cint

  "maximum front size"
  maxfront :: Cint

  "number of delayed eliminations"
  num_delay :: Cint

  "number of entries in the factor L"
  num_factor :: Clong

  "number of flops to perform the factorization"
  num_flops :: Clong

  "number of negative eigenvalues"
  num_neg :: Cint

  "number of supernodes"
  num_sup :: Cint

  "number of 2x2 pivots"
  num_two :: Cint

  ordering :: Cint

  "Fortran stat parameter in case of a memory error"
  stat :: Cint

  "spare integer storage currently unused"
  ispare :: Vector{Cint}

  "spare real storage currently unused"
  rspare :: Vector{Cdouble}

  function Ma97_Info()
    return new(0, 0, 0, 0, 0, 0, 0, 0,
               0, 0, 0, 0, 0, 0, 0, 0, 0,
               zeros(Cint, 5), zeros(Cdouble, 10))
  end
end


type Ma97
  __akeep :: Array{Ptr{Void}}
  __fkeep :: Array{Ptr{Void}}
  n :: Int
  colptr :: Vector{Cint}
  rowval :: Vector{Cint}
  nzval :: Vector{Cdouble}
  control :: Ma97_Control
  info :: Ma97_Info
end


function ma97_finalize(ma97 :: Ma97)
  ccall((:ma97_finalise_d, libhsl_ma97), Void,
        (Ptr{Ptr{Void}}, Ptr{Ptr{Void}}),
         ma97.__akeep,   ma97.__fkeep)
end


"""Instantiate an object of type `Ma97` and perform the
symbolic analysis on a matrix described in sparse CSC format.
"""
function ma97_csc{Ti <: Integer}(n :: Int, colptr :: Vector{Ti}, rowval :: Vector{Ti}, nzval :: Vector{Float64}; kwargs...)
  control = Ma97_Control(; kwargs...)
  info = Ma97_Info()
  M = Ma97([convert(Ptr{Void}, C_NULL)], [convert(Ptr{Void}, C_NULL)], n, colptr, rowval, nzval, control, info)

  # Perform symbolic analysis.
  ccall((:ma97_analyse_d, libhsl_ma97), Void,
        (Cint, Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Ptr{Ptr{Void}}, Ptr{Ma97_Control}, Ptr{Ma97_Info}, Ptr{Cint}),
          1,    M.n,  M.colptr,  M.rowval,  C_NULL,       M.__akeep,      &(M.control),      &(M.info),      C_NULL)

  if M.info.flag < 0
    ccall((:ma97_free_akeep_d, libhsl_ma97), Void, (Ptr{Ptr{Void}},), M.__akeep)
    throw(Ma97Exception("Ma97: Error during symbolic analysis", M.info.flag))
  end

  finalizer(M, ma97_finalize)
  return M
end


"""Instantiate an object of type `Ma97` and perform the
symbolic analysis on a sparse Julia matrix.
"""
function Ma97(A :: SparseMatrixCSC{Float64,Int}; kwargs...)
  m, n = size(A)
  m == n || throw(Ma97Exception("Ma97: input matrix must be square", 0))
  T = tril(convert(SparseMatrixCSC{Float64,Cint}, A))
  return ma97_csc(T.n, T.colptr, T.rowval, T.nzval; kwargs...)
end

Ma97(A :: Array{Float64,2}; kwargs...) = Ma97(sparse(A); kwargs...)


"""Instantiate an object of type `Ma97` and perform the
symbolic analysis on a matrix described in sparse coordinate format.
"""
function ma97_coord{Ti <: Integer}(n :: Int, cols :: Vector{Ti}, rows :: Vector{Ti}, nzval :: Vector{Float64}; kwargs...)
  control = Ma97_Control(; kwargs...)
  info = Ma97_Info()
  M = Ma97([convert(Ptr{Void}, C_NULL)], [convert(Ptr{Void}, C_NULL)], n, cols, rows, nzval, control, info)
  nz = length(cols)

  # Perform symbolic analysis.
  ccall((:ma97_analyse_coord_d, libhsl_ma97), Void,
        (Cint, Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Ptr{Ptr{Void}}, Ptr{Ma97_Control}, Ptr{Ma97_Info}, Ptr{Cint}),
         M.n,  nz,   M.rowval,  M.colptr,  C_NULL,       M.__akeep,      &(M.control),      &(M.info),      C_NULL)

  if M.info.flag < 0
    ccall((:ma97_free_akeep_d, libhsl_ma97), Void, (Ptr{Ptr{Void}},), M.__akeep)
    throw(Ma97Exception("Ma97: Error during symbolic analysis", M.info.flag))
  end

  finalizer(M, ma97_finalize)
  return M
end


"""Perform numerical factorization. The symbolic analysis must have
been performed and must have succeeded. Indicate the matrix type by
way of the `matrix_type` named argument. Accepted values are

* `:read_spd` for a real symmetric and positive definite matrix
* `:real_indef` for a real symmetric and indefinite matrix.
"""
function ma97_factorize(ma97 :: Ma97; matrix_type :: Symbol=:real_indef)
  t = matrix_types97[matrix_type]

  ccall((:ma97_factor_d, libhsl_ma97), Void,
        (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Ptr{Ptr{Void}}, Ptr{Ptr{Void}}, Ptr{Ma97_Control}, Ptr{Ma97_Info}, Ptr{Cdouble}),
         t,    C_NULL,    C_NULL,    ma97.nzval,   ma97.__akeep,   ma97.__fkeep,   &(ma97.control),   &(ma97.info),   C_NULL)

  if ma97.info.flag < 0
    ma97_finalize(ma97)
    throw(Ma97Exception("Ma97: Error during numerical factorization", ma97.info.flag))
  end
end


"""Convenience method that combines the symbolic analysis and numerical
factorization phases. An MA97 instance is returned, that can subsequently
be passed to other functions, e.g., `ma97_solve()`.
"""
function ma97_factorize(A :: SparseMatrixCSC{Float64,Int}; matrix_type :: Symbol=:real_indef)
  ma97 = Ma97(A)
  ma97_factorize(ma97, matrix_type=matrix_type)
  return ma97
end

# Z's not dead.
ma97_factorise = ma97_factorize


"""Solve a linear system with right-hand side `b`. Multiple right-hand
sides can be represented with an array `b` of size `n` by `nrhs`.
"""
function ma97_solve(ma97 :: Ma97, b :: Array{Float64})
  x = copy(b)
  ma97_solve!(ma97, x)
  return x
end


"""Solve a linear system in place with right-hand side `b`. Note that
`b` will be overwritten. To solve a system with multiple right-hand sides,
`b` should have size `n` by `nrhs`.
"""
function ma97_solve!(ma97 :: Ma97, b :: Array{Float64}; job :: Symbol=:A)
  size(b, 1) == ma97.n || throw(Ma97Exception("Ma97: rhs size mismatch", 0))
  nrhs = size(b, 2)

  j = jobs97[job]
  ccall((:ma97_solve_d, libhsl_ma97), Void,
        (Cint, Cint, Ptr{Cdouble}, Cint,   Ptr{Ptr{Void}}, Ptr{Ptr{Void}}, Ptr{Ma97_Control}, Ptr{Ma97_Info}),
         j,    nrhs, b,            ma97.n, ma97.__akeep,   ma97.__fkeep,   &(ma97.control),   &(ma97.info))

  if ma97.info.flag < 0
    ma97_finalize(ma97)
    throw(Ma97Exception("Ma97: Error during solve", ma97.info.flag))
  end
end


# Overload backslash to solve with MA97.
if VERSION ≥ v"0.4.0"
  import Base.\
end
\(ma97 :: Ma97, b :: Array{Float64}) = ma97_solve(ma97, b)


"""Convenience method that combines the symbolic analysis, numerical
factorization and solution phases.
"""
function ma97_solve(A :: SparseMatrixCSC{Float64,Int}, b :: Array{Float64}; matrix_type :: Symbol=:real_indef)
  (m, n) = size(A)
  m < n && (return ma97_min_norm(A, b))
  m > n && (return ma97_least_squares(A, b))
  x = copy(b)
  ma97_solve!(A, x, matrix_type=matrix_type)
  return x
end


"""Convenience method that combines the symbolic analysis, numerical
factorization and solution phases. The solution is performed in place,
i.e., `b` will be overwritten. To solve a system with multiple right-hand
sides, `b` should have size `n` by `nrhs`.
"""
function ma97_solve!(A :: SparseMatrixCSC{Float64,Int}, b :: Array{Float64}; matrix_type :: Symbol=:real_indef)
  t = matrix_types97[matrix_type]
  M = Ma97(A)
  size(b, 1) == M.n || throw(Ma97Exception("Ma97: rhs size mismatch", 0))
  nrhs = size(b, 2)
  ccall((:ma97_factor_solve_d, libhsl_ma97), Void,
        (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Cint, Ptr{Cdouble}, Cint, Ptr{Ptr{Void}}, Ptr{Ptr{Void}}, Ptr{Ma97_Control}, Ptr{Ma97_Info}, Ptr{Cdouble}),
         t,    M.colptr,  M.rowval,  M.nzval,      nrhs, b,            M.n,  M.__akeep,      M.__fkeep,      &(M.control),      &(M.info),      C_NULL)

  if M.info.flag < 0
    ma97_finalize(M)
    throw(Ma97Exception("Ma97: Error during combined factorize/solve", M.info.flag))
  end
end

ma97_solve(A :: Array{Float64,2}, b :: Array{Float64}; matrix_type :: Symbol=:real_indef) = ma97_solve(sparse(A), b, matrix_type=matrix_type)


"""Obtain information on the pivots after a successful factorization or solve.
An inquiry on a real or complex indefinite matrix returns two vectors:

* `piv_order`: contains the pivot sequence; a negative value indicates that the
  corresponding variable is part of a 2x2 pivot,
* `d`: a `2` by `n` array whose first row contains the diagonal of D⁻¹ in the
  factorization, and whose nonzeros in the second row contain the off-diagonals.

An inquiry on a positive definite matrix returns one vector with the pivot values.
"""
function ma97_inquire(ma97 :: Ma97; matrix_type :: Symbol=:real_indef)
  if matrix_type in [:real_indef, :herm_indef, :cmpl_indef]
    piv_order = zeros(Cint, ma97.n)
    # AMBUSH ALERT: although Julia will call the C interface of the library
    # Julia stores arrays column-major as Fortran does. Though the C interface
    # documentation says d should be n x 2, we must declare 2 x n.
    d = zeros(Cdouble, 2, ma97.n)
    ccall((:ma97_enquire_indef_d, libhsl_ma97), Void,
          (Ptr{Ptr{Void}}, Ptr{Ptr{Void}}, Ptr{Ma97_Control}, Ptr{Ma97_Info}, Ptr{Cint}, Ptr{Cdouble}),
           ma97.__akeep,   ma97.__fkeep,   &(ma97.control),   &(ma97.info),   piv_order, d)
    ret = (piv_order, d)
  else
    d = zeros(Cdouble, ma97.n)
    ccall((:ma97_enquire_posdef_d, libhsl_ma97), Void,
          (Ptr{Ptr{Void}}, Ptr{Ptr{Void}}, Ptr{Ma97_Control}, Ptr{Ma97_Info}, Ptr{Cdouble}),
           ma97.__akeep,   ma97.__fkeep,   &(ma97.control),   &(ma97.info),   d)
    ret = d
  end

  if ma97.info.flag < 0
    ma97_finalize(ma97)
    throw(Ma97Exception("Ma97: Error during inquiry", ma97.info.flag))
  end

  return ret
end

ma97_enquire = ma97_inquire


function ma97_alter(ma97 :: Ma97, d :: Array{Float64, 2})
  n, m = size(d)
  (m == ma97.n && n == 2) || throw(Ma97Exception("Ma97: input array d must be n x 2", 0))
  ccall((:ma97_alter_d, libhsl_ma97), Void,
        (Ptr{Cdouble}, Ptr{Ptr{Void}}, Ptr{Ptr{Void}}, Ptr{Ma97_Control}, Ptr{Ma97_Info}),
         d,            ma97.__akeep,   ma97.__fkeep,   &(ma97.control),   &(ma97.info))

  if ma97.info.flag < 0
    ma97_finalize(ma97)
    throw(Ma97Exception("Ma97: Error during alteration", ma97.info.flag))
  end
end


# Note: it seems inconvenient to have in-place versions of min_norm and
# least_squares because the user would have to provide a storage array
# of length n+m, which is not the size of the solution x alone.

"""Solve the minimum-norm problem

    minimize ‖x‖  subject to Ax=b,

where A has shape m-by-n with m < n,
by solving the saddle-point system

    [ I  A' ] [ x ]   [ 0 ]
    [ A     ] [ y ] = [ b ].
"""
function ma97_min_norm(A :: SparseMatrixCSC{Float64,Int}, b :: Vector{Float64})
  (m, n) = size(A)
  K = [ speye(n)  spzeros(n, m) ; A  0.0 * speye(m) ]
  rhs = [ zeros(n) ; b ]
  xy97 = ma97_solve(K, rhs)
  x97 = xy97[1:n]
  y97 = xy97[n+1:n+m]
  return (x97, y97)
end

ma97_min_norm(A :: Array{Float64,2}, b :: Vector{Float64}) = ma97_min_norm(sparse(A), b)


"""Solve the least-squares problem

    minimize ‖Ax - b‖,

where A has shape m-by-n with m > n,
by solving the saddle-point system

    [ I   A ] [ r ]   [ b ]
    [ A'    ] [ x ] = [ 0 ].
"""
function ma97_least_squares(A :: SparseMatrixCSC{Float64,Int}, b :: Vector{Float64})
  (m, n) = size(A)
  K = [ speye(m)  spzeros(m,n) ; A'  0.0 * speye(n) ]
  rhs = [ b ; zeros(n) ]
  rx97 = ma97_solve(K, rhs)
  r97 = rx97[1:m]
  x97 = rx97[m+1:m+n]
  return (r97, x97)
end

ma97_least_squares(A :: Array{Float64,2}, b :: Vector{Float64}) = ma97_least_squares(sparse(A), b)
