# 01_data_audit.R
#
# Project: Excess Mortality vs Reported COVID-19 Deaths



# 1. Load packages 

library(tidyverse)
library(here)


# IMPORT DATA



# 2. Import raw data

covid_raw <- read_csv(
  here(
    "data",
    "raw",
    "4- excess-deaths-cumulative-economist-single-entity.csv"
  ),
  show_col_types = FALSE
)


# BASIC STRUCTURE



# 3. Inspect dataset dimensions

dataset_dimensions <- tibble(
  
  rows =
    nrow(covid_raw),
  
  columns =
    ncol(covid_raw)
)


dataset_dimensions


# 4. Inspect variable names

names(
  covid_raw
)


# 5. Inspect variable types

glimpse(
  covid_raw
)


# TEMPORAL COVERAGE



# 6. Examine overall date coverage

date_coverage <- covid_raw |>
  summarise(
    
    first_date =
      min(
        Day,
        na.rm = TRUE
      ),
    
    last_date =
      max(
        Day,
        na.rm = TRUE
      ),
    
    number_of_dates =
      n_distinct(
        Day
      )
  )


date_coverage


# ENTITY COVERAGE



# 7. Count entities and country codes

entity_coverage <- covid_raw |>
  summarise(
    
    number_of_entities =
      n_distinct(
        Entity
      ),
    
    number_of_codes =
      n_distinct(
        Code,
        na.rm = TRUE
      ),
    
    missing_codes =
      sum(
        is.na(
          Code
        )
      )
  )


entity_coverage


# 8. List entities without country codes

uncoded_entities <- covid_raw |>
  filter(
    is.na(
      Code
    )
  ) |>
  distinct(
    Entity
  ) |>
  arrange(
    Entity
  )


print(
  uncoded_entities,
  n = Inf
)


# 9. Examine observation coverage by entity

entity_observation_summary <- covid_raw |>
  group_by(
    Entity,
    Code
  ) |>
  summarise(
    
    first_date =
      min(
        Day,
        na.rm = TRUE
      ),
    
    last_date =
      max(
        Day,
        na.rm = TRUE
      ),
    
    observations =
      n(),
    
    excess_death_observations =
      sum(
        !is.na(
          cumulative_estimated_daily_excess_deaths
        )
      ),
    
    confirmed_covid_death_observations =
      sum(
        !is.na(
          `Total confirmed deaths due to COVID-19`
        )
      ),
    
    .groups = "drop"
  ) |>
  arrange(
    desc(
      observations
    )
  )


print(
  entity_observation_summary,
  n = Inf
)


# MISSING DATA



# 10. Calculate missingness for every variable

missingness <- covid_raw |>
  summarise(
    across(
      everything(),
      ~ sum(
        is.na(.)
      )
    )
  ) |>
  pivot_longer(
    cols = everything(),
    names_to = "variable",
    values_to = "missing"
  ) |>
  mutate(
    
    percent_missing =
      100 *
      missing /
      nrow(
        covid_raw
      )
  ) |>
  arrange(
    desc(
      missing
    )
  )


missingness


# DUPLICATES



# 11. Check completely duplicated rows

duplicate_rows <- covid_raw |>
  duplicated() |>
  sum()


duplicate_rows


# 12. Check duplicate entity-date observations

duplicate_entity_dates <- covid_raw |>
  count(
    Entity,
    Day
  ) |>
  filter(
    n > 1
  )


duplicate_entity_dates


# DATE INTERVALS



# 13. Examine spacing between observations

date_intervals <- covid_raw |>
  arrange(
    Entity,
    Day
  ) |>
  group_by(
    Entity
  ) |>
  mutate(
    
    days_since_previous =
      as.numeric(
        Day -
          lag(
            Day
          )
      )
  ) |>
  ungroup()


interval_summary <- date_intervals |>
  count(
    days_since_previous,
    sort = TRUE
  )


print(
  interval_summary,
  n = Inf
)


# EXCESS DEATH ESTIMATES



# 14. Summarise cumulative estimated excess deaths

excess_death_summary <- covid_raw |>
  summarise(
    
    minimum =
      min(
        cumulative_estimated_daily_excess_deaths,
        na.rm = TRUE
      ),
    
    first_quartile =
      quantile(
        cumulative_estimated_daily_excess_deaths,
        0.25,
        na.rm = TRUE
      ),
    
    median =
      median(
        cumulative_estimated_daily_excess_deaths,
        na.rm = TRUE
      ),
    
    mean =
      mean(
        cumulative_estimated_daily_excess_deaths,
        na.rm = TRUE
      ),
    
    third_quartile =
      quantile(
        cumulative_estimated_daily_excess_deaths,
        0.75,
        na.rm = TRUE
      ),
    
    maximum =
      max(
        cumulative_estimated_daily_excess_deaths,
        na.rm = TRUE
      )
  )


