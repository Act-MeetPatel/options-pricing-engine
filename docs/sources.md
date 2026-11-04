# Sources and assumptions

## References used

| Used for | Source | Status |
|---|---|---|
| Black-Scholes derivation, risk-neutral pricing, notation (Phase 3) | Marchesi, P., "Black-Scholes From Scratch" (slides, Oct 2026) | Verified: formula matches the tree and Monte Carlo |
| Binomial tree (Phase 2) | Cox, Ross and Rubinstein (1979), "Option pricing: a simplified approach", Journal of Financial Economics | Verified: converges to Black-Scholes |
| Black-Scholes formula | Black and Scholes (1973), Journal of Political Economy | Verified |
| Gompertz-Makeham mortality (A = 0.00022, B = 0.0000027, C = 1.124) | ACT 3130 course notes | Parameters taken from course notes; not checked against a published table |
| Barrier shift 0.5826 | Broadie, Glasserman and Kou (1997), "A continuity correction for discrete barrier options", Mathematical Finance | Constant recalled from memory; result confirmed by the exact formula |
| Down-and-out call formula (Phase 4) | Standard continuous-barrier result (for example Hull, "Options, Futures, and Other Derivatives") | Typed from memory; confirmed by simulation, but page reference not yet checked |

## Data

| Item | Source | Date |
|---|---|---|
| TSLA prices and option chain | Yahoo Finance via the `quantmod` R package | Pulled 2026-11-02; chain saved in `data/` |
| Canada 10-year yield, 3.8% | Trading Economics news summary (tradingeconomics.com/canada/government-bond-yield), which reports Bank of Canada data | About mid-October 2026 (3.79% on 2026-10-15) |
| Canada 10-year yield, 3.94% (context only) | Bank of Canada via statisticsoftheworld.com | Close of 2026-09-10 |

## Placeholder assumptions (not facts)

- Phase 5: r = 4% (placeholder, never replaced, by choice).
- Phase 6: sigma = 20%, fee 2.5%, lapse 5%, issue age 50, guarantee 100%, term 10 years.
- Phase 6: r = 3.8% is a rounded value from a news summary, not the official Bank of Canada series and not today's close.
- Mortality and lapses are assumed independent of each other and of the market.