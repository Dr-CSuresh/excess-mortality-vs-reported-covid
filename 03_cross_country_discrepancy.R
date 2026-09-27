# 03_cross_country_discrepancy.R
#
# Project: Excess Mortality vs Reported COVID-19 Deaths



# 1. Load packages 

library(tidyverse)
library(here)
library(scales)


# 2. Create output directories if required

if (!dir.exists(here("plots"))) {
  dir.create(
    here("plots"),
    recursive = TRUE
  )
}

if (!dir.exists(here("tables"))) {
  dir.create(
    here("tables"),
    recursive = TRUE
  )
}


# IMPORT DATA



# 3. Import final paired dataset

final_paired <- read_csv(
  here(
    "data",
    "processed",
    "covid_excess_final_paired.csv"
  ),
  show_col_types = FALSE
)


# PREPARE ANALYSIS DATA



# 4. Restrict ratio and log analyses to positive values

comparison_data <- final_paired |>
  filter(
    excess_deaths > 0,
    confirmed_covid_deaths > 0
  ) |>
  mutate(
    
    log10_excess =
      log10(
        excess_deaths
      ),
    
    log10_confirmed =
      log10(
        confirmed_covid_deaths
      ),
    
    excess_reported_ratio =
      excess_deaths /
      confirmed_covid_deaths,
    
    log_ratio =
      log(
        excess_reported_ratio
      ),
    
    percent_difference =
      100 *
      (
        excess_deaths -
          confirmed_covid_deaths
      ) /
      confirmed_covid_deaths
  )


comparison_data


# DESCRIPTIVE COMPARISON



# 5. Summarise excess-to-reported mortality ratios

ratio_summary <- comparison_data |>
  summarise(
    
    n_entities =
      n(),
    
    median_ratio =
      median(
        excess_reported_ratio
      ),
    
    first_quartile =
      quantile(
        excess_reported_ratio,
        0.25
      ),
    
    third_quartile =
      quantile(
        excess_reported_ratio,
        0.75
      ),
    
    minimum =
      min(
        excess_reported_ratio
      ),
    
    maximum =
      max(
        excess_reported_ratio
      ),
    
    percent_excess_above_reported =
      100 *
      mean(
        excess_deaths >
          confirmed_covid_deaths
      )
  )


ratio_summary


# UNCERTAINTY INTERVAL CLASSIFICATION



# 6. Summarise reported mortality relative to excess 95% interval

interval_results <- final_paired |>
  count(
    position_vs_excess_interval
  ) |>
  mutate(
    
    percent =
      100 *
      n /
      sum(n)
  )


interval_results


# CORRELATION



# 7. Calculate Spearman rank correlation

spearman_test <- cor.test(
  comparison_data$confirmed_covid_deaths,
  comparison_data$excess_deaths,
  method = "spearman",
  exact = FALSE
)


spearman_results <- tibble(
  
  method =
    "Spearman rank correlation",
  
  rho =
    unname(
      spearman_test$estimate
    ),
  
  p_value =
    spearman_test$p.value
)


spearman_results


# 8. Calculate Pearson correlation on log10 values

pearson_log_test <- cor.test(
  comparison_data$log10_confirmed,
  comparison_data$log10_excess,
  method = "pearson"
)


pearson_log_results <- tibble(
  
  method =
    "Pearson correlation on log10 values",
  
  correlation =
    unname(
      pearson_log_test$estimate
    ),
  
  lower_95_ci =
    pearson_log_test$conf.int[1],
  
  upper_95_ci =
    pearson_log_test$conf.int[2],
  
  p_value =
    pearson_log_test$p.value
)


pearson_log_results


# LOG-LOG LINEAR REGRESSION



# 9. Fit ordinary linear regression

linear_model <- lm(
  log10_excess ~ log10_confirmed,
  data = comparison_data
)


summary(
  linear_model
)


# 10. Extract linear model results

linear_model_results <- broom::tidy(
  linear_model,
  conf.int = TRUE
)


