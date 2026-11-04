# ---------------------------------------------------------------
# 06_seg_fund.R
# Phase 6: Segregated fund maturity guarantee
# Project: options-pricing-engine
# Pricing here is under the RISK-NEUTRAL measure (stock grows at r).
# ---------------------------------------------------------------

source("r/03_black_scholes.R")   # loads Phases 1 to 3

# --- Assumptions (all adjustable) ------------------------------
seg <- list(
  P0    = 100,     # premium invested
  G     = 100,     # guarantee at maturity
  T     = 10,      # years
  fee   = 0.025,   # yearly fee (MER), acts like dividend yield
  sigma = 0.20,    # placeholder volatility
  r     = 0.04     # placeholder rate
)

# --- Guarantee cost, ignoring mortality and lapses -------------
guarantee_cost <- function(a) {
  bs_price(a$P0, a$G, a$r, a$fee, a$sigma, a$T, "put")
}


# --- Mortality (Gompertz-Makeham) and lapses --------------------
gm <- list(A = 0.00022, B = 0.0000027, C = 1.124)

surv_gm <- function(x, t, p = gm) {
  exp(-p$A * t - p$B * p$C^x * (p$C^t - 1) / log(p$C))
}

# --- Add to the assumptions ------------------------------------
seg$age   <- 50
seg$lapse <- 0.05

# --- Probability still in force at maturity --------------------
in_force <- function(a) {
  surv_gm(a$age, a$T) * (1 - a$lapse)^a$T
}


# --- Guarantee cost with mortality and lapses ------------------
guarantee_cost_dec <- function(a) {
  in_force(a) * guarantee_cost(a)
}


# --- Monte Carlo check of the guarantee (risk-neutral) ----------
# Pricing measure: market grows at r.
mc_guarantee <- function(a, n) {
  
  Z    <- rnorm(n)
  mkt  <- exp((a$r - 0.5 * a$sigma^2) * a$T + a$sigma * sqrt(a$T) * Z)
  fund <- a$P0 * mkt * exp(-a$fee * a$T)
  
  payoff <- exp(-a$r * a$T) * pmax(a$G - fund, 0)
  
  price <- mean(payoff)
  se    <- sd(payoff) / sqrt(n)
  
  list(price = price, se = se,
       lower = price - 1.96 * se,
       upper = price + 1.96 * se)
}


# --- Sensitivity: guarantee cost vs rate and vol ---------------
rates <- c(0.02, 0.03, 0.04, 0.05, 0.06)
vols  <- c(0.15, 0.20, 0.25, 0.30)

sens <- sapply(vols, function(v) {
  sapply(rates, function(rr) {
    a <- seg; a$r <- rr; a$sigma <- v
    guarantee_cost(a)
  })
})
dimnames(sens) <- list(paste0("r=", rates), paste0("vol=", vols))
round(sens, 2)


seg$r <- 0.038   # GoC 10-year yield, about 3.8%, mid-Oct 2026 (Trading Economics)


# --- Fair fee (pricing measure) ---------------------------------
# Probability still in force at time t
in_force_t <- function(a, t) {
  surv_gm(a$age, t) * (1 - a$lapse)^t
}

# Present value of fee income if the fee is m
pv_fees <- function(a, m) {
  m * a$P0 * integrate(function(t) in_force_t(a, t) * exp(-m * t),
                       0, a$T)$value
}

# Cost of the guarantee if the fee is m
cost_at_fee <- function(a, m) {
  a$fee <- m
  guarantee_cost_dec(a)
}

# Income minus cost. The fair fee makes this zero.
fee_gap <- function(m, a) pv_fees(a, m) - cost_at_fee(a, m)

fair_fee <- function(a) {
  uniroot(fee_gap, c(0.0001, 0.10), a = a)$root
}


# --- Hedging assumptions (adjustable) --------------------------
seg$mu          <- 0.07    # REAL-WORLD expected market return (assumption)
seg$hedge_steps <- 52      # rebalances per year
seg$n_paths     <- 5000
seg$seed        <- 3130

# --- Simulate fund paths: REAL-WORLD measure (drift = mu) ------
simulate_fund_real <- function(a, n) {
  
  m  <- a$T * a$hedge_steps
  dt <- 1 / a$hedge_steps
  
  Z   <- matrix(rnorm(n * m), nrow = n, ncol = m)
  inc <- (a$mu - 0.5 * a$sigma^2) * dt + a$sigma * sqrt(dt) * Z
  mkt <- cbind(1, exp(matrix(t(apply(inc, 1, cumsum)), nrow = n)))
  
  tt <- (0:m) * dt
  a$P0 * mkt * exp(-a$fee * rep(tt, each = n))
}


