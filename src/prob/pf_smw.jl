#
# Sherman-Morrison Jacobian updates and sensitivity-based donor selection
# for bus-type switching AC power flow.
#
# This file implements the strategy `swap_technique = "sensitivity_score"`:
# given a converged AC power flow at the current bus-type pattern, score every
# admissible PV donor for each violated PQ recipient by the first-order
# voltage sensitivity dV_l/dV_donor, pick the donor that moves V_l most
# efficiently per unit donor effort, and (optionally) seed the next NR call
# with the Sherman-Morrison-predicted post-swap state.
#
# Math (embedded form, V is a Newton variable at every nonslack bus):
#   - P-PQV swap is a rank-1 update of one row of J.
#   - Sensitivity of V_l to V_donor at a candidate i:  e_{V_l}^T J^{-1} e_{r_i}.
#   - Predicted first Newton step:  -(V_l - V_hat_l) / (e_{V_l}^T J^{-1} e_{r_i}) * J^{-1} e_{r_i}.
#
# The reduced-form NR solver in pf.jl is left untouched. The embedded
# Jacobian J_hat is built only for screening, factored once per swap
# decision, and probed with one back-solve per donor candidate.
#

# ------------------------------------------------------------------
# Module-level derivative helpers (lifted from the closures in jsp_mb!).
# Pure functions of (Y, V, theta) for nonslack buses i, j (j a neighbor of i).
# ------------------------------------------------------------------

function _smw_dpdv_diag(am, neighbors, vm, va, i)
    y_ii = am.matrix[i, i]
    s = 2 * real(y_ii) * vm[i]
    @inbounds for k in neighbors[i]
        k == i && continue
        s += real(am.matrix[i, k]) * vm[k] * cos(va[i] - va[k]) +
             imag(am.matrix[i, k]) * vm[k] * sin(va[i] - va[k])
    end
    return s
end

function _smw_dqdv_diag(am, neighbors, vm, va, i)
    y_ii = am.matrix[i, i]
    s = -2 * imag(y_ii) * vm[i]
    @inbounds for k in neighbors[i]
        k == i && continue
        s += -imag(am.matrix[i, k]) * vm[k] * cos(va[i] - va[k]) +
              real(am.matrix[i, k]) * vm[k] * sin(va[i] - va[k])
    end
    return s
end

function _smw_dpdtheta_diag(am, neighbors, vm, va, i)
    s = 0.0
    @inbounds for k in neighbors[i]
        k == i && continue
        s += real(am.matrix[i, k]) * vm[k] * -sin(va[i] - va[k]) +
             imag(am.matrix[i, k]) * vm[k] *  cos(va[i] - va[k])
    end
    return vm[i] * s
end

function _smw_dqdtheta_diag(am, neighbors, vm, va, i)
    s = 0.0
    @inbounds for k in neighbors[i]
        k == i && continue
        s += -imag(am.matrix[i, k]) * vm[k] * -sin(va[i] - va[k]) +
              real(am.matrix[i, k]) * vm[k] *  cos(va[i] - va[k])
    end
    return vm[i] * s
end

function _smw_dpn_dv(am, vm, va, i, j)
    y_ij = am.matrix[i, j]
    return vm[i] * (real(y_ij) * cos(va[i] - va[j]) + imag(y_ij) * sin(va[i] - va[j]))
end

function _smw_dqn_dv(am, vm, va, i, j)
    y_ij = am.matrix[i, j]
    return vm[i] * (-imag(y_ij) * cos(va[i] - va[j]) + real(y_ij) * sin(va[i] - va[j]))
end

function _smw_dpn_dtheta(am, vm, va, i, j)
    y_ij = am.matrix[i, j]
    return vm[i] * vm[j] * (real(y_ij) * sin(va[i] - va[j]) + imag(y_ij) * -cos(va[i] - va[j]))
end

function _smw_dqn_dtheta(am, vm, va, i, j)
    y_ij = am.matrix[i, j]
    return vm[i] * vm[j] * (-imag(y_ij) * sin(va[i] - va[j]) + real(y_ij) * -cos(va[i] - va[j]))
