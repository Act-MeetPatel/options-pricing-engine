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


# --- Live Government of Canada yield (Bank of Canada Valet API) ---
# Returns the rate as a decimal. Falls back to a saved value on any failure.
fetch_goc_yield <- function(series = "BD.CDN.10YR.DQ.YLD",
                            fallback = 0.038,
                            fallback_date = "2026-10-15") {
  old <- options(timeout = 10)
  on.exit(options(old))
  link <- paste0("https://www.bankofcanada.ca/valet/observations/",
                 series, "/json?recent=1")
  out <- tryCatch({
    txt <- suppressWarnings(paste(readLines(url(link), warn = FALSE),
                                  collapse = ""))
    x   <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
    obs <- x$observations[[1]]
    val <- as.numeric(obs[[series]]$v)
    if (!is.finite(val) || val <= 0 || val > 25) stop("unexpected value")
    list(rate = val / 100, date = obs$d, source = "live")
  }, error = function(e) NULL)
  if (is.null(out)) {
    out <- list(rate = fallback, date = fallback_date, source = "fallback")
  }
  out
}

# --- Safe snapshot of an option chain ---------------------------
# Never overwrites. The date comes from the system clock (your computer's
# time zone). To replace a snapshot, delete the file by hand first.
save_chain_snapshot <- function(ticker, expiry, calls, puts, spot,
                                dir = "data", date = Sys.Date()) {
  calls$type <- "call"
  puts$type  <- "put"
  snap <- rbind(calls, puts)
  snap$ticker        <- ticker
  snap$expiry        <- as.character(expiry)
  snap$snapshot_date <- as.character(date)
  snap$spot          <- spot
  
  file <- file.path(dir, paste0(tolower(ticker), "_chain_", expiry,
                                "_snapshot_", date, ".csv"))
  
  if (file.exists(file)) {
    return(list(file = file, saved = FALSE, rows = nrow(snap)))
  }
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  write.csv(snap, file, row.names = FALSE)
  list(file = file, saved = TRUE, rows = nrow(snap))
}


# --- Market data loader (Yahoo via quantmod) --------------------
# Returns the data, or list(error = "...") if anything fails.
fetch_market <- function(ticker, days = 365) {
  ticker <- toupper(trimws(ticker))
  if (!grepl("^[A-Z0-9.^-]{1,10}$", ticker)) {
    return(list(error = "Enter a valid ticker symbol (letters and numbers only)."))
  }
  tryCatch({
    px <- quantmod::getSymbols(ticker, src = "yahoo",
                               from = Sys.Date() - days, auto.assign = FALSE)
    ad <- na.omit(quantmod::Ad(px))
    if (nrow(ad) < 30) stop("Fewer than 30 days of prices found.")
    rets <- na.omit(diff(log(ad)))
    
    ch <- quantmod::getOptionChain(ticker, Exp = NULL)
    if (!is.list(ch) || length(ch) == 0) stop("No option chain found.")
    ex <- as.Date(names(ch), format = "%b.%d.%Y")
    if (any(is.na(ex))) stop("Could not read the expiry dates.")
    
    last <- tail(ad, 1)
    list(ticker = ticker, prices = ad, returns = rets,
         spot = as.numeric(last), last_date = as.character(zoo::index(last)),
         chain = ch, expiries = ex)
  }, error = function(e) {
    msg <- conditionMessage(e)
    if (grepl("Unable to import", msg)) {
      msg <- paste0("No price data found for ", ticker, ". Check the symbol.")
    }
    list(error = msg)
  })
}


# --- Historical volatility (annualized, sqrt(252) rule) --------
hist_vol <- function(returns, trading_days = 252) {
  r <- as.numeric(returns)
  if (length(r) < 2) return(NA_real_)
  sd(r) * sqrt(trading_days)
}

vol_window <- function(returns, days, trading_days = 252) {
  hist_vol(tail(as.numeric(returns), days), trading_days)
}


# --- Clean one expiry's chain (rules from Phase 5) --------------
# Returns the clean quotes and how many rows survive each rule.
clean_chain <- function(calls, puts, spot, r, q, T, lo = 0.7, hi = 1.3) {
  calls$type <- "call"
  puts$type  <- "put"
  x <- rbind(calls, puts)
  x$mid <- (x$Bid + x$Ask) / 2
  n0 <- nrow(x)
  
  x <- x[!is.na(x$Bid) & !is.na(x$Ask) & x$Bid > 0 & x$Ask > 0, ]
  n1 <- nrow(x)
  x <- x[!is.na(x$OI) & x$OI > 0, ]
  n2 <- nrow(x)
  x <- x[x$Strike >= lo * spot & x$Strike <= hi * spot, ]
  n3 <- nrow(x)
  x <- x[(x$type == "call" & x$Strike > spot) |
           (x$type == "put"  & x$Strike < spot), ]
  n4 <- nrow(x)
  if (nrow(x) > 0) {
    ok <- mapply(function(p, k, ty) {
      check_bounds(p, spot, k, r, q, T, ty)$within_bounds
    }, x$mid, x$Strike, x$type)
    x <- x[ok, ]
  }
  n5 <- nrow(x)
  
  counts <- data.frame(
    Step = c("All quotes (calls + puts)", "Bid and ask above 0",
             "Open interest above 0", "Strike inside the window",
             "Out of the money only", "Passes no-arbitrage bounds"),
    Rows = c(n0, n1, n2, n3, n4, n5))
  list(clean = x, counts = counts)
}


# --- Option-implied spot from put-call parity -------------------
# Uses the k strikes nearest spot_guess that have a usable call and put.
implied_spot <- function(calls, puts, spot_guess, r, q, T, k = 5) {
  none <- list(spot = NA_real_, n = 0, detail = NULL)
  both <- intersect(calls$Strike, puts$Strike)
  if (length(both) == 0) return(none)
  c1 <- calls[match(both, calls$Strike), ]
  p1 <- puts[match(both, puts$Strike), ]
  ok <- !is.na(c1$Bid) & !is.na(c1$Ask) & !is.na(p1$Bid) & !is.na(p1$Ask) &
    c1$Bid > 0 & c1$Ask > 0 & p1$Bid > 0 & p1$Ask > 0 &
    !is.na(c1$OI) & !is.na(p1$OI) & c1$OI > 0 & p1$OI > 0
  both <- both[ok]; c1 <- c1[ok, ]; p1 <- p1[ok, ]
  if (length(both) == 0) return(none)
  use <- order(abs(both - spot_guess))[seq_len(min(k, length(both)))]
  Cm  <- (c1$Bid[use] + c1$Ask[use]) / 2
  Pm  <- (p1$Bid[use] + p1$Ask[use]) / 2
  K   <- both[use]
  s   <- (Cm - Pm + K * exp(-r * T)) * exp(q * T)
  list(spot = median(s), n = length(s),
       detail = data.frame(Strike = K, Implied_spot = s))
}
