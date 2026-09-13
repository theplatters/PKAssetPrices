---
title: "Working-Paper Readiness Report: Keynes on speculation and endogenous money (teaching note)"
author: "Hermes (statistics profile)"
date: "2026-09-13"
tags: [review, working-paper, PKAssetPrices, teaching-note, v2]
project: "PKAssetModel / MoneyModel PKAssetPrices"
---

<span style="color:#800080">**Version 2**</span> --- 2026-09-13. Supersedes v1 of this report.

## Revision log

| Version | Date | Scope of change |
|---------|------|-----------------|
| v1 | 2026-09-13 | Original five-step readiness report (scope, numerical verification, citations, authoring gaps, July-11 assessment review, action list). |
| v2 | 2026-09-13 | Adds an EJHET outlet evaluation; marks two blocking items **resolved** (c-clipping in code; section 5.2 dual-rate equation corrected to the code's additive mechanism); reports the PQC parameter change (`s0 = 1.2`) that widens the `psi` gap; collapses the citations and authoring-gap sections into one; folds in TODOs/NOTEs extracted from `teaching-note.tex`; refreshes all reproduced numbers. |

# Executive summary

The manuscript is roughly 70-80% of the way to a circulable working paper. The history-of-thought framing (Treatise vs. General Theory as a 2x2 typology) is strong, the staged model architecture is clear, and the real-world section is well evidenced. The reported equilibrium numbers in the text are reproduced by the code (no numerical mismatch).

Since v1, **two of the four blocking errors have been resolved**:

1. **c-clipping is now in the code** (`asset_model.jl`): the credit-rationing rule `c = c0 - c1*SD` is wrapped in `clamp(..., 0, 1)`, in both the equation and the IS/ADc curve blocks, so plotted curves match the solved equilibrium. The economic range `0 <= c <= 1` is now enforced by construction rather than by assumption.
2. **The section 5.2 dual-rate equation is corrected** to the code's *additive* mechanism. The manuscript now writes `r_AP = r*(1 + theta*(i_AP-1))` and `SD = s0 - s1*r_AP - s2*(AP-1)` at the code's defaults (`theta = 1.2`, `i_AP = 1.2`), which reproduces the reported `AP = 0.81`, `psi 0.11 -> 0.09`. The old multiplicative form `SD = s0 - s1*i_AP*r` (implying `i_AP = 2`) did not.

In addition, per the author's request, the **PQC scenario now uses `s0 = 1.2`** (instead of the base `0.836`). This is an AD/SD-side lever: raising autonomous speculative debt lifts the level of `SD`, and because PQC endogenises credit rationing (`c` falls with `SD`), the Baseline `->` PQC gap in the risk indicator `psi = SD/dL` widens from about `0.006` to **`0.067`** (`0.106 -> 0.173`), making the effect clearly visible where the manuscript TODO complained it was too small to see. Caveat: this also strengthens PQC's crowding-out (output falls to 6.08, `c` to 0.74) -- a deliberate consequence that should be flagged in the text.

**Remaining blocking (unchanged from v1):** (1) the displayed closed-form Eq.~(5) is still algebraically wrong, (2) five in-text citations are still undefined in the `.bib` files and will throw `biber` at build, and (3) leftover author-comment blocks and a garbled string remain in the source.

# Outlet evaluation: EJHET vs IJPEE

This section addresses whether the European Journal of the History of Economic Thought (EJHET) is a plausible alternative to the IJPEE target recommended in v1.

**EJHET** (Taylor & Francis, impact factor about 0.32, JCR Q4) is a history-of-economic-thought journal. Its stated aims are the *historical* analysis of economic ideas, interdisciplinary approaches, contextualisation of theories, underrepresented voices, and methodological innovation in HET. It describes itself as pluralist and non-partisan, but its editorial centre of mass is textual and historical scholarship, not formal modelling or pedagogy.

**What EJHET would reward in this note:** the Treatise vs. General Theory framing, the 2x2 typology (exogenous/endogenous money x speculation-isolated/speculation-feedback), and the rational reconstruction of the deposit classification (industrial vs. financial circulation) are genuine and central HET contributions. A referee for EJHET would likely find the historical reasoning strong and the acknowledgement that the model does not re-derive the GT bond-market setup methodologically honest.

**What EJHET would not reward:** the teaching apparatus, the staged model variants (Baseline/PQC/PQCr/PQCrDIFF/FirmsRation), the balance-sheet tables, and the real-world policy section are outside EJHET's historical remit. As it stands the paper is *primarily a teaching model with an HET frame*; EJHET would require re-aiming it primarily as an historical essay (trimming or parking the model and code and foregrounding the textual reconstruction).

**IJPEE** (Inderscience, economics-education journal) explicitly publishes pluralist economics *pedagogy*: classroom exercises, teaching-from-a-pluralist-perspective material, notes/communications, and a "Pedagogical Techniques" section. The staged model architecture, the reproducible Julia code, and the turnover-multiplier / risk-indicator pedagogy are precisely its advertised scope. The Julia code and Dash dashboard are a selling point here, not a liability.

**Recommendation (unchanged, now cross-checked):** **IJPEE remains the right primary target** given the paper's current centre of mass (teaching model + code). **EJHET is a viable secondary target only if the paper is re-aimed around the historical contribution** -- a submission that treats the 2x2 typology and the deposit-classification reconstruction as the result, moves the model variants into an online appendix/repository, and drops or truncates the teaching framing. That is a substantial rescale, not a light edit. If the author accepts that trade, EJHET would be a credible home for the *historical* core; if not, the marginal effort is better spent on the IJPEE-specific assets (code, figures, classroom framing).

**JPKE** stays in view for a later, more theoretical submission, not the current scope: it requires a working dynamic model and a derived turnover multiplier, neither of which is currently present.

# What the static manuscript depends on (scope)

See the companion note `paper/code-to-paper-mapping.md`. The WP reproducibility surface is `src/static/` + `asset_model.jl` + `static_plotting.jl` + the five `plots/*_equilibrium_panel.pdf` + the two `paper/tables/*` files. The Dash dashboard, the dynamic models, the optimisation code, the Mathematica notebooks, and the exploration notebooks are project context, not paper inputs.

# Numerical and algebraic errors (steps 2-3), refreshed for v2

**Verification method.** All numbers below were obtained by **running the actual compiled model** under Julia 1.12.7 with `JULIA_DEPOT_PATH=/opt/julia-depot`, from the working tree after the c-clipping and PQC-s0 changes.

## Reproduced equilibrium values (compiled code, working tree)

| Scenario | AP | SD | Y | c | r | psi = SD/dL |
|---|---|---|---|---|---|---|
| Baseline | 0.9966 | 0.3887 | 6.566 | 0.8000 | 0.1120 | 0.1059 |
| **PQC** | 1.6321 | 0.6365 | 6.076 | 0.7363 | 0.1093 | **0.1732** |
| PQCr | 0.8700 | 0.3393 | 6.327 | 0.8000 | 0.1307 | 0.0969 |
| PQCrDIFF | 0.8143 | 0.3176 | 6.566 | 0.8000 | 0.1120 | 0.0882 |
| FirmsRation | 1.0258 | 0.4001 | 5.801 | 0.8000 | 0.1077 | 0.1212 |

Baseline `->` PQC gap in `psi`: **0.1059 -> 0.1732** (about 0.006 at the old `s0 = 0.836`). The TODO at `teaching-note.tex:420` ("increase too small to see in the rounded output") is addressed.

## Status of reported numbers (vs the draft text)

- **Baseline AP ~0.99 (paper) --- CORRECT.** Code gives 0.9966. Unchanged.
- **PQCrDIFF AP = 0.81, psi 0.10 -> 0.09 (paper) --- CORRECT after the section 5.2 fix.** Code gives AP = 0.8143, psi 0.1059 -> 0.0882. The written equation now matches the code's additive premium mechanism, closing the "equation does not reproduce the figure" objection.
- **PQC / PQCr / FirmsRation numbers** are internally consistent with the code. PQC's values changed relative to v1 only because `s0` was raised to 1.2 in the scenario; the mechanism and the other scenarios are untouched.

## Genuine errors and inconsistencies (still open)

1. **The closed-form solution Eq.~(5) (`teaching-note.tex:332`) is still algebraically wrong.** The displayed formula `AP = [(1-gamma) + (s0+s2-s1 r)] / [QA(1-gamma) + s2]` omits the `p1` and `gamma` factors. Evaluated with the real parameters it gives `AP ~ 1.84`, whereas the correct derivation (and the code's `AMD` curve) gives `AP = p1(s0+s2 - s1 r)/[(1-gamma)QA + p1 s2] = 0.9966`. The `@curves` block is correct; the displayed equation is not. **Still open, blocking.**
2. **Five in-text citations have no matching `.bib` entry** and will throw `biber` errors: `Keynes1938HarrodLetter`, `ft2020everything`, `handwiki`, `klein2025` (the defined key is `kleinQuantitativeEasingHousing2025`), `wolfsonPostKeynesianTheory1996a` (the defined key is `wolfsonPostKeynesianTheory1996`). **Still open, blocking.**
3. **Leftover author-comment blocks and a garbled string.** `%NOTE`/`%TODO`/`expand?` blocks at lines 67, 123, 172-173, 219, 270, 372, 375, 378, 420, 517, 533; the garbled `rortyHistoriographyPhilosophyFour1984riographyPhilosophyFour1984ng` string at line 388. **Still open, non-blocking.**

# Citations, authoring gaps, and new TODOs (steps 2 + 4; collapsed in v2)

This section merges the v1 "Citations and build integrity" and "Remaining authoring gaps" sections.

## Bibliography and build integrity

- Five undefined cite keys (listed above) -- blocking `biber`. The key `kleinQuantitativeEasingHousing2025` is defined but unused and is likely the intended entry for the three `klein2025` citations; `wolfsonPostKeynesianTheory1996` is defined without the `a`.
- `main.tex` / `main.typ` outlines are stale: they describe "three versions" (PQ / PQC / PQCr) and do not reflect the five-variant code. Archive or update them.

## Authoring gaps -- with drafting suggestions

For each gap a directed suggestion is given, **except "endogenising alpha"**, which the author has asked be handled separately and is left out of this WP.

- **Calibration note for `s0` (base `0.836`, PQC `1.2`).** *Suggestion:* one paragraph stating the normalisation -- reference asset price `AP = 1`, the reference speculative-debt scale, and how `s0` is rescaled in PQC to widen the `psi` gap. Give the student the number and its units, not just the code default.
- **Figure-caption closures (TODO line 372).** *Suggestion:* in each caption spell out the underlying definitions of the curve closures (what `IS`/`IR`/`AD`/`AS`/`AMD`/`AMS` are plotted against) and state that each curve is traced around *that model's own* equilibrium -- which is why an indirect shift (e.g. the AMD shift under PQC) is a general-equilibrium spillover, not a direct channel. The note states part of this at lines 339-340; the captions should restate it in one sentence.
- **Ad-hoc pricing limitation (`AP = p1*AD/AS`).** *Suggestion:* one crisp sentence near the asset-market section noting that the price is a demand/supply-ratio closure, not a forward-looking pricing model.
- **Dynamic section status.** *Suggestion:* the teaching note already frames dynamics as future work (lines 597-609); keep it that way for this WP. The `main.typ` dynamic equations (including possible endogenised `alpha` and the hysteresis sketch) are not results.
- **Financialization engagement in section 3.3.** *Suggestion:* the citations are present but the engagement is thin; one or two sentences should link the `firms_ap_channel` to the financialization literature already cited (Davis, Stockhammer) rather than only to `d2`.
- **SFC/stock framing.** Partially addressed (StockMatrix/FlowMatrix present); the July-11 "add stock balance sheets for Minskyan dynamics" point remains live only insofar as the dynamic follow-up is pursued.

## New TODOs and NOTEs folded in from `teaching-note.tex`

| Line | Marker | Content (condensed) | Status |
|------|--------|---------------------|--------|
| 67 | %NOTE | Consistency of "speculative markets" vs "financial markets" terminology (real estate). | open, minor |
| 123 | expand? | Whether to add top-left/top-right model variants; settled on staying with endogenous scenarios. | decided |
| 172-173 | expand? / NOTE | Interplay variant; whether liquidity preference pins `gamma` in the dynamic model. | open, dynamic track |
| 219 | expand? | Making portfolio choice explicit (expected profit vs expected price rise). | open, dynamic track |
| 270 | expand? | Whether a full (output-and-price) Taylor rule is needed; recursivity limit in the static model. | open |
| 372 | TODO | Caption definitions for closures; assignment of new deposits to households/firms. | open |
| 375 | NOTE | External reading (T&F DOI) to review. | open |
| 378 | expand? | Whether to split out rentiers as a separate class (settled: no). | decided |
| 420 | %todo | `psi` increase too small in rounded output. | **resolved** (s0 change) |
| 517 | %NOTE | Possible appendix on the firm asset-holding distinction (assets not in current FlowMatrix). | open |
| 533 | %TODO | Dual-rate storyline: rate premium vs the general policy-rate reaction (Eq. i-ap). | folded into section 5.2 fix |

# Review of the July-11 AI assessment (step 5)

- **IJPEE target:** still the right call given the current scope; EJHET evaluated above as a secondary target if a major rescale is accepted.
- **Turnover multiplier as the JPKE lever:** still the single biggest missing theoretical contribution; lines 339 and 580 cite `gamma` and `1/(1-gamma)` but do not formalise it as a derived "turnover multiplier" analogue to the income multiplier. Live.
- **Dynamic model completeness:** correctly identified as a sketch; `main.typ` remains a sketch. Live.
- **SFC / Minsky / financialization literature:** citations present, engagement thin; suggestions in the collapsed section above. Live.
- **Balance-sheet / stock framing:** StockMatrix present; fully closed only with the dynamic follow-up.

# Prioritised action list (v2)

Must fix before circulation (blocking):

1. Fix the closed-form Eq.~(5) (`teaching-note.tex:332`) -- algebraically wrong (~1.84 vs 0.9966): `AP = p1(s0+s2-s1 r)/[(1-gamma)QA + p1 s2]`.
2. Add the five missing `.bib` entries (or correct the five cite keys) and run `biber` for a clean build.
3. Clean the garbled `rorty` string (line 388) and strip the leftover `%NOTE`/`%TODO`/`expand?` blocks.

Should fix for a complete WP:

4. Calibration note for `s0` (and the PQC `s0 = 1.2` scaling).
5. Close the figure-caption TODO (line 372) with the own-equilibrium tracing convention.
6. One-paragraph limitations note on the ad-hoc asset pricing.
7. Finish the PQC `psi` narrative in section 3.3 (the s0 change makes it visible); decide whether the stronger crowding-out (Y 6.08, c 0.74) is desired as published.

Nice to have (post-WP / JPKE path):

8. Formalise the turnover multiplier as a derived result.
9. Deepen financialization / SFC / Minsky engagement.
10. Promote the dynamic model from sketch to result only in a follow-up paper.

**Tracked separately (not in this WP):** endogenising `alpha` (author's instruction) and the dynamic-track TODO / expand? items at lines 172-173, 219, 270.