end

# ------------------------------------------------------------------
# Embedded-form indexing.
# ------------------------------------------------------------------

"""
Build the index layout for the embedded Jacobian. Returns an `EmbeddedMap`
struct with bus -> (va_col, vm_col, p_row, aux_row) for every nonslack bus,
plus the dense ordering vectors used internally.

State vector layout (length 2*(n-1)):
    x[bus_to_pos[k]]            = theta_k
    x[(n-1) + bus_to_pos[k]]    = V_k

Equation vector layout (length 2*(n-1)):
    F[bus_to_pos[k]]            = P_k - P_bar_k                (always)
    F[(n-1) + bus_to_pos[k]]    = type-dependent (Q_k, V_k - V_bar_k, or borrowed V_l - V_hat_l)
"""
struct EmbeddedMap
    nonslack_buses::Vector{Int}              # ordered nonslack bus indices
    bus_to_pos::Dict{Int,Int}                # bus_idx -> position in 1..n-1
    p_row::Dict{Int,Int}                     # bus -> P-equation row in F_emb
    aux_row::Dict{Int,Int}                   # bus -> aux-equation row in F_emb (Q or V row)
    va_col::Dict{Int,Int}                    # bus -> column for theta variable
    vm_col::Dict{Int,Int}                    # bus -> column for V variable
    n_emb::Int                               # = 2 * length(nonslack_buses)
end

function build_embedded_map(pf_data)
    bti = pf_data.bus_type_idx
    n = length(bti)
    slack_pos = findfirst(==(3), bti)
    @assert slack_pos !== nothing "embedded jacobian: no slack (type 3) bus found"
    nonslack = [i for i in 1:n if i != slack_pos]
    bus_to_pos = Dict{Int,Int}(b => p for (p, b) in enumerate(nonslack))
    nm1 = length(nonslack)
    p_row   = Dict{Int,Int}(b => bus_to_pos[b]       for b in nonslack)
    aux_row = Dict{Int,Int}(b => nm1 + bus_to_pos[b] for b in nonslack)
    va_col  = Dict{Int,Int}(b => bus_to_pos[b]       for b in nonslack)
    vm_col  = Dict{Int,Int}(b => nm1 + bus_to_pos[b] for b in nonslack)
    return EmbeddedMap(nonslack, bus_to_pos, p_row, aux_row, va_col, vm_col, 2 * nm1)
end

# ------------------------------------------------------------------
# Embedded Jacobian assembly.
# ------------------------------------------------------------------

