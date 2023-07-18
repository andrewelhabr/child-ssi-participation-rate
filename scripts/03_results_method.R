
source(file.path('scripts', '01_functions.R'))



#source(file.path('scripts', '02_data-processing.R'))
#ssa <- readRDS(file.path('data', 'processed', 'ssa.RDS'))
#nsch <- readRDS(file.path('data', 'processed', 'nsch.RDS'))
#acs_point <- readRDS(file.path('data', 'processed', 'acs_point.RDS'))
df_disprev_year <- readRDS(file.path('data', 'processed', 'df_disprev_year.RDS'))
df_disprev <- readRDS(file.path('data', 'processed', 'df_disprev.RDS'))
df_ssi_year <- readRDS(file.path('data', 'processed', 'df_ssi_year.RDS'))
df_ssi <- readRDS(file.path('data', 'processed', 'df_ssi.RDS'))



# Table 1: Disability Prevalence -----------------------------------------------

t_disprev <-
  df_disprev_year |>
  select(year, state, disprev_nsch) |>
  pivot_wider(names_from = year, values_from = disprev_nsch, names_prefix = "nsch_") |>
  left_join(
    df_disprev_year |>
      select(year, state, disprev_acs) |>
      pivot_wider(names_from = year, values_from = disprev_acs, names_prefix = "acs_"),
    by = "state") |>
  left_join(
    df_disprev |> select(state, disprev_nsch, disprev_acs), #, disprev_mid
    by = "state"
  ) |>
  relocate(disprev_nsch, .after = nsch_2019) |>
  #mutate(diff = disprev_nsch - disprev_acs) |>
  mutate(across(nsch_2016:disprev_acs, ~.x*100)) |> #disprev_mid
  mutate(across(nsch_2016:disprev_acs, round, digits = 1)) #|> arrange(-diff) #|> View()

t_disprev |> 
  flextable::flextable()
#huxtable::huxtable()
#View()

write_csv(t_disprev, file.path('results', '01_method', 'disprev.csv'))



# Table 2: SSI -----------------------------------------------------------------

t_ssi <-
  df_ssi_year |>
  select(year, state, ssi_nsch) |>
  pivot_wider(names_from = year, values_from = ssi_nsch, names_prefix = "nsch_") |>
  left_join(
    df_ssi_year |>
      select(year, state, ssi_acs) |>
      pivot_wider(names_from = year, values_from = ssi_acs, names_prefix = "acs_"),
    by = "state") |>
  left_join(
    df_ssi |> select(state, ssi_nsch, ssi_acs), #ssi_mid
    by = "state"
  ) |>
  relocate(ssi_nsch, .after = nsch_2019) |> 
  #mutate(diff = ssi_acs - ssi_nsch) |>
  mutate(across(nsch_2016:ssi_acs, ~.x*100)) |>
  mutate(across(nsch_2016:ssi_acs, round, digits = 1)) #|> arrange(-ssi_mid) |> View()

t_ssi |>
  flextable::flextable()
#huxtable::huxtable()
#View()

write_csv(t_ssi, file.path('results', '01_method', 'ssi.csv'))



# Figure 1: USA Map ------------------------------------------------------------

f_usa_nsch <-
  usmap::plot_usmap(data = df_ssi |> filter(state != "United States"),
                    values = "ssi_nsch",
                    show.legend = T,
                    #color = "black",
                    regions = "states", labels = TRUE, label_color = "black") +
  scale_fill_continuous(low = "grey20", high = "grey90", 
                        name = "Child SSI \nParticipation Rate", 
                        label = scales::label_percent(accuracy = 1L),
                        limits = c(0, 1)) + #c(0.125, 0.575) c(0.15, 0.55)
  #labs(title = "New England Region", subtitle = "Poverty Percentage Estimates for New England Counties in 2014") +
  theme(strip.background = element_blank(),
        plot.margin = margin(0.1, 0.1, 0.1, 0.1, "cm"),
        plot.background = element_rect(fill = "white", color = "white"),
        #plot.title = ggplot2::element_text(face = "bold", size = 20), #40
        #plot.subtitle = ggplot2::element_text(size = 14),
        #plot.caption = ggplot2::element_text(size = 14),
        #strip.text = ggplot2::element_text(size = 16), #36
        legend.text = ggplot2::element_text(size = 14), #30
        legend.title = ggplot2::element_text(size = 12), #30
        legend.position = "right",
        legend.justification = "right")

