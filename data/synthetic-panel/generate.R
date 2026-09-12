#!/usr/bin/env Rscript

# Deterministic, source-free teaching panel. No external microdata are read.

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
root_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
local_lib <- file.path(root_dir, "_r-lib")
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))

required_packages <- c("fabricatr", "simstudy", "digest")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop(
    "Missing packages: ", paste(missing_packages, collapse = ", "),
    ". See README.md for a reversible installation route.",
    call. = FALSE
  )
}

seed <- 20260912L
generator_version <- "0.1.0"
waves <- 2019:2022
set.seed(seed)

clamp <- function(x, lower, upper) pmax(lower, pmin(upper, x))

write_csv <- function(x, path) {
  write.table(
    x,
    file = path,
    sep = ",",
    row.names = FALSE,
    col.names = TRUE,
    quote = TRUE,
    na = "",
    qmethod = "double",
    fileEncoding = "UTF-8",
    eol = "\n"
  )
}

make_schema <- function() {
  rows <- list()
  add <- function(table_name, column_name, storage_type, nullable, key_role,
                  description, allowed_values = "", unit = "") {
    rows[[length(rows) + 1L]] <<- data.frame(
      table_name, column_name, storage_type, nullable, key_role, description,
      allowed_values, unit, stringsAsFactors = FALSE
    )
  }

  add("person_static", "pid", "string", FALSE, "primary_key", "Stable opaque person identifier")
  add("person_static", "birth_year", "integer", FALSE, "", "Invented year of birth", "", "year")
  add("person_static", "sex_reported", "string", FALSE, "", "Broad invented reported-sex category", "female|male|diverse")
  add("person_static", "education", "string", FALSE, "", "Simplified education category", "low|medium|high")
  add("person_static", "sample_cohort", "string", FALSE, "", "Panel sample entry cohort", "baseline_2019|refreshment_2021")
  add("person_static", "entry_wave", "integer", FALSE, "", "First observed wave", "2019|2021", "year")
  add("person_static", "final_observed_wave", "integer", FALSE, "", "Last observed wave under monotone attrition", "2019|2020|2021|2022", "year")
  add("person_static", "exit_reason", "string", FALSE, "", "Observation-window status", "panel_attrition|still_observed_end")
  add("person_static", "origin_hid", "string", FALSE, "foreign_key", "Household identifier at panel entry")

  add("household_wave", "hid", "string", FALSE, "primary_key_part", "Stable opaque household identifier")
  add("household_wave", "wave", "integer", FALSE, "primary_key_part", "Survey wave", paste(waves, collapse = "|"), "year")
  add("household_wave", "region4", "string", FALSE, "", "Invented broad region", "north|east|south|west")
  add("household_wave", "hhsize_reported", "integer", FALSE, "", "Linked participating-person count", "", "persons")
  add("household_wave", "response_status", "string", FALSE, "", "Household-wave participation status", "interviewed")
  add("household_wave", "household_origin", "string", FALSE, "", "How this household entered the panel", "baseline|refreshment|split_off")
  add("household_wave", "move_event_flag", "integer", FALSE, "", "One when a split-off household first appears", "0|1")
  add("household_wave", "hh_xs_weight", "double", FALSE, "", "Simplified cross-sectional household weight", "", "invented population units")

  add("person_wave", "pid", "string", FALSE, "primary_key_part", "Stable opaque person identifier")
  add("person_wave", "wave", "integer", FALSE, "primary_key_part", "Survey wave", paste(waves, collapse = "|"), "year")
  add("person_wave", "hid", "string", FALSE, "foreign_key", "Current household identifier")
  add("person_wave", "age", "integer", FALSE, "", "Wave minus invented birth year", "", "years")
  add("person_wave", "employment_status", "string", FALSE, "", "Simplified annual status", "employed|unemployed|education|retired|not_in_labor_force")
  add("person_wave", "response_mode", "string", FALSE, "", "Invented questionnaire mode", "web|phone|paper")
  add("person_wave", "response_status", "string", FALSE, "", "Person-wave participation status", "interviewed")
  add("person_wave", "moved_since_prior_wave", "integer", FALSE, "", "One in the wave current household changes", "0|1")
  add("person_wave", "income_raw", "double", TRUE, "", "Reported monthly labor income before imputation", "", "invented currency units")
  add("person_wave", "income_final", "double", FALSE, "", "Analysis income after documented teaching substitution", "", "invented currency units")
  add("person_wave", "income_imp", "integer", FALSE, "", "One exactly when eligible raw income was imputed", "0|1")
  add("person_wave", "income_missing_code", "string", TRUE, "", "Why raw income is absent", "no_answer|not_applicable")
  add("person_wave", "person_xs_weight", "double", FALSE, "", "Simplified cross-sectional person weight", "", "invented population units")
  add("person_wave", "long_weight_2019_2022", "double", TRUE, "", "Baseline complete-panel longitudinal weight", "", "invented population units")

  add("questionnaire", "wave", "integer", FALSE, "primary_key_part", "Survey wave", paste(waves, collapse = "|"), "year")
  add("questionnaire", "item_id", "string", FALSE, "primary_key_part", "Wave-stable item identifier")
  add("questionnaire", "instrument", "string", FALSE, "", "Questionnaire instrument", "person")
  add("questionnaire", "variable", "string", FALSE, "", "Destination analytical variable")
  add("questionnaire", "value_type", "string", FALSE, "", "Declared response type", "categorical|integer|double")
  add("questionnaire", "allowed_codes", "string", TRUE, "", "Pipe-delimited categorical codes")
  add("questionnaire", "minimum", "double", TRUE, "", "Inclusive numeric minimum")
  add("questionnaire", "maximum", "double", TRUE, "", "Inclusive numeric maximum")
  add("questionnaire", "required_if", "string", FALSE, "", "Inspectable eligibility expression")
  add("questionnaire", "label", "string", FALSE, "", "Source-free teaching label")
  add("questionnaire", "metadata_version", "string", FALSE, "", "Questionnaire metadata version", "v1|v2")

  add("response", "pid", "string", FALSE, "foreign_key_part", "Stable opaque person identifier")
  add("response", "wave", "integer", FALSE, "foreign_key_part", "Survey wave", paste(waves, collapse = "|"), "year")
  add("response", "item_id", "string", FALSE, "foreign_key_part", "Questionnaire item identifier")
  add("response", "value", "string", TRUE, "", "Response serialized as text")
  add("response", "answer_status", "string", FALSE, "", "Observed missing or ineligible status", "answered|no_answer|not_applicable")
  add("response", "missing_code", "string", TRUE, "", "Declared missing reason", "no_answer|not_applicable")
  add("response", "source_mode", "string", FALSE, "", "Invented response mode", "web|phone|paper")
  add("response", "answered", "integer", FALSE, "", "One only for a supplied value", "0|1")

  do.call(rbind, rows)
}

