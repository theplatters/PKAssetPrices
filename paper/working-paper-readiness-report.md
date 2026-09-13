---
title: "Working-Paper Readiness Report: Keynes on speculation and endogenous money (teaching note)"
author: "Hermes (statistics profile)"
date: "2026-09-13"
tags: [review, working-paper, PKAssetPrices, teaching-note]
project: "PKAssetModel / MoneyModel PKAssetPrices"
---

This report focuses on **what is missing for a complete working-paper (WP) version** of
the teaching note `paper/teaching-note.tex`. It is the deliverable of steps (1)-(5) of
the review. The model was run directly under Julia 1.12.7 with
`JULIA_DEPOT_PATH=/opt/julia-depot` (the pre-populated depot); the equilibrium numbers in
this report are reproduced from the compiled code, not from a re-derivation.

# Executive summary

The manuscript is roughly 70-80% of the way to a circulable working paper. The history-
of-thought framing (Treatise vs. General Theory as a 2x2 typology) is strong, the staged
model architecture is clear, and the real-world section is well evidenced. The reported
equilibrium numbers in the text are reproduced by the code (no numerical mismatch). **However,
before any circulation there are still blocking errors**: (a) one displayed closed-form
equation is algebraically wrong, (b) the dual-interest-rate prose equation does not match
the code mechanism that produces the reported figures, (c) five in-text citations are
undefined in the `.bib` files and will break the `biber` build, and (d) leftover
author-comment blocks and a garbled string
remain in the source. The dynamic-model section is, as the manuscript itself states, a
forward-looking sketch and should stay framed as future work for this WP.

Recommendation (unchanged from the July-11 assessment): **IJPEE is the right home.** JPKE
would require the formalised "turnover multiplier" and a working dynamic model, neither of
which is present.

# What the static manuscript depends on (scope)

See the companion note `paper/code-to-paper-mapping.md`. In short, the WP reproducibility
surface is `src/static/` + `asset_model.jl` + `static_plotting.jl` + the five
`plots/*_equilibrium_panel.pdf` + the two `paper/tables/*` files. The Dash dashboard, the
dynamic models, the optimisation code, the Mathematica notebooks, and the exploration
notebooks are project context, not paper inputs.

# Numerical and algebraic errors to rectify (steps 2-3)

**Verification method (corrected).** An earlier draft of this report transcribed the model
equations into an external solver and reported several mismatches with the paper. That
transcription contained a bug; the numbers below were obtained by **running the actual
compiled model** under Julia 1.12.7 with `JULIA_DEPOT_PATH=/opt/julia-depot` (the pre-populated
depot). The code's parameters are `s0 = 0.836089551258839`, `s1 = 4.0`, `s2 = 0.2`,
`gamma = 0.5`, `p1 = 1.0`, `AQ_bar = 0.78`, `iAP = 1.2`, `c0 = 0.8`, `c1 = 0.1`.

## Reproduced equilibrium values (actual compiled code)

| Scenario | $AP$ | $SD$ | $Y$ | $c$ | $r$ | $\psi = SD/dL$ |
|---|---|---|---|---|---|---|
| Baseline | 0.9966 | 0.3887 | 6.566 | 0.8000 | 0.1120 | 0.1059 |
| PQC | 1.0081 | 0.3932 | 6.2641 | 0.7607 | 0.1103 | 0.1115 |
| PQCr | 0.8700 | 0.3393 | 6.3271 | 0.8000 | 0.1307 | 0.0969 |
| PQCrDIFF | 0.8143 | 0.3176 | 6.566 | 0.8000 | 0.1120 | 0.0882 |
| FirmsRation | 1.0258 | 0.4001 | 5.8006 | 0.8000 | 0.1077 | 0.1212 |

## Status of reported numbers

- **Baseline $AP \approx 0.99$ (paper) -- CORRECT.** Code gives 0.9966. (An earlier draft
  wrongly claimed 0.88 due to a transcription error; retracted.)