# --- Delta hedge of the guarantee: REAL-WORLD paths -------------
# Hedge is funded by the put price. Returns hedge error per path.
hedge_error <- function(a, F) {
  
  n  <- nrow(F)
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


# --- Hedging frequency: REAL-WORLD paths ------------------------
hedge_sd <- function(a, steps, n) {
  a$hedge_steps <- steps
  F   <- simulate_fund_real(a, n)
  err <- hedge_error(a, F)
  c(steps = steps, mean = mean(err), sd = sd(err))
}

set.seed(seg$seed)
res <- t(sapply(c(12, 52, 252), function(s) hedge_sd(seg, s, 2000)))
res


# --- CTE reserve, unhedged: REAL-WORLD paths --------------------
seg$guar_fee  <- fair_fee(seg)   # guarantee charge (assumption)
seg$cte_level <- 0.95

unhedged_loss <- function(a, F) {
  m  <- ncol(F) - 1
  dt <- 1 / a$hedge_steps
  tt <- (0:m) * dt
  
  pv_payout <- exp(-a$r * a$T) * pmax(a$G - F[, m + 1], 0)
  disc      <- exp(-a$r * tt[1:m])
  pv_fees   <- as.numeric(a$guar_fee * (F[, 1:m] %*% disc) * dt)
  
  pv_payout - pv_fees
}

cte <- function(loss, level) {
  mean(loss[loss >= quantile(loss, level)])
}



# --- CTE sensitivity: REAL-WORLD paths --------------------------
cte_for <- function(a, n) {
  set.seed(a$seed)
  F <- simulate_fund_real(a, n)
  L <- unhedged_loss(a, F)
  c(mean = mean(L), cte = cte(L, a$cte_level))
}

mus  <- c(0.04, 0.07, 0.09)
sens_mu <- t(sapply(mus, function(m) {
  a <- seg; a$mu <- m
  cte_for(a, seg$n_paths)
}))
rownames(sens_mu) <- paste0("mu=", mus)
round(sens_mu, 2)

sigs <- c(0.15, 0.20, 0.25)
sens_sig <- t(sapply(sigs, function(s) {
  a <- seg; a$sigma <- s
  a$guar_fee <- fair_fee(a)
  cte_for(a, seg$n_paths)
}))
rownames(sens_sig) <- paste0("sigma=", sigs)
round(sens_sig, 2)


# --- CTE reserve with decrements: REAL-WORLD paths --------------
# Per original policy sold. Large-pool assumption: the in-force
# fraction equals its expected value exactly.
unhedged_loss_dec <- function(a, F) {
  m  <- ncol(F) - 1
  dt <- 1 / a$hedge_steps
  tt <- (0:m) * dt
  
  pv_payout <- in_force(a) * exp(-a$r * a$T) * pmax(a$G - F[, m + 1], 0)
  disc      <- exp(-a$r * tt[1:m]) * in_force_t(a, tt[1:m])
  pv_fees   <- as.numeric(a$guar_fee * (F[, 1:m] %*% disc) * dt)
  
  pv_payout - pv_fees
}


# --- Plot 1: hedge error by frequency ---------------------------
set.seed(seg$seed)
errs <- lapply(c(12, 52, 252), function(s) {
  a <- seg; a$hedge_steps <- s
  hedge_error(a, simulate_fund_real(a, 2000))
})

png("outputs/seg_hedge_error.png", width = 800, height = 500)
boxplot(errs, names = c("Monthly", "Weekly", "Daily"),
        col = c("grey70", "steelblue", "darkgreen"),
        ylab = "Hedge error at year 10",
        main = "Hedge error by rebalancing frequency")
abline(h = 0, lty = 2)
dev.off()

# --- Plot 2: unhedged loss with CTE -----------------------------
png("outputs/seg_loss_cte.png", width = 800, height = 500)
hist(L2, breaks = 60, col = "steelblue", border = "white",
     xlab = "Loss per policy sold (today's dollars)",
     main = "Unhedged loss, real world, with mortality and lapses")
abline(v = cte(L2, seg$cte_level), col = "firebrick", lwd = 2, lty = 2)
dev.off()


# --- Delta hedge WITH decrements: REAL-WORLD paths --------------
# Per original policy sold. Large-pool assumption.
hedge_error_dec <- function(a, F) {
  
  n  <- nrow(F)
  m  <- ncol(F) - 1
  dt <- 1 / a$hedge_steps
  tt <- (0:m) * dt
  
  n_t <- in_force_t(a, tt)                              # in force at t
  s_t <- surv_gm(a$age + tt, a$T - tt) *
    (1 - a$lapse)^(a$T - tt)                       # still in force at T
  w   <- n_t * s_t
  
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
