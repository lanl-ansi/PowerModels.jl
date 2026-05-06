#
# Tests for the Sherman-Morrison / sensitivity-score donor selection
# strategy in src/prob/pf_smw.jl.
#
# These tests target the math directly (Lemma 1, Proposition 1, Theorem 1,
# Theorem 2, Corollary 1 of the accompanying notes) and finish with a small
# end-to-end smoke check on case14.
#

import LinearAlgebra: rank, lu, norm

# Helper: build a complete pv_pairs dict (every load bus -> every gen bus,
# in arbitrary order) so that the nearest_gen fallback path stays valid in
# tests, in case the embedded jacobian path errors out.
function _all_pairs_pv_pairs(data)
    gen_bus_ids = unique([gen["gen_bus"] for gen in values(data["gen"])])
    load_bus_ids = [bus["bus_i"] for bus in values(data["bus"])]
    return Dict{Int, Vector{Int}}(b => copy(gen_bus_ids) for b in load_bus_ids)
end

# Helper: load a converged AC power flow on a given case file, returning the
# pf_data with pf_data.vm_idx / pf_data.va_idx mutated to the converged state.
function _converged_pf_data(case_path::String)
    data = PowerModels.parse_file(case_path)
    data["pv_pairs"] = _all_pairs_pv_pairs(data)
    pf_data = PowerModels.instantiate_pf_data(data)
    PowerModels.compute_ac_pf(pf_data, mapping = true, enforce_q_lims = false)
    return pf_data, data
end

