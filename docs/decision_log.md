# Decision Log

| # | Step | Decision | Code | Why | Other notes |
|---|------|----------|------|-----|-------------|
| 1 | P1 setup | Public repo with R .gitignore and MIT license | Chosen at repo creation | Portfolio piece; recruiters recognise MIT | `.DS_Store`, `.quarto/`, `*_files/` added to .gitignore |
| 2 | P1 setup | Folders: r, data, outputs, docs, app | `.gitkeep` in each | Git doesn't track empty folders | Delete a `.gitkeep` once its folder has real files |
| 3 | P1 setup | Use an RStudio Project | `.Rproj` file | Fixes the working directory to the repo | Paths stay short, like `r/01_payoffs.R` |
| 4 | P1 S6 | Payoff uses `pmax()`, not `max()` | `option_payoff()` | Works on a whole vector of prices at once | `stop()` catches typos like "Call" |
| 5 | P1 S7 | Save plots from code, not by clicking | `png()` ... `dev.off()` | Plots regenerate identically | Forgetting `dev.off()` leaves an empty file |
| 6 | P1 S8 | Keep spread and straddle (your choice) | `bull_spread`, `straddle` | Show any position is a sum of payoffs | Illustrative only; no later phase uses them |
| 7 | P1 S9 | Parity check returns lhs, rhs, diff, holds | `check_parity()` | See how big a failure is | Tolerance 1e-8; loosen for Monte Carlo |
| 8 | P1 S9 | Correct test value for P | `P <- C - (S*exp(-q*T) - K*exp(-r*T))` | My first answer (7.0796) was wrong | Correct value is 7.103075 |
| 9 | P1 S10 | Bounds check uses `max()`, not `pmax()` | `check_bounds()` | Inputs are single numbers | American put upper bound is K, not discounted |
| 10 | P1 close | Remove `docs/` line from .gitignore | Deleted line 43 | It was hiding our phase docs | Found with `git check-ignore -v` |
| 11 | P1 close | One commit per phase, written phase doc | `docs/phase1.md` | Clean history | Message: "Phase 1: payoffs, parity, and no-arbitrage bounds" |
| 12 | P2 S1 | Use CRR tree: u = exp(sigma*sqrt(dt)), d = 1/u | `crr_params()` | d = 1/u makes the tree recombine, so N+1 endpoints, not 2^N | p is risk-neutral, not a forecast |
| 13 | P2 S1 | Stop if p is outside 0 to 1 | `if (p <= 0 \|\| p >= 1) stop(...)` | A bad p gives nonsense prices | My sigma = 3 test did not trigger it; my mistake |
| 14 | P2 S2 | Compute all endpoints as one vector | `S * u^j * d^(N-j)`, `j <- 0:N` | Only the number of up-moves matters | Middle node returns exactly S |
| 15 | P2 S3 | Reuse Phase 1 payoff at expiry | `terminal_values()`, `source("r/01_payoffs.R")` | At expiry, value = payoff | `1.4e-14` instead of 0 is floating-point noise |
| 16 | P2 S3 | Hand-check was my error | u = 1.1 with d = 1/1.1 | I used d = 0.9 by mistake | Put value 17.355 was correct |
| 17 | P2 S4 | Backward induction with vector shifts | `V[-1]` (up), `V[-length(V)]` (down) | Each pass shrinks V by one until 1 value remains | Loop `N:1` |
| 18 | P2 S4 | Validate with parity, not a guessed price | `check_parity()` on tree prices | Parity is model-free | Call 9.188225, put 6.2913, diff -1.29e-13 |
| 19 | P2 S5 | Add `american` switch, default FALSE | `binomial_price()` | FALSE must match Step 4 (regression test) | Loop `(N-1):0` so `i` is the step number |
| 20 | P2 S5 | Early exercise via `pmax(hold, exercise)` | `pmax()` | Compare node by node | Reuses `terminal_prices(..., i)` for node prices |
| 21 | P2 S5 | Results | American put 6.641549 | Higher than European 6.2913, as expected | American call (q=2%) = 9.188225, same as European. My prediction was wrong |
| 22 | P2 S5 | q = 0 check | Call 10.41069, both types | Early exercise never helps a no-dividend call | Parity doesn't apply to American options |
| 23 | Process | Work one small step at a time | n/a | You learn at your pace | I wait for "next" |
| 24 | Process | Use RStudio only; Git tab for git | n/a | Your preference | No Terminal |
| 25 | Process | Short, simple answers | n/a | Your preference | Decision log updated every step |
| 26 | P2 S5 | Keep `docs/.gitkeep` | none | Your choice; it does no harm | Earlier advice to delete it was optional |
| 27 | P2 S6 | Convergence plot, N = 10 to 500 by 10 | `sapply(N_values, ...)` | Shows price settling as steps increase | Wobble not seen: only even N used |
| 28 | P2 S6 | Save convergence plot from code | `png()` ... `dev.off()` | Regenerates identically | File: `outputs/binomial_convergence.png` |
| 29 | P2 S6 | Skip the early exercise check | none | Your choice; optional | Can revisit later |
| 30 | P2 S7 | Write `docs/phase2.md` | none | Same pattern as Phase 1 | Includes the mistakes I made |
| 31 | P2 S8 | One commit closes Phase 2 | Git tab | Clean history | Message: "Phase 2: American exercise, convergence plot, write-up" |
| 32 | P3 prep | Use the Marchesi slides as the Black-Scholes reference | none | Your source | Slides assume q = 0; our code adds q |
| 33 | P3 S1 | Code d1, d2 first, with dividend yield q | `bs_d()` | Price and Greeks all use them | Hand-checked: d1 = 0.25, d2 = 0.05 |
| 34 | P3 S2 | Closed-form price with q; T = 0 returns the payoff | `bs_price()` | Avoids divide-by-zero; reuses `option_payoff()` | Slides' formula is the q = 0 case |
| 35 | P3 S2 | Four tests: call, put, parity, T = 0 | `bs_price()` | Parity is the strong check | Parity can't catch a shared error like wrong d1 |
| 36 | P3 S2 | Re-explained `bs_price()` by inputs | none | Your request: simpler | Call = "what you get" − "what you pay" |
| 37 | P3 S1 | Re-explained `bs_d()` by inputs | none | Your request: simpler | d1 = distance ahead ÷ usual move |
| 38 | P3 | Sigma = 0.2 stays a made-up example | none | Real sigma comes from data later | Historical: Phase 5a. Implied: Phase 3 end |
| 39 | P3 S3 | Measure the tree's error against Black-Scholes | `tree_error <- conv_call - bs_call` | Independent check of d1 and d2 | Error shrinks as N grows |
| 40 | P3 S3 | Re-explained the tree vs. Black-Scholes check | none | Your request: simpler | Two independent methods agreeing is our proof |
| 41 | P3 S4 | Code delta with q; check by bumping S | `bs_delta()` | Bump check is independent of the formula | Call 0.5869, put -0.3933 |
| 42 | P3 S4 | Re-explained the 3 delta tests | none | Your request: simpler | Test 3 (bump) is the real proof |
| 43 | P3 S4 | Explained put delta for a $1 drop | none | Your question | Put gains about $0.39; delta moves toward -1 |
| 44 | P3 S4 | Explained the sign of put delta | none | Your question | Sign = direction, not good/bad |
| 45 | P3 S4 | Put delta is never positive | none | Your question | Range -1 to 0 |
| 46 | P3 S4 | Delta is not a buy/sell signal | none | Your question | Sensitivity and hedge ratio only |
| 47 | P3 S4 | Defined ITM, ATM, OTM, "deep" | none | Your question | Deep = far from the strike |
| 48 | P3 S4 | ITM/OTM is not good/bad | none | Your question | ITM costs more; OTM needs a bigger move |
| 49 | P3 S4 | Why a put writer accepts buying at K | none | Your question | Writer is paid the premium upfront |
| 50 | P3 S4 | Who trades the other side | none | Your question | Exchange, market maker, clearing house |
| 51 | P3 S5 | Gamma, no `type` input; check by bumping delta | `bs_gamma()` | Call and put share gamma | Expected 0.0190 |
| 52 | P3 S6 | Vega per 1 vol point; check by bumping sigma | `bs_vega()` | Traders quote per point | Expected 0.3814 |
| 53 | P3 S6 | Vega for a volatility fall | none | Your question | Same vega, opposite effect |
| 54 | P3 S6 | Greeks measure risk, not worth | none | Your question | Worth = view + price vs. fair value + break-even |
| 55 | P3 S7 | Theta per calendar day; check by bumping T | `bs_theta()` | Traders quote daily decay | Call -0.0139, put -0.0063 |
| 56 | P3 S7 | Sign rules for delta and theta | none | Your question | Theta usually negative for long options |
| 57 | P3 S7 | Is theta always negative | none | Your question | Deep ITM European puts can be positive |
| 58 | P3 S7 | Defined long and short | none | Your question | All Greeks flip sign when short |
| 59 | P3 S7 | How an insurer is short a put | none | Your question | Option is embedded in the contract |
| 60 | P3 S8 | Rho per 1 rate point; check by bumping r | `bs_rho()` | Traders quote per point | Call 0.4945, put -0.4578 |
| 61 | P3 doc | Phase 3 doc gets a newbie Greeks section | none | Your request | Definition, example, sign, use, glossary |
| 62 | P3 S9 | Implied vol via `uniroot()`; `NA` if out of bounds or search fails | `bs_implied_vol()` | No formula exists; bad quotes must not crash Phase 5 | Round trip: price at 0.25, recover 0.25 |
| 63 | P3 S9 | Explained the bad-price test | none | Your question | Impossible price returns `NA` |
| 64 | P3 S10 | Save tree vs. Black-Scholes plot from code | `png()` ... `dev.off()` | Regenerates identically | File: `outputs/tree_vs_black_scholes.png` |
| 65 | P3 S11 | Write `docs/phase3.md` | none | Your request | Includes glossary, units, bump-check explanation |
| 66 | P3 S12 | One commit closes Phase 3 | Git tab | Clean history | Message: "Phase 3: Black-Scholes, Greeks, implied volatility" |
| 67 | Process | After every step I tell you to paste the log row | none | I forgot to tell you for rows 27-66 | Your log was 25 rows behind until now |