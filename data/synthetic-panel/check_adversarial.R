#!/usr/bin/env Rscript

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
root_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
source(file.path(root_dir, "validate.R"))
clean <- file.path(root_dir, "fixtures", "clean")
write_csv <- function(x, path) write.table(x, path, sep = ",", row.names = FALSE, col.names = TRUE, quote = TRUE, na = "", qmethod = "double", fileEncoding = "UTF-8", eol = "\n")
refresh_manifest <- function(dir) {
  m <- read_release_csv(file.path(dir, "release_manifest.csv"))
  for (i in seq_len(nrow(m))) {
    path <- file.path(dir, m$file_name[i])
    m$row_count[i] <- nrow(read_release_csv(path))
    m$sha256[i] <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }
  write_csv(m, file.path(dir, "release_manifest.csv"))
}
change_table <- function(dir, file, fn) {
  path <- file.path(dir, file)
  x <- read_release_csv(path)
  write_csv(fn(x), path)
}
cases <- list(
  missing_response = list(check = "response_cardinality", fn = function(d) { d[-1, , drop = FALSE] }, file = "response.csv"),
  missing_questionnaire_item = list(check = "questionnaire_metadata", fn = function(d) d[-1, , drop = FALSE], file = "questionnaire.csv"),
  metadata_type = list(check = "questionnaire_metadata", fn = function(d) { d$value_type[d$item_id == "EMP"] <- "double"; d }, file = "questionnaire.csv"),
  metadata_code = list(check = "questionnaire_metadata", fn = function(d) { d$allowed_codes[d$item_id == "EMP"] <- "forbidden"; d }, file = "questionnaire.csv"),
  metadata_range = list(check = "questionnaire_metadata", fn = function(d) { d$maximum[d$item_id == "LSAT"] <- 99; d }, file = "questionnaire.csv"),
  metadata_eligibility = list(check = "questionnaire_metadata", fn = function(d) { d$required_if[d$item_id == "INC"] <- "FALSE"; d }, file = "questionnaire.csv"),
  metadata_version = list(check = "questionnaire_metadata", fn = function(d) { d$metadata_version[1] <- "v9"; d }, file = "questionnaire.csv"),
  employment_disagreement = list(check = "employment_agreement", fn = function(d) { d$value[d$item_id == "EMP"][1] <- "education"; d }, file = "response.csv"),
  income_disagreement = list(check = "income_consistency", fn = function(d) { d$income_raw[1] <- 1234; d }, file = "person_wave.csv"),
  imputation_donor_substitution = list(check = "income_consistency", fn = function(d) { j <- which(d$income_imp == 1L)[1]; d$income_final[j] <- d$income_final[j] + 10; d }, file = "person_wave.csv"),
  response_mode_disagreement = list(check = "mode_agreement", fn = function(d) { d$source_mode[1] <- "carrier_pigeon"; d }, file = "response.csv"),
  person_mode_disagreement = list(check = "mode_agreement", fn = function(d) { d$response_mode[1] <- "carrier_pigeon"; d }, file = "person_wave.csv"),
  email_pid = list(check = "opaque_identifier_format", fn = function(d) { d$pid[1] <- "person@example.org"; d }, file = "person_static.csv"),
  address_hid = list(check = "opaque_identifier_format", fn = function(d) { d$hid[1] <- "12 Main Street"; d }, file = "household_wave.csv"),
  origin_membership_disagreement = list(check = "membership_origin", fn = function(d) { d$origin_hid[1] <- "H0002"; d }, file = "person_static.csv"),
  baseline_refreshment_swap = list(check = "origin_refreshment", fn = function(d) { d$sample_cohort[1] <- "refreshment_2021"; d }, file = "person_static.csv"),
  household_baseline_refreshment_swap = list(check = "origin_refreshment", fn = function(d) { d$household_origin[d$wave == 2019][1] <- "refreshment"; d }, file = "household_wave.csv"),
  split_origin_swap = list(check = "origin_split", fn = function(d) { j <- which(d$household_origin == "split_off")[1]; d$household_origin[j] <- "baseline"; d }, file = "household_wave.csv"),
  second_join_existing_split = list(check = "move_mechanics", fn = function(d) { j <- which(d$household_origin == "split_off" & d$wave > min(d$wave[d$household_origin == "split_off"]))[1]; d$move_event_flag[j] <- 1L; d }, file = "household_wave.csv"),
  baseline_relabel_after_outsider_move = list(check = "move_mechanics", fn = function(d) { target <- "H0001"; j <- which(d$wave == max(d$wave) & d$hid != target)[1]; d$hid[j] <- target; d$moved_since_prior_wave[j] <- 1L; d }, file = "person_wave.csv"),
  person_move_flag = list(check = "move_mechanics", fn = function(d) { d$moved_since_prior_wave[1] <- 1L; d }, file = "person_wave.csv"),
  household_move_flag = list(check = "move_mechanics", fn = function(d) { d$move_event_flag[1] <- 1L - d$move_event_flag[1]; d }, file = "household_wave.csv"),
  exit_window = list(check = "observation_windows", fn = function(d) { j <- which(d$final_observed_wave < 2022)[1]; d$final_observed_wave[j] <- 2022L; d$exit_reason[j] <- "still_observed_end"; d }, file = "person_static.csv"),
  schema_type = list(check = "schema_semantics", fn = function(d) { d$storage_type[d$column_name == "pid" & d$table_name == "person_static"] <- "double"; d }, file = "schema.csv"),
  schema_nullable = list(check = "schema_semantics", fn = function(d) { d$nullable[d$column_name == "pid" & d$table_name == "person_static"] <- TRUE; d }, file = "schema.csv"),
  schema_key = list(check = "schema_semantics", fn = function(d) { d$key_role[d$column_name == "pid" & d$table_name == "person_static"] <- ""; d }, file = "schema.csv"),
  schema_allowed = list(check = "schema_semantics", fn = function(d) { d$allowed_values[d$column_name == "sex_reported" & d$table_name == "person_static"] <- "invented"; d }, file = "schema.csv"),
  schema_unit = list(check = "schema_semantics", fn = function(d) { d$unit[d$column_name == "birth_year" & d$table_name == "person_static"] <- "months"; d }, file = "schema.csv"),
  long_eligibility = list(check = "longitudinal_weight", fn = function(d) { j <- which(!is.na(d$long_weight_2019_2022))[1]; d$long_weight_2019_2022[j] <- NA; d }, file = "person_wave.csv"),
  long_constancy = list(check = "longitudinal_weight_constancy", fn = function(d) { j <- which(!is.na(d$long_weight_2019_2022))[1]; d$long_weight_2019_2022[j] <- d$long_weight_2019_2022[j] * 2; d }, file = "person_wave.csv"),
  long_total = list(check = "longitudinal_weight_targets", fn = function(d) { j <- which(!is.na(d$long_weight_2019_2022))[1]; d$long_weight_2019_2022[j] <- d$long_weight_2019_2022[j] + 1; d }, file = "person_wave.csv"),
  manifest_release_id = list(check = "manifest_provenance", fn = function(d) { d$release_id[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_profile = list(check = "manifest_provenance", fn = function(d) { d$defect_profile[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_generator_version = list(check = "manifest_provenance", fn = function(d) { d$generator_version[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_seed = list(check = "manifest_provenance", fn = function(d) { d$seed[1] <- 1; d }, file = "release_manifest.csv"),
  manifest_epoch = list(check = "manifest_provenance", fn = function(d) { d$generated_utc[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_r_version = list(check = "manifest_provenance", fn = function(d) { d$r_version[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_r_platform = list(check = "manifest_provenance", fn = function(d) { d$r_platform[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_fabricatr_version = list(check = "manifest_provenance", fn = function(d) { d$fabricatr_version[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_simstudy_version = list(check = "manifest_provenance", fn = function(d) { d$simstudy_version[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_data_table_version = list(check = "manifest_provenance", fn = function(d) { d$data_table_version[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_digest_version = list(check = "manifest_provenance", fn = function(d) { d$digest_version[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_renv_version = list(check = "manifest_provenance", fn = function(d) { d$renv_version[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_lock_hash = list(check = "manifest_provenance", fn = function(d) { d$lockfile_sha256[1] <- strrep("0", 64); d }, file = "release_manifest.csv"),
  manifest_generator_hash = list(check = "manifest_provenance", fn = function(d) { d$generator_sha256[1] <- strrep("0", 64); d }, file = "release_manifest.csv"),
  manifest_input_fingerprint = list(check = "manifest_provenance", fn = function(d) { d$generator_inputs_sha256[1] <- strrep("0", 64); d }, file = "release_manifest.csv"),
  manifest_source_provenance = list(check = "manifest_provenance", fn = function(d) { d$source_provenance[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_expected_status = list(check = "manifest_provenance", fn = function(d) { d$expected_validation_status[1] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_target_total = list(check = "manifest_provenance", fn = function(d) { d$target_total[d$table_name == "person_wave"] <- 999; d }, file = "release_manifest.csv"),
  manifest_target_unit = list(check = "manifest_provenance", fn = function(d) { d$target_unit[d$table_name == "person_wave"] <- "wrong"; d }, file = "release_manifest.csv"),
  manifest_table_name_swap = list(check = "manifest_provenance", fn = function(d) { j <- 1:2; d$table_name[j] <- rev(d$table_name[j]); d }, file = "release_manifest.csv"),
  canonical_feature = list(check = "canonical_seed_features", fn = function(d) { d$moved_since_prior_wave <- 0L; d }, file = "person_wave.csv")
)

for (nm in names(cases)) {
  dir <- file.path(tempfile(paste0("synthetic-panel-mutation-", nm, "-")), "clean")
  dir.create(dir, recursive = TRUE)
  file.copy(list.files(clean, full.names = TRUE), dir, overwrite = TRUE)
  case <- cases[[nm]]
  if (case$file == "release_manifest.csv") {
    change_table(dir, case$file, case$fn)
  } else {
    change_table(dir, case$file, case$fn)
    refresh_manifest(dir)
  }
  report <- validate_release(dir, file.path(root_dir, "invariants.csv"), quiet = TRUE)
  failed <- report$check_id[report$status == "FAIL"]
  if (!(case$check %in% failed)) stop(nm, " was not caught by ", case$check, call. = FALSE)
  if (case$file != "release_manifest.csv" && any(report$status[report$check_id %in% c("manifest_counts", "manifest_checksums")] != "PASS")) stop(nm, " stale integrity failure masked semantic result", call. = FALSE)
}
cat("PASS G8 refreshed-manifest adversarial mutations:", length(cases), "semantic cases caught\n")