linear_model_results


linear_model_fit <- broom::glance(
  linear_model
)


linear_model_fit


# ROBUST REGRESSION



# 11. Fit robust regression
#
# Robust regression reduces the influence of countries with
# unusually large discrepancies.

robust_model <- MASS::rlm(
  log10_excess ~ log10_confirmed,
  data = comparison_data
)


summary(
  robust_model
)


robust_results <- tibble(
  
  term =
    names(
      coef(
        robust_model
      )
    ),
  
  estimate =
    as.numeric(
      coef(
        robust_model
      )
    )
)


robust_results


# COMPARE MODEL SLOPES



# 12. Compare ordinary and robust regression coefficients

model_comparison <- tibble(
  
  model = c(
    "Ordinary least squares",
    "Robust regression"
  ),
  
  intercept = c(
    coef(
      linear_model
    )[["(Intercept)"]],
    
    coef(
      robust_model
    )[["(Intercept)"]]
  ),
  
  slope = c(
    coef(
      linear_model
    )[["log10_confirmed"]],
    
    coef(
      robust_model
    )[["log10_confirmed"]]
  )
)


model_comparison


# INFLUENCE DIAGNOSTICS



# 13. Calculate influence statistics

comparison_diagnostics <- comparison_data |>
  mutate(
    
    fitted_log10_excess =
      fitted(
        linear_model
      ),
    
    residual =
      residuals(
        linear_model
      ),
    
    studentized_residual =
      rstudent(
        linear_model
      ),
    
    cooks_distance =
      cooks.distance(
        linear_model
      )
  )


# 14. Define Cook's distance threshold

cooks_threshold <- 4 /
  nrow(
    comparison_diagnostics
  )


cooks_threshold


# 15. Identify influential observations

influential_countries <- comparison_diagnostics |>
  filter(
    cooks_distance >
      cooks_threshold
  ) |>
  arrange(
    desc(
      cooks_distance
    )
  ) |>
  select(
    entity,
    code,
    excess_deaths,
    confirmed_covid_deaths,
    excess_reported_ratio,
    studentized_residual,
    cooks_distance
  )


print(
  influential_countries,
  n = Inf
)


# SENSITIVITY ANALYSIS WITHOUT INFLUENTIAL COUNTRIES



# 16. Refit linear model after excluding influential observations

sensitivity_data <- comparison_diagnostics |>
  filter(
    cooks_distance <=
      cooks_threshold
  )


sensitivity_model <- lm(
  log10_excess ~ log10_confirmed,
  data = sensitivity_data
)


sensitivity_model_results <- broom::tidy(
  sensitivity_model,
  conf.int = TRUE
)


sensitivity_model_results


# 17. Compare primary and influence-adjusted slopes

slope_sensitivity <- tibble(
  
  analysis = c(
    "Primary model",
    "Excluding influential observations"
  ),
  
  n_entities = c(
    nrow(
      comparison_data
    ),
    
    nrow(
      sensitivity_data
    )
  ),
  
  slope = c(
    coef(
      linear_model
    )[["log10_confirmed"]],
    
    coef(
      sensitivity_model
    )[["log10_confirmed"]]
  )
)


slope_sensitivity


# DENOMINATOR THRESHOLD SENSITIVITY



# 18. Examine ratio estimates at different denominator thresholds

thresholds <- c(
  1,
  100,
  1000,
  10000
)


threshold_sensitivity <- map_dfr(
  thresholds,
  function(threshold) {
    
    comparison_data |>
      filter(
        confirmed_covid_deaths >=
          threshold
      ) |>
      summarise(
        
        minimum_reported_deaths =
          threshold,
        
        n_entities =
          n(),
        
        median_ratio =
          median(
            excess_reported_ratio
          ),
        
        first_quartile =
          quantile(
            excess_reported_ratio,
            0.25
          ),
        
        third_quartile =
          quantile(
            excess_reported_ratio,
            0.75
          ),
        
        percent_excess_above_reported =
          100 *
          mean(
            excess_deaths >
              confirmed_covid_deaths
          )
      )
  }
)