f_usa_nsch$layers[[2]]$aes_params$size <- 4.5
f_usa_nsch

f_usa_acs <-
  usmap::plot_usmap(data = df_ssi |> filter(state != "United States"),
                    values = "ssi_acs", 
                    show.legend = F,
                    #color = "black",
                    regions = "states", labels = TRUE, label_color = "black") +
  scale_fill_continuous(low = "grey20", high = "grey90", 
                        name = "Child SSI \nParticipation Rate", 
                        label = scales::label_percent(accuracy = 1L),
                        limits = c(0, 1)) + #c(0.125, 0.575) c(0.15, 0.55)
  #labs(title = "New England Region", subtitle = "Poverty Percentage Estimates for New England Counties in 2014") +
  theme(strip.background = element_blank(),
        plot.margin = margin(0.1, 0.1, 0.1, 0.1, "cm"),
        plot.background = element_rect(fill = "white", color = "white"),
        #plot.title = ggplot2::element_text(face = "bold", size = 20), #40
        #plot.subtitle = ggplot2::element_text(size = 14),
        #plot.caption = ggplot2::element_text(size = 14),
        #strip.text = ggplot2::element_text(size = 16), #36
        legend.text = ggplot2::element_text(size = 14), #30
        legend.title = ggplot2::element_text(size = 12), #30
        legend.position = "right",
        legend.justification = "right")

f_usa_acs$layers[[2]]$aes_params$size <- 4.5
f_usa_acs



f_usa <-
  f_usa_nsch / f_usa_acs + 
  plot_layout(ncol = 1) &
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 24))
f_usa

ggsave(
  f_usa,
  filename = file.path('results', '01_method', 'usa-heatmap.png'),
  width = 11.5,
  height = 8,
  dpi = 300,
  units = "in"
)



# Figure 2: Disability Prevalence EDA ------------------------------------------

lm(disprev_diff ~ disprev_acs, 
   data = df_disprev_year |> mutate(disprev_diff = disprev_nsch - disprev_acs)) |> 
  summary()

f_disprev_diff <-
  df_disprev_year |>
  mutate(disprev_diff = disprev_nsch - disprev_acs,
         sy = paste0(state, ", ", year)) |>
  ggplot() +
  aes(x = disprev_acs, y = disprev_diff) +
  geom_point() +
  geom_smooth(formula = y ~ x, method = "lm", color = "black") +
  ggrepel::geom_text_repel(aes(label = sy), max.overlaps = 4, size = 5) +
  ggpubr::stat_regline_equation(label.y = 0.2, size = 5) + 
  ggpubr::stat_cor(label.y = 0.192, size = 5) + 
  scale_x_continuous(label = scales::label_percent(accuracy = 1L), limits = c(0.025, 0.125)) +
  scale_y_continuous(label = scales::label_percent(accuracy = 1L), limits = c(0.01, 0.2)) +
  theme_minimal() + 
  theme(strip.background = element_blank(),
        plot.margin = margin(0.5, 0.5, 0.5, 0.5, "cm"),
        plot.background = element_rect(fill = "white", color = "white"),
        strip.text = element_text(size = 18),
        legend.text = element_text(size = 18),
        legend.title = element_text(size = 18),
        axis.title.y = element_text(size = 16),
        axis.text.y = element_text(size = 18),
        #panel.grid.major.y = element_blank(),
        #panel.grid.minor.y = element_blank(),
        axis.title.x = element_text(size = 18),
        axis.text.x = element_text(size = 18),
        plot.title.position = "panel",
        legend.position = "right") +
  labs(title = NULL, #"Difference Between State-Level Disability Prevalence Estimates",
       subtitle = NULL, #"For Each Year",
       caption = NULL, #"Data: ACS, NSCH",
       x = "ACS Child Disability Prevalence Among Financially Eligible",
       y = "NSCH - ACS Child Disability Prevalence Among Financially Eligible")
