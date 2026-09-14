---
title: "Turnover multiplier: novelty assessment and reframing draft (working note)"
author: "Hermes (statistics profile)"
date: "2026-09-13"
tags: [working-note, PKAssetPrices, turnover-multiplier, novelty, JPKE, EJHET]
project: "PKAsset Model / MoneyModel PKAssetPrices"
---

# Purpose

Working note for the author, discussing whether the "turnover multiplier"
`1/(1-gamma)` (from `AE = SD/(1-gamma)` in the asset-market block) is a defensibly
novel theoretical contribution, and how to frame it if we want to re-aim the note at
EJHET / ROKE / JPKE. This is a discussion document, not paper text; nothing here has
been written into `teaching-note.tex`.

# The ingredient, stated precisely

New speculative debt `SD` buys assets. Sellers spend a share `gamma` of receipts on
further asset purchases within the period; repeated recycling produces gross asset
expenditure

    AE = SD / (1 - gamma),      AP = p1 * AE / AS.

Three jointly-distinct ingredients:

1. Endogenous bank money finances the purchase: `dL = cD + SD`, `dM = dL`.
2. `gamma` is a turnover/velocity parameter on the *secondary* asset market (the
   share of sale receipts reinvested within the period).
3. `1/(1-gamma)` is an explicit multiplier coupling money creation to gross
   speculative spending.

# What it is NOT (checked against the literature)

- Not `turnover` as a liquidity/efficiency statistic (Lagos-Zhang AER "Turnover,
  Liquidity and Monetary Transmission"; market micro-structure volume work). Those
  use turnover as a property of the market, not as a structural amplifier inside a
  money loop.
- Not the Gabaix-Koijen (2021) "inelastic markets" / price-impact multiplier, nor the
  newer aggregation-level price-multiplier results. Those are demand-shock-to-price
  impact multipliers; they contain no bank-credit creation and no reinvestment loop.
- Not Harrison-Kreps / Scheinkman-Xiong (resale option / speculative volume):
  turnover matters there, but there is no endogenous money creation.
- Not Minsky: debtor *leverage* (hedge/speculative/Ponzi), not secondary-market
  turnover.
- Not the Treatise itself: it has the *idea* of a financial circulation that can
  expand independently of the industrial circulation (and Keynes discusses velocity),
  but no multiplier formalisation. The paper's own marginalia flag this lineage.

# Closest living cousin (and best bridge, not competitor)

Recent empirical financial-economics work distinguishes **gross** from **net** trading
volume:

- Chicago Booth "Rethinking Volume" (2025): gross equity volume quintupled since 1980;
  **net** volume roughly unchanged; gross-to-net ratio rose from ~5x to ~25x. Round-trip
  trading (buys netting to zero) improves *high-frequency* liquidity but cannot absorb
  *persistent* demand shifts.
- Gabaix-Koijen (2021) inelastic-markets multiplier (M ~ 5) is explained precisely by
  how small net volume is relative to gross.

Our `gamma` is a **structural macro formalisation of that gross-over-net gap**: a trade
that is a buy for one agent and a sell for their counterparty (gross), which nets to zero
in a flow sense, still requires money to *transact*, and through `1/(1-gamma)` inflates
gross asset expenditure relative to the net credit injected. This converts the standard
objection "this is just velocity / churn" into a strength: the model gives a
macro-theoretic reason why financial circulation can be a multiple of net money creation.

# Novelty verdict (honest confidence)

- Exact `1/(1-gamma)` credit-finance + reinvestment multiplier as a formal macro
  ingredient: ~70% novel.
- Risk a referee says "velocity / reinvestment with new notation": ~50%. Mitigation =
  the gross/net-volume bridge above, plus the joint endogeneity of money and turnover.

# Reframing options

- **IJPEE (status quo):** turnover multiplier stays a nice-to-have; code/figures carry
  the pedagogical value. No change needed.
- **EJHET:** frame as a *reconstruction*: the model converts the Treatise's
  financial-circulation / velocity intuition into an explicit multiplier, and shows the
  private-vs-public channel split. History-of-thought payoff, formalisation is the result.
- **JPKE / ROKE:** promote the turnover multiplier (jointly endogenous money + turnover,
  gross-vs-net bridge) to the *primary theoretical contribution*; the dynamic model
  would need to carry it further (endogenise `alpha`, hysteresis).

# Next steps (for discussion, nothing edited yet)

- Decide target journal (drives how much the turnover multiplier is foregrounded).
- Whether to add the gross-vs-net-volume citation bridge into the manuscript.
- Whether the two-private / two-public channel-split paragraph (verified: PQC +
  FirmsRation both raise AP/psi; PQCr + PQCrDIFF both lower them) becomes a new
  contribution paragraph.