"""
    build_embedded_jacobian(pf_data, p_pqv_pairs)

Build the dense `2(n-1) x 2(n-1)` embedded-form Jacobian J_hat at the current
state of `pf_data` (uses pf_data.vm_idx, pf_data.va_idx). `p_pqv_pairs` is the
dictionary mapping donor (type 6) bus -> recipient (type 5) bus from the
swap state. Returns `(Jhat, emap)`.

Per-bus aux row (q_or_v):
    type 1 (PQ)        : Q_k balance row
    type 2 (PV)        : V_k - V_bar_k row  (gradient = e_{V_k})
    type 5 (PQV recip) : Q_k balance row    (V row borrowed by linked donor)
    type 6 (P donor)   : V_l - V_hat_l row, l = p_pqv_pairs[k]   (gradient = e_{V_l})
    type 3 (slack)     : excluded from embedded form
"""
function build_embedded_jacobian(pf_data, p_pqv_pairs::AbstractDict = Dict{Int,Int}())
    am = pf_data.am
    neighbors = pf_data.neighbors
    vm = pf_data.vm_idx
    va = pf_data.va_idx
    bti = pf_data.bus_type_idx

    emap = build_embedded_map(pf_data)
    n_emb = emap.n_emb

    # Build the embedded Jacobian as a sparse matrix via COO triplets. The
    # admittance graph is sparse (~k nonzeros per row, k = avg degree), and
    # PV/PQV-donor aux rows are 1-nonzero identity rows, so dense storage
    # wastes O(n^2) memory and the dense LU dominates per-swap-iter cost on
    # mid-size grids (case300 was a 598x598 dense factor per swap).
    nnz_est = 0
    @inbounds for i in emap.nonslack_buses
        deg = 1 + count(j -> j != i && haskey(emap.va_col, j), neighbors[i])
        bt  = bti[i]
        nnz_est += 2 * deg                 # P row: dtheta + dV per (self + nonslack neighbor)
        if bt == 1 || bt == 5
            nnz_est += 2 * deg             # Q row: dtheta + dV per (self + nonslack neighbor)
        else
            nnz_est += 1                   # PV / P-donor identity row
        end
    end
    I = Vector{Int}(undef, 0); sizehint!(I, nnz_est)
    J = Vector{Int}(undef, 0); sizehint!(J, nnz_est)
    V = Vector{Float64}(undef, 0); sizehint!(V, nnz_est)
    @inline function _push!(r, c, v)
        push!(I, r); push!(J, c); push!(V, v)
    end

    # Fill P rows for every nonslack bus, and the aux row depending on type.
    @inbounds for i in emap.nonslack_buses
        pr  = emap.p_row[i]
        qr  = emap.aux_row[i]
        vai = emap.va_col[i]
        vmi = emap.vm_col[i]

        # P_i row: derivatives w.r.t. theta_j and V_j for all neighbors j (and self).
        #          (We only differentiate w.r.t. nonslack variables.)
        _push!(pr, vai, _smw_dpdtheta_diag(am, neighbors, vm, va, i))
        _push!(pr, vmi, _smw_dpdv_diag(am, neighbors, vm, va, i))
        for j in neighbors[i]
            j == i && continue
            haskey(emap.va_col, j) || continue   # skip slack neighbor cols
            _push!(pr, emap.va_col[j], _smw_dpn_dtheta(am, vm, va, i, j))
            _push!(pr, emap.vm_col[j], _smw_dpn_dv(am, vm, va, i, j))
        end

        bt = bti[i]
        if bt == 1 || bt == 5
            # Q_i row: standard Q balance.
            _push!(qr, vai, _smw_dqdtheta_diag(am, neighbors, vm, va, i))
            _push!(qr, vmi, _smw_dqdv_diag(am, neighbors, vm, va, i))
            for j in neighbors[i]
                j == i && continue
                haskey(emap.va_col, j) || continue
                _push!(qr, emap.va_col[j], _smw_dqn_dtheta(am, vm, va, i, j))
                _push!(qr, emap.vm_col[j], _smw_dqn_dv(am, vm, va, i, j))
            end
        elseif bt == 2
            # V_i = V_bar_i row: gradient is e_{V_i}.
            _push!(qr, vmi, 1.0)
        elseif bt == 6
            # P-donor: borrowed V_l = V_hat_l row, l = p_pqv_pairs[i].
            l = get(p_pqv_pairs, i, nothing)
            if l === nothing || !haskey(emap.vm_col, l)
                # No linked recipient (or recipient is slack -- shouldn't happen).
                # Fall back to keeping a V_i = V_i row so Jhat stays nonsingular by structure.
                _push!(qr, vmi, 1.0)
            else
                _push!(qr, emap.vm_col[l], 1.0)
            end
        else
            # bt == 3 (slack) is excluded from emap, so this branch is unreachable.
            error("build_embedded_jacobian: unexpected bus type $bt at bus $i")
        end
    end

    Jhat = SparseArrays.sparse(I, J, V, n_emb, n_emb)
    return Jhat, emap
end

