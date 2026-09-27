# 04_temporal_discrepancy.R
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



# 3. Import annual paired dataset

annual_paired <- read_csv(
  here(
    "data",
    "processed",
    "covid_excess_annual_paired.csv"
  ),
  show_col_types = FALSE
)


# PREPARE DATA



# 4. Create annual ratio variables

annual_analysis <- annual_paired |>
  mutate(
    
    excess_reported_ratio =
      if_else(
        excess_deaths > 0 &
          confirmed_covid_deaths > 0,
        
        excess_deaths /
          confirmed_covid_deaths,
        
        NA_real_
      ),
    
    log_ratio =
      if_else(
        excess_reported_ratio > 0,
        
        log(
          excess_reported_ratio
        ),
        
        NA_real_
      )
  )


# ANNUAL SUMMARY



# 5. Summarise annual discrepancies

annual_ratio_summary <- annual_analysis |>
  group_by(year) |>
  summarise(
    
    paired_entities =
      n(),
    
    positive_ratio_entities =
      sum(
        !is.na(
          excess_reported_ratio
        )
      ),
    
    median_ratio =
      median(
        excess_reported_ratio,
        na.rm = TRUE
      ),
    
    first_quartile =
      quantile(
        excess_reported_ratio,
        0.25,
        na.rm = TRUE
      ),
    
    third_quartile =
      quantile(
        excess_reported_ratio,
        0.75,
        na.rm = TRUE
      ),
    
    percent_excess_above_reported =
      100 *
      mean(
        excess_deaths >
          confirmed_covid_deaths,
        na.rm = TRUE
      ),
    
    .groups = "drop"
  )


annual_ratio_summary


# UNCERTAINTY INTERVALS OVER TIME



# 6. Summarise position relative to excess-mortality interval

annual_interval_summary <- annual_analysis |>
  count(
    year,
    position_vs_excess_interval
  ) |>
  group_by(year) |>
  mutate(
    
    percent =
      100 *
      n /
      sum(n)
  ) |>
  ungroup()


annual_interval_summary


# 2020 VS 2023 PAIRED COMPARISON



# 7. Create paired 2020 and 2023 dataset

paired_2020_2023 <- annual_analysis |>
  filter(
    year %in% c(
      2020,
      2023
    ),
    !is.na(
      log_ratio
    )
  ) |>
  select(
    entity,
    code,
    year,
    excess_reported_ratio,
    log_ratio
  ) |>
  pivot_wider(
    names_from = year,
    values_from = c(
      excess_reported_ratio,
      log_ratio
    ),
    names_sep = "_"
  ) |>
  filter(
    !is.na(log_ratio_2020),
    !is.na(log_ratio_2023)
  )


paired_2020_2023


# 8. Summarise within-country change

paired_change_summary <- paired_2020_2023 |>
  summarise(
    
    n_countries =
      n(),
    
    median_ratio_2020 =
      median(
        excess_reported_ratio_2020
      ),
    
    median_ratio_2023 =
      median(
        excess_reported_ratio_2023
      ),
    
    median_log_ratio_change =
      median(
        log_ratio_2023 -
          log_ratio_2020
      ),
    
    percent_ratio_increased =
      100 *
      mean(
        excess_reported_ratio_2023 >
          excess_reported_ratio_2020
      ),
    
    percent_ratio_decreased =
      100 *
      mean(
        excess_reported_ratio_2023 <
          excess_reported_ratio_2020
      )
  )


paired_change_summary


# PAIRED WILCOXON TEST



# 9. Test within-country change in log ratio

wilcoxon_test <- wilcox.test(
  paired_2020_2023$log_ratio_2023,
  paired_2020_2023$log_ratio_2020,
  paired = TRUE,
  exact = FALSE
)


wilcoxon_results <- tibble(
  
  test =
    "Paired Wilcoxon signed-rank test",
  
  statistic =
    unname(
      wilcoxon_test$statistic
    ),
  
  p_value =
    wilcoxon_test$p.value
)


wilcoxon_results


# PERSISTENCE OF DISCREPANCY



# 10. Measure persistence of interval classification

country_persistence <- annual_analysis |>
  group_by(
    entity,
    code
  ) |>
  summarise(
    
    years_observed =
      n(),
    
    years_reported_below_interval =
      sum(
        position_vs_excess_interval ==
          "Reported below excess 95% interval"
      ),
    
    years_reported_within_interval =
      sum(
        position_vs_excess_interval ==
          "Reported within excess 95% interval"
      ),
    
    years_reported_above_interval =
      sum(
        position_vs_excess_interval ==
          "Reported above excess 95% interval"
      ),
    
    .groups = "drop"
  ) |>
  mutate(
    
    persistent_below_interval =
      years_observed >= 3 &
      years_reported_below_interval >= 3
  )