make_questionnaire <- function() {
  item_template <- data.frame(
    item_id = c("EMP", "INC", "LSAT", "TRN"),
    instrument = "person",
    variable = c("employment_status", "income_raw", "life_satisfaction", "training_hours"),
    value_type = c("categorical", "double", "integer", "double"),
    allowed_codes = c("employed|unemployed|education|retired|not_in_labor_force", NA, NA, NA),
    minimum = c(NA, 0, 0, 0),
    maximum = c(NA, 25000, 10, 80),
    required_if = c("TRUE", "employment_status == employed", "TRUE", "employment_status in {employed,education}"),
    label = c("Current employment status", "Monthly labor income", "Overall life satisfaction", "Training hours in last four weeks"),
    stringsAsFactors = FALSE
  )
  out <- do.call(rbind, lapply(waves, function(wave) {
    x <- item_template
    x$wave <- wave
    x$metadata_version <- if (wave < 2021) "v1" else "v2"
    x$maximum[x$item_id == "TRN"] <- if (wave < 2021) 60 else 80
    x[, c("wave", names(item_template), "metadata_version")]
  }))
  rownames(out) <- NULL
  out
}

# fabricatr creates the nested source-free household -> person population.
n_baseline_households <- 60L
n_refresh_households <- 12L
n_households <- n_baseline_households + n_refresh_households
entry_wave_hh <- c(rep(2019L, n_baseline_households), rep(2021L, n_refresh_households))
hh_sizes <- sample(1:4, n_households, replace = TRUE, prob = c(0.28, 0.36, 0.24, 0.12))