"""
    embedded_residual(pf_data, emap, p_pqv_pairs)

Compute the embedded residual F_hat at the current pf_data state. Used for
sanity checks (should be ~0 at a converged reduced-form state) and for the
sensitivity warm-start computation.
"""
function embedded_residual(pf_data, emap::EmbeddedMap, p_pqv_pairs::AbstractDict = Dict{Int,Int}())
    am = pf_data.am
    neighbors = pf_data.neighbors
    vm = pf_data.vm_idx
    va = pf_data.va_idx
    bti = pf_data.bus_type_idx
    p_inj = pf_data.p_inject_idx
    q_inj = pf_data.q_inject_idx
    p_delta = pf_data.p_delta_base_idx
    q_delta = pf_data.q_delta_base_idx

    F = zeros(Float64, emap.n_emb)

    @inbounds for i in emap.nonslack_buses
        balance_real = p_delta[i] + p_inj[i]
        balance_imag = q_delta[i] + q_inj[i]
        for j in neighbors[i]
            if j == i
                balance_real += vm[i] * vm[i] *  real(am.matrix[i, i])
                balance_imag += vm[i] * vm[i] * -imag(am.matrix[i, i])
            else
                balance_real += vm[i] * vm[j] * ( real(am.matrix[i, j]) * cos(va[i] - va[j]) + imag(am.matrix[i, j]) * sin(va[i] - va[j]))
                balance_imag += vm[i] * vm[j] * (-imag(am.matrix[i, j]) * cos(va[i] - va[j]) + real(am.matrix[i, j]) * sin(va[i] - va[j]))
            end
        end
        F[emap.p_row[i]] = balance_real

        bt = bti[i]
        if bt == 1 || bt == 5
            F[emap.aux_row[i]] = balance_imag
        elseif bt == 2
            # vm[i] is fixed at the V_bar_i setpoint by the reduced-form solver,
            # so the residual V_i - V_bar_i should be exactly zero here.
            F[emap.aux_row[i]] = 0.0
        elseif bt == 6
            l = get(p_pqv_pairs, i, nothing)
            if l === nothing || !haskey(emap.vm_col, l)
                F[emap.aux_row[i]] = 0.0
            else
                # vm[l] is fixed at V_hat_l; residual is 0 at converged x*.
                F[emap.aux_row[i]] = 0.0
            end
        end
    end
    return F
end

# ------------------------------------------------------------------
# Sensitivity columns and donor scoring.
# ------------------------------------------------------------------

"""
    compute_sensitivity_columns(Jhat, emap, donor_buses)

For each `i` in `donor_buses`, solve `Jhat * z_i = e_{r_i}` where `r_i` is the
aux-row index of the donor (i.e. the row of the V_i = V_bar_i equation for a
PV donor). Returns `Dict{Int, Vector{Float64}}` keyed by donor bus index.

Reuses one LU factorization across all candidates, per the "Computational
reuse" remark of the math notes.
"""
function compute_sensitivity_columns(Jhat::AbstractMatrix, emap::EmbeddedMap, donor_buses)
    F = LinearAlgebra.lu(Jhat)
    out = Dict{Int, Vector{Float64}}()
    rhs = zeros(Float64, emap.n_emb)
    for i in donor_buses
        haskey(emap.aux_row, i) || continue
        ri = emap.aux_row[i]
        fill!(rhs, 0.0)
        rhs[ri] = 1.0
        out[i] = F \ rhs
    end
    return out
end

"""
    score_local_optimal(z_dict, emap, recipient_l; rho_dict = nothing)

Theorem 2 of the math notes: pick the donor i* that maximizes
    |e_{V_l}^T z_i| / sqrt(rho_i).

Returns `(best_donor::Int, best_score::Float64, sensitivity::Float64)`.
`sensitivity` is the signed e_{V_l}^T z_{best_donor} (used downstream to
compute the implied donor effort delta). If no donor is admissible, returns
`(nothing, 0.0, 0.0)`.
"""
function score_local_optimal(z_dict::AbstractDict, emap::EmbeddedMap, recipient_l::Int;
                              rho_dict = nothing)
    haskey(emap.vm_col, recipient_l) || return (nothing, 0.0, 0.0)
    vl_col = emap.vm_col[recipient_l]
    best_donor = nothing
    best_score = -Inf
    best_sens  = 0.0
    for (i, z) in z_dict
        s = z[vl_col]
        rho = rho_dict === nothing ? 1.0 : get(rho_dict, i, 1.0)
        score = abs(s) / sqrt(rho)
        if score > best_score
            best_score = score
            best_donor = i
            best_sens  = s
        end
    end
    return (best_donor, best_score == -Inf ? 0.0 : best_score, best_sens)
