# ---------------------------------------------------------------
# 05_market_data.R
# Phase 5: Market data, historical volatility, implied volatility
# Project: options-pricing-engine
# ---------------------------------------------------------------

library(quantmod)

source("r/03_black_scholes.R")   # loads Phases 1 to 3


# --- Daily log returns -----------------------------------------
prices  <- Ad(TSLA)
returns <- na.omit(diff(log(prices)))


# --- Historical volatility (annualized) ------------------------
hist_vol <- function(returns, trading_days = 252) {
  sd(as.numeric(returns)) * sqrt(trading_days)
}


# --- Volatility over different windows -------------------------
vol_window <- function(returns, days) {
  r <- tail(as.numeric(returns), days)
  sd(r) * sqrt(252)
}


# --- Rolling 30-day volatility ---------------------------------
roll_vol <- rollapply(returns, width = 30,
                      FUN = function(x) sd(x) * sqrt(252),
                      align = "right")


png("outputs/tsla_rolling_vol.png", width = 800, height = 500)
plot(as.numeric(roll_vol) ~ index(roll_vol), type = "l",
     col = "steelblue", lwd = 2,
     xlab = "Date", ylab = "30-day volatility (annualized)",
     main = "TSLA rolling 30-day volatility")
abline(h = hist_vol(returns), lty = 2, col = "firebrick", lwd = 2)
dev.off()


# --- Option chain ----------------------------------------------
chain <- getOptionChain("TSLA", Exp = NULL)


# --- Save snapshot ---------------------------------------------
calls <- chain[["Jan.15.2027"]]$calls
puts  <- chain[["Jan.15.2027"]]$puts
calls$type <- "call"
puts$type  <- "put"

snap <- rbind(calls, puts)
snap$snapshot_date <- "2026-11-02"
snap$spot <- as.numeric(tail(prices, 1))

write.csv(snap, "data/tsla_chain_2027-01-15_snapshot.csv",
          row.names = FALSE)


# --- Clean the chain -------------------------------------------
spot <- unique(snap$spot)
r_in <- 0.04          # placeholder: replace with a real short yield
q_in <- 0             # TSLA pays no dividend
T_in <- as.numeric(as.Date("2027-01-15") - as.Date("2026-11-02")) / 365

snap$mid <- (snap$Bid + snap$Ask) / 2

keep <- snap$Bid > 0 & snap$Ask > 0 & snap$OI > 0 &
  snap$Strike >= 0.7 * spot & snap$Strike <= 1.3 * spot &
  ((snap$type == "call" & snap$Strike > spot) |
     (snap$type == "put"  & snap$Strike < spot))

clean <- snap[keep, ]

clean$in_bounds <- mapply(function(p, k, ty) {
  check_bounds(p, spot, k, r_in, q_in, T_in, ty)$within_bounds
}, clean$mid, clean$Strike, clean$type)

clean <- clean[clean$in_bounds, ]


# --- Implied volatility at each strike -------------------------
clean$iv <- mapply(function(p, k, ty) {
  bs_implied_vol(p, spot, k, r_in, q_in, T_in, ty)
}, clean$mid, clean$Strike, clean$type)


# --- Redo implied vol with market-implied spot -----------------
spot2 <- Cm - Pm + 400 * exp(-r_in * T_in)

clean$iv2 <- mapply(function(p, k, ty) {
  bs_implied_vol(p, spot2, k, r_in, q_in, T_in, ty)
}, clean$mid, clean$Strike, clean$type)


# --- Plot the smile --------------------------------------------
cl <- clean[order(clean$Strike), ]

png("outputs/tsla_vol_smile.png", width = 800, height = 500)
plot(cl$Strike, cl$iv2, pch = 16,
     col = ifelse(cl$type == "put", "firebrick", "steelblue"),
     xlab = "Strike", ylab = "Implied volatility",
     main = "TSLA volatility smile (Jan 15, 2027)")
abline(h = hist_vol(returns), lty = 2)
abline(v = spot2, lty = 3)
legend("topright", pch = 16, col = c("firebrick", "steelblue"),
       legend = c("Put", "Call"))
dev.off()


# --- Implied vs historical volatility --------------------------
atm_iv <- mean(clean$iv2[clean$Strike %in% c(390, 400)])

vols <- c(implied = atm_iv,
          hist_30  = vol_window(returns, 30),
          hist_90  = vol_window(returns, 90),
          hist_365 = vol_window(returns, 365))


# --- Model price (historical vol) vs market --------------------
sig_h <- hist_vol(returns)

clean$model <- mapply(function(k, ty) {
  bs_price(spot2, k, r_in, q_in, sig_h, T_in, ty)
}, clean$Strike, clean$type)

clean$diff <- clean$mid - clean$model



cl <- clean[order(clean$Strike), ]

png("outputs/tsla_model_vs_market.png", width = 800, height = 500)
plot(cl$Strike, cl$mid, pch = 16, col = "steelblue",
     xlab = "Strike", ylab = "Option price",
     main = "TSLA: market mid vs. model (45.3% vol)")
points(cl$Strike, cl$model, pch = 1, col = "firebrick", lwd = 2)
legend("top", pch = c(16, 1), col = c("steelblue", "firebrick"),
       legend = c("Market mid", "Model"))
dev.off()
