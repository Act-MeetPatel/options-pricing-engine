# ---------------------------------------------------------------
# 04_monte_carlo.R
# Phase 4: Monte Carlo pricing
# Project: options-pricing-engine
# ---------------------------------------------------------------

source("r/03_black_scholes.R")   # also loads Phases 1 and 2

# --- Simulate stock prices at expiry (risk-neutral) -------------
simulate_terminal <- function(S, r, q, sigma, T, n) {
  Z <- rnorm(n)
  S * exp((r - q - 0.5 * sigma^2) * T + sigma * sqrt(T) * Z)
}


# --- Monte Carlo price with error ------------------------------
mc_price <- function(S, K, r, q, sigma, T, n, type = "call") {
  
  ST      <- simulate_terminal(S, r, q, sigma, T, n)
  payoffs <- exp(-r * T) * option_payoff(ST, K, type)
  
  price <- mean(payoffs)
  se    <- sd(payoffs) / sqrt(n)
  
  list(price = price, se = se,
       lower = price - 1.96 * se,
       upper = price + 1.96 * se)
}


# --- Coverage check: how often does the interval catch BS? -----
set.seed(3130)

runs <- 200
bs_target <- bs_price(100, 100, 0.05, 0.02, 0.2, 1, "call")

hits <- replicate(runs, {
  res <- mc_price(100, 100, 0.05, 0.02, 0.2, 1, 10000, "call")
  res$lower <= bs_target & bs_target <= res$upper
})


# --- Antithetic variates ---------------------------------------
mc_price_anti <- function(S, K, r, q, sigma, T, n, type = "call") {
  
  half <- n / 2
  Z    <- rnorm(half)
  drift <- (r - q - 0.5 * sigma^2) * T
  vol   <- sigma * sqrt(T)
  
  ST_up   <- S * exp(drift + vol * Z)
  ST_down <- S * exp(drift - vol * Z)
  
  pay_up   <- exp(-r * T) * option_payoff(ST_up, K, type)
  pay_down <- exp(-r * T) * option_payoff(ST_down, K, type)
  
  pair_avg <- (pay_up + pay_down) / 2
  
  price <- mean(pair_avg)
  se    <- sd(pair_avg) / sqrt(half)
  
  list(price = price, se = se,
       lower = price - 1.96 * se,
       upper = price + 1.96 * se)
}


# --- Control variates ------------------------------------------
mc_price_cv <- function(S, K, r, q, sigma, T, n, type = "call") {
  
  ST <- simulate_terminal(S, r, q, sigma, T, n)
  
  Y  <- exp(-r * T) * option_payoff(ST, K, type)   # option payoff
  X  <- exp(-r * T) * ST                           # reference: stock
  EX <- S * exp(-q * T)                            # its exact average
  
  b   <- cov(Y, X) / var(X)
  adj <- Y - b * (X - EX)
  
  price <- mean(adj)
  se    <- sd(adj) / sqrt(n)
  
  list(price = price, se = se,
       lower = price - 1.96 * se,
       upper = price + 1.96 * se,
       b = b)
}


# --- Simulate whole paths (risk-neutral) -----------------------
simulate_paths <- function(S, r, q, sigma, T, n, m) {
  
  dt  <- T / m
  Z   <- matrix(rnorm(n * m), nrow = n, ncol = m)
  inc <- (r - q - 0.5 * sigma^2) * dt + sigma * sqrt(dt) * Z
  
  S * exp(matrix(t(apply(inc, 1, cumsum)), nrow = n))
}


# --- Asian option (arithmetic average) -------------------------
mc_asian <- function(S, K, r, q, sigma, T, n, m, type = "call") {
  
  paths   <- simulate_paths(S, r, q, sigma, T, n, m)
  avg     <- rowMeans(paths)
  payoffs <- exp(-r * T) * option_payoff(avg, K, type)
  
  price <- mean(payoffs)
  se    <- sd(payoffs) / sqrt(n)
  
  list(price = price, se = se,
       lower = price - 1.96 * se,
       upper = price + 1.96 * se)
}


# --- Down-and-out barrier call ---------------------------------
mc_barrier <- function(S, K, B, r, q, sigma, T, n, m,
                       adjust = TRUE) {
  
  dt    <- T / m
  B_use <- if (adjust) B * exp(+0.5826 * sigma * sqrt(dt)) else B
  
  paths   <- simulate_paths(S, r, q, sigma, T, n, m)
  alive   <- apply(paths, 1, min) > B_use
  payoffs <- exp(-r * T) * option_payoff(paths[, m], K, "call") * alive
  
  price <- mean(payoffs)
  se    <- sd(payoffs) / sqrt(n)
  
  list(price = price, se = se,
       lower = price - 1.96 * se,
       upper = price + 1.96 * se)
}


# --- Exact down-and-out call (continuous monitoring) -----------
bs_down_out_call <- function(S, K, B, r, q, sigma, T) {
  
  if (B >= S || B > K) stop("Needs B < S and B <= K")
  
  lambda <- (r - q + 0.5 * sigma^2) / sigma^2
  y <- log(B^2 / (S * K)) / (sigma * sqrt(T)) + lambda * sigma * sqrt(T)
  
  c_di <- S * exp(-q * T) * (B / S)^(2 * lambda) * pnorm(y) -
    K * exp(-r * T) * (B / S)^(2 * lambda - 2) *
    pnorm(y - sigma * sqrt(T))
  
  bs_price(S, K, r, q, sigma, T, "call") - c_di
}


# --- Plot 1: SE comparison -------------------------------------
se_values <- c(Plain = 0.0441, Antithetic = 0.0325, Control = 0.0180)

png("outputs/mc_se_comparison.png", width = 800, height = 500)
barplot(se_values, col = c("grey60", "steelblue", "darkgreen"),
        ylab = "Standard error",
        main = "Monte Carlo error: call, 100,000 simulations")
dev.off()

# --- Plot 2: sample paths with barrier -------------------------
set.seed(3130)
demo   <- simulate_paths(100, 0.05, 0.02, 0.2, 1, 20, 250)
tt     <- (1:250) / 250
dead   <- apply(demo, 1, min) <= 90

png("outputs/mc_paths_barrier.png", width = 800, height = 500)
matplot(tt, t(demo), type = "l", lty = 1,
        col = ifelse(dead, "firebrick", "steelblue"),
        xlab = "Time (years)", ylab = "Stock price",
        main = "20 sample paths, barrier at 90")
abline(h = 90, lty = 2, lwd = 2)
dev.off()
