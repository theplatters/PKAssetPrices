---
title: "Working-Paper Readiness Report: Keynes on speculation and endogenous money (teaching note)"
author: "Hermes (statistics profile)"
date: "2026-09-13"
tags: [review, working-paper, PKAssetPrices, teaching-note, v2]
project: "PKAssetModel / MoneyModel PKAssetPrices"
---

**Version 2** \textcolor{revisionV1}{(2026-09-13)}
**Version 1** (2026-09-13)

> \textcolor{revisionV1}{This version supersedes v1. All changes relative to v1 are marked in purple.}

This report focuses on **what is missing for a complete working-paper (WP) version** of
the teaching note `paper/teaching-note.tex`. It is the deliverable of steps (1)-(5) of
the review. The model was run directly under Julia 1.12.7 with
`JULIA_DEPOT_PATH=/opt/julia-depot` (the pre-populated depot); the equilibrium numbers in
this report are reproduced from the compiled code, not from a re-derivation.

# Executive summary

The manuscript is roughly 70\%---80\% of the way to a circulable working paper. The history-
of-thought framing (Treatise vs. General Theory as a 2x2 typology) is strong, the staged
model architecture is clear, and the real-world section is well evidenced. The reported
equilibrium numbers in the text are reproduced by the code (no numerical mismatch).

\textcolor{revisionV1}{\textbf{Since v1, the blocking-error picture has improved materially.} Re-checking the manuscript against the \texttt{.bib} files and the code, this revision finds that \textbf{three of the four blocking items v1 listed are already resolved}:}