threshold_sensitivity


# EXTREME DISCREPANCIES



# 19. Identify largest absolute differences

largest_absolute_gaps <- comparison_data |>
  arrange(
    desc(
      absolute_difference
    )
  ) |>
  select(
    entity,
    code,
    excess_deaths,
    confirmed_covid_deaths,
    absolute_difference,
    excess_reported_ratio
  ) |>
  slice_head(
    n = 20
  )


largest_absolute_gaps


# 20. Identify largest relative differences
#
# Require at least 100 reported deaths to reduce
# instability from very small denominators.

largest_relative_gaps <- comparison_data |>
  filter(
    confirmed_covid_deaths >= 100
  ) |>
  arrange(
    desc(
      excess_reported_ratio
    )
  ) |>
  select(
    entity,
    code,
    excess_deaths,
    confirmed_covid_deaths,
    excess_reported_ratio,
    absolute_difference
  ) |>
  slice_head(
    n = 20
  )


largest_relative_gaps


# VISUALISATION 1: EXCESS VS REPORTED



# 21. Identify countries to label

label_countries <- comparison_data |>
  slice_max(
    order_by = absolute_difference,
    n = 12,
    with_ties = FALSE
  ) |>
  pull(entity)


# 22. Plot excess mortality against reported COVID deaths

plot_comparison <- comparison_data |>
  ggplot(
    aes(
      x = confirmed_covid_deaths,
      y = excess_deaths
    )
  ) +
  geom_abline(
    slope = 1,
    intercept = 0,
    linetype = "dashed"
  ) +
  geom_point(
    alpha = 0.7
  ) +
  geom_text(
    data =
      comparison_data |>
      filter(
        entity %in%
          label_countries
      ),
    aes(
      label = entity
    ),
    check_overlap = TRUE,
    hjust = -0.05,
    size = 3
  ) +
  scale_x_log10(
    labels = label_comma()
  ) +
  scale_y_log10(
    labels = label_comma()
  ) +
  labs(
    title = "Estimated excess mortality versus reported COVID-19 deaths",
    subtitle = "Final approximately aligned cumulative values by country",
    x = "Reported COVID-19 deaths",
    y = "Estimated excess deaths",
    caption = "Dashed line represents equal excess and reported mortality."
  ) +
  theme_minimal(
    base_size = 12
  )


plot_comparison


ggsave(
  here(
    "plots",
    "01_excess_vs_reported_covid_deaths.png"
  ),
  plot_comparison,
  width = 10,
  height = 7,
  dpi = 300
)


# VISUALISATION 2: RATIO DISTRIBUTION



# 23. Plot distribution of excess-to-reported ratio

plot_ratio_distribution <- comparison_data |>
  filter(
    confirmed_covid_deaths >= 100
  ) |>
  ggplot(
    aes(
      x = excess_reported_ratio
    )
  ) +
  geom_histogram(
    bins = 30
  ) +
  geom_vline(
    xintercept = 1,
    linetype = "dashed"
  ) +
  scale_x_log10() +
  labs(
    title = "Distribution of excess-to-reported mortality ratios",
    subtitle = "Countries with at least 100 reported COVID-19 deaths",
    x = "Excess-to-reported mortality ratio (log scale)",
    y = "Number of countries",
    caption = "Values above 1 indicate estimated excess deaths exceeded reported COVID-19 deaths."
  ) +
  theme_minimal(
    base_size = 12
  )


plot_ratio_distribution


ggsave(
  here(
    "plots",
    "02_excess_reported_ratio_distribution.png"
  ),
  plot_ratio_distribution,
  width = 9,
  height = 6,
  dpi = 300
)


# VISUALISATION 3: LARGEST RELATIVE DISCREPANCIES



# 24. Prepare top relative discrepancies

