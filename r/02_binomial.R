# ---------------------------------------------------------------
# 02_binomial.R
# Phase 2: Binomial tree (Cox-Ross-Rubinstein)
# Project: options-pricing-engine
# ---------------------------------------------------------------

source("r/01_payoffs.R")
# --- CRR parameters ------------------------------------------------
# u, d: per-step up/down growth factors, sized to sigma over dt.
# p: risk-neutral probability of an up-move (not a real-world forecast)
# -- it's whatever makes discounting at r valid; see docs/phase2.md).

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



params <- crr_params(sigma = 0.2, r = 0.05, q = 0.02, T = 1, N = 50)

# --- Terminal stock prices ------------------------------------------
# After N steps, only the *count* of up-moves matters for the ending
# price, not the order -- so there are only N+1 distinct endpoints.
# j = number of up-moves, ranging 0 to N.

terminal_prices <- function(S, u, d, N) {
  j <- 0:N
  S * u^j * d^(N - j)
}


# --- Terminal option values -----------------------------------------
# At expiry, the option is worth exactly its payoff -- no uncertainty
# left to average over. Reuses option_payoff() from Phase 1.

terminal_values <- function(S, u, d, N, K, type = "call") {
  S_T <- terminal_prices(S, u, d, N)
  option_payoff(S_T, K, type)
}

# --- Backward induction ---------------------------------------------
# Walk from expiry back to today, one step at a time. At each node:
# value = discounted risk-neutral average of its up- and down-child.
# European only for now; American exercise comes in Step 5.

binomial_price_european <- function(S, K, r, q, sigma, T, N, type = "call") {
  
  cp <- crr_params(sigma, r, q, T, N)
  V  <- terminal_values(S, cp$u, cp$d, N, K, type)
  
  for (i in N:1) {
    V <- exp(-r * cp$dt) * (cp$p * V[-1] + (1 - cp$p) * V[-length(V)])
  }
  
  V  # now length 1: the price today
}


# --- American options ----------------------------------------------
# Same backward walk, but at every node take the larger of
# (hold: discounted risk-neutral average) and (exercise now: payoff).

binomial_price <- function(S, K, r, q, sigma, T, N, type = "call",
                           american = FALSE) {
  
  cp <- crr_params(sigma, r, q, T, N)
  V  <- terminal_values(S, cp$u, cp$d, N, K, type)
  
  for (i in (N - 1):0) {
    hold <- exp(-r * cp$dt) * (cp$p * V[-1] + (1 - cp$p) * V[-length(V)])
    
    if (american) {
      S_i      <- terminal_prices(S, cp$u, cp$d, i)
      exercise <- option_payoff(S_i, K, type)
      V <- pmax(hold, exercise)
    } else {
      V <- hold
    }
  }
  
  V
}