hierarchy <- fabricatr::fabricate(
  households = fabricatr::add_level(
    N = n_households,
    entry_wave_hh = entry_wave_hh,
    region4 = sample(c("north", "east", "south", "west"), N, replace = TRUE),
    selection_probability = runif(N, 0.045, 0.085),
    household_size = hh_sizes
  ),
  persons = fabricatr::add_level(
    N = household_size,
    sex_reported = sample(c("female", "male", "diverse"), N, replace = TRUE,
                          prob = c(0.49, 0.49, 0.02)),
    education_draw = runif(N),
    employment_latent = rnorm(N),
    income_person_effect = rnorm(N, 0, 0.24),
    response_mode_draw = runif(N),
    attrition_draw = runif(N),
    move_draw = runif(N)
  )
)
household_lookup <- hierarchy[!duplicated(hierarchy$households), c(
  "households", "region4", "selection_probability"
)]
household_lookup <- household_lookup[order(as.integer(household_lookup$households)), ]

person_static <- data.frame(
  pid = sprintf("P%06d", as.integer(hierarchy$persons)),
  origin_hid = sprintf("H%04d", as.integer(hierarchy$households)),
  entry_wave = hierarchy$entry_wave_hh,
  sex_reported = hierarchy$sex_reported,
  stringsAsFactors = FALSE
)
entry_age <- ifelse(
  person_static$entry_wave == 2019,
  sample(18:78, nrow(person_static), replace = TRUE),
  sample(18:75, nrow(person_static), replace = TRUE)
)
person_static$birth_year <- person_static$entry_wave - entry_age
person_static$education <- ifelse(
  hierarchy$education_draw < 0.24, "low",
  ifelse(hierarchy$education_draw < 0.72, "medium", "high")
)
person_static$sample_cohort <- ifelse(
  person_static$entry_wave == 2019, "baseline_2019", "refreshment_2021"
)
person_static$final_observed_wave <- ifelse(
  person_static$entry_wave == 2019,
  ifelse(hierarchy$attrition_draw < 0.07, 2019L,
         ifelse(hierarchy$attrition_draw < 0.15, 2020L,
                ifelse(hierarchy$attrition_draw < 0.24, 2021L, 2022L))),
  ifelse(hierarchy$attrition_draw < 0.15, 2021L, 2022L)
)
person_static$exit_reason <- ifelse(
  person_static$final_observed_wave < 2022, "panel_attrition", "still_observed_end"
)

origin_sizes <- table(person_static$origin_hid)
eligible_mover <- entry_age <= 40 & origin_sizes[person_static$origin_hid] > 1 &
  person_static$entry_wave == 2019 & hierarchy$move_draw < 0.18
move_wave <- rep(NA_integer_, nrow(person_static))
move_wave[eligible_mover] <- sample(2020:2022, sum(eligible_mover), replace = TRUE)
move_wave[!is.na(move_wave) & move_wave > person_static$final_observed_wave] <- NA_integer_
new_hid <- rep(NA_character_, nrow(person_static))
new_hid[!is.na(move_wave)] <- sprintf(
  "H%04d", n_households + seq_len(sum(!is.na(move_wave)))
)
new_region <- rep(NA_character_, nrow(person_static))
new_region[!is.na(move_wave)] <- sample(
  c("north", "east", "south", "west"), sum(!is.na(move_wave)), replace = TRUE
)

person_static <- person_static[, c(
  "pid", "birth_year", "sex_reported", "education", "sample_cohort",
  "entry_wave", "final_observed_wave", "exit_reason", "origin_hid"
)]

# Explicit observation windows and persistent memberships create the panel.
membership <- do.call(rbind, lapply(seq_len(nrow(person_static)), function(i) {
  observed_waves <- person_static$entry_wave[i]:person_static$final_observed_wave[i]
  data.frame(
    pid = person_static$pid[i],
    wave = observed_waves,
    hid = ifelse(!is.na(move_wave[i]) & observed_waves >= move_wave[i],
                 new_hid[i], person_static$origin_hid[i]),
    moved_since_prior_wave = as.integer(!is.na(move_wave[i]) & observed_waves == move_wave[i]),
    stringsAsFactors = FALSE
  )
}))
rownames(membership) <- NULL

origin_for_member <- person_static$origin_hid[match(membership$pid, person_static$pid)]
origin_index <- as.integer(sub("^H0*", "", origin_for_member))
is_split <- membership$hid != origin_for_member
membership$region4 <- household_lookup$region4[origin_index]
membership$region4[is_split] <- new_region[match(membership$hid[is_split], new_hid)]