f_disprev_diff

ggsave(
  f_disprev_diff,
  filename = file.path('results', '01_method', 'disprev-diff.png'),
  width = 11.5,
  height = 8,
  dpi = 300,
  units = "in"
)



# Supplementary Figure 1: SSI EDA ----------------------------------------------

lm(ssi_diff ~ ssi_nsch, data = df_ssi_year |>
     mutate(ssi_diff = ssi_acs - ssi_nsch)) |> summary()

f_ssi <-
  df_ssi_year |>
  mutate(ssi_diff = ssi_acs - ssi_nsch,
         sy = paste0(state, ", ", year)) |>
  ggplot() +
  aes(x = ssi_nsch, y = ssi_acs) +
  geom_point() +
  geom_smooth(formula = y ~ x, method = "lm", color = "black") +
  ggrepel::geom_text_repel(aes(label = sy), max.overlaps = 4, size = 5) +
  ggpubr::stat_regline_equation(label.y = 0.9, size = 5) + 
  ggpubr::stat_cor(label.y = 0.8, size = 5) + 
  scale_x_continuous(label = scales::label_percent(accuracy = 1L)) + #, limits = c(0.025, 0.125)
  scale_y_continuous(label = scales::label_percent(accuracy = 1L)) + #, limits = c(0.01, 0.2)
  theme_minimal() + 
  theme(strip.background = element_blank(),
        plot.margin = margin(0.5, 0.5, 0.5, 0.5, "cm"),
        plot.background = element_rect(fill = "white", color = "white"),
        strip.text = element_text(size = 18),
        legend.text = element_text(size = 18),
        legend.title = element_text(size = 18),
        axis.title.y = element_text(size = 18),
        axis.text.y = element_text(size = 18),
        #panel.grid.major.y = element_blank(),
        #panel.grid.minor.y = element_blank(),
        axis.title.x = element_text(size = 18),
        axis.text.x = element_text(size = 18),
        plot.title.position = "panel",
        legend.position = "right") +
  labs(title = NULL, 
       subtitle = NULL,
       caption = NULL, 
       x = "NSCH SSI Child Participation Rate",
       y = "ACS SSI Child Participation Rate")
f_ssi

ggsave(
  f_ssi,
  filename = file.path('results', '01_method', 'ssi.png'),
  width = 11.5,
  height = 8,
  dpi = 300,
  units = "in"
)



# Supplementary Table 1: Children Impacted -------------------------------------

df_ssi |> filter(state == "United States") 

# Computing the expected number of children to be impacted if the SSI participation rate could be brought up to 50% for all states using the NSCH numbers only. The ACS numbers will indicate almost non-zero impact.
df_impacted <-
  df_ssi_year |>
  filter(state != "United States") |>
  mutate(#child_us_rate = 0.3861982*child_elig_mid,
         child_50_rate = 0.5*child_elig_nsch) |>
  mutate(#child_impacted_us = round(child_us_rate - recip_age_under_18),
         child_impacted_50 = round(child_50_rate - recip_age_under_18)) |>
  mutate(#child_impacted_us = ifelse(child_impacted_us > 0, child_impacted_us, 0),
         child_impacted_50 = ifelse(child_impacted_50 > 0, child_impacted_50, 0)) |>
  select(year, state, recip_age_under_18, child_impacted_50) #child_impacted_us, 
df_impacted

df_impacted_state_avg <-
  df_impacted |>
  group_by(state) |>
  summarize(#child_impacted_us_avg = sum(child_impacted_us)/4,
            child_impacted_50_avg = sum(child_impacted_50)/4)
df_impacted_state_avg

df_impacted |>
  summarize(#child_impacted_us_avg = sum(child_impacted_us)/4,
            child_impacted_50_avg = sum(child_impacted_50)/4)