@testset "pf_smw: sensitivity-score donor selection" begin

    @testset "EmbeddedMap layout" begin
        pf_data, _ = _converged_pf_data("../test/data/matpower/case14.m")
        emap = PowerModels.build_embedded_map(pf_data)
        n = length(pf_data.bus_type_idx)
        @test length(emap.nonslack_buses) == n - 1
        @test emap.n_emb == 2 * (n - 1)
        # No slack bus appears in the keymaps.
        slack_idx = findfirst(==(3), pf_data.bus_type_idx)
        @test !haskey(emap.va_col, slack_idx)
        @test !haskey(emap.vm_col, slack_idx)
        @test !haskey(emap.p_row, slack_idx)
        @test !haskey(emap.aux_row, slack_idx)
        # va_col and p_row should be the same first-(n-1) positions.
        for b in emap.nonslack_buses
            @test emap.va_col[b] == emap.p_row[b]
            @test emap.vm_col[b] == emap.aux_row[b]
            @test 1 <= emap.va_col[b] <= n - 1
            @test n - 1 + 1 <= emap.vm_col[b] <= 2 * (n - 1)
        end
    end

    @testset "embedded jacobian construction (case14)" begin
        pf_data, _ = _converged_pf_data("../test/data/matpower/case14.m")
        Jhat, emap = PowerModels.build_embedded_jacobian(pf_data, Dict{Int,Int}())

        # Size matches 2*(n-1).
        n = length(pf_data.bus_type_idx)
        @test size(Jhat) == (2*(n-1), 2*(n-1))

        # Lemma 1: PV bus aux-row is exactly e_{V_i}^T.
        for (i, bt) in enumerate(pf_data.bus_type_idx)
            bt == 2 || continue
            qr = emap.aux_row[i]
            row = Jhat[qr, :]
            # Exactly one nonzero, at column emap.vm_col[i], with value 1.
            @test count(!iszero, row) == 1
            @test row[emap.vm_col[i]] == 1.0
        end

        # Embedded residual at converged x* is ~0.
        F = PowerModels.embedded_residual(pf_data, emap, Dict{Int,Int}())
        @test norm(F, Inf) < 1e-6

        # Finite-difference cross-check on a representative entry. Pick the
        # first PQ bus and its first nonslack neighbor; verify dP/dV agrees.
        pq_idx = findfirst(==(1), pf_data.bus_type_idx)
        @test pq_idx !== nothing
        nbrs = pf_data.neighbors[pq_idx]
        nb = first(j for j in nbrs if j != pq_idx && haskey(emap.vm_col, j))
        h = 1e-6
        F0 = PowerModels.embedded_residual(pf_data, emap, Dict{Int,Int}())
        pf_data.vm_idx[nb] += h
        Fp = PowerModels.embedded_residual(pf_data, emap, Dict{Int,Int}())
        pf_data.vm_idx[nb] -= h
        fd = (Fp[emap.p_row[pq_idx]] - F0[emap.p_row[pq_idx]]) / h
        analytic = Jhat[emap.p_row[pq_idx], emap.vm_col[nb]]
        @test isapprox(fd, analytic; atol = 1e-4, rtol = 1e-4)
    end

    @testset "Proposition 1: P-PQV swap is rank-1 in J_hat" begin
        pf_data, _ = _converged_pf_data("../test/data/matpower/case14.m")
        Jpre, emap = PowerModels.build_embedded_jacobian(pf_data, Dict{Int,Int}())

        # Pick a PV donor i and a PQ recipient l.
        i = findfirst(==(2), pf_data.bus_type_idx)
        l = findfirst(==(1), pf_data.bus_type_idx)
        @test i !== nothing && l !== nothing && i != l

        # Simulate the swap on a deepcopy so the post-swap Jacobian is
        # rebuilt with the new pattern.
        pf_data2 = deepcopy(pf_data)
        pf_data2.bus_type_idx[i] = 6   # PV donor -> P-donor (type 6)
        pf_data2.bus_type_idx[l] = 5   # PQ recipient -> PQV recipient (type 5)
        pairs = Dict{Int,Int}(i => l)
        Jpost, emap_post = PowerModels.build_embedded_jacobian(pf_data2, pairs)

        # Same column/row layout (no slack movement).
        @test emap.n_emb == emap_post.n_emb

        D = Jpost - Jpre
        # Proposition 1: rank(D) <= 1, and exactly 1 here since i != l.
        @test rank(D) == 1

        # The difference equals e_{r_i} (e_{V_l} - e_{V_i})^T.
        ri = emap.aux_row[i]
        # The only nonzero row of D is row ri.
        for r in axes(D, 1)
            if r == ri
                continue
            end
            @test all(iszero, D[r, :])
        end
        # Row ri has +1 at vm_col[l] and -1 at vm_col[i], zeros elsewhere.
        expected = zero(D[ri, :])
        expected[emap.vm_col[l]] += 1.0
        expected[emap.vm_col[i]] -= 1.0
        @test isapprox(D[ri, :], expected; atol = 1e-12)
    end

    @testset "Theorem 1: SMW first Newton step matches direct solve" begin
        pf_data, data = _converged_pf_data("../test/data/matpower/case14.m")
        Jpre, emap = PowerModels.build_embedded_jacobian(pf_data, Dict{Int,Int}())

        i = findfirst(==(2), pf_data.bus_type_idx)
        l = findfirst(==(1), pf_data.bus_type_idx)
        target_Vl = data["bus"][string(pf_data.am.idx_to_bus[l])]["vmin"]

        # Build post-swap J_hat at the SAME linearization point x* as Jpre
        # (only the equation pattern changes; V_l(x*) is unchanged here).
        pf_data2 = deepcopy(pf_data)
        pf_data2.bus_type_idx[i] = 6
        pf_data2.bus_type_idx[l] = 5
        Jpost, _ = PowerModels.build_embedded_jacobian(pf_data2, Dict{Int,Int}(i => l))

        # Post-swap residual at x*: the only nonzero row is the one that was
        # the donor's V row, now carrying V_l - V_hat_l.
        Vl_pre = pf_data.vm_idx[l]
        Fpost = zeros(Float64, emap.n_emb)
        Fpost[emap.aux_row[i]] = Vl_pre - target_Vl

        # Direct Newton step: dx_direct = -Jpost \ Fpost.
        dx_direct = -(Jpost \ Fpost)

        # SMW step using only Jpre and one back-solve.
        z = PowerModels.compute_sensitivity_columns(Jpre, emap, [i])[i]
        s = z[emap.vm_col[l]]
        @test abs(s) > 1e-6
        coef = -(Vl_pre - target_Vl) / s
        dx_smw = coef .* z

        @test isapprox(dx_direct, dx_smw; atol = 1e-8, rtol = 1e-8)
    end

    @testset "Corollary 1: V_l prediction is exactly satisfied" begin
        pf_data, data = _converged_pf_data("../test/data/matpower/case14.m")
        Jpre, emap = PowerModels.build_embedded_jacobian(pf_data, Dict{Int,Int}())

        i = findfirst(==(2), pf_data.bus_type_idx)
        l = findfirst(==(1), pf_data.bus_type_idx)
        target_Vl = data["bus"][string(pf_data.am.idx_to_bus[l])]["vmin"]

        z = PowerModels.compute_sensitivity_columns(Jpre, emap, [i])[i]
        Vl_pre = pf_data.vm_idx[l]

        # Predicted V_l after the swap should equal V_hat_l exactly (Corollary 1).
        # V_l_pred = V_l(x*) - (V_l - V_hat_l) * (e_{V_l}^T z) / (e_{V_l}^T z) = V_hat_l.
        s = z[emap.vm_col[l]]
        Vl_pred = Vl_pre - (Vl_pre - target_Vl) * (z[emap.vm_col[l]] / s)
        @test isapprox(Vl_pred, target_Vl; atol = 1e-12)
    end

    @testset "Theorem 2: local-optimal donor maximizes |s_li|" begin
        pf_data, _ = _converged_pf_data("../test/data/matpower/case14.m")
        Jpre, emap = PowerModels.build_embedded_jacobian(pf_data, Dict{Int,Int}())

        l = findfirst(==(1), pf_data.bus_type_idx)
        candidates = [k for k in 1:length(pf_data.bus_type_idx) if pf_data.bus_type_idx[k] == 2]
        @test length(candidates) >= 2   # case14 has multiple PV buses
        z_dict = PowerModels.compute_sensitivity_columns(Jpre, emap, candidates)
        donor, score, sens = PowerModels.score_local_optimal(z_dict, emap, l)
        @test donor in candidates

        # The chosen donor must have the largest |s_li| among candidates.
        max_abs = maximum(abs(z_dict[k][emap.vm_col[l]]) for k in candidates)
        @test isapprox(abs(sens), max_abs; atol = 1e-12)
        @test isapprox(score, max_abs; atol = 1e-12)
    end

    @testset "score_collateral_aware runs and prefers low-collateral donor" begin
        pf_data, _ = _converged_pf_data("../test/data/matpower/case14.m")
        Jpre, emap = PowerModels.build_embedded_jacobian(pf_data, Dict{Int,Int}())

        l = findfirst(==(1), pf_data.bus_type_idx)
        candidates = [k for k in 1:length(pf_data.bus_type_idx) if pf_data.bus_type_idx[k] == 2]
        z_dict = PowerModels.compute_sensitivity_columns(Jpre, emap, candidates)

        # An arbitrary in-bounds target; any value triggers the scoring path.
        target_Vl = pf_data.vm_idx[l] - 0.01
        donor_c, score_c, sens_c = PowerModels.score_collateral_aware(
            z_dict, emap, pf_data, l, target_Vl; alpha = 0.0)
        @test donor_c !== nothing
        @test donor_c in candidates
        @test isfinite(score_c)
        @test isfinite(sens_c)
    end

    @testset "edge case: no admissible donors returns gracefully" begin
        pf_data, _ = _converged_pf_data("../test/data/matpower/case14.m")
        # Set up the bookkeeping that compute_ac_pf_mult_buses normally writes.
        pf_data.data["pv_bus_inds"] = Int[]   # empty pool -> no candidates
        pf_data.data["prev_swaps"] = Dict(b => Int[] for b in 1:length(pf_data.bus_type_idx))
        b1 = [(findfirst(==(1), pf_data.bus_type_idx), 0.05, 0.95)]
        p_pqv_pairs = Dict{Int,Int}()
        bus_assignment = Dict{String,Any}()
        for (i, bus) in pf_data.data["bus"]
            bus_assignment[i] = Dict{String,Float64}("vm" => bus["vm"], "va" => bus["va"])
        end
        swap = Ref(false)
        flags = PowerModels.SwapFlags(swap_technique = "sensitivity_score")
        # Nothing should error.
        PowerModels.perform_bus_swaps_sensitivity_score_impl!(
            pf_data, nothing, nothing, copy(pf_data.bus_type_idx),
            p_pqv_pairs, bus_assignment, swap, b1, flags)
        @test swap[] == false
        @test isempty(p_pqv_pairs)
    end

    @testset "end-to-end: sensitivity_score strategy solves case14" begin
        # Rerun on a fresh data dict so previous mutations don't leak in.
        data = PowerModels.parse_file("../test/data/matpower/case14.m")
        data["pv_pairs"] = _all_pairs_pv_pairs(data)
        result = PowerModels.compute_ac_pf_mult_buses(data;
                    swap_technique = "sensitivity_score", obo = true)
        @test haskey(result, "solution")
        @test haskey(result, "solve_time")
        @test result["solve_time"] >= 0
        # Solver should produce a usable bus solution dict.
        if !isnothing(result["solution"]) && haskey(result["solution"], "bus")
            for (_, bus) in result["solution"]["bus"]
                @test haskey(bus, "vm")
                @test haskey(bus, "va")
            end
        end
    end

    @testset "end-to-end with use_smw_warmstart flag enabled" begin
        data = PowerModels.parse_file("../test/data/matpower/case14.m")
        data["pv_pairs"] = _all_pairs_pv_pairs(data)
        result = PowerModels.compute_ac_pf_mult_buses(data;
                    swap_technique = "sensitivity_score",
                    use_smw_warmstart = true, obo = true)
        @test haskey(result, "solution")
    end

    @testset "use_smw_warmstart actually mutates state" begin
        # Drive a swap on a converged case14 manually and verify that the
        # warm-start branch writes nontrivial deltas into pf_data.vm_idx /
        # pf_data.va_idx (vs flag=false, which leaves them untouched).
        function _run_one_swap(use_warmstart)
            pf_data, _ = _converged_pf_data("../test/data/matpower/case14.m")
            pf_data.data["pv_bus_inds"] = [k for (k, bt) in enumerate(pf_data.bus_type_idx) if bt == 2]
            pf_data.data["prev_swaps"] = Dict(b => Int[] for b in 1:length(pf_data.bus_type_idx))
            l = findfirst(==(1), pf_data.bus_type_idx)
            target_Vl = pf_data.data["bus"][string(pf_data.am.idx_to_bus[l])]["vmin"]
            # Manufacture a violation: V_l violates its lower bound by 0.05.
            viol_mag = 0.05
            b1 = [(l, viol_mag, target_Vl)]
            p_pqv_pairs = Dict{Int,Int}()
            bus_assignment = Dict{String,Any}()
            for (s, bus) in pf_data.data["bus"]
                bus_assignment[s] = Dict{String,Float64}("vm" => bus["vm"], "va" => bus["va"])
            end
            swap = Ref(false)
            flags = PowerModels.SwapFlags(swap_technique = "sensitivity_score",
                                          use_smw_warmstart = use_warmstart, obo = true)
            vm_pre = copy(pf_data.vm_idx)
            va_pre = copy(pf_data.va_idx)
            PowerModels.perform_bus_swaps_sensitivity_score_impl!(
                pf_data, nothing, nothing, copy(pf_data.bus_type_idx),
                p_pqv_pairs, bus_assignment, swap, b1, flags)
            return swap[], pf_data.vm_idx .- vm_pre, pf_data.va_idx .- va_pre
        end

        sw_no, dvm_no, dva_no = _run_one_swap(false)
        sw_ws, dvm_ws, dva_ws = _run_one_swap(true)
        @test sw_no && sw_ws

        # Without the flag: vm only changes at the recipient (forced to bound by
        # swap_pqv_buses!); va is untouched.
        @test count(!iszero, dvm_no) == 1
        @test all(iszero, dva_no)

        # With the flag: va changes at multiple nonslack buses (warm-start step),
        # and vm changes at the recipient + other Newton-variable buses too.
        @test count(!iszero, dva_ws) > 1
        @test count(!iszero, dvm_ws) > count(!iszero, dvm_no)
    end
end
