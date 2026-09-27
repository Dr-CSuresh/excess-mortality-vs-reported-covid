# 02_data_cleaning_and_alignment.R
#
# Project: Excess Mortality vs Reported COVID-19 Deaths



# 1. Load packages 

library(tidyverse)
library(here)


# 2. Create output directories if required

if (!dir.exists(here("data", "processed"))) {
  dir.create(
    here("data", "processed"),
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



# 3. Import raw data

covid_raw <- read_csv(
  here(
    "data",
    "raw",
    "4- excess-deaths-cumulative-economist-single-entity.csv"
  ),
  show_col_types = FALSE
)


# RENAME VARIABLES



# 4. Rename variables

covid_clean <- covid_raw |>
  rename(
    
    entity =
      Entity,
    
    code =
      Code,
    
    date =
      Day,
    
    excess_deaths =
      cumulative_estimated_daily_excess_deaths,
    
    confirmed_covid_deaths =
      `Total confirmed deaths due to COVID-19`,
    
    excess_deaths_upper =
      cumulative_estimated_daily_excess_deaths_ci_95_top,
    
    excess_deaths_lower =
      cumulative_estimated_daily_excess_deaths_ci_95_bot
  )


# EXCLUDE AGGREGATE ENTITIES



# 5. Identify excluded aggregate entities

excluded_entities <- covid_clean |>
  filter(
    is.na(code) |
      entity == "World"
  ) |>
  distinct(
    entity,
    code
  ) |>
  arrange(
    entity
  )


print(
  excluded_entities,
  n = Inf
)


# 6. Create country-level dataset

covid_country <- covid_clean |>
  filter(
    !is.na(code),
    entity != "World"
  ) |>
  arrange(
    entity,
    date
  )


country_dataset_summary <- covid_country |>
  summarise(
    
    observations =
      n(),
    
    entities =
      n_distinct(entity),
    
    first_date =
      min(date),
    
    last_date =
      max(date)
  )


country_dataset_summary


# SERIES AVAILABILITY



# 7. Create helper function for final non-missing date

last_nonmissing_date <- function(date, value) {
  
  if (any(!is.na(value))) {
    
    max(
      date[
        !is.na(value)
      ]
    )
    
  } else {
    
    as.Date(NA)
  }
}


# 8. Summarise availability of each mortality series

series_availability <- covid_country |>
  group_by(
    entity,
    code
  ) |>
  summarise(
    
    n_excess_observations =
      sum(
        !is.na(excess_deaths)
      ),
    
    n_confirmed_observations =
      sum(
        !is.na(confirmed_covid_deaths)
      ),
    
    first_excess_date =
      if (
        any(
          !is.na(excess_deaths)
        )
      ) {
        
        min(
          date[
            !is.na(excess_deaths)
          ]
        )
        
      } else {
        
        as.Date(NA)
      },
    
    last_excess_date =
      last_nonmissing_date(
        date,
        excess_deaths
      ),
    
    first_confirmed_date =
      if (
        any(
          !is.na(confirmed_covid_deaths)
        )
      ) {
        
        min(
          date[
            !is.na(confirmed_covid_deaths)
          ]
        )
        
      } else {
        
        as.Date(NA)
      },
    
    last_confirmed_date =
      last_nonmissing_date(
        date,
        confirmed_covid_deaths
      ),
    
    .groups = "drop"
  ) |>
  mutate(
    
    has_excess =
      n_excess_observations > 0,
    
    has_confirmed =
      n_confirmed_observations > 0,
    
    has_both =
      has_excess &
      has_confirmed
  )


series_availability


# 9. Summarise availability

availability_summary <- series_availability |>
  summarise(
    
    total_entities =
      n(),
    
    entities_with_excess =
      sum(has_excess),
    
    entities_with_confirmed =
      sum(has_confirmed),
    
    entities_with_both =
      sum(has_both),
    
    excess_only =
      sum(
        has_excess &
          !has_confirmed
      ),
    
    confirmed_only =
      sum(
        !has_excess &
          has_confirmed
      )
  )


availability_summary


# FINAL COMMON CUTOFF



# 10. Create country-specific common cutoff dates
#
# The common cutoff is the earlier of the final available dates
# for the two mortality series.

paired_cutoffs <- series_availability |>
  filter(
    has_both
  ) |>
  mutate(
    
    common_cutoff_date =
      pmin(
        last_excess_date,
        last_confirmed_date
      )
  )


paired_cutoffs


# FINAL EXCESS MORTALITY VALUES



# 11. Extract latest excess mortality estimate at or before common cutoff

final_excess <- covid_country |>
  inner_join(
    paired_cutoffs |>
      select(
        entity,
        code,
        common_cutoff_date
      ),
    by = c(
      "entity",
      "code"
    )
  ) |>
  filter(
    !is.na(excess_deaths),
    date <= common_cutoff_date
  ) |>
  group_by(
    entity,
    code,
    common_cutoff_date
  ) |>
  slice_max(
    order_by = date,
    n = 1,
    with_ties = FALSE
  ) |>
  ungroup() |>
  transmute(
    
    entity,
    code,
    common_cutoff_date,
    
    excess_date =
      date,
    
    excess_deaths,
    excess_deaths_lower,
    excess_deaths_upper
  )


# FINAL REPORTED COVID-19 DEATH VALUES



# 12. Extract latest reported COVID deaths at or before common cutoff

final_confirmed <- covid_country |>
  inner_join(
    paired_cutoffs |>
      select(
        entity,
        code,
        common_cutoff_date
      ),
    by = c(
      "entity",
      "code"
    )
  ) |>
  filter(
    !is.na(confirmed_covid_deaths),
    date <= common_cutoff_date
  ) |>
  group_by(
    entity,
    code,
    common_cutoff_date
  ) |>
  slice_max(
    order_by = date,
    n = 1,
    with_ties = FALSE
  ) |>
  ungroup() |>
  transmute(
    
    entity,
    code,
    common_cutoff_date,
    
    confirmed_date =
      date,
    
    confirmed_covid_deaths
  )


# FINAL PAIRED DATASET



# 13. Join final excess and reported mortality estimates

final_paired <- final_excess |>
  inner_join(
    final_confirmed,
    by = c(
      "entity",
      "code",
      "common_cutoff_date"
    )
  ) |>
  mutate(
    
    days_between_measurements =
      abs(
        as.numeric(
          excess_date -
            confirmed_date
        )
      ),
    
    absolute_difference =
      excess_deaths -
      confirmed_covid_deaths,
    
    excess_reported_ratio =
      if_else(
        excess_deaths > 0 &
          confirmed_covid_deaths > 0,
        
        excess_deaths /
          confirmed_covid_deaths,
        
        NA_real_
      ),
    
    reported_percent_of_excess =
      if_else(
        excess_deaths > 0 &
          confirmed_covid_deaths >= 0,
        
        100 *
          confirmed_covid_deaths /
          excess_deaths,
        
        NA_real_
      ),
    
    position_vs_excess_interval =
      case_when(
        
        confirmed_covid_deaths <
          excess_deaths_lower ~
          "Reported below excess 95% interval",
        
        confirmed_covid_deaths >
          excess_deaths_upper ~
          "Reported above excess 95% interval",
        
        TRUE ~
          "Reported within excess 95% interval"
      )
  ) |>
  arrange(
    desc(
      excess_deaths
    )
  )


final_paired


# 14. Inspect final date alignment

final_alignment_summary <- final_paired |>
  summarise(
    
    n_entities =
      n(),
    
    median_days_between =
      median(
        days_between_measurements
      ),
    
    maximum_days_between =
      max(
        days_between_measurements
      ),
    
    within_7_days =
      sum(
        days_between_measurements <= 7
      ),
    
    percent_within_7_days =
      100 *
      mean(
        days_between_measurements <= 7
      )
  )


final_alignment_summary


# ANNUAL ALIGNMENT



# 15. Identify final available date for each series within each year

annual_availability <- covid_country |>
  mutate(
    
    year =
      lubridate::year(date)
  ) |>
  group_by(
    entity,
    code,
    year
  ) |>
  summarise(
    
    last_excess_date =
      last_nonmissing_date(
        date,
        excess_deaths
      ),
    
    last_confirmed_date =
      last_nonmissing_date(
        date,
        confirmed_covid_deaths
      ),
    
    .groups = "drop"
  ) |>
  filter(
    !is.na(last_excess_date),
    !is.na(last_confirmed_date)
  ) |>
  mutate(
    
    common_cutoff_date =
      pmin(
        last_excess_date,
        last_confirmed_date
      )
  )


annual_availability


# 16. Extract annual excess estimate at common cutoff

annual_excess <- covid_country |>
  mutate(
    
    year =
      lubridate::year(date)
  ) |>
  inner_join(
    annual_availability,
    by = c(
      "entity",
      "code",
      "year"
    )
  ) |>
  filter(
    !is.na(excess_deaths),
    date <= common_cutoff_date
  ) |>
  group_by(
    entity,
    code,
    year,
    common_cutoff_date
  ) |>
  slice_max(
    order_by = date,
    n = 1,
    with_ties = FALSE
  ) |>
  ungroup() |>
  transmute(
    
    entity,
    code,
    year,
    common_cutoff_date,
    
    excess_date =
      date,
    
    excess_deaths,
    excess_deaths_lower,
    excess_deaths_upper
  )


# 17. Extract annual reported COVID deaths at common cutoff

annual_confirmed <- covid_country |>
  mutate(
    
    year =
      lubridate::year(date)
  ) |>
  inner_join(
    annual_availability,
    by = c(
      "entity",
      "code",
      "year"
    )
  ) |>
  filter(
    !is.na(confirmed_covid_deaths),
    date <= common_cutoff_date
  ) |>
  group_by(
    entity,
    code,
    year,
    common_cutoff_date
  ) |>
  slice_max(
    order_by = date,
    n = 1,
    with_ties = FALSE
  ) |>
  ungroup() |>
  transmute(
    
    entity,
    code,
    year,
    common_cutoff_date,
    
    confirmed_date =
      date,
    
    confirmed_covid_deaths
  )


# 18. Join annual paired series

annual_paired <- annual_excess |>
  inner_join(
    annual_confirmed,
    by = c(
      "entity",
      "code",
      "year",
      "common_cutoff_date"
    )
  ) |>
  mutate(
    
    days_between_measurements =
      abs(
        as.numeric(
          excess_date -
            confirmed_date
        )
      ),
    
    aligned_within_14_days =
      days_between_measurements <= 14,
    
    absolute_difference =
      excess_deaths -
      confirmed_covid_deaths,
    
    excess_reported_ratio =
      if_else(
        excess_deaths > 0 &
          confirmed_covid_deaths > 0,
        
        excess_deaths /
          confirmed_covid_deaths,
        
        NA_real_
      ),
    
    reported_percent_of_excess =
      if_else(
        excess_deaths > 0 &
          confirmed_covid_deaths >= 0,
        
        100 *
          confirmed_covid_deaths /
          excess_deaths,
        
        NA_real_
      ),
    
    position_vs_excess_interval =
      case_when(
        
        confirmed_covid_deaths <
          excess_deaths_lower ~
          "Reported below excess 95% interval",
        
        confirmed_covid_deaths >
          excess_deaths_upper ~
          "Reported above excess 95% interval",
        
        TRUE ~
          "Reported within excess 95% interval"
      )
  )


# 19. Summarise annual alignment

annual_alignment_summary <- annual_paired |>
  group_by(year) |>
  summarise(
    
    paired_entities =
      n(),
    
    median_days_between =
      median(
        days_between_measurements
      ),
    
    maximum_days_between =
      max(
        days_between_measurements
      ),
    
    within_14_days =
      sum(
        aligned_within_14_days
      ),
    
    percent_within_14_days =
      100 *
      mean(
        aligned_within_14_days
      ),
    
    .groups = "drop"
  )


annual_alignment_summary


# UNCERTAINTY INTERVAL POSITION



# 20. Summarise final reported mortality relative to excess interval

interval_summary <- final_paired |>
  count(
    position_vs_excess_interval
  ) |>
  mutate(
    
    percent =
      100 *
      n /
      sum(n)
  )


interval_summary


# DISCREPANCIES



# 21. Inspect largest positive absolute differences

largest_positive_gaps <- final_paired |>
  arrange(
    desc(
      absolute_difference
    )
  ) |>
  select(
    entity,
    code,
    common_cutoff_date,
    excess_deaths,
    confirmed_covid_deaths,
    absolute_difference,
    excess_reported_ratio,
    position_vs_excess_interval
  ) |>
  slice_head(
    n = 20
  )


largest_positive_gaps


# 22. Inspect largest excess-to-reported ratios
#
# Restrict to entities with at least 100 reported deaths
# to reduce instability from very small denominators.

largest_ratios <- final_paired |>
  filter(
    confirmed_covid_deaths >= 100,
    excess_deaths > 0
  ) |>
  arrange(
    desc(
      excess_reported_ratio
    )
  ) |>
  select(
    entity,
    code,
    common_cutoff_date,
    excess_deaths,
    confirmed_covid_deaths,
    excess_reported_ratio,
    absolute_difference,
    position_vs_excess_interval
  ) |>
  slice_head(
    n = 20
  )


largest_ratios


# SAVE OUTPUTS



# 23. Save processed country-level dataset

write_csv(
  covid_country,
  here(
    "data",
    "processed",
    "covid_excess_country.csv"
  )
)


# 24. Save series availability

write_csv(
  series_availability,
  here(
    "tables",
    "series_availability.csv"
  )
)


# 25. Save final paired dataset

write_csv(
  final_paired,
  here(
    "data",
    "processed",
    "covid_excess_final_paired.csv"
  )
)


# 26. Save annual paired dataset

write_csv(
  annual_paired,
  here(
    "data",
    "processed",
    "covid_excess_annual_paired.csv"
  )
)


# 27. Save final alignment summary

write_csv(
  final_alignment_summary,
  here(
    "tables",
    "final_alignment_summary.csv"
  )
)


# 28. Save annual alignment summary

write_csv(
  annual_alignment_summary,
  here(
    "tables",
    "annual_alignment_summary.csv"
  )
)


# 29. Save interval classification

write_csv(
  interval_summary,
  here(
    "tables",
    "reported_vs_excess_interval_summary.csv"
  )
)


# 30. Save largest discrepancies

write_csv(
  largest_positive_gaps,
  here(
    "tables",
    "largest_absolute_discrepancies.csv"
  )
)


write_csv(
  largest_ratios,
  here(
    "tables",
    "largest_relative_discrepancies.csv"
  )
)



message(
  "COVID excess mortality data cleaning and alignment complete."
)