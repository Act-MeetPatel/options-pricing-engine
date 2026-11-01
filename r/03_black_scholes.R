# ---------------------------------------------------------------
# 03_black_scholes.R
# Phase 3: Black-Scholes price, Greeks, implied volatility
# Project: options-pricing-engine
# ---------------------------------------------------------------

source("r/01_payoffs.R")
source("r/02_binomial.R")

# --- d1 and d2 -------------------------------------------------
bs_d <- function(S, K, r, q, sigma, T) {
  d1 <- (log(S / K) + (r - q + 0.5 * sigma^2) * T) / (sigma * sqrt(T))
  d2 <- d1 - sigma * sqrt(T)
  list(d1 = d1, d2 = d2)
}


# --- Black-Scholes price ---------------------------------------
bs_price <- function(S, K, r, q, sigma, T, type = "call") {
  
  if (!type %in% c("call", "put")) {
    stop("type must be either 'call' or 'put'")
  }
  
  if (T == 0) return(option_payoff(S, K, type))
  
  d <- bs_d(S, K, r, q, sigma, T)
  
  if (type == "call") {
    S * exp(-q * T) * pnorm(d$d1) - K * exp(-r * T) * pnorm(d$d2)
  } else {
    K * exp(-r * T) * pnorm(-d$d2) - S * exp(-q * T) * pnorm(-d$d1)
  }
}


# --- Tree vs Black-Scholes -------------------------------------
bs_call    <- bs_price(100, 100, 0.05, 0.02, 0.2, 1, "call")
tree_error <- conv_call - bs_call


plot(N_values, conv_call, type = "b", pch = 16, col = "steelblue",
     xlab = "Number of steps (N)", ylab = "Call price",
     main = "Tree price vs. Black-Scholes")
abline(h = bs_call, col = "firebrick", lty = 2, lwd = 2)


# --- Delta -----------------------------------------------------
#How much an option price changes when the stock moves by $1
bs_delta <- function(S, K, r, q, sigma, T, type = "call") {
  
  if (!type %in% c("call", "put")) {
    stop("type must be either 'call' or 'put'")
  }
  
  d1 <- bs_d(S, K, r, q, sigma, T)$d1
  
  if (type == "call") {
    exp(-q * T) * pnorm(d1)
  } else {
    exp(-q * T) * (pnorm(d1) - 1)
  }
}


# --- Gamma -----------------------------------------------------
#How fast delta changes; how often the hedge needs adjusting
bs_gamma <- function(S, K, r, q, sigma, T) {
  d1 <- bs_d(S, K, r, q, sigma, T)$d1
  exp(-q * T) * dnorm(d1) / (S * sigma * sqrt(T))
}


# --- Vega (per 1 volatility point) -----------------------------
#How much an option price changes when volatility changes by 1
bs_vega <- function(S, K, r, q, sigma, T) {
  d1 <- bs_d(S, K, r, q, sigma, T)$d1
  S * exp(-q * T) * dnorm(d1) * sqrt(T) / 100
}


# --- Theta (per calendar day) ----------------------------------
#How much value the option loses each day just from time passing
bs_theta <- function(S, K, r, q, sigma, T, type = "call") {
  
  if (!type %in% c("call", "put")) {
    stop("type must be either 'call' or 'put'")
  }
  
  d  <- bs_d(S, K, r, q, sigma, T)
  decay <- -S * exp(-q * T) * dnorm(d$d1) * sigma / (2 * sqrt(T))
  
  if (type == "call") {
    theta <- decay - r * K * exp(-r * T) * pnorm(d$d2) +
      q * S * exp(-q * T) * pnorm(d$d1)
  } else {
    theta <- decay + r * K * exp(-r * T) * pnorm(-d$d2) -
      q * S * exp(-q * T) * pnorm(-d$d1)
  }
  
  theta / 365
}


# --- Rho (per 1 interest rate point) ---------------------------
#How much an option's price changes when interest rates change by 1 point
bs_rho <- function(S, K, r, q, sigma, T, type = "call") {
  
  if (!type %in% c("call", "put")) {
    stop("type must be either 'call' or 'put'")
  }
  
  d2 <- bs_d(S, K, r, q, sigma, T)$d2
  
  if (type == "call") {
    K * T * exp(-r * T) * pnorm(d2) / 100
  } else {
    -K * T * exp(-r * T) * pnorm(-d2) / 100
  }
}


# --- Implied volatility ----------------------------------------
bs_implied_vol <- function(price, S, K, r, q, T, type = "call") {
  
  b <- check_bounds(price, S, K, r, q, T, type)
  if (!b$within_bounds) return(NA_real_)
  
  f <- function(sigma) bs_price(S, K, r, q, sigma, T, type) - price
  
  out <- try(uniroot(f, lower = 0.0001, upper = 5)$root, silent = TRUE)
  if (inherits(out, "try-error")) return(NA_real_)
  out
}


# --- Save tree vs Black-Scholes plot ---------------------------
png("outputs/tree_vs_black_scholes.png", width = 800, height = 500)
plot(N_values, conv_call, type = "b", pch = 16, col = "steelblue",
     xlab = "Number of steps (N)", ylab = "Call price",
     main = "Tree price vs. Black-Scholes")
abline(h = bs_call, col = "firebrick", lty = 2, lwd = 2)
dev.off()
