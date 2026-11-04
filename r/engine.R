# ---------------------------------------------------------------
# engine.R
# Functions only (no plots, no loops that run on load).
# Copied from the phase scripts; the phase scripts are unchanged.
# ---------------------------------------------------------------

# --- Phase 1: payoffs, parity, bounds --------------------------
option_payoff <- function(S_T, K, type = "call") {
  if (!type %in% c("call", "put")) stop("type must be either 'call' or 'put'")
  if (type == "call") pmax(S_T - K, 0) else pmax(K - S_T, 0)
}

check_parity <- function(C, P, S, K, r, q, T, tol = 1e-8) {
  lhs  <- C - P
  rhs  <- S * exp(-q * T) - K * exp(-r * T)
  diff <- lhs - rhs
  list(lhs = lhs, rhs = rhs, diff = diff, holds = abs(diff) < tol)
}

check_bounds <- function(price, S, K, r, q, T, type = "call",
                         american = FALSE) {
  if (!type %in% c("call", "put")) stop("type must be either 'call' or 'put'")
  if (type == "call") {
    lower <- max(S * exp(-q * T) - K * exp(-r * T), 0)
    upper <- S * exp(-q * T)
  } else {
    lower <- max(K * exp(-r * T) - S * exp(-q * T), 0)
    upper <- if (american) K else K * exp(-r * T)
  }
  list(lower = lower, upper = upper,
       within_bounds = price >= lower & price <= upper)
}

# --- Phase 2: binomial tree ------------------------------------
crr_params <- function(sigma, r, q, T, N) {
  dt <- T / N
  u  <- exp(sigma * sqrt(dt))
  d  <- 1 / u
  p  <- (exp((r - q) * dt) - d) / (u - d)
  if (p <= 0 || p >= 1) {
    stop("Invalid risk-neutral probability (p = ", round(p, 4),
         "). Try increasing N or check sigma/r/q/T.")
  }
  list(dt = dt, u = u, d = d, p = p)
}

terminal_prices <- function(S, u, d, N) {
  j <- 0:N
  S * u^j * d^(N - j)
}

terminal_values <- function(S, u, d, N, K, type = "call") {
  option_payoff(terminal_prices(S, u, d, N), K, type)
}

binomial_price <- function(S, K, r, q, sigma, T, N, type = "call",
                           american = FALSE) {
  cp <- crr_params(sigma, r, q, T, N)
  V  <- terminal_values(S, cp$u, cp$d, N, K, type)
  for (i in (N - 1):0) {
    hold <- exp(-r * cp$dt) * (cp$p * V[-1] + (1 - cp$p) * V[-length(V)])
    if (american) {
      exercise <- option_payoff(terminal_prices(S, cp$u, cp$d, i), K, type)
      V <- pmax(hold, exercise)
    } else {
      V <- hold
    }
  }
  V
}

# --- Phase 3: Black-Scholes, Greeks, implied volatility --------
bs_d <- function(S, K, r, q, sigma, T) {
  d1 <- (log(S / K) + (r - q + 0.5 * sigma^2) * T) / (sigma * sqrt(T))
  list(d1 = d1, d2 = d1 - sigma * sqrt(T))
}

bs_price <- function(S, K, r, q, sigma, T, type = "call") {
  if (!type %in% c("call", "put")) stop("type must be either 'call' or 'put'")
  if (T == 0) return(option_payoff(S, K, type))
  d <- bs_d(S, K, r, q, sigma, T)
  if (type == "call") {
    S * exp(-q * T) * pnorm(d$d1) - K * exp(-r * T) * pnorm(d$d2)
  } else {
    K * exp(-r * T) * pnorm(-d$d2) - S * exp(-q * T) * pnorm(-d$d1)
  }
}

bs_delta <- function(S, K, r, q, sigma, T, type = "call") {
  if (!type %in% c("call", "put")) stop("type must be either 'call' or 'put'")
  d1 <- bs_d(S, K, r, q, sigma, T)$d1
  if (type == "call") exp(-q * T) * pnorm(d1)
  else exp(-q * T) * (pnorm(d1) - 1)
}

bs_gamma <- function(S, K, r, q, sigma, T) {
  d1 <- bs_d(S, K, r, q, sigma, T)$d1
  exp(-q * T) * dnorm(d1) / (S * sigma * sqrt(T))
}

# per 1 volatility point
bs_vega <- function(S, K, r, q, sigma, T) {
  d1 <- bs_d(S, K, r, q, sigma, T)$d1
  S * exp(-q * T) * dnorm(d1) * sqrt(T) / 100
}

