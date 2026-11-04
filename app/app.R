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
                                  numericInput("N", "Tree steps (N)", 50, min = 1, max = 5000,step = 10),
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
    )
  )
)

server <- function(input, output) {
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
}

shinyApp(ui, server)

