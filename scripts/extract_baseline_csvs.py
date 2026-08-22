"""
Extract the numerical data underlying baseline_equilibrium_panel.pdf → 4 CSVs,
including the "lower i₀" (lower autonomous policy rate) counterfactual curves
shown as dashed lines in the original PDF.
"""

import numpy as np
import pandas as pd
import os
from scipy.optimize import fsolve

# ── 1. Parameter values (from asset_model.jl, Baseline = AssetModel) ──────
PAR = {
    "b": 0.5,
    "c0": 0.8,
    "c1": 0.1,
    "d0": 5.0,
    "d1": 8.0,
    "d2": 1.0,
    "i0": 0.01,
    "i1": 0.05,
    "i2": 0.01,
    "iAP": 2.0,
    "m": 0.15,
    "k": 0.3,
    "n": 0.15,
    "W0": 2.0,
    "h": 0.8,
    "a": 0.8,
    "Nf": 6.0,
    "p1": 1.0,
    "s0": 0.836089551258839,
    "s1": 4.0,
    "s2": 0.2,
    "g0": 0.0,
    "g": 0.5,
    "AQ_bar": 0.78,
    "credit_sd_channel": 0.0,
    "policy_ap_channel": 0.0,
    "firms_ap_channel": 0.0,
    "differential_rate_channel": 0.0,
}

# ── 2. Model solver ───────────────────────────────────────────────────────
def build_equations(params):
    """Return an equation function using a given parameter dict (allows overriding i₀ etc.)."""
    def equations(vars_):
        Y, ND, D, Ip, c, i, r, P_level, dL, dM, dR, W, N, U, SD, AE, AP, AQ_var = vars_

        b = params["b"]; c0 = params["c0"]; c1 = params["c1"]
        d0 = params["d0"]; d1 = params["d1"]; d2 = params["d2"]
        i0 = params["i0"]; i1 = params["i1"]; i2 = params["i2"]
        iAP = params["iAP"]; m = params["m"]; k = params["k"]; n = params["n"]
        W0 = params["W0"]; h = params["h"]; a = params["a"]; Nf = params["Nf"]
        p1 = params["p1"]; s0 = params["s0"]; s1 = params["s1"]; s2 = params["s2"]
        g0 = params["g0"]; g = params["g"]; AQ_bar = params["AQ_bar"]
        csd = params["credit_sd_channel"]
        pap = params["policy_ap_channel"]
        fap = params["firms_ap_channel"]
        drc = params["differential_rate_channel"]

        eqs = [
            Y - (ND + c * D),
            ND - (b * Y),
            D - (d0 - d1 * r - fap * d2 * AP),
            Ip - D,
            i - (i0 + i1 * P_level + pap * i2 * AP),
            r - ((1 + m) * i),
            dL - (c * D + SD),
            dM - dL,
            dR - (k * dM),
            P_level - ((1 + n) * a * W),
            W - (W0 - h * U),
            N - (a * Y),
            U - (1 - N / Nf),
            SD - (s0 - s1 * r * (1 + drc * (iAP - 1)) - s2 * (AP - 1)),
            AE - (g0 + SD / (1 - g)),
            AP - (p1 * AE / AQ_var),
            AQ_var - AQ_bar,
            c - (c0 - c1 * (csd * SD)),
        ]
        return eqs
    return equations


def solve_model(params):
    """Solve the full model with given parameters. Returns {var_name: value}."""
    eq_func = build_equations(params)
    initial_guess = [6.0, 3.0, 3.0, 3.0, 0.8, 0.05, 0.06, 1.5,
                     3.0, 3.0, 0.9, 2.0, 5.0, 0.15, 0.5, 1.0, 1.0, 0.78]
    sol = fsolve(eq_func, initial_guess, maxfev=10000, xtol=1e-14)
    var_names = ["Y", "ND", "D", "Ip", "c", "i", "r", "P", "dL", "dM", "dR",
                 "W", "N", "U", "SD", "AE", "AP", "AQ"]
    return dict(zip(var_names, sol))