# simstudy supplies reproducible AR(1)-correlated annual person shocks.
shock_input <- data.table::data.table(
  pid_int = seq_len(nrow(person_static)),
  shock_mean = 0,
  shock_variance = 0.16
)
shock_data <- simstudy::addCorGen(
  shock_input,
  nvars = length(waves),
  idvar = "pid_int",
  rho = 0.65,
  corstr = "ar1",
  dist = "normal",
  param1 = "shock_mean",
  param2 = "shock_variance",
  cnames = paste0("shock_", waves, collapse = ",")
)
shock_matrix <- as.matrix(shock_data[, paste0("shock_", waves), with = FALSE])

pindex <- match(membership$pid, person_static$pid)
windex <- match(membership$wave, waves)
annual_shock <- shock_matrix[cbind(pindex, windex)]
age <- membership$wave - person_static$birth_year[pindex]
employment_score <- hierarchy$employment_latent[pindex] + 0.45 * annual_shock
employment_status <- ifelse(
  age >= 67, "retired",
  ifelse(age <= 23 & employment_score < 0.45, "education",
         ifelse(employment_score > -0.30, "employed",
                ifelse(employment_score > -0.90, "unemployed", "not_in_labor_force")))
)
response_mode <- ifelse(
  hierarchy$response_mode_draw[pindex] < 0.64 + 0.05 * (membership$wave - 2019), "web",
  ifelse(hierarchy$response_mode_draw[pindex] < 0.89, "phone", "paper")
)

education_effect <- c(low = -0.18, medium = 0, high = 0.30)[person_static$education[pindex]]
income_complete <- ifelse(
  employment_status == "employed",
  round(exp(7.55 + education_effect + hierarchy$income_person_effect[pindex] +
              annual_shock + 0.025 * (membership$wave - 2019)) / 10) * 10,
  NA_real_
)
income_complete <- pmin(income_complete, 25000)

# simstudy generates item nonresponse from observed mode, education, and wave.
eligible_income <- which(employment_status == "employed")
miss_input <- data.table::data.table(
  row_id = seq_along(eligible_income),
  income_complete = income_complete[eligible_income],
  paper_mode = as.integer(response_mode[eligible_income] == "paper"),
  low_education = as.integer(person_static$education[pindex[eligible_income]] == "low"),
  wave = membership$wave[eligible_income]
)
miss_definition <- simstudy::defMiss(
  varname = "income_complete",
  formula = "-3.0 + 0.55*paper_mode + 0.25*low_education + 0.12*(wave-2019)",
  logit.link = TRUE
)
income_missing <- rep(FALSE, nrow(membership))
income_missing[eligible_income] <- as.logical(
  simstudy::genMiss(miss_input, miss_definition, idvars = "row_id")$income_complete
)

income_raw <- income_complete
income_raw[income_missing] <- NA_real_
income_final <- ifelse(employment_status == "employed", income_raw, 0)
income_imp <- as.integer(income_missing)
for (wave in waves) {
  for (education in c("low", "medium", "high")) {
    group <- membership$wave == wave & employment_status == "employed" &
      person_static$education[pindex] == education
    donor <- median(income_raw[group], na.rm = TRUE)
    if (!is.finite(donor)) donor <- median(income_raw[membership$wave == wave], na.rm = TRUE)
    income_final[group & income_missing] <- round(donor / 10) * 10
  }
}
income_missing_code <- ifelse(
  employment_status != "employed", "not_applicable",
  ifelse(income_missing, "no_answer", NA_character_)
)

person_wave <- data.frame(
  pid = membership$pid,
  wave = membership$wave,
  hid = membership$hid,
  age = age,
  employment_status = employment_status,
  response_mode = response_mode,
  response_status = "interviewed",
  moved_since_prior_wave = membership$moved_since_prior_wave,
  income_raw = income_raw,
  income_final = income_final,
  income_imp = income_imp,
  income_missing_code = income_missing_code,
  stringsAsFactors = FALSE
)

# Simplified inverse-probability weights, calibrated to invented totals.
selection_probability <- hierarchy$selection_probability[pindex]
person_wave$person_xs_weight <- 1 / selection_probability /
  (0.94 - 0.035 * (person_wave$wave - 2019))
