# Interview guide: Option Pricing Engine

For my own preparation. Every number here comes from the project, and the
chapter or phase it came from is in `docs/`. If something here is not true for
me, I change the guide, not my answer.

## 30-second pitch

I built an option pricing engine in R. It prices options three independent ways,
a binomial tree, the Black-Scholes formula and Monte Carlo simulation, and checks
them against each other. Then I used it on a problem an insurer faces: the
minimum-return guarantee on a segregated fund is really a put option the insurer
has sold. I priced it, solved for the fair fee, simulated a delta hedge, and
sized a tail reserve. I also tested the models on real Tesla option data, and
packaged everything in a Shiny app and a written report.

## 2-minute walkthrough

1. **The idea.** An option's price comes from replication: a portfolio of the
   stock and borrowed cash that pays exactly what the option pays. So the price
   does not depend on where the stock is heading.
2. **Three methods that check each other.** The tree handles American options,
   the formula is exact for European ones and gives the Greeks, and Monte Carlo
   handles path-dependent products and the guarantee. For the same call they
   gave 9.2231 (tree, 500 steps), 9.2270 (formula) and 9.2553 (simulation, with
   an error bar of 0.018). Put-call parity held to rounding error on all of them.
3. **Real data.** I pulled Tesla options and found that most quotes were
   unusable, and that the downloaded stock price did not match the price the
   options were quoted at. Put-call parity exposed that. Implied volatility
   showed a smile: about 55% at the lowest strikes, about 42% at the highest. One
   volatility cannot match that.
4. **The insurance application.** The guarantee costs about 13.8 per 100
   invested if the policy lasts 10 years, and about 8.1 once mortality and
   lapses are included. The fee that covers it is about 0.79% a year, out of a
   2.5% fee.
5. **Risk.** A weekly delta hedge removed about 95% of the risk. A CTE95 reserve
   came to about 38.6 per 100 without mortality and lapses and 21.6 with them,
   far above the price, because the price and the reserve answer different
   questions.
6. **Honesty about limits.** Many inputs are assumptions, the results are
   sensitive to them, and I list the mistakes I found along the way.

## Numbers to remember