# ── 3. Curve evaluation (parameterised) ────────────────────────────────────
def make_curve_eval(params, base_vars):
    """
    Return a curve-evaluator function that uses `params` for parameters
    and fills missing variables from `base_vars`.
    """
    def eval_curves(vars_dict):
        Y = vars_dict.get("Y", base_vars.get("Y", 0.0))
        r = vars_dict.get("r", base_vars.get("r", 0.0))
        P = vars_dict.get("P", base_vars.get("P", 0.0))
        AP = vars_dict.get("AP", base_vars.get("AP", 0.0))

        b = params["b"]; c0 = params["c0"]; c1 = params["c1"]
        d0 = params["d0"]; d1 = params["d1"]; d2 = params["d2"]
        i0 = params["i0"]; i1 = params["i1"]; i2 = params["i2"]
        iAP = params["iAP"]; m = params["m"]; k = params["k"]; n = params["n"]
        W0 = params["W0"]; h = params["h"]; a = params["a"]; Nf = params["Nf"]
        p1 = params["p1"]; s0 = params["s0"]; s1 = params["s1"]; s2 = params["s2"]
        g0 = params["g0"]; g = params["g"]; AQ_bar = params["AQ_bar"]
        csd = params["credit_sd_channel"]
        pap = params["policy_ap_channel"]
        fap = params["firms_ap_channel"]
        drc = params["differential_rate_channel"]

        sr_mult = 1 + drc * (iAP - 1)
        reinvest = 1 / (1 - g)

        # IS curve: IS(r)
        debt_at_ref = s0 - s1 * sr_mult * r
        ap_calc = (p1 * (g0 + reinvest * (debt_at_ref + s2))) / (AQ_bar + p1 * reinvest * s2)
        sd_calc = debt_at_ref - s2 * (ap_calc - 1)
        cr_calc = c0 - c1 * (csd * sd_calc)
        prod_demand = d0 - d1 * r - fap * d2 * ap_calc
        IS_val = cr_calc * prod_demand / (1 - b)

        # IR curve: IR(Y)
        pl = (1 + n) * a * (W0 - h * (1 - a * Y / Nf))
        base_rate = (1 + m) * (i0 + i1 * pl)
        pf = (1 + m) * pap * i2
        debt_intercept = s0 + s2 - s1 * sr_mult * base_rate
        total_price_sens = s2 + s1 * sr_mult * pf
        ap_ir = (p1 * (g0 + reinvest * debt_intercept)) / (AQ_bar + p1 * reinvest * total_price_sens)
        IR_val = base_rate + pf * ap_ir

        # AD curve: ADc(P)
        base_rate_ad = (1 + m) * (i0 + i1 * P)
        pf_ad = (1 + m) * pap * i2
        debt_intercept_ad = s0 + s2 - s1 * sr_mult * base_rate_ad
        total_price_sens_ad = s2 + s1 * sr_mult * pf_ad
        ap_ad = (p1 * (g0 + reinvest * debt_intercept_ad)) / (AQ_bar + p1 * reinvest * total_price_sens_ad)
        rate_ad = base_rate_ad + pf_ad * ap_ad
        sd_ad = s0 - s1 * sr_mult * rate_ad - s2 * (ap_ad - 1)
        cr_ad = c0 - c1 * (csd * sd_ad)
        prod_demand_ad = d0 - d1 * rate_ad - fap * d2 * ap_ad
        ADc_val = cr_ad * prod_demand_ad / (1 - b)

        # AS curve: ASc(Y)
        ASc_val = (1 + n) * a * (W0 - h * (1 - a * Y / Nf))

        # AMD curve: AMD(AP)
        pl_amd = (1 + n) * a * (W0 - h * (1 - a * Y / Nf))
        rate_amd = (1 + m) * (i0 + i1 * pl_amd + pap * i2 * AP)
        sd_amd = s0 - s1 * sr_mult * rate_amd - s2 * (AP - 1)
        nom_asset_demand = g0 + sd_amd / (1 - g)
        AMD_val = p1 * nom_asset_demand / AP

        AMS_val = AQ_bar

        return {"IS": IS_val, "IR": IR_val, "ADc": ADc_val,
                "ASc": ASc_val, "AMD": AMD_val, "AMS": AMS_val}

    return eval_curves