for (wave in waves) {
  idx <- person_wave$wave == wave
  person_wave$person_xs_weight[idx] <-
    person_wave$person_xs_weight[idx] * 10000 / sum(person_wave$person_xs_weight[idx])
}
complete_baseline <- person_static$pid[
  person_static$sample_cohort == "baseline_2019" & person_static$final_observed_wave == 2022
]
long_base <- 1 / hierarchy$selection_probability[match(complete_baseline, person_static$pid)] / 0.76
long_base <- long_base * 10000 / sum(long_base)
person_wave$long_weight_2019_2022 <- long_base[
  match(person_wave$pid, complete_baseline)
]
person_wave$person_xs_weight <- round(person_wave$person_xs_weight, 6)
person_wave$long_weight_2019_2022 <- round(person_wave$long_weight_2019_2022, 6)

# Household-wave rows are derived from the person membership relation.
membership_key <- paste(membership$hid, membership$wave, sep = "::")
household_wave <- do.call(rbind, lapply(split(seq_len(nrow(membership)), membership_key), function(idx) {
  hid <- membership$hid[idx[1]]
  wave <- membership$wave[idx[1]]
  split_off <- hid %in% new_hid
  data.frame(
    hid = hid,
    wave = wave,
    region4 = membership$region4[idx[1]],
    hhsize_reported = length(unique(membership$pid[idx])),
    response_status = "interviewed",
    household_origin = if (split_off) "split_off" else
      if (as.integer(sub("^H0*", "", hid)) <= n_baseline_households) "baseline" else "refreshment",
    move_event_flag = as.integer(any(membership$moved_since_prior_wave[idx] == 1L)),
    base_weight = 1 / hierarchy$selection_probability[pindex[idx[1]]],
    stringsAsFactors = FALSE
  )
}))
rownames(household_wave) <- NULL
household_wave$hh_xs_weight <- household_wave$base_weight /
  (0.96 - 0.025 * (household_wave$wave - 2019))
for (wave in waves) {
  idx <- household_wave$wave == wave
  household_wave$hh_xs_weight[idx] <-
    household_wave$hh_xs_weight[idx] * 5000 / sum(household_wave$hh_xs_weight[idx])
}
household_wave$hh_xs_weight <- round(household_wave$hh_xs_weight, 6)
household_wave$base_weight <- NULL
household_wave <- household_wave[order(household_wave$wave, household_wave$hid), ]
person_static <- person_static[order(person_static$pid), ]
rownames(household_wave) <- rownames(person_static) <- NULL

questionnaire <- make_questionnaire()

life_complete <- round(clamp(
  6.4 + 0.35 * (employment_status == "employed") -
    0.55 * (employment_status == "unemployed") + annual_shock,
  0, 10
))
life_missing <- runif(nrow(person_wave)) < 0.035
life_value <- ifelse(life_missing, NA_character_, as.character(life_complete))
training_eligible <- employment_status %in% c("employed", "education")
training_complete <- pmin(
  ifelse(training_eligible, rpois(nrow(person_wave), 5 + 3 * (employment_status == "education")), NA),
  ifelse(person_wave$wave < 2021, 60, 80)
)
training_missing <- training_eligible & runif(nrow(person_wave)) < 0.045

make_response_rows <- function(i) {
  income_status <- if (employment_status[i] != "employed") "not_applicable" else
    if (income_missing[i]) "no_answer" else "answered"
  training_status <- if (!training_eligible[i]) "not_applicable" else
    if (training_missing[i]) "no_answer" else "answered"
  data.frame(
    pid = person_wave$pid[i],
    wave = person_wave$wave[i],
    item_id = c("EMP", "INC", "LSAT", "TRN"),
    value = c(
      employment_status[i],
      if (income_status == "answered") format(income_raw[i], scientific = FALSE, trim = TRUE) else NA,
      life_value[i],
      if (training_status == "answered") as.character(training_complete[i]) else NA
    ),
    answer_status = c("answered", income_status,
                      if (life_missing[i]) "no_answer" else "answered", training_status),
    missing_code = c(NA, if (income_status == "answered") NA else income_status,
                     if (life_missing[i]) "no_answer" else NA,
                     if (training_status == "answered") NA else training_status),
    source_mode = person_wave$response_mode[i],
    answered = c(1L, as.integer(income_status == "answered"),
                 as.integer(!life_missing[i]), as.integer(training_status == "answered")),
    stringsAsFactors = FALSE
  )
}
response <- do.call(rbind, lapply(seq_len(nrow(person_wave)), make_response_rows))
person_wave <- person_wave[order(person_wave$wave, person_wave$pid), ]
response <- response[order(response$wave, response$pid, response$item_id), ]
rownames(person_wave) <- rownames(response) <- NULL