end

"""
    score_collateral_aware(z_dict, emap, pf_data, recipient_l, target_Vl;
                           alpha = 0.0, eps_singular = 1e-10)

Corollary 1 / "Collateral-aware" remark of the math notes: for each donor i,
predict V_m at every nonslack bus m via
    V_m^pred(i, l) = V_m(x*) - (V_l(x*) - V_hat_l) * (e_{V_m}^T z_i) / (e_{V_l}^T z_i)
and score the donor by the total predicted bound violation summed across all
buses, plus optional `alpha * delta_i^2` donor-effort penalty.

Returns `(best_donor::Int, best_score::Float64, sensitivity::Float64)`.
"""
function score_collateral_aware(z_dict::AbstractDict, emap::EmbeddedMap, pf_data,
                                 recipient_l::Int, target_Vl::Float64;
                                 alpha::Float64 = 0.0, eps_singular::Float64 = 1e-10)
    haskey(emap.vm_col, recipient_l) || return (nothing, 0.0, 0.0)
    vl_col = emap.vm_col[recipient_l]
    bus_dict = pf_data.data["bus"]
    am = pf_data.am
    Vl_now = pf_data.vm_idx[recipient_l]
    mismatch = Vl_now - target_Vl

    best_donor = nothing
    best_score = Inf
    best_sens  = 0.0
    for (i, z) in z_dict
        s = z[vl_col]
        if abs(s) < eps_singular
            continue   # donor cannot move V_l to first order
        end
        delta_i = -mismatch / s
        viol_total = 0.0
        for (m, vmcol) in emap.vm_col
            zm = z[vmcol]
            Vm_pred = pf_data.vm_idx[m] - mismatch * (zm / s)
            bus_str = string(am.idx_to_bus[m])
            haskey(bus_dict, bus_str) || continue
            vmin = bus_dict[bus_str]["vmin"]
            vmax = bus_dict[bus_str]["vmax"]
            if Vm_pred > vmax
                viol_total += Vm_pred - vmax
            elseif Vm_pred < vmin
                viol_total += vmin - Vm_pred
            end
        end
        score = viol_total + alpha * delta_i^2
        if score < best_score
            best_score = score
            best_donor = i
            best_sens  = s
        end
    end
    return (best_donor, best_score == Inf ? 0.0 : best_score, best_sens)
end

# ------------------------------------------------------------------
# Sherman-Morrison first-Newton-step prediction (warm-start).
# ------------------------------------------------------------------

"""
    smw_predicted_post_swap_state(z_donor, emap, pf_data, recipient_l, donor_i, target_Vl)

Given the sensitivity column z_donor = J_hat^{-1} e_{r_i} and the chosen swap
(donor_i, recipient_l, target V_hat_l), compute the SMW-predicted post-swap
embedded state (Theorem 1 part (3)/(4) of the notes):

    Delta_x_emb^(1) = -(V_l(x*) - V_hat_l) / (e_{V_l}^T z_donor) * z_donor

Returns `(theta_pred::Dict{Int,Float64}, vm_pred::Dict{Int,Float64})` keyed by
nonslack bus index. The caller is responsible for writing these into pf_data
fields if a warm-start is desired.
"""
function smw_predicted_post_swap_state(z_donor::AbstractVector, emap::EmbeddedMap, pf_data,
                                        recipient_l::Int, target_Vl::Float64;
                                        eps_singular::Float64 = 1e-10)
    vl_col = emap.vm_col[recipient_l]
    s = z_donor[vl_col]
    if abs(s) < eps_singular
        # Degenerate: cannot scale z_donor reliably. Fall back to no warm-start.
        return (Dict{Int,Float64}(), Dict{Int,Float64}())
    end
    Vl_now = pf_data.vm_idx[recipient_l]
    mismatch = Vl_now - target_Vl
    coef = -mismatch / s

    theta_pred = Dict{Int,Float64}()
    vm_pred    = Dict{Int,Float64}()
    for (m, vacol) in emap.va_col
        theta_pred[m] = pf_data.va_idx[m] + coef * z_donor[vacol]
    end
    for (m, vmcol) in emap.vm_col
        vm_pred[m] = pf_data.vm_idx[m] + coef * z_donor[vmcol]
    end
    return (theta_pred, vm_pred)