country_persistence


# 11. Summarise persistent discrepancy

persistence_summary <- country_persistence |>
  filter(
    years_observed >= 3
  ) |>
  summarise(
    
    countries_with_at_least_3_years =
      n(),
    
    persistently_below_interval =
      sum(
        persistent_below_interval
      ),
    
    percent_persistently_below =
      100 *
      mean(
        persistent_below_interval
      )
  )


persistence_summary


# VISUALISATION 1: ANNUAL MEDIAN RATIO



# 12. Plot annual median ratio

plot_annual_ratio <- annual_ratio_summary |>
  ggplot(
    aes(
      x = year,
      y = median_ratio
    )
  ) +
  geom_ribbon(
    aes(
      ymin = first_quartile,
      ymax = third_quartile
    ),
    alpha = 0.2
  ) +
  geom_line(
    linewidth = 0.9
  ) +
  geom_point(
    size = 2
  ) +
  geom_hline(
    yintercept = 1,
    linetype = "dashed"
  ) +
  scale_x_continuous(
    breaks = c(
      2020,
      2021,
      2022,
      2023
    )
  ) +
  labs(
    title = "Excess-to-reported mortality ratio over time",
    subtitle = "Median and interquartile range across countries",
    x = "Year",
    y = "Median excess-to-reported mortality ratio",
    caption = "Values above 1 indicate estimated excess deaths exceeded reported COVID-19 deaths."
  ) +
  theme_minimal(
    base_size = 12
  )


plot_annual_ratio


ggsave(
  here(
    "plots",
    "05_annual_excess_reported_ratio.png"
  ),
  plot_annual_ratio,
  width = 9,
  height = 6,
  dpi = 300
)


# VISUALISATION 2: INTERVAL CLASSIFICATION



# 13. Plot annual uncertainty interval classification

plot_interval_time <- annual_interval_summary |>
  ggplot(
    aes(
      x = factor(year),
      y = percent,
      fill = position_vs_excess_interval
    )
  ) +
  geom_col() +
  labs(
    title = "Reported COVID-19 mortality relative to excess-mortality uncertainty",
    subtitle = "Annual country classification using the estimated excess-mortality 95% interval",
    x = "Year",
    y = "Countries (%)",
    fill = NULL
  ) +
  theme_minimal(
    base_size = 12
  ) +
  theme(
    legend.position = "bottom"
  )


plot_interval_time


ggsave(
  here(
    "plots",
    "06_annual_interval_classification.png"
  ),
  plot_interval_time,
  width = 10,
  height = 6,
  dpi = 300
)


# VISUALISATION 3: WITHIN-COUNTRY CHANGE



# 14. Plot 2020 versus 2023 ratios

plot_paired_change <- paired_2020_2023 |>
  ggplot(
    aes(
      x = excess_reported_ratio_2020,
      y = excess_reported_ratio_2023
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
  scale_x_log10() +
  scale_y_log10() +
  labs(
    title = "Within-country change in excess-to-reported mortality ratios",
    subtitle = "Comparison of cumulative ratios in 2020 and 2023",
    x = "2020 ratio",
    y = "2023 ratio",
    caption = "Points above the dashed line had a higher excess-to-reported ratio in 2023 than in 2020."
  ) +
  theme_minimal(
    base_size = 12
  )


plot_paired_change


ggsave(
  here(
    "plots",
    "07_2020_vs_2023_ratio_change.png"
  ),
  plot_paired_change,
  width = 8,
  height = 7,
  dpi = 300
)


# SAVE OUTPUTS



# 15. Save annual summaries

write_csv(
  annual_ratio_summary,
  here(
    "tables",
    "annual_ratio_summary.csv"
  )
)


write_csv(
  annual_interval_summary,
  here(
    "tables",
    "annual_interval_summary.csv"
  )
)


# 16. Save paired change analysis

write_csv(
  paired_2020_2023,
  here(
    "data",
    "processed",
    "covid_ratio_2020_2023_paired.csv"
  )
)


write_csv(
  paired_change_summary,
  here(
    "tables",
    "paired_2020_2023_summary.csv"
  )
)


write_csv(
  wilcoxon_results,
  here(
    "tables",
    "paired_wilcoxon_test.csv"
  )
)


# 17. Save persistence analysis

write_csv(
  country_persistence,
  here(
    "tables",
    "country_discrepancy_persistence.csv"
  )
)


write_csv(
  persistence_summary,
  here(
    "tables",
    "discrepancy_persistence_summary.csv"
  )
)



message(
  "Temporal COVID excess mortality discrepancy analysis complete."
)