- **PQCrDIFF $AP = 0.81$, $\psi$ 0.10->0.09 (paper) -- CORRECT.** Code gives
  $AP = 0.8143$, $\psi = 0.1059 \to 0.0882$. (Earlier "wrong number" claim retracted.)
- **PQC / PQCr / FirmsRation numbers** are internally consistent with the code; no action.

## Genuine errors and inconsistencies (still open)

1. **The closed-form solution Eq. (5) (teaching-note.tex:332) is algebraically wrong.**
   The displayed formula
   $AP = [(1-\gamma) + (s_0 + s_2 - s_1 r)] / [QA(1-\gamma) + s_2]$
   omits the $p_1$ and $\gamma$ factors on the right-hand side. Evaluated with the real
   parameters it gives $AP \approx 1.84$, whereas the correct derivation (and the code's
   `AMD` curve) gives
   $AP = p_1(s_0 + s_2 - s_1 r) / [(1-\gamma)QA + p_1 s_2] = 0.9966$.
   The `@curves` block in `asset_model.jl` is correct; the displayed equation is not and
   must be fixed. This is the one confirmed algebraic error in the manuscript.

2. **The dual-interest-rate prose equation is mis-stated (teaching-note.tex:545-550).**
   The text writes the penalty as multiplying into the rate coefficient,
   $SD = s_0 - s_1 i_{AP} r - s_2(AP-1)$, and also labels the result with "$i_{AP}=2$".
   Taken literally that yields $AP \approx 0.24$, not the reported $0.81$. The **code**
   instead uses a separate speculative rate $r_{AP} = i_{AP} r$ together with
   $SD = s_0 - s_1 r\,[1 + \text{differential\_rate\_channel}\,(i_{AP}-1)] - s_2(AP-1)$,
   at the code's defaults (`differential_rate_channel = 1.2`, `iAP = 1.2`), which produces
   the reported $AP = 0.81$. So the *numbers* are reproducible from the code, but the
   *written equation* that is supposed to generate them does not. Either correct the
   equation to match the code mechanism, or state explicitly that the figure uses the
   code's default `iAP = 1.2` (not 2).

3. **Unclipped $c$ (known, still open).** The paper notes (teaching-note.tex:407-409) that
   $c = c_0 - c_1 SD$ is not clipped in code and requires $0 \le c \le 1$. At PQC,
   $c = 0.7607$, inside the range, but the parameter space where $c$ turns negative is
   never characterised. The July-11 assessment flagged this as a weakness; it remains
   unaddressed. A short "parameter-space" note is needed before WP.

# Citations and build integrity (step 2)

A citation check (`\cite`/`\citep`/`\citet` keys vs. both `.bib` files) found **five
in-text citations with no matching entry** -- these will throw `biber` errors at build:

- `Keynes1938HarrodLetter` (teaching-note.tex:63)
- `ft2020everything` (teaching-note.tex:575)
- `handwiki` (teaching-note.tex:575)
- `klein2025` (teaching-note.tex:575, 583) -- note a *different* key
  `kleinQuantitativeEasingHousing2025` is defined but unused; likely the intended entry.
- `wolfsonPostKeynesianTheory1996a` (teaching-note.tex:398) -- the defined key is
  `wolfsonPostKeynesianTheory1996` (without the `a`).

Additionally:

- A garbled duplicate string at teaching-note.tex:388:
  "rortyHistoriographyPhilosophyFour1984riographyPhilosophyFour1984ng" -- a copy-paste
  corruption that must be cleaned.
- Leftover author-comment blocks remain in the source and should be stripped before WP:
  the `NOTE:` at line 67, the `expand?`/`NOTE:` blocks at lines 123, 172-173, 380, 521,
  and the `%TODO` + `%NOTE` at lines 374-377. These are internal scratch, not reader text.
- The `main.tex` / `main.typ` outlines are **stale**: they still describe "three versions"
  (PQ / PQC / PQCr) and do not reflect the five-variant code. They are planning artifacts,
  not the manuscript; either archive them or update them.

# Remaining authoring gaps (step 4: what is actually missing in the text)