# per calendar day
bs_theta <- function(S, K, r, q, sigma, T, type = "call") {
  if (!type %in% c("call", "put")) stop("type must be either 'call' or 'put'")
  d <- bs_d(S, K, r, q, sigma, T)
  decay <- -S * exp(-q * T) * dnorm(d$d1) * sigma / (2 * sqrt(T))
  theta <- if (type == "call") {
    decay - r * K * exp(-r * T) * pnorm(d$d2) +
      q * S * exp(-q * T) * pnorm(d$d1)
  } else {
    decay + r * K * exp(-r * T) * pnorm(-d$d2) -
      q * S * exp(-q * T) * pnorm(-d$d1)
  }
  theta / 365
}

# per 1 interest rate point
bs_rho <- function(S, K, r, q, sigma, T, type = "call") {
  if (!type %in% c("call", "put")) stop("type must be either 'call' or 'put'")
  d2 <- bs_d(S, K, r, q, sigma, T)$d2
  if (type == "call") K * T * exp(-r * T) * pnorm(d2) / 100
  else -K * T * exp(-r * T) * pnorm(-d2) / 100
}

bs_implied_vol <- function(price, S, K, r, q, T, type = "call") {
  b <- check_bounds(price, S, K, r, q, T, type)
  if (!b$within_bounds) return(NA_real_)
  f   <- function(sigma) bs_price(S, K, r, q, sigma, T, type) - price
  out <- try(uniroot(f, lower = 0.0001, upper = 5)$root, silent = TRUE)
  if (inherits(out, "try-error")) return(NA_real_)
  out
}

# --- Phase 4: Monte Carlo (risk-neutral) -----------------------
simulate_terminal <- function(S, r, q, sigma, T, n) {
  Z <- rnorm(n)
  S * exp((r - q - 0.5 * sigma^2) * T + sigma * sqrt(T) * Z)
}

mc_summary <- function(x, n) {
  price <- mean(x)
  se    <- sd(x) / sqrt(n)
  list(price = price, se = se,
       lower = price - 1.96 * se, upper = price + 1.96 * se)
}

mc_price <- function(S, K, r, q, sigma, T, n, type = "call") {
  ST <- simulate_terminal(S, r, q, sigma, T, n)
  mc_summary(exp(-r * T) * option_payoff(ST, K, type), n)
}

# antithetic: n is the total number of prices; SE uses the pair averages
mc_price_anti <- function(S, K, r, q, sigma, T, n, type = "call") {
  half  <- n / 2
  Z     <- rnorm(half)
  drift <- (r - q - 0.5 * sigma^2) * T
  vol   <- sigma * sqrt(T)
  pay_up   <- exp(-r * T) * option_payoff(S * exp(drift + vol * Z), K, type)
  pay_down <- exp(-r * T) * option_payoff(S * exp(drift - vol * Z), K, type)
  mc_summary((pay_up + pay_down) / 2, half)
}

# control variate: discounted stock price, known mean S*exp(-qT)
mc_price_cv <- function(S, K, r, q, sigma, T, n, type = "call") {
  ST <- simulate_terminal(S, r, q, sigma, T, n)
  Y  <- exp(-r * T) * option_payoff(ST, K, type)
  X  <- exp(-r * T) * ST
  b  <- cov(Y, X) / var(X)
  out <- mc_summary(Y - b * (X - S * exp(-q * T)), n)
  out$b <- b
  out
}

# --- Phase 6: seg fund guarantee -------------------------------
# Pricing here is RISK-NEUTRAL (market grows at r).
# Every assumption is an input. All values below are assumptions.
seg_defaults <- function() {
  list(P0 = 100, G = 100, T = 10, fee = 0.025,
       sigma = 0.20,           # placeholder volatility
       r = 0.038,              # Canada 10-year yield, about mid-Oct 2026
       age = 50, lapse = 0.05,
       gm = list(A = 0.00022, B = 0.0000027, C = 1.124),
       mu = 0.07,              # real-world return (hedging, reserves)
       n_sims = 100000, n_paths = 5000, seed = 3130,
       hedge_steps = 52, cte_level = 0.95)
}

guarantee_cost <- function(a) {
  bs_price(a$P0, a$G, a$r, a$fee, a$sigma, a$T, "put")
}

surv_gm <- function(x, t, p) {
  exp(-p$A * t - p$B * p$C^x * (p$C^t - 1) / log(p$C))
}

in_force_t <- function(a, t) {
  surv_gm(a$age, t, a$gm) * (1 - a$lapse)^t
}

in_force <- function(a) in_force_t(a, a$T)

guarantee_cost_dec <- function(a) in_force(a) * guarantee_cost(a)

mc_guarantee <- function(a, n) {
  Z    <- rnorm(n)
  mkt  <- exp((a$r - 0.5 * a$sigma^2) * a$T + a$sigma * sqrt(a$T) * Z)
  fund <- a$P0 * mkt * exp(-a$fee * a$T)
  mc_summary(exp(-a$r * a$T) * pmax(a$G - fund, 0), n)
}

