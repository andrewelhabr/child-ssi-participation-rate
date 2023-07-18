
library(tidyverse)
library(purrr)
library(rvest)
library(patchwork)

# Load in SSA recipient counts from downloaded files by year.
get_ssa_recipients <- function(year) {
  
  ssa_clean <-
    readr::read_csv(file.path('data', 'raw', 'ssa', 'recipients', glue::glue('ssa-ssi-recipients_dec-{year}.csv')),
                    skip = 0,
                    show_col_types = FALSE) |>
    janitor::clean_names() |>
    filter(!(state %in% c("District of Columbia"))) |> 
    mutate(state = ifelse(state == "All areas", "United States", state)) |>
    mutate(year = as.character({year})) |> relocate(year, .before = state) |>
    select(year, state, recip_age_under_18)
  
  return(ssa_clean)
  
}



# Finding concept and variable names within ACS that correspond to financially-eligible children counts in total and with disability.
Sys.getenv("CENSUS_API_KEY")
acs_v19 <- tidycensus::load_variables(2019, "acs1", cache = TRUE)
acs_var_names <-
  acs_v19 |>
  filter(str_detect(name, "B18131")) |> #View()
  slice(c(3:4, 8:9, 13:14, 18:19, 29:30, 37:38, 45:46, 53:54)) |> #pull(concept)
  pull(name)
acs_var_names
acs_v19 |> filter(name %in% acs_var_names)

# Load in financially-eligible children counts in total and with disability from ACS by year.
get_acs <- function(year) {
  
  acs_state <-
    tidycensus::get_acs(
      geography = "state",
      variables = acs_var_names,
      cache_table = TRUE,
      year = {year},
      survey = "acs1",
      moe_level = 90
    )
  
  acs_us <-
    tidycensus::get_acs(
      geography = "us",
      variables = acs_var_names,
      cache_table = TRUE,
      year = {year},
      survey = "acs1"
    )
  
  acs_aggregated <-
    acs_us |>
    bind_rows(acs_state) |>
    select(-GEOID) |> rename(state = NAME) |>
    filter(!state %in% c("District of Columbia", "Puerto Rico")) |>
    mutate(fpl_type = 
             case_when(variable %in% c("B18131_003", "B18131_029",
                                       "B18131_008", "B18131_037") ~ "fpl_000100_total",
                       variable %in% c("B18131_004", "B18131_030",
                                       "B18131_009", "B18131_038") ~ "fpl_000100_disability",
                       variable %in% c("B18131_013", "B18131_045",
                                       "B18131_018", "B18131_053") ~ "fpl_100200_total",
                       variable %in% c("B18131_014", "B18131_046",
                                       "B18131_019", "B18131_054") ~ "fpl_100200_disability",
                       TRUE ~ "error")) |>
    group_by(state, fpl_type) |>
    summarize(estimate = sum(estimate),
              moe = tidycensus::moe_sum(moe, estimate),
              .groups = "drop") |>
    rename(mid_acs = estimate) |>
    mutate(low_acs = mid_acs - moe, high_acs = mid_acs + moe) |>
    #select(-moe) |>
    mutate(year = as.character({year})) |> relocate(year, .before = state)
  
  return(acs_aggregated)
  
}



# Load in financially-eligible children counts in total and with disability from ACS by year.
scrape_nsch_table <- function(i, year, cshcn_cat) {
  
  if (year == 2016){
    if (cshcn_cat == "less") {
      url <- sprintf("https://www.childhealthdata.org/browse/survey/results?q=4667&r=1&g=615&a=7631&r2=%d", i)
    } else if (cshcn_cat == "more") {
      url <- sprintf("https://www.childhealthdata.org/browse/survey/results?q=4667&r=1&g=615&a=7632&r2=%d", i)
    }
    
  } else if (year == 2017) {
    if (cshcn_cat == "less") {
      url <- sprintf("https://www.childhealthdata.org/browse/survey/results?q=6555&r=1&g=692&a=9959&r2=%d", i)
    } else if (cshcn_cat == "more") {
      url <- sprintf("https://www.childhealthdata.org/browse/survey/results?q=6555&r=1&g=692&r2=%d", i)
    }
    
  } else if (year == 2018) {
    if (cshcn_cat == "less") {
      url <- sprintf("https://www.childhealthdata.org/browse/survey/results?q=7556&g=766&a=12497&r=1&r2=%d", i)
    } else if (cshcn_cat == "more") {
      url <- sprintf("https://www.childhealthdata.org/browse/survey/results?q=7556&g=766&r=1&r2=%d", i)
    }
    
  } else if (year == 2019) {
    if (cshcn_cat == "less") {
      url <- sprintf("https://www.childhealthdata.org/browse/survey/results?q=8111&g=840&a=14382&r=1&r2=%d", i)
    } else if (cshcn_cat == "more") {
      url <- sprintf("https://www.childhealthdata.org/browse/survey/results?q=8111&g=840&r=1&r2=%d", i)
    }
    
  }
  
  page <- url |> read_html()
  tb <- page |> 
    html_table() |> 
    pluck(2)
  tb <- tb[2:(nrow(tb) - 1), ]
  names(tb) <- c('group', 'state', sprintf('fpl_%s', c('000100', '100200', '200400', '400000')))
  
  tb_clean <-
    tb %>%
    filter(state == "%") %>% 
    select(-state) %>% rename(state = group) %>%
    select(-fpl_200400, -fpl_400000)%>%
    pivot_longer(-state) %>% rename(mid_nsch = value) %>%
    left_join(tb %>%
                filter(state == "C.I.") %>% 
                select(-state) %>% rename(state = group) %>%
                select(-fpl_200400, -fpl_400000) %>%
                pivot_longer(-state) %>%
                separate(value, c("low_nsch", "high_nsch"), "-"),
              by = c("state", "name")) %>%
    mutate(year = as.character({year})) %>% relocate(year, .before = state) %>%
    mutate(cshcn_class = as.character({cshcn_cat})) %>%
    filter(state != "District of Columbia") %>%
    mutate(state = ifelse(state == "Nationwide", "United States", state)) %>%
    rename(fpl_class = name)
  
  return(tb_clean)
  
}


