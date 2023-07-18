
source(file.path('scripts', '01_functions.R'))



# Use custom function to read in number of SSA recipients by year.
ssa <- map_df(2016:2019, get_ssa_recipients)
ssa

# Use custom function to read in number of financially-eligible children by age group, disability status, and year from ACS.
acs_boot <- map_df(2016:2019, get_acs)
acs_boot

# Converts counts into disability prevalence by FPL class (0-100%, 100-200%)
acs_point <- 
  acs_boot |>
  select(year, state, fpl_type, mid_acs) |>
  separate(fpl_type, sep =  "(_)(?=[^_]+$)", into = c("fpl_class", "frac_part")) |>
  pivot_wider(names_from = frac_part, values_from = mid_acs) |>
  mutate(mid_acs = disability/total*100)
acs_point



# Use custom scarping function to read in number of financially-eligible children by age group, disability status, and year from NSCH. This takes about 5 minutes to run on my computer. NAs will be generated because of 2017 NH.
tictoc::tic()
nsch <-
  map_dfr(2:52, scrape_nsch_table, 2016, "more") |> distinct() |>
  #bind_rows(2:52, scrape_nsch_table, 2016, "less") |> distinct() |>
  bind_rows(2:52 |> map_dfr(scrape_nsch_table, 2017, "more") |> distinct()) |>
  #bind_rows(2:52 |> map_dfr(scrape_nsch_table, 2017, "less") |> distinct()) |>
  bind_rows(2:52 |> map_dfr(scrape_nsch_table, 2018, "more") |> distinct()) |>
  #bind_rows(2:52 |> map_dfr(scrape_nsch_table, 2018, "less") |> distinct()) |>
  bind_rows(2:52 |> map_dfr(scrape_nsch_table, 2019, "more") |> distinct()) |> 
  #bind_rows(2:52 |> map_dfr(scrape_nsch_table, 2019, "less") |> distinct()) |>
  select(-cshcn_class) |>
  mutate(across(mid_nsch:high_nsch, str_trim)) |> 
  mutate(across(mid_nsch:high_nsch, as.numeric))
tictoc::toc()

# Use the midpoint of 2016 NH and 2018 NH to impute the NAs.
nsch |> filter(is.na(mid_nsch))
nsch |> filter(state == "New Hampshire")
nsch[161, 4:6]
nsch[161, 4:6] <- list(17.55, 10.3, 38.25)
nsch[161, 4:6]



# Commented out the parts where the midpoint of the disability prevalences are used. Aggregating numbers accounting for different disability prevalence by 0-100% and 100-200% FPL grouping.
df_disprev_year <-
  acs_point |>
  left_join(nsch, by = c("year", "state", "fpl_class")) |>
  select(-low_nsch, -high_nsch, -disability) |>
  #mutate(disprev_fpl = (mid_acs + mid_nsch)/2) |>
  mutate(#child_elig_mid = disprev_fpl*total/100,
         child_elig_acs = mid_acs*total/100,
         child_elig_nsch = mid_nsch*total/100) |>
  group_by(year, state) |>
  summarize(#child_elig_mid = sum(child_elig_mid),
            child_elig_acs = sum(child_elig_acs),
            child_elig_nsch = sum(child_elig_nsch),
            total = sum(total),
            .groups = "drop") |>
  mutate(#disprev_mid = child_elig_mid/total,
         disprev_acs = child_elig_acs/total,
         disprev_nsch = child_elig_nsch/total)
df_disprev_year

# Same calculation as above, except aggregated over all years.
df_disprev <-
  acs_point |>
  left_join(nsch, by = c("year", "state", "fpl_class")) |>
  select(-low_nsch, -high_nsch, -disability) |>
  #mutate(disprev_fpl = (mid_acs + mid_nsch)/2) |>
  mutate(#child_elig_mid = disprev_fpl*total/100,
         child_elig_acs = mid_acs*total/100,
         child_elig_nsch = mid_nsch*total/100) |>
  group_by(state) |>
  summarize(#child_elig_mid = sum(child_elig_mid),
            child_elig_acs = sum(child_elig_acs),
            child_elig_nsch = sum(child_elig_nsch),
            total = sum(total),
            .groups = "drop") |>
  mutate(#disprev_mid = child_elig_mid/total,
         disprev_acs = child_elig_acs/total,
         disprev_nsch = child_elig_nsch/total)
df_disprev

# Using the numbers computed above to compute the number of financially and disability-eligible children that participated by year.
df_ssi_year <-
  ssa |>
  left_join(df_disprev_year, by = c("state", "year")) |>
  mutate(#ssi_mid = recip_age_under_18/child_elig_mid,
         ssi_acs = recip_age_under_18/child_elig_acs,
         ssi_nsch = recip_age_under_18/child_elig_nsch) 

# Same calculation as above, except aggregated over all years.
df_ssi <-
  ssa |>
  group_by(state) |>
  summarize(recip_age_under_18 = sum(recip_age_under_18)) |>
  left_join(df_disprev, by = "state") |>
  mutate(#ssi_mid = recip_age_under_18/child_elig_mid,
         ssi_acs = recip_age_under_18/child_elig_acs,
         ssi_nsch = recip_age_under_18/child_elig_nsch)

# There are clearly few SSI participation rate estimates above 100% according to ACS. 
df_ssi_year |>
  group_by(year) |>
  summarize(min_acs = min(ssi_acs), max_acs = max(ssi_acs),
            min_nsch = min(ssi_nsch), max_nsch = max(ssi_nsch))



saveRDS(ssa, file.path('data', 'processed', 'ssa.RDS'))
saveRDS(nsch, file.path('data', 'processed', 'nsch.RDS'))
saveRDS(acs_point, file.path('data', 'processed', 'acs_point.RDS'))
saveRDS(df_disprev_year, file.path('data', 'processed', 'df_disprev_year.RDS'))
saveRDS(df_disprev, file.path('data', 'processed', 'df_disprev.RDS'))
saveRDS(df_ssi_year, file.path('data', 'processed', 'df_ssi_year.RDS'))
saveRDS(df_ssi, file.path('data', 'processed', 'df_ssi.RDS'))

