# Urban Population Percentage Forecast by Country (Next 6 Months)
# Runs in RStudio. It downloads data from the World Bank automatically.

required_packages <- c(
  "WDI",
  "dplyr",
  "tidyr",
  "purrr",
  "tibble",
  "forecast",
  "zoo",
  "ggplot2",
  "readr",
  "lubridate"
)

missing_packages <- required_packages[!required_packages %in% rownames(installed.packages())]
if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

invisible(lapply(required_packages, library, character.only = TRUE))

# ---------------------------
# CONFIGURATION
# ---------------------------
start_year <- 1990
forecast_months <- 6
min_observations <- 10

# World Bank indicator:
# SP.URB.TOTL.IN.ZS = Urban population (% of total population)
indicator_code <- "SP.URB.TOTL.IN.ZS"

message("Downloading data from World Bank...")

urban_data <- WDI::WDI(
  country = "all",
  indicator = indicator_code,
  start = start_year,
  end = as.numeric(format(Sys.Date(), "%Y")),
  extra = FALSE
) %>%
  dplyr::rename(urban_percent = !!indicator_code) %>%
  dplyr::filter(!is.na(urban_percent)) %>%
  dplyr::arrange(iso2c, year)

if (nrow(urban_data) == 0) {
  stop("No data downloaded. Check internet connection and try again.")
}

message("Creating monthly series and forecasting by country...")

build_country_forecast <- function(df_country, forecast_months = 6, min_observations = 10) {
  if (nrow(df_country) < min_observations) {
    return(NULL)
  }

  df_country <- df_country %>%
    dplyr::arrange(year) %>%
    dplyr::distinct(year, .keep_all = TRUE)

  # Build annual time index and convert to monthly by interpolation
  annual_dates <- as.Date(paste0(df_country$year, "-01-01"))
  monthly_dates <- seq(min(annual_dates), max(annual_dates), by = "month")

  monthly_values <- zoo::na.approx(
    x = df_country$urban_percent[match(format(monthly_dates, "%Y"), as.character(df_country$year))],
    xout = seq_along(monthly_dates),
    na.rm = FALSE
  )

  # Fallback interpolation if above mapping leaves too many NAs
  if (all(is.na(monthly_values)) || sum(!is.na(monthly_values)) < 12) {
    monthly_values <- zoo::na.spline(
      x = zoo::zoo(df_country$urban_percent, annual_dates),
      xout = monthly_dates
    )
    monthly_values <- as.numeric(monthly_values)
  } else {
    monthly_values <- zoo::na.locf(monthly_values, na.rm = FALSE)
    monthly_values <- zoo::na.locf(monthly_values, fromLast = TRUE, na.rm = FALSE)
  }

  monthly_values <- as.numeric(monthly_values)

  if (sum(!is.na(monthly_values)) < 24) {
    return(NULL)
  }

  ts_data <- stats::ts(
    monthly_values,
    frequency = 12,
    start = c(lubridate::year(min(monthly_dates)), lubridate::month(min(monthly_dates)))
  )

  model <- forecast::ets(ts_data)
  fc <- forecast::forecast(model, h = forecast_months)

  future_months <- seq(max(monthly_dates) %m+% months(1), by = "month", length.out = forecast_months)
  predicted <- as.numeric(fc$mean)
  increase <- c(predicted[1] - tail(monthly_values, 1), diff(predicted))

  tibble::tibble(
    iso2c = df_country$iso2c[1],
    country = df_country$country[1],
    forecast_month = future_months,
    predicted_urban_percent = round(predicted, 4),
    monthly_increase_percent_points = round(increase, 4)
  )
}

country_list <- split(urban_data, urban_data$iso2c)

all_forecasts <- purrr::map_dfr(
  country_list,
  build_country_forecast,
  forecast_months = forecast_months,
  min_observations = min_observations
)

if (nrow(all_forecasts) == 0) {
  stop("No forecasts generated. Try reducing min_observations or changing start_year.")
}

# Save full forecast output
readr::write_csv(all_forecasts, "urban_population_forecast_next_6_months.csv")

# Create a summary: total increase over next 6 months per country
summary_forecast <- all_forecasts %>%
  dplyr::group_by(iso2c, country) %>%
  dplyr::summarise(
    current_to_6m_change = round(sum(monthly_increase_percent_points), 4),
    month_6_prediction = round(dplyr::last(predicted_urban_percent), 4),
    .groups = "drop"
  ) %>%
  dplyr::arrange(dplyr::desc(current_to_6m_change))

readr::write_csv(summary_forecast, "urban_population_forecast_summary.csv")

message("Forecast files created:")
message(" - urban_population_forecast_next_6_months.csv")
message(" - urban_population_forecast_summary.csv")

# Optional quick chart for one country (edit country code as needed)
example_country <- "IN" # Example: India
plot_df <- all_forecasts %>% dplyr::filter(iso2c == example_country)

if (nrow(plot_df) > 0) {
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = forecast_month, y = predicted_urban_percent)) +
    ggplot2::geom_line(color = "#2C7FB8", linewidth = 1) +
    ggplot2::geom_point(color = "#2C7FB8", size = 2) +
    ggplot2::labs(
      title = paste0("6-Month Urban Population % Forecast: ", unique(plot_df$country)),
      x = "Month",
      y = "Predicted Urban Population (%)"
    ) +
    ggplot2::theme_minimal()

  print(p)
}

message("Done.")
