
#fs::dir_tree()

#source(file.path('scripts', '02_data-processing.R'))
df_disprev_year <- readRDS(file.path('data', 'processed', 'df_disprev_year.RDS'))
df_disprev <- readRDS(file.path('data', 'processed', 'df_disprev.RDS'))
df_ssi_year <- readRDS(file.path('data', 'processed', 'df_ssi_year.RDS'))
df_ssi <- readRDS(file.path('data', 'processed', 'df_ssi.RDS'))