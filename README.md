# Option Pricing Engine

Option pricing in R, three independent ways (binomial tree, Black-Scholes and
Monte Carlo), checked against each other, tested on real Tesla option data, and
applied to a segregated fund guarantee, which is a put option the insurer has
sold. It ends in a three-tab Shiny app and a written report.

**Report:** https://act-meetpatel.github.io/options-pricing-engine/
The report is also in this repo as a single file, `docs/index.html`.

## What it does

- **Pricing.** European and American calls and puts by a binomial tree,
  European options by Black-Scholes, and Monte Carlo with two variance
  reduction methods. Asian and barrier options by simulation.
- **Checks.** Put-call parity, no-arbitrage bounds, every Greek compared with a
  direct nudge calculation, the tree against the formula, the formula against a
  simulation, and an exact barrier formula against the simulated barrier price.
- **Market data.** Historical volatility, a cleaned option chain, implied
  volatility and the volatility smile for any ticker Yahoo Finance has options
  for, and a comparison of model prices with market prices.
- **Seg fund guarantee.** The price of the guarantee, mortality and lapses, the
  fair fee, a delta hedge and a CTE reserve, with every assumption an input.

## Key results

All examples use stock 100, strike 100, rate 5%, dividend yield 2%, volatility
20%, one year, unless stated.

| Result | Value |
|---|---|
| European call, Black-Scholes | 9.2270 |
| European put, Black-Scholes | 6.3301 |
| Call, tree with 50 steps | 9.1882 (9.2231 with 500 steps) |
| American put, tree with 50 steps | 6.6415 |
| Call, Monte Carlo with a control variate | 9.2553 (standard error 0.018) |
| Seg fund guarantee, cost per 100 invested (10 years, rate 3.8%) | 13.77; 8.08 with mortality and lapses |
| Fair yearly fee for the guarantee alone | 0.79% |
| Weekly delta hedge | removes about 95% of the risk |
| Reserve (CTE95) per 100 sold | 38.6 without, 21.6 with mortality and lapses |

Tesla, January 2027 options, saved 2026-11-02: implied volatility near the money
was about 44%, against 36%, 51% and 45% historical (30 days, 90 days, about a
year). A single volatility cannot match the volatility smile.

Most of the seg fund inputs are assumptions, not data (volatility, expected
return, lapse rate). The results move a lot with them.

## How it is organized

| Folder | Contents |
|---|---|
| `r/` | One script per phase (`01_payoffs.R` to `06_seg_fund.R`) and `engine.R`, the functions the app and the report call |
| `app/` | `app.R`, the Shiny app, and `toy_app.R`, a small first exercise |
| `docs/` | A write-up for each phase, `decision_log.md`, `sources.md`, and the report (`report.qmd`, rendered to `index.html`) |
| `data/` | A saved Tesla option chain, used by the report |
| `outputs/` | Plots and the app screenshots |

## How to run it

1. Install R and RStudio.
2. In R, install the packages:
   `install.packages(c("shiny", "bslib", "jsonlite", "quantmod"))`
3. Open `options-pricing-engine.Rproj` in RStudio.
4. **App:** open `app/app.R` and click **Run App**. The Market tab and the live
   interest rate need internet.
5. **Report:** open `docs/report.qmd` and click **Render**. It uses the Quarto
   that comes with RStudio.
6. **Phase scripts:** run them in numbered order. Every simulation uses
   `set.seed(3130)`, so the numbers repeat.

**Warning about `r/05_market_data.R`.** It downloads fresh data and overwrites
the saved snapshot in `data/` and the Phase 5 plots every time it runs. The
report uses that snapshot, so run the script only if you want to replace it.

## Limits

- Black-Scholes is a formula for European options, and Tesla's options are
  American. I did not measure the difference.
- The volatility is a single constant in the models. Real options show a smile.
- In the seg fund model, lapses are independent of the market and the pool of
  policies is large. Both are assumptions, and both probably understate the
  cost.
- The CTE reserve is an illustration of a tail measure, not the regulatory
  formula.
- Some formulas were written from memory and are marked in `docs/sources.md`.
- The app's functions were copied into `engine.R` and the phase scripts were
  left as they were, so the same function can exist in two places. The known
  differences are listed in `docs/phase7.md`.
- Yahoo Finance data can lag by a day.

## How this was built

I built this step by step with an AI assistant (Claude, by Anthropic). Every
step was a small piece of code with a test, and I ran each one and checked its
output. Every decision, including the mistakes and corrections, is recorded in
`docs/decision_log.md`.

## Sources

See `docs/sources.md`.

## License

MIT. See `LICENSE`.

## Author

Meet Patel