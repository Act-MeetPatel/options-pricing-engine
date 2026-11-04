library(shiny)

ui <- fluidPage(
  titlePanel("Toy app: option payoffs"),
  sliderInput("st", "Stock price at expiry", min = 50, max = 150,
              value = 100),
  textOutput("call_pay"),
  textOutput("put_pay")
)

server <- function(input, output) {
  output$call_pay <- renderText(paste("Call pays:", max(input$st - 100, 0)))
  output$put_pay  <- renderText(paste("Put pays:",  max(100 - input$st, 0)))
}

shinyApp(ui, server)