schema <- make_schema()
tables <- list(
  person_static = person_static,
  household_wave = household_wave,
  person_wave = person_wave,
  questionnaire = questionnaire,
  response = response,
  schema = schema
)

expected_failure <- c(
  clean = "",
  duplicate_person_wave = "unique_person_wave|weight_targets|income_consistency",
  duplicate_questionnaire_item = "unique_questionnaire",
  orphan_household = "foreign_keys|household_size|move_mechanics",
  zero_person_weight = "positive_weights|weight_targets",
  inconsistent_imputation_flag = "income_consistency",
  stale_manifest_checksum = "manifest_checksums"
)

write_release <- function(release_tables, release_dir, profile, stale_checksum = FALSE) {
  if (dir.exists(release_dir)) unlink(release_dir, recursive = TRUE)
  dir.create(release_dir, recursive = TRUE, showWarnings = FALSE)
  for (table_name in names(release_tables)) {
    write_csv(release_tables[[table_name]], file.path(release_dir, paste0(table_name, ".csv")))
  }
  manifest <- do.call(rbind, lapply(names(release_tables), function(table_name) {
    file_name <- paste0(table_name, ".csv")
    path <- file.path(release_dir, file_name)
    data.frame(
      release_id = "synthetic-panel-0.1.0",
      defect_profile = profile,
      generator_version = generator_version,
      seed = seed,
      generated_utc = "2026-09-12T00:00:00Z",
      r_version = paste(R.version$major, R.version$minor, sep = "."),
      fabricatr_version = as.character(utils::packageVersion("fabricatr")),
      simstudy_version = as.character(utils::packageVersion("simstudy")),
      table_name = table_name,
      file_name = file_name,
      row_count = nrow(release_tables[[table_name]]),
      sha256 = digest::digest(file = path, algo = "sha256", serialize = FALSE),
      validation_status = if (profile == "clean") "pass" else
        paste0("expected_failure:", expected_failure[[profile]]),
      intended_target_total = if (table_name == "person_wave") "10000 persons per wave" else
        if (table_name == "household_wave") "5000 households per wave" else "",
      stringsAsFactors = FALSE
    )
  }))
  if (stale_checksum) manifest$sha256[manifest$table_name == "person_wave"] <- strrep("0", 64)
  write_csv(manifest, file.path(release_dir, "release_manifest.csv"))
}

write_csv(schema, file.path(root_dir, "schema.csv"))
fixtures_dir <- file.path(root_dir, "fixtures")
write_release(tables, file.path(fixtures_dir, "clean"), "clean")

defects <- list()
defects$duplicate_person_wave <- lapply(tables, identity)
defects$duplicate_person_wave$person_wave <- rbind(
  defects$duplicate_person_wave$person_wave,
  defects$duplicate_person_wave$person_wave[1, ]
)

defects$duplicate_questionnaire_item <- lapply(tables, identity)
defects$duplicate_questionnaire_item$questionnaire <- rbind(
  defects$duplicate_questionnaire_item$questionnaire,
  defects$duplicate_questionnaire_item$questionnaire[1, ]
)

defects$orphan_household <- lapply(tables, identity)
defects$orphan_household$person_wave$hid[1] <- "H9999"

defects$zero_person_weight <- lapply(tables, identity)
defects$zero_person_weight$person_wave$person_xs_weight[1] <- 0

defects$inconsistent_imputation_flag <- lapply(tables, identity)
imputed_row <- which(defects$inconsistent_imputation_flag$person_wave$income_imp == 1L)[1]
if (is.na(imputed_row)) stop("Seed produced no imputed rows; adjust the mechanism.", call. = FALSE)
defects$inconsistent_imputation_flag$person_wave$income_imp[imputed_row] <- 0L

defects$stale_manifest_checksum <- lapply(tables, identity)

for (profile in names(defects)) {
  write_release(
    defects[[profile]],
    file.path(fixtures_dir, "defects", profile),
    profile,
    stale_checksum = identical(profile, "stale_manifest_checksum")
  )
}

message(
  "Generated clean release: ", nrow(person_static), " people; ",
  nrow(household_wave), " household-waves; ", nrow(person_wave),
  " person-waves; ", nrow(response), " responses."
)
