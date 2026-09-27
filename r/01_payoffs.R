# ---------------------------------------------------------------
# 01_payoffs.R
# Phase 1: Option payoffs, put-call parity, no-arbitrage bounds
# Project: options-pricing-engine
# ---------------------------------------------------------------

option_payoff <- function(S_T, K, type = "call") {
  
  if (!type %in% c("call", "put")) {
    stop("type must be either 'call' or 'put'")
  }
  
  if (type == "call") {
    pmax(S_T - K, 0)
  } else {
    pmax(K - S_T, 0)
  }
}


# --- Payoff diagrams ---------------------------------------------

K <- 100
S_grid <- seq(50, 150, by = 1)

call_payoff <- option_payoff(S_grid, K, "call")
put_payoff  <- option_payoff(S_grid, K, "put")


#---call plot------------------------------------------------------

plot(S_grid, call_payoff,
     type = "l", lwd = 2, col = "steelblue",
     xlab = "Stock price at expiry",
     ylab = "Payoff",
     main = "Long call payoff (K = 100)")
abline(h = 0, col = "grey60")
abline(v = K, lty = 2, col = "grey60")

#---put plot------------------------------------------------------

plot(S_grid, put_payoff,
     type = "l", lwd = 2, col = "firebrick",
     xlab = "Stock price at expiry",
     ylab = "Payoff",
     main = "Long put payoff (K = 100)")
abline(h = 0, col = "grey60")
abline(v = K, lty = 2, col = "grey60")


# --- Combination strategies --------------------------------------
# Illustrative only; no later phase depends on these. Included to show
# that any position is a sum of basic payoffs, with a minus sign on
# anything sold.

# Bull call spread: long 95 call, short 110 call.
# Short leg subtracted (it's a liability). Payoff capped at 15, the
# gap between strikes.
bull_spread <- option_payoff(S_grid, 95, "call") - 
  option_payoff(S_grid, 110, "call")

# Straddle: long call + long put at K = 100.
# Pays on movement in either direction, nothing if the stock sits
# still. A bet on volatility with no view on direction.
straddle <- option_payoff(S_grid, 100, "call") + 
  option_payoff(S_grid, 100, "put")

plot(S_grid, bull_spread,
     type = "l", lwd = 2, col = "darkgreen",
     ylim = c(-5, 55),
     xlab = "Stock price at expiry", ylab = "Payoff",
     main = "Bull call spread (long 95, short 110)")
abline(h = 0, col = "grey60")

plot(S_grid, straddle,
     type = "l", lwd = 2, col = "purple",
     ylim = c(-5, 55),
     xlab = "Stock price at expiry", ylab = "Payoff",
     main = "Straddle (long call + long put, K = 100)")
abline(h = 0, col = "grey60")


# --- Put-call parity ---------------------------------------------
# C - P = S*exp(-qT) - K*exp(-rT), for European options.
# Model-free: follows from replication alone, so it holds for every
# pricing method in this project. Used as a cross-check in Phases 2-4.

check_parity <- function(C, P, S, K, r, q, T, tol = 1e-8) {
  
  lhs <- C - P
  rhs <- S * exp(-q * T) - K * exp(-r * T)
  diff <- lhs - rhs
  
  list(
    lhs     = lhs,
    rhs     = rhs,
    diff    = diff,
    holds   = abs(diff) < tol
  )
}


# --- No-arbitrage bounds ------------------------------------------
# Bounds any option price must satisfy, model-free. Used in Phase 5 to
# filter bad real-market quotes before solving for implied volatility.

check_bounds <- function(price, S, K, r, q, T, type = "call", 
                         american = FALSE) {
  
  if (!type %in% c("call", "put")) {
    stop("type must be either 'call' or 'put'")
  }
  
  if (type == "call") {
    lower <- max(S * exp(-q*T) - K * exp(-r*T), 0)
    upper <- S * exp(-q*T)
  } else {
    lower <- max(K * exp(-r*T) - S * exp(-q*T), 0)
    upper <- if (american) K else K * exp(-r*T)
  }
  
  list(
    lower = lower,
    upper = upper,
    within_bounds = price >= lower & price <= upper
  )
}