excess_death_summary


# 15. Count negative cumulative excess-death estimates

negative_excess_deaths <- covid_raw |>
  summarise(
    
    negative_observations =
      sum(
        cumulative_estimated_daily_excess_deaths < 0,
        na.rm = TRUE
      ),
    
    zero_observations =
      sum(
        cumulative_estimated_daily_excess_deaths == 0,
        na.rm = TRUE
      ),
    
    positive_observations =
      sum(
        cumulative_estimated_daily_excess_deaths > 0,
        na.rm = TRUE
      )
  )


negative_excess_deaths


# CONFIRMED COVID-19 DEATHS



# 16. Summarise confirmed COVID-19 deaths

confirmed_death_summary <- covid_raw |>
  summarise(
    
    minimum =
      min(
        `Total confirmed deaths due to COVID-19`,
        na.rm = TRUE
      ),
    
    median =
      median(
        `Total confirmed deaths due to COVID-19`,
        na.rm = TRUE
      ),
    
    maximum =
      max(
        `Total confirmed deaths due to COVID-19`,
        na.rm = TRUE
      ),
    
    observed =
      sum(
        !is.na(
          `Total confirmed deaths due to COVID-19`
        )
      ),
    
    missing =
      sum(
        is.na(
          `Total confirmed deaths due to COVID-19`
        )
      )
  )


confirmed_death_summary


# CONFIDENCE INTERVAL CHECKS



# 17. Check whether confidence intervals are ordered correctly

confidence_interval_checks <- covid_raw |>
  summarise(
    
    estimate_below_lower =
      sum(
        cumulative_estimated_daily_excess_deaths <
          cumulative_estimated_daily_excess_deaths_ci_95_bot,
        na.rm = TRUE
      ),
    
    estimate_above_upper =
      sum(
        cumulative_estimated_daily_excess_deaths >
          cumulative_estimated_daily_excess_deaths_ci_95_top,
        na.rm = TRUE
      ),
    
    lower_above_upper =
      sum(
        cumulative_estimated_daily_excess_deaths_ci_95_bot >
          cumulative_estimated_daily_excess_deaths_ci_95_top,
        na.rm = TRUE
      )
  )


confidence_interval_checks


# LATEST OBSERVATION PER ENTITY



# 18. Extract latest available observation for each entity

latest_entity_values <- covid_raw |>
  arrange(
    Entity,
    Day
  ) |>
  group_by(
    Entity,
    Code
  ) |>
  slice_max(
    order_by = Day,
    n = 1,
    with_ties = FALSE
  ) |>
  ungroup()


# 19. Inspect largest cumulative excess-death estimates

largest_excess_death_estimates <- latest_entity_values |>
  arrange(
    desc(
      cumulative_estimated_daily_excess_deaths
    )
  ) |>
  select(
    Entity,
    Code,
    Day,
    cumulative_estimated_daily_excess_deaths,
    `Total confirmed deaths due to COVID-19`,
    cumulative_estimated_daily_excess_deaths_ci_95_bot,
    cumulative_estimated_daily_excess_deaths_ci_95_top
  ) |>
  slice_head(
    n = 20
  )


largest_excess_death_estimates


# 20. Inspect largest confirmed COVID-19 death totals

largest_confirmed_death_totals <- latest_entity_values |>
  arrange(
    desc(
      `Total confirmed deaths due to COVID-19`
    )
  ) |>
  select(
    Entity,
    Code,
    Day,
    cumulative_estimated_daily_excess_deaths,
    `Total confirmed deaths due to COVID-19`
  ) |>
  slice_head(
    n = 20
  )


largest_confirmed_death_totals


# SAVE AUDIT TABLES



# 21. Save audit outputs

if (!dir.exists(here("tables"))) {
  dir.create(
    here("tables"),
    recursive = TRUE
  )
}


write_csv(
  missingness,
  here(
    "tables",
    "data_audit_missingness.csv"
  )
)


write_csv(
  entity_observation_summary,
  here(
    "tables",
    "data_audit_entity_coverage.csv"
  )
)


write_csv(
  latest_entity_values,
  here(
    "tables",
    "data_audit_latest_entity_values.csv"
  )
)



message(
  "COVID excess mortality data audit complete."
)