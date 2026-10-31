# Urban Population Forecast Dashboard (Shiny)
# Run this file in RStudio to launch an interactive dashboard.

required_packages <- c("shiny", "dplyr", "ggplot2", "readr", "DT", "scales")
missing_packages <- required_packages[!required_packages %in% rownames(installed.packages())]
if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}
invisible(lapply(required_packages, library, character.only = TRUE))

forecast_file <- "urban_population_forecast_next_6_months.csv"
summary_file <- "urban_population_forecast_summary.csv"
forecast_script <- "urban_population_forecast.R"

# If forecast outputs are missing, run the forecast script once.
if (!file.exists(forecast_file) || !file.exists(summary_file)) {
  if (!file.exists(forecast_script)) {
    stop("urban_population_forecast.R not found in this folder.")
  }
  message("Forecast CSVs not found. Running urban_population_forecast.R ...")
  source(forecast_script, local = TRUE)
}

forecast_data <- readr::read_csv(forecast_file, show_col_types = FALSE) %>%
  dplyr::mutate(forecast_month = as.Date(forecast_month))

summary_data <- readr::read_csv(summary_file, show_col_types = FALSE)

country_choices <- sort(unique(forecast_data$country))

ui <- shiny::fluidPage(
  shiny::titlePanel("Urban Population % Forecast Dashboard"),

  shiny::sidebarLayout(
    shiny::sidebarPanel(
      shiny::selectInput(
        inputId = "country_select",
        label = "Select country:",
        choices = country_choices,
        selected = country_choices[1]
      ),
      shiny::sliderInput(
        inputId = "top_n",
        label = "Top countries by 6-month increase:",
        min = 5,
        max = 30,
        value = 10,
        step = 1
      )
    ),

    shiny::mainPanel(
      shiny::fluidRow(
        shiny::column(4, shiny::wellPanel(shiny::h4("Month 6 Predicted %"), shiny::textOutput("kpi_month6"))),
        shiny::column(4, shiny::wellPanel(shiny::h4("Total 6-Month Increase"), shiny::textOutput("kpi_6m_change"))),
        shiny::column(4, shiny::wellPanel(shiny::h4("Average Monthly Increase"), shiny::textOutput("kpi_avg_monthly")))
      ),

      shiny::h3("Selected Country Forecast Trend"),
      shiny::plotOutput("country_forecast_plot", height = "300px"),

      shiny::h3("Selected Country Monthly Increase Cycle"),
      shiny::plotOutput("country_increase_plot", height = "280px"),

      shiny::h3("Top Countries by Predicted 6-Month Increase"),
      DT::DTOutput("top_countries_table"),

      shiny::h3("Selected Country - 6 Month Detailed Forecast"),
      DT::DTOutput("country_detail_table")
    )
  )
)

server <- function(input, output, session) {
  selected_country_data <- shiny::reactive({
    forecast_data %>% dplyr::filter(country == input$country_select)
  })

  selected_country_summary <- shiny::reactive({
    summary_data %>% dplyr::filter(country == input$country_select)
  })

  output$kpi_month6 <- shiny::renderText({
    row <- selected_country_summary()
    if (nrow(row) == 0) return("NA")
    paste0(round(row$month_6_prediction[1], 3), "%")
  })

  output$kpi_6m_change <- shiny::renderText({
    row <- selected_country_summary()
    if (nrow(row) == 0) return("NA")
    paste0(round(row$current_to_6m_change[1], 3), " pp")
  })

  output$kpi_avg_monthly <- shiny::renderText({
    df <- selected_country_data()
    if (nrow(df) == 0) return("NA")
    paste0(round(mean(df$monthly_increase_percent_points, na.rm = TRUE), 4), " pp")
  })

  output$country_forecast_plot <- shiny::renderPlot({
    df <- selected_country_data()
    if (nrow(df) == 0) return(NULL)

    ggplot2::ggplot(df, ggplot2::aes(x = forecast_month, y = predicted_urban_percent)) +
      ggplot2::geom_line(color = "#1f78b4", linewidth = 1.2) +
      ggplot2::geom_point(color = "#1f78b4", size = 2) +
      ggplot2::labs(
        x = "Forecast Month",
        y = "Predicted Urban Population (%)"
      ) +
      ggplot2::scale_y_continuous(labels = scales::label_number(accuracy = 0.01)) +
      ggplot2::theme_minimal()
  })

  output$country_increase_plot <- shiny::renderPlot({
    df <- selected_country_data()
    if (nrow(df) == 0) return(NULL)

    ggplot2::ggplot(df, ggplot2::aes(x = forecast_month, y = monthly_increase_percent_points)) +
      ggplot2::geom_col(fill = "#33a02c", alpha = 0.85) +
      ggplot2::labs(
        x = "Forecast Month",
        y = "Monthly Increase (percentage points)"
      ) +
      ggplot2::theme_minimal()
  })

  output$top_countries_table <- DT::renderDT({
    summary_data %>%
      dplyr::arrange(dplyr::desc(current_to_6m_change)) %>%
      dplyr::slice_head(n = input$top_n) %>%
      dplyr::rename(
        Country = country,
        `6-Month Increase (pp)` = current_to_6m_change,
        `Month 6 Predicted (%)` = month_6_prediction
      ) %>%
      DT::datatable(options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  output$country_detail_table <- DT::renderDT({
    selected_country_data() %>%
      dplyr::transmute(
        `Forecast Month` = format(forecast_month, "%Y-%m"),
        `Predicted Urban Population (%)` = round(predicted_urban_percent, 4),
        `Monthly Increase (pp)` = round(monthly_increase_percent_points, 4)
      ) %>%
      DT::datatable(options = list(pageLength = 6, dom = "t"), rownames = FALSE)
  })
}

shiny::shinyApp(ui = ui, server = server)