# ── 4. Solve baseline ─────────────────────────────────────────────────────
solution = solve_model(PAR)
print("=== Baseline equilibrium ===")
for k, v in solution.items():
    print(f"  {k} = {v:.10f}")

# Verify: baseline curve evaluator
base_curves = make_curve_eval(PAR, solution)
eq_curves = base_curves(solution)
print(f"Max residual at eq: {max(abs(v - solution[k]) for k, v in [('Y', eq_curves['IS']), ('r', eq_curves['IR']), ('P', eq_curves['ASc']), ('AP', eq_curves['AMD'])]):.2e}")

# ── 5. Lower-i₀ model (factor=0.0 ⇒ i₀=0) ────────────────────────────────
PAR_LOWER = dict(PAR)
PAR_LOWER["i0"] = 0.0

# Also solve the lower-i₀ model (needed for the asset market AMD curve,
# as done in Julia's plot_asset_market)
solution_lower = solve_model(PAR_LOWER)
print("\n=== Lower-i₀ equilibrium ===")
for k, v in solution_lower.items():
    print(f"  {k} = {v:.10f}")

# Curve evaluator for the lower-i₀ model
lower_curves = make_curve_eval(PAR_LOWER, solution)
lower_curves_from_lower = make_curve_eval(PAR_LOWER, solution_lower)

# ── 6. Output directory ───────────────────────────────────────────────────
script_dir = os.path.dirname(os.path.abspath(__file__))
output_dir = os.path.join(script_dir, "..", "output")
os.makedirs(output_dir, exist_ok=True)

# =====================================================================
# CSV 1: IS‑IR panel  (200 points each)
# =====================================================================
# IS curve: interest rate → output (BASELINE only — IS not affected by i₀)
rate_range = np.linspace(0.05, 0.15, 200)
is_rows = [{"interest_rate": r, "output_IS": base_curves({"r": r})["IS"]} for r in rate_range]

# IR curve: output → interest rate (BASELINE + LOWER i₀)
output_range_isir = np.linspace(3.0, 12.0, 200)
ir_rows = []
for y in output_range_isir:
    ir_base = base_curves({"Y": y})["IR"]
    ir_lower = lower_curves({"Y": y})["IR"]
    ir_rows.append({"output": y, "interest_rate_IR": ir_base, "interest_rate_IR_lower_i0": ir_lower})

pd.DataFrame(is_rows).to_csv(os.path.join(output_dir, "is_ir_curves.csv"), index=False)
pd.DataFrame(ir_rows).to_csv(os.path.join(output_dir, "ir_curves.csv"), index=False)
print("[1/4] is_ir_curves.csv + ir_curves.csv ✓")

# =====================================================================
# CSV 2: AD‑AS panel  (200 points each, aligned grids)
# =====================================================================
# AS(Y) = (1+n)*a*(W0 - h*(1 - a*Y/Nf)) is linear in Y.
# Invert analytically:  Y = (P/((1+n)*a) - W0 + h) * Nf/(h*a)
def inverse_AS(P, params):
    n = params["n"]; a = params["a"]; W0 = params["W0"]
    h = params["h"]; Nf = params["Nf"]
    return (P / ((1 + n) * a) - W0 + h) * Nf / (h * a)

# ── Grid A: price_level ∈ [0.5, 2.5] (200 points) ──
# AD: P → Y_AD(P)       (direct evaluation)
# AS: P → Y_AS_inv(P)   (inverse, both curves share P-axis)
price_range = np.linspace(0.5, 2.5, 200)
ad_rows = []
for p in price_range:
    curves_base = base_curves({"P": p})
    curves_lower = lower_curves({"P": p})
    ad_rows.append({
        "price_level": p,
        "output_AD": curves_base["ADc"],
        "output_AD_lower_i0": curves_lower["ADc"],
        "output_AS_inv": inverse_AS(p, PAR),  # Y at which AS(Y) = P
        "output_AS_inv_lower_i0": inverse_AS(p, PAR_LOWER),  # same real economy
    })