1. \textcolor{revisionV1}{\textbf{References are now OK.} All 23 in-text cite keys are defined in the two \texttt{.bib} files (zero missing). The five keys v1 flagged as undefined --- \texttt{Keynes1938HarrodLetter}, \texttt{ft2020everything}, \texttt{handwiki}, \texttt{klein2025}, \texttt{wolfsonPostKeynesianTheory1996a} --- are no longer cited in the tex, and the intended keys (\texttt{kleinQuantitativeEasingHousing2025}, \texttt{wolfsonPostKeynesianTheory1996}) are used instead. The garbled \texttt{rorty...riography...ng} string v1 reported at line 388 is also clean.}
2. \textcolor{revisionV1}{\textbf{The closed-form Eq.~(5) (\texttt{teaching-note.tex:332}) is correct.} The file holds \texttt{AP = (s\_0+s\_2-s\_1 r)/[QA(1-\gamma)+s\_2]}, which reproduces the compiled \texttt{AP = 0.9966}. The "wrong" formula quoted in v1 (with an extra \texttt{(1-\gamma)} term in the numerator) is \textit{not} what the manuscript contains.}
3. \textcolor{revisionV1}{\textbf{Section 5.1's dual-rate equation is rewritten to be purely additive.} The speculative rate is now written \texttt{r\_{AP} = r + \pi} with \texttt{\pi = \theta(i\_{AP}-1)r}, and \texttt{SD = s\_0 - s\_1 r - s\_1 \pi - s\_2(AP-1)}. No multiplicative framing remains, and at the code defaults (\texttt{i\_{AP}=1.2}) this reproduces \texttt{AP = 0.81}, \texttt{\psi 0.11 \to 0.09}.}

\textcolor{revisionV1}{A fourth change is now in the code: \textbf{\texttt{c} is clipped} to \texttt{[0,1]} (\texttt{asset\_model.jl}), so the credit-rationing rule \texttt{c = c\_0 - c\_1 SD} can no longer leave its economically valid range. \textbf{The one remaining v1 blocking item that is still open is the leftover author-comment blocks (\texttt{\%NOTE}/\texttt{\%TODO}/\texttt{expand?})}; these remain in the source as of this revision.}

Recommendation (unchanged from the July-11 assessment): **IJPEE is the right home.** JPKE
would require the formalised "turnover multiplier" and a working dynamic model, neither of
which is present.

\textcolor{revisionV1}{\textbf{Outlet evaluation added (EJHET vs IJPEE).} The European Journal of the History of Economic Thought (EJHET; T\&F, IF ~0.32, Q4) is a history-of-economic-thought journal whose remit is textual and historical scholarship. EJHET would reward the Treatise/GT framing, the 2x2 typology and the deposit-classification reconstruction, but not the teaching apparatus, staged model variants or code. IJPEE (Inderscience economics-education) advertises exactly the pluralist-pedagogy material this note delivers, and the Julia code/dashboard are an asset there. \textbf{Verdict: IJPEE remains primary; EJHET is viable only if the paper is re-aimed as an historical essay} (park the model variants and code, foreground the textual reconstruction) --- a substantial rescale, not a light edit. JPKE stays a later target requiring the formalised turnover multiplier and a working dynamic model. Full evaluation in the section below.}

# Outlet evaluation: EJHET vs IJPEE

\textcolor{revisionV1}{\textbf{EJHET} publishes historical analysis of economic ideas, interdisciplinary HET, contextualisation of theory, and methodological innovation in HET; it is pluralist/non-partisan but not education-focused. What it would reward: the Treatise-vs-General Theory framing, the 2x2 typology, and the rational reconstruction of the deposit classification (industrial vs financial circulation). What it would not reward: the teaching frame, the staged variants, the balance-sheet tables, and the policy section --- all outside its historical remit. \textbf{IJPEE} publishes pluralist economics pedagogy (classroom exercises, pedagogical techniques); the staged architecture, reproducible Julia code and risk-indicator/turnover pedagogy fit its advertised scope, and code/tooling is a selling point. \textbf{Recommendation:} IJPEE primary; EJHET only if the paper is re-aimed as an HET essay (model and code moved to an appendix/repository, teaching framing dropped).}

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

\textcolor{revisionV1}{\textbf{Base specification (\texttt{s0 = 0.836}), current working tree (c-clipping in place, PQC \texttt{s0} reverted to base).}}

| Scenario | $AP$ | $SD$ | $Y$ | $c$ | $r$ | $\psi = SD/dL$ |
|---|---|---|---|---|---|---|
| Baseline | 0.9966 | 0.3887 | 6.566 | 0.8000 | 0.1120 | 0.1059 |
| PQC | 1.0081 | 0.3932 | 6.2641 | 0.7607 | 0.1103 | 0.1115 |
| PQCr | 0.8700 | 0.3393 | 6.3271 | 0.8000 | 0.1307 | 0.0969 |
| PQCrDIFF | 0.8143 | 0.3176 | 6.566 | 0.8000 | 0.1120 | 0.0882 |
| FirmsRation | 1.0258 | 0.4001 | 5.8006 | 0.8000 | 0.1077 | 0.1212 |

\textcolor{revisionV1}{\textbf{Comparison across specifications (part of v2).} For completeness, the table below compares the PQC row under the base spec and under a tested alternative in which the PQC scenario overrides \texttt{s0 = 1.2}. The override was applied to PQC only; every other scenario is identical across the two specifications.}

| Scenario | Spec | $AP$ | $SD$ | $Y$ | $c$ | $r$ | $\psi = SD/dL$ |
|---|---|---|---|---|---|---|---|
| Baseline | base ($s_0=0.836$) | 0.9966 | 0.3887 | 6.566 | 0.8000 | 0.1120 | 0.1059 |
| Baseline | alt ($s_0=1.2$) | 0.9966 | 0.3887 | 6.566 | 0.8000 | 0.1120 | 0.1059 |
| **PQC** | base ($s_0=0.836$) | 1.0081 | 0.3932 | 6.2641 | 0.7607 | 0.1103 | 0.1115 |
| \textcolor{revisionV1}{\textbf{PQC}} | \textcolor{revisionV1}{alt ($s_0=1.2$)} | \textcolor{revisionV1}{1.6321} | \textcolor{revisionV1}{0.6365} | \textcolor{revisionV1}{6.0762} | \textcolor{revisionV1}{0.7363} | \textcolor{revisionV1}{0.1093} | \textcolor{revisionV1}{\textbf{0.1732}} |
| PQCr | base / alt | 0.8700 | 0.3393 | 6.3271 | 0.8000 | 0.1307 | 0.0969 |
| PQCrDIFF | base / alt | 0.8143 | 0.3176 | 6.566 | 0.8000 | 0.1120 | 0.0882 |
| FirmsRation | base / alt | 1.0258 | 0.4001 | 5.8006 | 0.8000 | 0.1077 | 0.1212 |

\textcolor{revisionV1}{Raising PQC \texttt{s0} to \texttt{1.2} lifts \texttt{SD} (0.393 -> 0.637) and \texttt{AP} (1.008 -> 1.632), lowers \texttt{c} (0.761 -> 0.736) and output (6.264 -> 6.076), and raises \texttt{psi} to 0.1732 (a delta of ~0.062) --- which would make the Baseline->PQC \texttt{psi} gap clearly visible. \textbf{This was tested and then reverted:} the working tree is back at the base \texttt{s0 = 0.836} (PQC \texttt{psi = 0.1115}), and the figures are regenerated from the base spec. The \texttt{s0 = 1.2} column is thus retrospective documentation of a tried-but-reverted alternative, included so the report records what was examined.}

## Status of reported numbers

- **Baseline $AP \approx 0.99$ (paper) -- CORRECT.** Code gives 0.9966. (An earlier draft
  wrongly claimed 0.88 due to a transcription error; retracted.)
- **PQCrDIFF $AP = 0.81$, $\psi$ 0.10->0.09 (paper) -- CORRECT.** Code gives
  $AP = 0.8143$, $\psi = 0.1059 \to 0.0882$. (Earlier "wrong number" claim retracted.)
- **PQC / PQCr / FirmsRation numbers** are internally consistent with the code; no action.

## Genuine errors and inconsistencies

\textcolor{revisionV1}{\textbf{Revisiting the three items v1 listed:} the first two are \textbf{resolved}, as verified this revision; only the third (comments) remains open as a WP-readiness cleanup, and it is cosmetic rather than scientific.}

1. \textcolor{revisionV1}{\textbf{Closed-form Eq.~(5) (\texttt{teaching-note.tex:332}) -- RESOLVED (verified correct).} The file contains \texttt{AP = (s\_0+s\_2-s\_1 r)/[QA(1-\gamma)+s\_2]}, which with the real parameters evaluates to \texttt{AP = 0.99656}, matching the compiled model. The v1 claim of an algebraically wrong closed form (giving ~1.84, from a formula with an extra \texttt{(1-\gamma)} in the numerator) does not match the current text. No fix needed.}
2. \textcolor{revisionV1}{\textbf{Dual-interest-rate prose equation (\texttt{teaching-note.tex:540-562}) -- RESOLVED (rewritten additively).} Section 5.1 now writes the premium purely additively: \texttt{r\_{AP} = r + \pi} with \texttt{\pi = \theta(i\_{AP}-1)r}, and \texttt{SD = s\_0 - s\_1 r - s\_1 \pi - s\_2(AP-1)}. There is no multiplicative framing (\texttt{i\_{AP}r}, "24\% rate premium", etc.) anywhere in the section or its figure caption. At \texttt{i\_{AP}=1.2} this reproduces \texttt{AP=0.81}, \texttt{\psi 0.11\to0.09}, GDP constant.}
3. **Unclipped $c$ (formerly open) -- RESOLVED in code.** \textcolor{revisionV1}{The rule \texttt{c = c\_0 - c\_1 SD} is now wrapped in \texttt{clamp(..., 0, 1)} in both the equation and the IS/ADc curve blocks (\texttt{asset\_model.jl}), so \texttt{0 \le c \le 1} holds by construction. At PQC \texttt{c = 0.7607}, inside the range. The "parameter-space note" v1 asked for is therefore obsolete at the code level; a one-line statement in the paper that \texttt{c} is clipped would close it in the text.}

# Citations and build integrity (step 2)

\textcolor{revisionV1}{\textbf{Resolved.} A fresh citation check finds \textbf{all 23 in-text cite keys are defined} in the two \texttt{.bib} files; zero are missing. The five keys that v1 flagged as undefined (\texttt{Keynes1938HarrodLetter}, \texttt{ft2020everything}, \texttt{handwiki}, \texttt{klein2025}, \texttt{wolfsonPostKeynesianTheory1996a}) are no longer used in the tex, so \texttt{biber} will not fail on them. The garbled duplicate string at line 388 is also clean.}

- The `main.tex` / `main.typ` outlines are **stale**: they still describe "three versions"
  (PQ / PQC / PQCr) and do not reflect the five-variant code. They are planning artifacts,
  not the manuscript; either archive them or update them. \textcolor{revisionV1}{(Unchanged from v1; still open but non-blocking.)}

# Remaining authoring gaps (step 4: what is actually missing in the text)

Beyond fixing errors, the following content is needed for a complete WP. \textcolor{revisionV1}{For each gap, a drafting suggestion is given, now \textbf{including} the endogenising-\texttt{alpha} item, which v2 \textbf{re-adds} to this list (in the manuscript it stays a future-work / dynamic-track idea; this report does not implement it in the tex).}

- **Calibration note.** Where does $s_0 = 0.836089551258839$ come from? \textcolor{revisionV1}{\textit{Suggestion:} a one-paragraph statement of the normalisation (reference asset price $AP=1$, reference rate) and, if the PQC \texttt{s0} scaling is ever used, how it widens \texttt{psi}. Give the student the number and its units, not just the code default.}
- **Endogenising $\alpha$.** \textcolor{revisionV1}{\textit{Re-added to v2.} The teaching note mentions \texttt{gamma} as a turnover proxy (lines 339, 580) but never develops \texttt{alpha}-endogenisation as a result. \textit{Suggestion:} add the \textit{endogenising \texttt{\alpha}} subsection to the dynamic track (treat \texttt{\alpha} as a function of past asset prices, as sketched in \texttt{main.typ}), or move it explicitly to future work. \texttt{main.typ} lists it as a section; the current note does not. Keep it out of the static WP unless promoted to a result.}
- **Figure-caption closures (TODO line 372 or 374).** The TODO asks to spell out, in each caption,
  the underlying definitions for the curve closures. \textcolor{revisionV1}{\textit{Suggestion:} state the convention in each caption -- each curve is traced around \textit{that model's own} equilibrium, so an indirect shift (e.g. the AMD shift under PQC) is a general-equilibrium spillover, not a direct channel. The note states part of this at lines 339-340; restate it in one sentence per caption.}
- **Ad-hoc pricing limitation paragraph.** The July-11 assessment (point 2) notes
  $AP = p_1 \cdot AD/AS$ is a demand-supply ratio, not a forward-looking pricing model.
  \textcolor{revisionV1}{\textit{Suggestion:} one crisp "limitations" sentence near the asset-market section (lines 339-340) noting the price is a demand/supply-ratio closure, not forward-looking pricing.}
- **Dynamic section status.** teaching-note.tex:597-609 already frames dynamics as future
  work. Keep it that way for this WP; do not promise results the repo does not contain.
  The `main.typ` hysteresis sketch is not a result.
- **Financialization engagement in section 3.3.** \textcolor{revisionV1}{\textit{Suggestion:} link the \texttt{firms\_ap\_channel} (\texttt{d\_2}) to the financialization literature already cited (Davis 2016, Stockhammer 2004) with one or two sentences, rather than presenting \texttt{d\_2} only as a reduced-form coefficient.}

## New TODOs and NOTEs folded in from `teaching-note.tex` \textcolor{revisionV1}{\normalsize [added v2]}

| Line | Marker | Content (condensed) | Status |
|------|--------|---------------------|--------|
| 67 | \%NOTE | Consistency of "speculative markets" vs "financial markets" terminology (real estate). | open, minor |
| 123 | expand? | Whether to add top-left/top-right model variants; settled on staying with endogenous scenarios. | decided |
| 172-173 | expand? / NOTE | Interplay variant; whether liquidity preference pins \texttt{gamma} in the dynamic model. | open, dynamic track |
| 219 | expand? | Making portfolio choice explicit (expected profit vs expected price rise). | open, dynamic track |
| 270 | expand? | Whether a full (output-and-price) Taylor rule is needed; recursivity limit in the static model. | open |
| 372 | TODO | Caption definitions for closures; assignment of new deposits to households/firms. | open |
| 375 | NOTE | External reading (T\&F DOI) to review. | open |
| 378 | expand? | Whether to split out rentiers as a separate class (settled: no). | decided |
| 420 | \%todo | \texttt{psi} increase too small in rounded output. | open (base spec); resolves only under \texttt{s0=1.2} |
| 517 | \%NOTE | Possible appendix on the firm asset-holding distinction (assets not in current FlowMatrix). | open |
| 533 | \%TODO | Dual-rate storyline: rate premium vs the general policy-rate reaction (Eq. i-ap). | folded into section 5.1 fix |

# Review of the July-11 AI assessment (step 5)

The assessment (`paper/AI-assessment-July11.txt`) remains largely live:

- **IJPEE target:** still the right call given the current scope. \textcolor{revisionV1}{Cross-checked against EJHET this revision; see the outlet-evaluation section.}
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

\textcolor{revisionV1}{\textbf{Revised for v2.} Items 1-4 of v1 (closed-form equation, dual-rate equation, missing citations, garbled string) are resolved and removed from the blocking list. The revised list is:}

Must fix before circulation (blocking):

1. \textcolor{revisionV1}{Strip the leftover author-comment blocks (\texttt{\%NOTE}/\texttt{\%TODO}/\texttt{expand?} at lines 67, 123, 172-173, 219, 270, 372, 375, 378, 420, 517, 533) from the source before circulation. (v1 item 4, still open.)}
2. \textcolor{revisionV1}{Optionally add a one-sentence statement in the text that \texttt{c} is clipped to \texttt{[0,1]} in the code, to close the v1 "parameter-space" concern at the level of the manuscript.}

Should fix for a complete WP:

3. Add the calibration note for $s_0$ and the asset-market normalisation.
4. Close the figure-caption TODO (line 372) with the own-equilibrium tracing convention.
5. Add a one-paragraph limitations note on the ad-hoc asset pricing.
6. Add the endogenising-$\alpha$ subsection to the dynamic track, or state explicitly that it stays future work. \textcolor{revisionV1}{(Re-added to the list in v2.)}

Nice to have (post-WP / JPKE path):

7. Formalise the turnover multiplier as a derived result.
8. Deepen engagement with the financialization/SFC/Minsky literature in section 3.
9. Promote the dynamic model from sketch to result only in a follow-up paper.

\textcolor{revisionV1}{\textbf{Working-tree notes (v2):} the compiled model is reverted to the base specification (\texttt{s0 = 0.836}); the \texttt{s0 = 1.2} PQC values are retrospective. Regenerated figures reflect the base spec. The \texttt{Manifest.toml} is the 1.12.7 content; cleaner version-numbered manifests (\texttt{Manifest-1.12.1.toml}, \texttt{Manifest-1.12.7.toml}) are available. All figures were regenerated under Julia 1.12.7 (warm depot).}
## Revision Log

- **Version 1** (2026-09-13) --- Original five-step readiness report (scope, numerical verification, citations, authoring gaps, July-11 assessment review, action list).
- **Version 2** \textcolor{revisionV1}{(2026-09-13)} --- Verifies that the citation/reference errors and the garbled string reported in v1 are already resolved; verifies the closed-form Eq.~(5) is algebraically correct; rewrites section 5.1 so the dual-rate premium is expressed purely additively; implements c-clipping in the code; adds an EJHET outlet evaluation; documents a test of PQC `s0 = 1.2` (later reverted); collapses the citations and authoring-gap sections; folds in TODOs/NOTEs from the tex; re-adds the endogenising-`alpha` item as a suggestion.