| What | Number |
|---|---|
| Call, Black-Scholes (stock 100, strike 100, rate 5%, dividend yield 2%, volatility 20%, 1 year) | 9.2270 |
| Put, same inputs | 6.3301 |
| Call, tree with 50 steps and 500 steps | 9.1882 and 9.2231 |
| American put, tree with 50 steps | 6.6415 (European put 6.2913) |
| Call, Monte Carlo with a control variate | 9.2553, standard error 0.018 |
| Error reduction against plain Monte Carlo | control variate about 59%, antithetic about 26% |
| Parity check on the tree | difference about 1e-13 |
| Seg fund guarantee, cost per 100 (10 years, rate 3.8%, volatility 20%) | 13.77; 8.08 with mortality and lapses |
| Chance still in force at year 10 | 0.5869 (alive 0.9803, not lapsed 0.5987) |
| Fair yearly fee for the guarantee alone | 0.79% (income 17.4 against cost 8.1 at the product's 2.5%) |
| Hedge error SD, weekly | 0.98 against 18.3 unhedged (about 95% removed) |
| Hedge error SD, monthly, weekly, daily | 2.05, 0.96, 0.43 |
| CTE95 reserve per 100 sold | 38.6 without mortality and lapses, 21.6 with |
| Rate sensitivity of the guarantee cost | one point of rate moves it by about 3 to 4 (25% to 30%) |
| Tesla, January 2027 options, saved 2026-11-02 | implied about 44%; historical 36% (30 days), 51% (90 days), 45% (1 year) |
| Live Canada 10-year yield | 3.74% on 2026-11-02 |

## Likely questions

**Q1. What is a put option, and why is a seg fund guarantee one?**
A put is the right to sell at a fixed price. The guarantee says I get the larger
of the fund value and 100 at maturity, so the insurer pays the shortfall, the
larger of (100 minus the fund) and zero. That is a put payoff on the fund with a
strike of 100, and the insurer has sold it. The fee leaves the fund continuously,
like a dividend, so Black-Scholes with the fee as the dividend yield prices it.

**Q2. Why doesn't the option price depend on where the stock is going?**
Replication. I can build a portfolio of stock and borrowed cash that pays what
the option pays in every outcome, so the option must cost what that portfolio
costs, or there is arbitrage. In my one-step example the call is 6.67 whether
the chance of "up" is 10% or 90%. The price is the cost of the exposure, not a
forecast.

**Q3. What is a risk-neutral probability?**
The probability that makes the stock's expected growth equal the interest rate
(less the dividend yield). It is a calculating device that lets me discount at
the interest rate. It is not a prediction. The real-world growth rate is used
only for hedging and reserves.

**Q4. Why three pricing methods?**
Each has a strength. The tree handles American options, the formula is exact for
European options and gives the Greeks, and Monte Carlo handles path-dependent
options and the seg fund. They also check each other: the tree converges to the
formula, the simulation's interval contains it, and for the seg fund the formula
(13.77) and the simulation (13.78) agree.

**Q5. What is put-call parity, and how did you use it?**
Call minus put equals the stock (discounted for dividends) minus the strike
(discounted for interest), for European options with the same strike and expiry.
It uses no model, so it checks every pricer: the tree satisfies it to about 1e-13.
I also used it to back out the stock price the options market was using, which
differed from the downloaded close. It does not hold for American options.

**Q6. Why does an American put cost more than a European put, but not a
no-dividend call?**
A put can pay at most the strike, so after a crash waiting adds little while
cash earns interest. A call with no dividends gains nothing from early use,
costs interest on the strike, and gives up the downside protection. In the tree
the American put was 6.6415 against 6.2913, and the American call equalled the
European call.

**Q7. What does the hedge do, and what doesn't it do?**
Each week the insurer holds the put's delta of the market, plus cash. The
average error was about zero and the error SD fell from 18.3 to 0.98. It does
not remove everything: weekly rebalancing leaves error that shrinks with the
square root of the number of hedges, a wrong volatility would hurt, and I ignored
transaction costs.

**Q8. What is the difference between the price and the reserve?**
The price is the risk-neutral value of the promise, 13.77 per 100 if the policy
lasts. The reserve is capital for a bad market, computed in the real world from
the worst outcomes, 38.6 per 100 without mortality and lapses. They answer
different questions with different probability measures.

**Q9. What is CTE95?**
The average loss across the worst 5% of outcomes. Here the loss on each path is
the present value of the guarantee payout minus the present value of guarantee
fees collected on it. It rests on 5,000 paths, so the worst 5% is the worst 250,
which is noisy. It is an illustration of a tail measure. I have not checked the
regulatory formula.

**Q10. How did you find the fair fee?**
The fee appears on both sides: more income, but it also drags the fund down and
makes the guarantee costlier. So there is no formula, and `uniroot()` finds the
fee where the present value of fee income equals the cost. It came to about
0.79% a year. It treats the whole fee as the guarantee charge, which is a
simplification.

**Q11. How do mortality and lapses enter?**
The payout happens only if the policyholder is alive and still in the contract at
year 10. Survival uses Gompertz-Makeham with parameters from my course notes:
98.0% survive 10 years from age 50. Persistency at a 5% lapse rate is 59.9%.
Together, 58.7%, so the cost falls from 13.77 to 8.08. Lapses matter far more
than deaths. I assumed they are independent of the market, which probably
understates the cost.

**Q12. What is implied volatility, and what is the smile?**
The volatility that makes Black-Scholes reproduce a market price, found by a
numeric search. If Black-Scholes were exact, every strike would give the same
number. For Tesla, low-strike puts were about 55% and high-strike calls about
42%: the market charges more for crash protection. One volatility cannot match
that, which is why the model-versus-market gaps were positive for puts and
negative for calls.

**Q13. Is a Tesla option cheap or expensive?**
It depends on the comparison. Implied near the money was about 44%, above the
calm last month (36%), below the wild last quarter (51%), and about equal to the
year (45%). Historical volatility looks backward and the market looks forward.
It is a comparison, not advice.

**Q14. Why use the Canada 10-year yield?**
It is a stand-in for a risk-free rate that matches the 10-year term of the
guarantee. It is an official Bank of Canada series (3.74% on 2026-11-02, fetched
live in the app). It is an assumption. I have not checked what insurers
actually use.

**Q15. How sensitive is the guarantee cost to your assumptions?**
Very. One point of interest rate moves it by 3 to 4, about 25% to 30%. Across
the grid I tried, the cost ran from about 4 to about 31. The reserve is also
sensitive to the expected return: 45.6, 38.6 and 32.6 for 4%, 7% and 9%.

**Q16. How does Monte Carlo error work, and what do variance reduction methods
do?**
The standard error is the spread of the payoffs divided by the square root of
the number of simulations, so halving it takes four times as many. Antithetic
variates use each random draw and its mirror, with the error computed from the
pair averages. Control variates use the stock's known average to correct the
estimate. I confirmed the error bars were honest by repeating the experiment 200
times and counting how often the interval caught the exact price, about 95%.

**Q17. What mistake did you find?**
Two I like. An Asian option with one monitoring step must equal the plain call.
It did not: R had flattened a one-column matrix and collapsed all paths into one
number. The normal tests had passed. And my barrier correction had the wrong
sign: the unadjusted simulation was 8.06, the wrong sign gave 8.42, and the
exact formula (7.587) showed the right sign gives 7.59.

**Q18. What are the weaknesses of your model?**
Constant volatility, when real options show a smile. Black-Scholes on American
options. Lapses independent of the market, and a large pool with no random
variation in deaths and lapses. The whole fee treated as the guarantee charge.
No transaction costs. Placeholder inputs: 20% volatility, 7% expected return,
5% lapses. A reserve that is not the regulatory formula. Yahoo data that can lag
by a day.

**Q19. What would you do next?**
Add a model that produces a smile, such as stochastic volatility, which I have
not built. Make lapses depend on how far the guarantee is in the money. Use a
real mortality table. Add transaction costs. Look up the regulatory capital
formula. Remove the duplicated functions between the engine file and the phase
scripts. Check the formulas I wrote from memory against their sources.

**Q20. How did you use AI?**
I built it step by step with an AI assistant. Each step was a small piece of
code with a test, and I ran each one and checked its output. Its predictions
were sometimes wrong, and running the code caught them. Every decision is in
`docs/decision_log.md`. I need to be able to explain any piece of it myself.

## Honest weaknesses

- **Do not claim** the app is published online. It is not.
- **Do not claim** the reserve is the regulatory capital. It is an illustration.
- **Do not claim** the seg fund inputs are real data. Volatility, expected
  return and lapse rate are assumptions.
- **Do not claim** I read the Black-Scholes or Cox-Ross-Rubinstein papers. I did
  not. `docs/sources.md` says which formulas I wrote from memory.
- **Do not claim** the down-and-out barrier formula was checked against a source.
  It agrees with the simulation, and that is all I can say.
- **Say plainly** that the Market tab was only tried on Tesla, and on one other
  ticker briefly, so I have not tested it widely.
- **Say plainly** that Black-Scholes is a European formula and Tesla's options
  are American, and that I did not measure the difference.

## If I am asked something I do not know

1. Say what I do know that is closest.
2. Say what I would check, and where.
3. Do not guess a number.

For example: "I haven't looked at how insurers set that. In my model I used the
Canada 10-year yield and showed how much the answer moves with it."

## Practice

- Say the 30-second pitch out loud with a timer.
- Pick five questions at random and answer them without reading.
- Re-read the report's chapter 10 (mistakes). They are the best stories.