# ── Grid B: output ∈ [4.5, 9.0] (200 points) ──
# AS: Y → P_AS(Y)       (direct evaluation — pure AS curve data)
output_range_adas = np.linspace(4.5, 9.0, 200)
as_rows = [{"output": y, "price_level_AS": base_curves({"Y": y})["ASc"]} for y in output_range_adas]

pd.DataFrame(ad_rows).to_csv(os.path.join(output_dir, "ad_as_curves.csv"), index=False)
pd.DataFrame(as_rows).to_csv(os.path.join(output_dir, "as_curves.csv"), index=False)
print("[2/4] ad_as_curves.csv ✓ (P-grid: AD + inverse AS)")
print("      as_curves.csv ✓ (Y-grid: direct AS)")

# =====================================================================
# CSV 3: Asset‑market panel  (200 points each)
# =====================================================================
# Julia's plot_asset_market: uses the LOWER-i₀ SOLUTION as the base vars
# for computing the lower-i₀ AMD curve.
AP_eq_base = solution["AP"]
ap_low, ap_high = sorted([0.55 * AP_eq_base, 1.8 * AP_eq_base])
asset_price_range = np.linspace(ap_low, ap_high, 200)

# AMD range: use the same price range for both, but with different base vars
am_rows = []
for ap in asset_price_range:
    base_vars = {"AP": ap}
    curves_base = base_curves(base_vars)
    curves_lower = lower_curves_from_lower(base_vars)
    am_rows.append({
        "asset_price": ap,
        "demand_at_base_price": curves_base["AMD"],
        "demand_at_base_price_lower_i0": curves_lower["AMD"],
        "asset_supply": curves_base["AMS"],
    })

pd.DataFrame(am_rows).to_csv(os.path.join(output_dir, "asset_market_curves.csv"), index=False)
print("[3/4] asset_market_curves.csv ✓")

# =====================================================================
# CSV 4: Balance‑sheet data
# =====================================================================
bs_data = [
    {"sector": "PrivateSector", "side": "asset",     "instrument": "deposits",
     "value": solution["dM"], "abs_value": abs(solution["dM"])},
    {"sector": "PrivateSector", "side": "liability", "instrument": "loans",
     "value": solution["dL"], "abs_value": abs(solution["dL"])},
    {"sector": "Banks", "side": "asset",     "instrument": "loans",
     "value": solution["dL"], "abs_value": abs(solution["dL"])},
    {"sector": "Banks", "side": "asset",     "instrument": "reserves",
     "value": solution["dR"], "abs_value": abs(solution["dR"])},
    {"sector": "Banks", "side": "liability", "instrument": "deposits",
     "value": solution["dM"], "abs_value": abs(solution["dM"])},
    {"sector": "Banks", "side": "liability", "instrument": "central_bank_credit",
     "value": solution["dR"], "abs_value": abs(solution["dR"])},
    {"sector": "CentralBank", "side": "asset",     "instrument": "central_bank_credit",
     "value": solution["dR"], "abs_value": abs(solution["dR"])},
    {"sector": "CentralBank", "side": "liability", "instrument": "reserves",
     "value": solution["dR"], "abs_value": abs(solution["dR"])},
]
pd.DataFrame(bs_data).to_csv(os.path.join(output_dir, "balance_sheets.csv"), index=False)
print("[4/4] balance_sheets.csv ✓")

# ── Convenience: equilibrium values for both scenarios ────────────────
eq_rows = []
for k in solution:
    eq_rows.append({"variable": k, "value_baseline": solution[k], "value_lower_i0": solution_lower[k]})
pd.DataFrame(eq_rows).to_csv(os.path.join(output_dir, "equilibrium_values.csv"), index=False)
print("(bonus) equilibrium_values.csv ✓")

print(f"\n✓ All CSVs → {output_dir}/")