top_relative_plot_data <- largest_relative_gaps |>
  slice_head(
    n = 20
  ) |>
  mutate(
    
    entity =
      fct_reorder(
        entity,
        excess_reported_ratio
      )
  )


# 25. Plot largest relative discrepancies

plot_relative_gaps <- top_relative_plot_data |>
  ggplot(
    aes(
      x = excess_reported_ratio,
      y = entity
    )
  ) +
  geom_point(
    size = 2
  ) +
  geom_segment(
    aes(
      x = 1,
      xend = excess_reported_ratio,
      y = entity,
      yend = entity
    )
  ) +
  scale_x_log10() +
  labs(
    title = "Largest excess-to-reported mortality ratios",
    subtitle = "Restricted to countries with at least 100 reported COVID-19 deaths",
    x = "Excess-to-reported mortality ratio (log scale)",
    y = NULL
  ) +
  theme_minimal(
    base_size = 12
  )


plot_relative_gaps


ggsave(
  here(
    "plots",
    "03_largest_relative_discrepancies.png"
  ),
  plot_relative_gaps,
  width = 9,
  height = 7,
  dpi = 300
)


# VISUALISATION 4: MODEL INFLUENCE



# 26. Plot Cook's distance

plot_influence <- comparison_diagnostics |>
  arrange(
    cooks_distance
  ) |>
  mutate(
    
    rank =
      row_number()
  ) |>
  ggplot(
    aes(
      x = rank,
      y = cooks_distance
    )
  ) +
  geom_point() +
  geom_hline(
    yintercept =
      cooks_threshold,
    linetype = "dashed"
  ) +
  labs(
    title = "Influence diagnostics for log-log mortality model",
    subtitle = "Cook's distance across country observations",
    x = "Country observation",
    y = "Cook's distance",
    caption = "Dashed line represents the 4/n influence threshold."
  ) +
  theme_minimal(
    base_size = 12
  )


plot_influence


ggsave(
  here(
    "plots",
    "04_regression_influence_diagnostics.png"
  ),
  plot_influence,
  width = 9,
  height = 6,
  dpi = 300
)


# SAVE OUTPUTS



# 27. Save comparison dataset

write_csv(
  comparison_data,
  here(
    "data",
    "processed",
    "covid_excess_comparison.csv"
  )
)


# 28. Save descriptive results

write_csv(
  ratio_summary,
  here(
    "tables",
    "ratio_summary.csv"
  )
)


write_csv(
  interval_results,
  here(
    "tables",
    "interval_results.csv"
  )
)


# 29. Save correlation results

write_csv(
  spearman_results,
  here(
    "tables",
    "spearman_correlation.csv"
  )
)


write_csv(
  pearson_log_results,
  here(
    "tables",
    "log_correlation.csv"
  )
)


# 30. Save regression results

write_csv(
  linear_model_results,
  here(
    "tables",
    "log_log_linear_model.csv"
  )
)


write_csv(
  robust_results,
  here(
    "tables",
    "robust_regression.csv"
  )
)


write_csv(
  model_comparison,
  here(
    "tables",
    "regression_model_comparison.csv"
  )
)


# 31. Save influence diagnostics

write_csv(
  influential_countries,
  here(
    "tables",
    "influential_countries.csv"
  )
)


write_csv(
  sensitivity_model_results,
  here(
    "tables",
    "influence_sensitivity_model.csv"
  )
)


write_csv(
  slope_sensitivity,
  here(
    "tables",
    "slope_sensitivity.csv"
  )
)


# 32. Save threshold sensitivity

write_csv(
  threshold_sensitivity,
  here(
    "tables",
    "ratio_threshold_sensitivity.csv"
  )
)


# 33. Save discrepancy tables

write_csv(
  largest_absolute_gaps,
  here(
    "tables",
    "largest_absolute_gaps.csv"
  )
)


write_csv(
  largest_relative_gaps,
  here(
    "tables",
    "largest_relative_gaps.csv"
  )
)



message(
  "Cross-country COVID excess mortality analysis complete."
)