end

# ------------------------------------------------------------------
# Strategy entry point: called by perform_bus_swaps! when
# flags.swap_technique == "sensitivity_score".
# ------------------------------------------------------------------

"""
    perform_bus_swaps_sensitivity_score_impl!(pf_data, mapping_dict, jacobian, bus_type_idx,
                                              p_pqv_pairs, bus_assignment, swap, b1_violations, flags)

Score every admissible PV donor for each violated PQ recipient using the
embedded-form first-order voltage sensitivity, pick donors via Theorem 2
(default) or Corollary 1 (`flags.score_collateral_aware`), apply the swaps,
and (optionally) seed pf_data with the SMW-predicted post-swap state.
"""
function perform_bus_swaps_sensitivity_score_impl!(pf_data, mapping_dict, jacobian,
                                                    bus_type_idx, p_pqv_pairs,
                                                    bus_assignment, swap, b1_violations, flags)
    # mapping_dict / jacobian / bus_type_idx are part of the strategy signature
    # used by perform_bus_swaps! but the embedded-form path re-derives everything
    # from pf_data, so they are not used here.
    mapping_dict, jacobian, bus_type_idx
    if isempty(b1_violations)
        return
    end

    # Build embedded Jacobian once at the converged x*. The reduced-form
    # `jacobian` argument is unused here (kept for signature compatibility);
    # we re-derive J_hat from pf_data state to avoid index-translation bugs.
    Jhat, emap = nothing, nothing
    try
        Jhat, emap = build_embedded_jacobian(pf_data, p_pqv_pairs)
    catch e
        @_debug("sensitivity_score: failed to build embedded jacobian ($e); falling back to nearest_gen")
        return perform_bus_swaps_nearest_gen!(pf_data, bus_assignment, p_pqv_pairs,
                                              b1_violations, swap, flags)
    end

    # Sort violations the same way the existing strategies do.
    sort_func = flags.highest_mag ? val -> -abs(val) : val -> abs(val)
    sort!(b1_violations, by = x -> sort_func(x[2]))

    # Working copy of admissible PV donors (will be mutated as donors are claimed).
    available_pv = Set{Int}(pf_data.data["pv_bus_inds"])

    swap_recipients = Tuple{Int, Float64, Float64}[]
    swap_donors     = Int[]
    smw_columns     = Dict{Int, Vector{Float64}}()  # store z_i for chosen pairs (warm-start)
    smw_mismatches  = Dict{Int, Float64}()          # pre-swap (V_l - target) keyed by donor

    for viol in b1_violations
        l, _, target_Vl = viol
        # Build candidate donor set: type-2 PV buses not already claimed and
        # not previously paired with this recipient.
        prev_for_l = Set{Int}(get(pf_data.data["prev_swaps"], l, Int[]))
        candidates = Int[]
        for i in available_pv
            i in prev_for_l && continue
            haskey(emap.aux_row, i) || continue
            push!(candidates, i)
        end
        if isempty(candidates)
            continue
        end

        # Compute sensitivity columns z_i for all candidates.
        z_dict = nothing
        try
            z_dict = compute_sensitivity_columns(Jhat, emap, candidates)
        catch e
            @_debug("sensitivity_score: singular embedded jacobian ($e); falling back to nearest_gen")
            return perform_bus_swaps_nearest_gen!(pf_data, bus_assignment, p_pqv_pairs,
                                                  b1_violations, swap, flags)
        end

        score_result = if flags.score_collateral_aware
            score_collateral_aware(z_dict, emap, pf_data, l, target_Vl)
        else
            score_local_optimal(z_dict, emap, l)
        end
        donor = score_result[1]
        sens  = score_result[3]
        if donor === nothing || abs(sens) < 1e-10
            continue
        end

        push!(swap_recipients, viol)
        push!(swap_donors, donor)
        smw_columns[donor] = z_dict[donor]
        # mismatch = V_l(x*) - target_Vl. From check_vm_bounds!:
        #   lower-bound viol -> viol[2] = vmin - V_l > 0,  target = vmin
        #   upper-bound viol -> viol[2] = vmax - V_l < 0,  target = vmax
        # In both cases mismatch = V_l - target = -viol[2].
        smw_mismatches[donor] = -viol[2]
        delete!(available_pv, donor)

        if flags.obo
            break
        end
    end

    if isempty(swap_donors)
        return
    end

    # Apply swaps via the existing helper. swap_pqv_buses! also updates
    # pf_data.data["pv_bus_inds"] / prev_swaps and sets vm_idx[recipient]
    # to the violated bound.
    swap_pqv_buses!(pf_data, swap_recipients, swap_donors, p_pqv_pairs, bus_assignment, swap)

    # Optional Sherman-Morrison warm-start: seed pf_data with the predicted
    # post-swap state from Theorem 1 part (3)/(4) of the math notes.
    # Each P-PQV swap is rank-1, so for `obo=true` (one swap this iter) the
    # SMW step is exact to first order. For multiple swaps in one iter,
    # composing rank-1 updates is not handled here -- we only apply the
    # first swap's prediction (a partial warm-start, still better than the
    # unmodified pre-swap state in practice).
    if flags.use_smw_warmstart
        first_donor    = swap_donors[1]
        z_first        = smw_columns[first_donor]
        first_recipient = swap_recipients[1][1]
        mismatch       = smw_mismatches[first_donor]
        if !iszero(mismatch)
            vl_col = emap.vm_col[first_recipient]
            s = z_first[vl_col]
            # Safety net: the SMW step is only first-order valid. If the
            # predicted maximum |Δvm| or |Δva| over all nonslack buses is too
            # large, the linearization isn't trustworthy here -- skip the
            # warm-start rather than seed NR from a bad point. Empirically,
            # |Δvm| > 0.3 pu or |Δva| > 0.5 rad signals trouble (and on the
            # case300 dataset, applying such steps strictly increased average
            # NR iteration count).
            apply_smw = abs(s) >= 1e-10
            if apply_smw
                coef = -mismatch / s
                max_dvm = 0.0; max_dva = 0.0
                @inbounds for (m, vmcol) in emap.vm_col
                    bt = pf_data.bus_type_idx[m]
                    (bt == 1 || bt == 6) || continue
                    d = abs(coef * z_first[vmcol])
                    d > max_dvm && (max_dvm = d)
                end
                @inbounds for (_, vacol) in emap.va_col
                    d = abs(coef * z_first[vacol])
                    d > max_dva && (max_dva = d)
                end
                if max_dvm > 0.3 || max_dva > 0.5
                    apply_smw = false
                end
            end
            if apply_smw
                @inbounds for (m, vacol) in emap.va_col
                    pf_data.va_idx[m] += coef * z_first[vacol]
                end
                # Skip writing vm at the recipient (now fixed by PQV swap to
                # target_Vl) and at remaining PV buses (still pinned to their
                # V setpoints). Write only at buses whose V is currently a
                # Newton variable, i.e. PQ (type 1) and the new P-donor (6).
                bti = pf_data.bus_type_idx
                @inbounds for (m, vmcol) in emap.vm_col
                    bt = bti[m]
                    if bt == 1 || bt == 6
                        pf_data.vm_idx[m] += coef * z_first[vmcol]
                    end
                end
                # Mirror the new vm/va into bus_assignment so warm_start_prev_soln!
                # picks them up via the solution_history path.
                @inbounds for (m, _) in emap.va_col
                    bus_str = string(pf_data.am.idx_to_bus[m])
                    if haskey(bus_assignment, bus_str)
                        bus_assignment[bus_str]["va"] = pf_data.va_idx[m]
                        if bti[m] == 1 || bti[m] == 6
                            bus_assignment[bus_str]["vm"] = pf_data.vm_idx[m]
                        end
                    end
                end
            end
        end
    end
    return
end