# --- Fair fee (pricing measure) --------------------------------
pv_fees <- function(a, m) {
  m * a$P0 * integrate(function(t) in_force_t(a, t) * exp(-m * t),
                       0, a$T)$value
}

cost_at_fee <- function(a, m) {
  a$fee <- m
  guarantee_cost_dec(a)
}

fee_gap <- function(m, a) pv_fees(a, m) - cost_at_fee(a, m)

fair_fee <- function(a) {
  uniroot(fee_gap, c(0.0001, 0.10), a = a)$root
}

# --- Phase 6: hedging and reserves (REAL-WORLD measure) --------
# The market grows at mu, not r. All values are assumptions.
simulate_fund_real <- function(a, n) {
  m  <- a$T * a$hedge_steps
  dt <- 1 / a$hedge_steps
  Z   <- matrix(rnorm(n * m), nrow = n, ncol = m)
  inc <- (a$mu - 0.5 * a$sigma^2) * dt + a$sigma * sqrt(dt) * Z
  mkt <- cbind(1, exp(matrix(t(apply(inc, 1, cumsum)), nrow = n)))
  tt  <- (0:m) * dt
  a$P0 * mkt * exp(-a$fee * rep(tt, each = n))
}

# Delta hedge of the plain put (no mortality or lapses)
hedge_error <- function(a, F) {
  m  <- ncol(F) - 1
  dt <- 1 / a$hedge_steps
  tt <- (0:m) * dt
  price0 <- bs_price(a$P0, a$G, a$r, a$fee, a$sigma, a$T, "put")
  delta  <- bs_delta(F[, 1], a$G, a$r, a$fee, a$sigma, a$T, "put")
  B      <- price0 - delta * F[, 1]
  for (i in 1:m) {
    B <- B * exp(a$r * dt) + delta * a$fee * F[, i] * dt
    V <- delta * F[, i + 1] + B
    if (i < m) {
      delta <- bs_delta(F[, i + 1], a$G, a$r, a$fee, a$sigma,
                        a$T - tt[i + 1], "put")
      B <- V - delta * F[, i + 1]
    }
  }
  V - pmax(a$G - F[, m + 1], 0)
}

# Delta hedge with mortality and lapses, per policy sold
hedge_error_dec <- function(a, F) {
  m  <- ncol(F) - 1
  dt <- 1 / a$hedge_steps
  tt <- (0:m) * dt
  w  <- in_force_t(a, tt) *
    surv_gm(a$age + tt, a$T - tt, a$gm) * (1 - a$lapse)^(a$T - tt)
  price0 <- bs_price(a$P0, a$G, a$r, a$fee, a$sigma, a$T, "put")
  delta  <- w[1] * bs_delta(F[, 1], a$G, a$r, a$fee, a$sigma, a$T, "put")
  B      <- w[1] * price0 - delta * F[, 1]
  for (i in 1:m) {
    B <- B * exp(a$r * dt) + delta * a$fee * F[, i] * dt
    V <- delta * F[, i + 1] + B
    if (i < m) {
      delta <- w[i + 1] * bs_delta(F[, i + 1], a$G, a$r, a$fee,
                                   a$sigma, a$T - tt[i + 1], "put")
      B <- V - delta * F[, i + 1]
    }
  }
  V - w[m + 1] * pmax(a$G - F[, m + 1], 0)
}

# Guarantee charge: the fair fee unless the user supplies one
guar_charge <- function(a) {
  if (is.null(a$guar_fee)) fair_fee(a) else a$guar_fee
}

unhedged_loss <- function(a, F) {
  m  <- ncol(F) - 1
  dt <- 1 / a$hedge_steps
  tt <- (0:m) * dt
  pv_payout <- exp(-a$r * a$T) * pmax(a$G - F[, m + 1], 0)
  disc      <- exp(-a$r * tt[1:m])
  pv_fees   <- as.numeric(guar_charge(a) * (F[, 1:m] %*% disc) * dt)
  pv_payout - pv_fees
}

unhedged_loss_dec <- function(a, F) {
  m  <- ncol(F) - 1
  dt <- 1 / a$hedge_steps
  tt <- (0:m) * dt
  pv_payout <- in_force(a) * exp(-a$r * a$T) * pmax(a$G - F[, m + 1], 0)
  disc      <- exp(-a$r * tt[1:m]) * in_force_t(a, tt[1:m])
  pv_fees   <- as.numeric(guar_charge(a) * (F[, 1:m] %*% disc) * dt)
  pv_payout - pv_fees
}

cte <- function(loss, level) {
  mean(loss[loss >= quantile(loss, level)])
}