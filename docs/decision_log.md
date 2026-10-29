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