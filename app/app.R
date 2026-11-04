library(shiny)

# Run App sets the working directory to app/, so look in both places
engine <- if (file.exists("r/engine.R")) "r/engine.R" else "../r/engine.R"
source(engine)

ui <- fluidPage(
  theme = bslib::bs_theme(
    bootswatch = "flatly",
    primary = "#1a5276",
    secondary = "#7fb3d5"
  ),
  
  tags$head(tags$style(HTML("
    body::before {
      content: '📈';
      font-size: 500px;
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      opacity: 0.12;
      z-index: -1;
    }
    .well {
      background-color: #f4f6f7;
      border-radius: 12px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    }
    .form-control {
      border-radius: 8px;
      transition: box-shadow 0.2s ease;
    }
    .form-control:focus {
      box-shadow: 0 0 0 3px rgba(26,82,118,0.2);
    }
    .result-card {
      background-color: white;
      border-radius: 12px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
      padding: 20px;
    }
    .footer {
      position: fixed;
      bottom: 15px;
      right: 25px;
      font-size: 12px;
      color: #888;
    }
    #shiny-notification-panel {
      top: auto !important;
      bottom: 15px !important;
      left: 25px !important;
      right: auto !important;
    }
    h1 { color: #1a5276; }
  "))),
  
  titlePanel(
    div(span("📈", style = "font-size: 32px; margin-right: 10px;"),
        "Option Pricing Engine")
  ),
  
  div(class = "footer",
      "© 2026 Meet Patel. Option Pricing Engine. For illustrative and educational purposes only."),
  
  tabsetPanel(
    
    # ---------------- Tab 1: Pricing ----------------
    tabPanel("Pricing",
             sidebarLayout(
               sidebarPanel(
                 radioButtons("type", "Option type", c("call", "put"), inline = TRUE),
                 numericInput("S", "Stock price (S)", 100),
                 numericInput("K", "Strike (K)", 100),
                 numericInput("r", "Interest rate (r, e.g. 0.05)", 0.05, step = 0.005),
                 numericInput("q", "Dividend yield (q)", 0.02, step = 0.005),
                 numericInput("sigma", "Volatility (sigma)", 0.20, step = 0.01),
                 numericInput("T", "Years to expiry (T)", 1, step = 0.25),
                 selectInput("method", "Method",
                             c("Black-Scholes", "Binomial tree", "Monte Carlo")),
                 conditionalPanel("input.method == 'Binomial tree'",
                                  numericInput("N", "Tree steps (N)", 50, min = 1, max = 5000, step = 10),
                                  checkboxInput("american", "American (early exercise)", FALSE)),
                 conditionalPanel("input.method == 'Monte Carlo'",
                                  selectInput("mc_kind", "Variance reduction",
                                              c("Plain", "Antithetic", "Control variate")),
                                  numericInput("n", "Simulations (n, even)", 100000,
                                               min = 1000, step = 10000),
                                  numericInput("seed", "Random seed", 3130))
               ),
               mainPanel(
                 div(class = "result-card",
                     h3("Results"),
                     tableOutput("result"),
                     textOutput("note"),
                     conditionalPanel("input.method == 'Black-Scholes'",
                                      h4("Greeks"),
                                      tableOutput("greeks")),
                     plotOutput("payoff", height = "320px"))
               )
             )
    ),
    
    # ---------------- Tab 2: Seg fund ----------------
    tabPanel("Seg fund",
             sidebarLayout(
               sidebarPanel(
                 h4("Product"),
                 numericInput("sf_P0", "Premium invested (P0)", seg_defaults()$P0),
                 numericInput("sf_G", "Guarantee at maturity (G)", seg_defaults()$G),
                 numericInput("sf_T", "Term in years (T)", seg_defaults()$T),
                 numericInput("sf_fee", "Yearly fee (e.g. 0.025)", seg_defaults()$fee, step = 0.005),
                 h4("Market (assumptions)"),
                 numericInput("sf_sigma", "Volatility (sigma)", seg_defaults()$sigma, step = 0.01),
                 numericInput("sf_r", "Interest rate (r)", seg_defaults()$r, step = 0.0025),
                 actionButton("sf_fetch_rate", "Fetch latest Canada 10-year yield"),
                 textOutput("sf_rate_note"),
                 h4("Policyholder (assumptions)"),
                 numericInput("sf_age", "Issue age", seg_defaults()$age),
                 numericInput("sf_lapse", "Lapse rate per year", seg_defaults()$lapse, step = 0.01),
                 h4("Mortality (Gompertz-Makeham)"),
                 numericInput("sf_A", "A", seg_defaults()$gm$A, step = 0.00001),
                 numericInput("sf_B", "B", seg_defaults()$gm$B, step = 0.0000001),
                 numericInput("sf_C", "C", seg_defaults()$gm$C, step = 0.001),
                 h4("Hedging and reserve (real world, assumptions)"),
                 numericInput("sf_mu", "Expected market return (mu)", seg_defaults()$mu, step = 0.01),
                 numericInput("sf_steps", "Hedges per year", seg_defaults()$hedge_steps, min = 1, step = 1),
                 numericInput("sf_paths", "Simulated paths", seg_defaults()$n_paths, min = 500, step = 500),
                 numericInput("sf_cte", "CTE level (e.g. 0.95)", seg_defaults()$cte_level, step = 0.01),
                 numericInput("sf_seed", "Random seed", seg_defaults()$seed),
                 actionButton("sf_run", "Run hedging and reserve simulation", class = "btn-primary")
               ),
               mainPanel(
                 div(class = "result-card",
                     h3("Results"),
                     tableOutput("sf_table"),
                     textOutput("sf_note")),
                 div(class = "result-card", style = "margin-top: 20px;",
                     h3("Hedging and reserve (real world)"),
                     tableOutput("sf_sim"),
                     textOutput("sf_sim_note"))
               )
             )
    ),
    
    # ---------------- Tab 3: Market ----------------
    tabPanel("Market",
             sidebarLayout(
               sidebarPanel(
                 h4("Stock"),
                 textInput("mk_ticker", "Ticker symbol", value = "",
                           placeholder = "Enter a ticker, e.g. TSLA"),
                 actionButton("mk_load", "Load market data", class = "btn-primary"),
                 selectInput("mk_expiry", "Option expiry", choices = character(0)),
                 h4("Inputs (assumptions)"),
                 numericInput("mk_r", "Interest rate (r, typed in)", 0.04, step = 0.0025),
                 numericInput("mk_q", "Dividend yield (q). 0 suits TSLA; enter the yield for dividend payers", 0, step = 0.005),
                 numericInput("mk_lo", "Strike window, lowest (% of spot)", 70, step = 5),
                 numericInput("mk_hi", "Strike window, highest (% of spot)", 130, step = 5),
                 radioButtons("mk_spot_src", "Spot price used for cleaning",
                              choices = c("Option-implied (recommended)" = "implied",
                                          "Last close" = "close")),
               ),
               mainPanel(
                 div(class = "result-card",
                     h3("Market data"),
                     tableOutput("mk_table"),
                     textOutput("mk_note")),
                 div(class = "result-card", style = "margin-top: 20px;",
                     h3("Option chain for the selected expiry"),
                     textOutput("mk_info"),
                     h4("Cleaning"),
                     tableOutput("mk_counts"),
                     h4("Clean quotes"),
                     tableOutput("mk_quotes")),
                 div(class = "result-card", style = "margin-top: 20px;",
                     h3("Volatility smile"),
                     textOutput("mk_smile_note"),
                     plotOutput("mk_smile_plot", height = "360px")),
                 div(class = "result-card", style = "margin-top: 20px;",
                     h3("Implied vs. historical volatility"),
                     tableOutput("mk_cmp_table"),
                     textOutput("mk_cmp_note")),
                 div(class = "result-card", style = "margin-top: 20px;",
                     h3("Model price vs. market price"),
                     selectInput("mk_vol_win", "Historical volatility used by the model",
                                 choices = c("Last 30 trading days" = "30",
                                             "Last 90 trading days" = "90",
                                             "All returns, about 1 year" = "252"),
                                 selected = "252"),
                     textOutput("mk_model_note"),
                     tableOutput("mk_model_table"),
                     plotOutput("mk_model_plot", height = "360px"))
               )
             )
    )
  )
)



server <- function(input, output, session) {
  res <- reactive({
    withProgress(message = "Calculating...", value = 0.5, calc())
  })
  calc <- reactive({
    validate(
      need(input$S > 0,     "Stock price must be positive."),
      need(input$K > 0,     "Strike must be positive."),
      need(input$sigma > 0, "Volatility must be positive."),
      need(input$T > 0,     "Time to expiry must be positive."),
      need(is.finite(input$r), "Enter an interest rate."),
      need(is.finite(input$q), "Enter a dividend yield.")
    )
    
    if (input$method == "Black-Scholes") {
      list(price = bs_price(input$S, input$K, input$r, input$q,
                            input$sigma, input$T, input$type),
           note = "Black-Scholes is exact for European options only.")
      
    } else if (input$method == "Binomial tree") {
      validate(
        need(is.finite(input$N) && input$N >= 1 && input$N <= 5000,
             "Tree steps must be between 1 and 5000."),
        need(input$N == round(input$N), "Tree steps must be a whole number."))
      p <- tryCatch(
        binomial_price(input$S, input$K, input$r, input$q, input$sigma,
                       input$T, input$N, input$type, input$american),
        error = function(e) e)
      if (inherits(p, "error")) validate(need(FALSE, conditionMessage(p)))
      list(price = p,
           note = if (input$american) "American option, early exercise allowed."
           else "European option.")
      
    } else {
      validate(
        need(input$n >= 1000, "Use at least 1000 simulations."),
        need(input$n %% 2 == 0, "Simulations must be an even number."),
        need(is.finite(input$seed), "Enter a seed."))
      set.seed(input$seed)
      out <- switch(input$mc_kind,
                    "Plain"           = mc_price(input$S, input$K, input$r, input$q,
                                                 input$sigma, input$T, input$n, input$type),
                    "Antithetic"      = mc_price_anti(input$S, input$K, input$r, input$q,
                                                      input$sigma, input$T, input$n, input$type),
                    "Control variate" = mc_price_cv(input$S, input$K, input$r, input$q,
                                                    input$sigma, input$T, input$n, input$type))
      out$note <- "Monte Carlo prices European options only. Results depend on the seed."
      out
    }
  })
  
  output$result <- renderTable({
    x <- res()
    d <- data.frame(Measure = "Price", Value = x$price)
    if (!is.null(x$se)) {
      d <- rbind(d, data.frame(
        Measure = c("Standard error", "95% interval, low", "95% interval, high"),
        Value   = c(x$se, x$lower, x$upper)))
    }
    be <- if (input$type == "call") input$K + x$price else input$K - x$price
    d <- rbind(d, data.frame(Measure = "Break-even stock price at expiry", Value = be))
    d
  }, digits = 4)
  
  output$note <- renderText({
    x <- tryCatch(res(), error = function(e) NULL)
    if (is.null(x)) NULL else x$note
  })
  
  output$greeks <- renderTable({
    x <- tryCatch(res(), error = function(e) NULL)
    req(x)
    data.frame(
      Greek = c("Delta", "Gamma", "Vega (per 1 vol point)",
                "Theta (per day)", "Rho (per 1 rate point)"),
      Value = c(
        bs_delta(input$S, input$K, input$r, input$q, input$sigma, input$T, input$type),
        bs_gamma(input$S, input$K, input$r, input$q, input$sigma, input$T),
        bs_vega(input$S, input$K, input$r, input$q, input$sigma, input$T),
        bs_theta(input$S, input$K, input$r, input$q, input$sigma, input$T, input$type),
        bs_rho(input$S, input$K, input$r, input$q, input$sigma, input$T, input$type)))
  }, digits = 4)
  
  output$payoff <- renderPlot({
    x <- tryCatch(res(), error = function(e) NULL)
    req(x)
    grid   <- seq(0.5 * input$K, 1.5 * input$K, length.out = 200)
    profit <- option_payoff(grid, input$K, input$type) - x$price
    be     <- if (input$type == "call") input$K + x$price else input$K - x$price
    
    plot(grid, profit, type = "l", lwd = 2, col = "steelblue",
         xlab = "Stock price at expiry", ylab = "Profit or loss",
         main = "Profit or loss at expiry (long position)")
    abline(h = 0, col = "grey60")
    abline(v = be, lty = 2, col = "firebrick")
    abline(v = input$S, lty = 3)
  })
  sf_assump <- reactive({
    validate(
      need(input$sf_P0 > 0,    "Premium must be positive."),
      need(input$sf_G > 0,     "Guarantee must be positive."),
      need(input$sf_T > 0,     "Term must be positive."),
      need(is.finite(input$sf_fee) && input$sf_fee >= 0 && input$sf_fee < 1,
           "Fee must be between 0 and 1 (e.g. 0.025)."),
      need(input$sf_sigma > 0, "Volatility must be positive."),
      need(is.finite(input$sf_r), "Enter an interest rate."),
      need(is.finite(input$sf_age) && input$sf_age >= 0 && input$sf_age <= 110,
           "Issue age must be between 0 and 110."),
      need(is.finite(input$sf_lapse) && input$sf_lapse >= 0 && input$sf_lapse < 1,
           "Lapse rate must be between 0 and 1."),
      need(is.finite(input$sf_A) && input$sf_A >= 0, "A must be 0 or more."),
      need(is.finite(input$sf_B) && input$sf_B >= 0, "B must be 0 or more."),
      need(is.finite(input$sf_C) && input$sf_C > 1,  "C must be above 1.")
    )
    a <- seg_defaults()
    a$P0 <- input$sf_P0;   a$G <- input$sf_G;   a$T <- input$sf_T
    a$fee <- input$sf_fee; a$sigma <- input$sf_sigma; a$r <- input$sf_r
    a$age <- input$sf_age; a$lapse <- input$sf_lapse
    a$gm <- list(A = input$sf_A, B = input$sf_B, C = input$sf_C)
    a
  })
  
  sf_res <- reactive({
    a  <- sf_assump()
    ff <- tryCatch(fair_fee(a), error = function(e) NA_real_)
    list(cost = guarantee_cost(a),
         alive = surv_gm(a$age, a$T, a$gm),
         persist = (1 - a$lapse)^a$T,
         inforce = in_force(a),
         cost_dec = guarantee_cost_dec(a),
         fair = ff)
  })
  
  output$sf_table <- renderTable({
    x <- sf_res()
    data.frame(
      Measure = c("Guarantee cost, if the policy lasts to maturity",
                  "Chance alive at maturity",
                  "Chance not lapsed at maturity",
                  "Chance still in force at maturity",
                  "Guarantee cost with mortality and lapses",
                  "Fair guarantee fee (per year)"),
      Value = c(sprintf("%.4f", x$cost),
                sprintf("%.4f", x$alive),
                sprintf("%.4f", x$persist),
                sprintf("%.4f", x$inforce),
                sprintf("%.4f", x$cost_dec),
                if (is.na(x$fair)) "not found"
                else sprintf("%.4f%%", 100 * x$fair)))
  })
  
  output$sf_note <- renderText({
    x <- tryCatch(sf_res(), error = function(e) NULL)
    req(x)
    if (is.na(x$fair)) "The fair fee could not be found for these inputs."
    else "Risk-neutral pricing. Mortality and lapses are assumed independent of each other and of the market. The fair fee treats the whole fee as the guarantee charge."
  })
  
  # ---- Seg fund tab: hedging and reserve (REAL-WORLD measure) ----
  sf_sim <- eventReactive(input$sf_run, {
    a <- sf_assump()
    validate(
      need(is.finite(input$sf_mu), "Enter an expected return (mu)."),
      need(is.finite(input$sf_steps) && input$sf_steps >= 1 &&
             input$sf_steps == round(input$sf_steps),
           "Hedges per year must be a whole number, 1 or more."),
      need(is.finite(input$sf_paths) && input$sf_paths >= 500 &&
             input$sf_paths == round(input$sf_paths),
           "Use at least 500 paths (a whole number)."),
      need(is.finite(input$sf_cte) && input$sf_cte > 0 && input$sf_cte < 1,
           "CTE level must be between 0 and 1."),
      need(is.finite(input$sf_seed), "Enter a seed.")
    )
    a$mu <- input$sf_mu;           a$hedge_steps <- input$sf_steps
    a$n_paths <- input$sf_paths;   a$seed <- input$sf_seed
    a$cte_level <- input$sf_cte
    validate(
      need(abs(a$T * a$hedge_steps - round(a$T * a$hedge_steps)) < 1e-8,
           "Term times hedges per year must be a whole number."),
      need(a$n_paths * a$T * a$hedge_steps <= 6e6,
           "Too large: paths x term x hedges per year must be 6,000,000 or less.")
    )
    
    withProgress(message = "Simulating...", value = 0.5, {
      ff <- tryCatch(fair_fee(a), error = function(e) NA_real_)
      validate(need(!is.na(ff), "The fair fee could not be found for these inputs."))
      a$guar_fee <- ff
      
      set.seed(a$seed)
      F   <- simulate_fund_real(a, a$n_paths)
      last <- ncol(F)
      err <- hedge_error_dec(a, F)
      pay <- in_force(a) * pmax(a$G - F[, last], 0)
      L   <- unhedged_loss(a, F)
      L2  <- unhedged_loss_dec(a, F)
      
      list(below = mean(F[, last] < a$G),
           pay_sd = sd(pay), err_mean = mean(err), err_sd = sd(err),
           removed = 1 - sd(err) / sd(pay),
           L_mean = mean(L),   L_cte = cte(L, a$cte_level),
           L2_mean = mean(L2), L2_cte = cte(L2, a$cte_level),
           fee = ff, level = a$cte_level)
    })
  })
  
  output$sf_sim <- renderTable({
    x <- sf_sim()
    data.frame(
      Measure = c("Share of paths where the fund ends below the guarantee",
                  "Unhedged payout, SD (per policy sold)",
                  "Hedge error, mean (per policy sold)",
                  "Hedge error, SD (per policy sold)",
                  "Risk removed by the hedge",
                  "Mean loss, with mortality and lapses",
                  paste0("CTE", 100 * x$level, ", with mortality and lapses"),
                  "Mean loss, no mortality or lapses",
                  paste0("CTE", 100 * x$level, ", no mortality or lapses"),
                  "Guarantee fee used (fair fee, per year)"),
      Value = c(sprintf("%.4f", x$below),
                sprintf("%.4f", x$pay_sd),
                sprintf("%.4f", x$err_mean),
                sprintf("%.4f", x$err_sd),
                sprintf("%.1f%%", 100 * x$removed),
                sprintf("%.4f", x$L2_mean),
                sprintf("%.4f", x$L2_cte),
                sprintf("%.4f", x$L_mean),
                sprintf("%.4f", x$L_cte),
                sprintf("%.4f%%", 100 * x$fee)))
  })
  
  output$sf_sim_note <- renderText({
    if (input$sf_run == 0) {
      "Click the button to run the simulation (a few seconds)."
    } else {
      x <- tryCatch(sf_sim(), error = function(e) NULL)
      req(x)
      "Real-world simulation (the market grows at mu, not r). Results are from the last click, so click again after changing any input. Assumptions: lapses independent of the market, large pool, delta hedge with no transaction costs, volatility known and constant."
    }
  })
  
  # ---- Seg fund tab: live Canada 10-year yield ----
  goc_info <- reactiveVal(NULL)
  
  fetch_and_fill <- function() {
    withProgress(message = "Fetching rate...", value = 0.5, {
      g <- fetch_goc_yield()
      goc_info(g)
      updateNumericInput(session, "sf_r", value = g$rate)
    })
  }
  
  observeEvent(TRUE, fetch_and_fill(), once = TRUE)     # once, on start
  observeEvent(input$sf_fetch_rate, fetch_and_fill())   # on each click
  
  output$sf_rate_note <- renderText({
    g <- goc_info()
    if (is.null(g)) return("Fetching the latest rate...")
    r <- input$sf_r
    if (!is.finite(r)) return("Enter an interest rate.")
    if (abs(r - g$rate) > 1e-9) {
      "Rate source: manual value (you changed it)."
    } else if (g$source == "live") {
      paste0("Rate source: Bank of Canada 10-year yield, ", g$date, " (live).")
    } else {
      paste0("Rate source: SAVED fallback, ", sprintf("%.2f%%", 100 * g$rate),
             " from ", g$date, ". Could not reach the Bank of Canada.")
    }
  })
  
  # ---- Market tab: load data ----
  mk <- reactiveVal(NULL)
  
  observeEvent(input$mk_load, {
    withProgress(message = "Loading market data...", value = 0.5, {
      m <- fetch_market(input$mk_ticker)
      mk(m)
      if (is.null(m$error)) {
        ex  <- m$expiries[m$expiries >= Sys.Date()]
        far <- ex[ex >= Sys.Date() + 30]
        sel <- if (length(far) > 0) far[1] else tail(ex, 1)
        updateSelectInput(session, "mk_expiry",
                          choices = as.character(ex),
                          selected = as.character(sel))
      } else {
        updateSelectInput(session, "mk_expiry", choices = character(0))
      }
    })
  })
  
  output$mk_table <- renderTable({
    m <- mk()
    req(m)
    validate(need(is.null(m$error), m$error))
    n <- length(m$returns)
    data.frame(
      Measure = c("Ticker", "Last close", "Date of last close",
                  "Historical volatility, last 30 days",
                  "Historical volatility, last 90 days",
                  paste0("Historical volatility, all ", n,
                         " daily returns (about 1 year)"),
                  "Option expiry dates available"),
      Value = c(m$ticker, sprintf("%.2f", m$spot), m$last_date,
                sprintf("%.2f%%", 100 * vol_window(m$returns, 30)),
                sprintf("%.2f%%", 100 * vol_window(m$returns, 90)),
                sprintf("%.2f%%", 100 * hist_vol(m$returns)),
                as.character(length(m$expiries))))
  })
  
  output$mk_note <- renderText({
    m <- mk()
    if (is.null(m)) {
      "Enter a ticker and click Load market data."
    } else if (!is.null(m$error)) {
      NULL
    } else {
      "Prices come from Yahoo Finance and can lag by a day. Historical volatility looks backward; it is not a forecast."
    }
  })
  
  # ---- Market tab: chain for the selected expiry ----
  mk_chain <- reactive({
    m <- mk()
    req(m, is.null(m$error), input$mk_expiry)
    validate(
      need(is.finite(input$mk_r), "Enter an interest rate."),
      need(is.finite(input$mk_q) && input$mk_q >= 0 && input$mk_q < 1,
           "Dividend yield must be between 0 and 1 (e.g. 0.005)."),
      need(is.finite(input$mk_lo) && is.finite(input$mk_hi) &&
             input$mk_lo > 0 && input$mk_lo < 100 &&
             input$mk_hi > 100 && input$mk_hi <= 300,
           "Strike window: lowest % between 0 and 100, highest % between 100 and 300.")
    )
    ex  <- as.Date(input$mk_expiry)
    idx <- match(ex, m$expiries)
    validate(need(!is.na(idx), "Pick an expiry."))
    days <- as.numeric(ex - Sys.Date())
    validate(need(days >= 1, "That expiry is today or in the past. Pick a later one."))
    ch <- m$chain[[idx]]
    need_cols <- c("Strike", "Bid", "Ask", "OI")
    validate(
      need(!is.null(ch$calls) && !is.null(ch$puts) &&
             nrow(ch$calls) > 0 && nrow(ch$puts) > 0,
           "No calls or puts were found for this expiry."),
      need(all(need_cols %in% names(ch$calls)) && all(need_cols %in% names(ch$puts)),
           "The option data is missing expected columns.")
    )
    T_in <- days / 365
    imp  <- implied_spot(ch$calls, ch$puts, m$spot, input$mk_r, input$mk_q, T_in)
    src_choice <- if (is.null(input$mk_spot_src)) "implied" else input$mk_spot_src
    use_imp    <- identical(src_choice, "implied") && is.finite(imp$spot)
    spot_used <- if (use_imp) imp$spot else m$spot
    cl <- clean_chain(ch$calls, ch$puts, spot_used, input$mk_r, input$mk_q,
                      T_in, input$mk_lo / 100, input$mk_hi / 100)
    c(cl, list(expiry = ex, days = days, close = m$spot, close_date = m$last_date,
               implied = imp$spot, n_imp = imp$n,
               spot_used = spot_used, use_imp = use_imp))
  })
  
  output$mk_info <- renderText({
    x <- tryCatch(mk_chain(), error = function(e) NULL)
    req(x)
    src <- if (x$use_imp) {
      paste0("option-implied spot ", sprintf("%.2f", x$implied),
             " (median of ", x$n_imp, " strikes)")
    } else if (is.finite(x$implied)) {
      paste0("last close ", sprintf("%.2f", x$close))
    } else {
      paste0("last close ", sprintf("%.2f", x$close),
             " (no usable call and put pair for an implied spot)")
    }
    paste0("Expiry ", x$expiry, ": ", x$days, " days away (T = ",
           sprintf("%.4f", x$days / 365), " years). Spot used for cleaning: ", src,
           ". For comparison, last close ", sprintf("%.2f", x$close), " from ",
           x$close_date, ". The implied spot depends on the rate and dividend yield you typed.")
  })
  
  output$mk_counts <- renderTable({
    x <- mk_chain()
    data.frame(Step = x$counts$Step, Rows = as.character(x$counts$Rows))
  })
  
  output$mk_quotes <- renderTable({
    x <- tryCatch(mk_chain(), error = function(e) NULL)
    req(x)
    d <- x$clean[order(x$clean$type, x$clean$Strike), ]
    validate(need(nrow(d) > 0, "No quotes survived the cleaning rules."))
    data.frame(Type = d$type,
               Strike = sprintf("%.2f", d$Strike),
               Bid = sprintf("%.2f", d$Bid),
               Ask = sprintf("%.2f", d$Ask),
               Mid = sprintf("%.3f", d$mid),
               `Open interest` = format(d$OI, big.mark = ","),
               check.names = FALSE)
  })
  
  # ---- Market tab: volatility smile ----
  mk_iv <- reactive({
    x <- mk_chain()
    d <- add_implied_vol(x$clean, x$spot_used, input$mk_r, input$mk_q,
                         x$days / 365)
    list(data = d, spot_used = x$spot_used, expiry = x$expiry, days = x$days)
  })
  
  output$mk_smile_note <- renderText({
    x <- tryCatch(mk_iv(), error = function(e) NULL)
    req(x)
    n  <- nrow(x$data)
    req(n > 0)
    ok <- sum(!is.na(x$data$iv))
    paste0(ok, " of ", n, " clean quotes have an implied volatility.",
           if (ok < n) paste0(" ", n - ok, " could not be solved (price at or ",
                              "outside the no-arbitrage limits for this spot ",
                              "and rate) and are left out."),
           " Black-Scholes assumes European exercise; US stock options are American, ",
           "so low-strike puts may be slightly distorted.")
  })
  
  output$mk_smile_plot <- renderPlot({
    x <- tryCatch(mk_iv(), error = function(e) NULL)
    req(x)
    d <- x$data[!is.na(x$data$iv), ]
    req(nrow(d) > 0)
    d  <- d[order(d$Strike), ]
    m  <- mk()
    hv <- hist_vol(m$returns)
    plot(d$Strike, 100 * d$iv, pch = 16,
         col = ifelse(d$type == "put", "firebrick", "steelblue"),
         xlab = "Strike", ylab = "Implied volatility (%)",
         main = paste0(m$ticker, " volatility smile, expiry ", x$expiry),
         ylim = range(c(100 * d$iv, 100 * hv)))
    lines(d$Strike, 100 * d$iv, col = "grey60")
    abline(h = 100 * hv, lty = 2)
    abline(v = x$spot_used, lty = 3)
    legend("topright", bty = "n",
           pch = c(16, 16, NA, NA), lty = c(NA, NA, 2, 3),
           col = c("firebrick", "steelblue", "black", "black"),
           legend = c("Put", "Call", "1-year historical volatility", "Spot used"))
  })
  
  # ---- Market tab: implied vs historical volatility ----
  output$mk_cmp_table <- renderTable({
    x <- tryCatch(mk_iv(), error = function(e) NULL)
    req(x)
    m <- mk()
    a <- atm_iv(x$data, x$spot_used)
    validate(need(is.finite(a$iv), "No implied volatility available to compare."))
    wins <- c(30, 90, 252)
    hv   <- sapply(wins, function(w) vol_window(m$returns, w))
    best <- closest_window(x$days)
    data.frame(
      Measure = c(paste0("Implied, near the money (",
                         paste(a$strikes$type, a$strikes$Strike, collapse = ", "), ")"),
                  "Historical, last 30 trading days",
                  "Historical, last 90 trading days",
                  paste0("Historical, all ", length(m$returns),
                         " returns (about 1 year)")),
      Volatility = sprintf("%.2f%%", 100 * c(a$iv, hv)),
      `Implied minus historical` = c("", sprintf("%+.2f points", 100 * (a$iv - hv))),
      `Closest to this expiry` = c("", ifelse(wins == best, "yes", "")),
      check.names = FALSE)
  })
  
  output$mk_cmp_note <- renderText({
    x <- tryCatch(mk_iv(), error = function(e) NULL)
    req(x)
    a <- atm_iv(x$data, x$spot_used)
    req(is.finite(a$iv))
    paste0("This expiry is ", x$days, " calendar days away, about ",
           round(x$days * 252 / 365), " trading days. Implied above a historical ",
           "number means the options cost more than that period's movement would ",
           "suggest; below means less. The answer depends on the window, and ",
           "historical volatility looks backward. This is a comparison, not advice.")
  })
  
  # ---- Market tab: model price vs market price ----
  mk_model <- reactive({
    x <- mk_iv()
    m <- mk()
    sig <- vol_window(m$returns, as.numeric(input$mk_vol_win))
    req(is.finite(sig), sig > 0)
    d <- x$data[order(x$data$Strike), ]
    list(data = model_vs_market(d, x$spot_used, input$mk_r, input$mk_q,
                                x$days / 365, sig),
         sigma = sig)
  })
  
  output$mk_model_note <- renderText({
    x <- tryCatch(mk_model(), error = function(e) NULL)
    req(x)
    req(nrow(x$data) > 0)
    paste0("Model: Black-Scholes at ", sprintf("%.2f%%", 100 * x$sigma),
           " volatility for every strike. Gap = market mid minus model price, ",
           "per share (a contract is 100 shares). One volatility cannot match a ",
           "smile, so much of the gap is the smile itself. Black-Scholes is ",
           "European and US stock options are American. This is a comparison, ",
           "not advice.")
  })
  
  output$mk_model_table <- renderTable({
    x <- tryCatch(mk_model(), error = function(e) NULL)
    req(x)
    d <- x$data
    req(nrow(d) > 0)
    rows <- lapply(c("put", "call"), function(ty) {
      g <- d$diff[d$type == ty]
      if (length(g) == 0) return(NULL)
      data.frame(Type = ty, Quotes = length(g),
                 `Average gap` = sprintf("%+.3f", mean(g)),
                 `Smallest gap` = sprintf("%+.3f", min(g)),
                 `Largest gap` = sprintf("%+.3f", max(g)),
                 check.names = FALSE)
    })
    do.call(rbind, rows)
  })
  
  output$mk_model_plot <- renderPlot({
    x <- tryCatch(mk_model(), error = function(e) NULL)
    req(x)
    d <- x$data
    req(nrow(d) > 0)
    plot(d$Strike, d$mid, pch = 16, col = "steelblue",
         ylim = range(c(d$mid, d$model)),
         xlab = "Strike", ylab = "Option price",
         main = paste0("Market mid vs. model (",
                       sprintf("%.1f%%", 100 * x$sigma), " volatility)"))
    points(d$Strike, d$model, pch = 1, col = "firebrick", lwd = 2)
    legend("topright", pch = c(16, 1), col = c("steelblue", "firebrick"),
           legend = c("Market mid", "Model"), bty = "n")
  })
}

shinyApp(ui, server)