Beyond fixing errors, the following content is needed for a complete WP:

- **Calibration note.** Where does $s_0 = 0.836089551258839$ come from? A one-paragraph
  statement of how the asset-market parameters were normalised (reference price $AP=1$,
  reference rate) would make the numbers defensible.
- **Endogenising $\alpha$.** `main.typ` lists "Endogenizing $\alpha$" as a section; the
  teaching note mentions $\gamma$ as a turnover proxy (teaching-note.tex:339, 580) but
  never develops an $\alpha$-endogenisation as a result. Either add the subsection or
  move it explicitly to future work.
- **Figure-caption closures (TODO line 374).** The TODO asks to spell out, in each caption,
  the underlying definitions for the curve closures. This is still open and should be
  closed before WP.
- **Ad-hoc pricing limitation paragraph.** The July-11 assessment (point 2) notes
  $AP = p_1 \cdot AD/AS$ is a demand-supply ratio, not a forward-looking pricing model.
  The paper gestures at this (teaching-note.tex:339) but a crisp "limitations" sentence
  belongs near the asset-market section.
- **Dynamic section status.** teaching-note.tex:597-609 already frames dynamics as future
  work. Keep it that way for this WP; do not promise results the repo does not contain.
  The `main.typ` hysteresis sketch is not a result.

# Review of the July-11 AI assessment (step 5)

The assessment (`paper/AI-assessment-July11.txt`) remains largely live:

- **IJPEE target:** still the right call given the current scope.
- **Turnover multiplier as the JPKE lever:** still the single biggest missing theoretical
  contribution. The note references $\gamma$ and the $1/(1-\gamma)$ multiplier (lines 339,
  580) but does not formalise it as a derived "turnover multiplier" analogous to the income
  multiplier. Live recommendation.
- **Dynamic model completeness:** correctly identified as incomplete; the repo's dynamic
  part is still a sketch. Live.
- **SFC / Minsky / financialization literature:** the citations are present
  (`nikolaidi2017`, `ryoo2010`, `ryoo2016`, `grasselli2015`, `stockhammer2004`,
  `minsky1986`) but the real-impacts section engages them thinly. Strengthening the
  engagement with the financialization channel (section 3.3) would lift the note without
  requiring new theory.
- **Balance-sheet / stock framing:** the assessment suggested adding stock balance sheets
  for Minskyan dynamics. The note already includes `StockMatrix_*.tex`; this is partially
  addressed. Live only insofar as the dynamic follow-up is pursued.

# Prioritised action list

Must fix before circulation (blocking):

1. Fix the closed-form Eq. (5) (teaching-note.tex:332) -- it is algebraically wrong and
   evaluates to ~1.84 instead of ~1.00. Replace with
   $AP = p_1(s_0 + s_2 - s_1 r)/[(1-\gamma)QA + p_1 s_2]$.
2. Reconcile the dual-interest-rate prose equation (teaching-note.tex:545-550) with the
   code: the written $SD = s_0 - s_1 i_{AP} r - s_2(AP-1)$ does not reproduce the reported
   $AP=0.81$; either correct it to the code mechanism or state that the figure uses the
   code default `iAP = 1.2` (not 2).
3. Add the five missing `.bib` entries (or correct the five cite keys) and run `biber` to
   confirm a clean build.
4. Clean the garbled "rorty" string (line 388) and strip the leftover `NOTE`/`TODO`/
   `expand?` author blocks.

Should fix for a complete WP:

5. Add the calibration note for $s_0$ and the asset-market normalisation.
6. Characterise the parameter space where $0 \le c \le 1$ (or clip $c$ and state it).
7. Close the figure-caption TODO (line 374).
8. Add a one-paragraph limitations note on the ad-hoc asset pricing.
9. Decide and either write or explicitly defer the "endogenising $\alpha$" subsection.

Nice to have (post-WP / JPKE path):

10. Formalise the turnover multiplier as a derived result.
11. Deepen engagement with the financialization/SFC/Minsky literature in section 3.
12. Promote the dynamic model from sketch to result only in a follow-up paper.
