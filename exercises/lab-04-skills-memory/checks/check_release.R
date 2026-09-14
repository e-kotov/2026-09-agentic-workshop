#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
sp <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
lab <- dirname(dirname(normalizePath(sp, mustWork = TRUE))); base <- file.path(lab, "work")
if (length(args) == 1L && args[[1]] %in% c("--help", "-h")) { cat("Usage: Rscript checks/check_release.R [--base PATH]\nChecks only an assembled release and income summary.\n"); quit(status = 0L) }
if (length(args) == 2L && args[1] == "--base") base <- normalizePath(args[2], mustWork = FALSE) else if (length(args)) stop("usage: Rscript checks/check_release.R [--base PATH]", call. = FALSE)
release <- file.path(base, "release"); fixture <- file.path(lab, "fixture", "release")
read <- function(p) utils::read.csv(p, stringsAsFactors = FALSE, na.strings = c("", "NA"), check.names = FALSE)
bad <- character(); fail <- function(x) bad <<- c(bad, x)
required <- c("person_static.csv", "household_wave.csv", "person_wave.csv", "questionnaire.csv", "response.csv", "schema.csv", "release_manifest.csv")
if (!all(file.exists(file.path(release, required)))) fail("repaired release is incomplete")
if (!file.exists(file.path(base, "outputs", "income-summary.csv"))) fail("income-summary.csv is missing")
repair_script <- file.path(base, "code", "repair_release.R")
summary_script <- file.path(base, "code", "summarize_income.R")
if (!file.exists(repair_script) || !file.exists(summary_script)) fail("repair and summary scripts are required")
if (!length(bad)) {
  st <- read(file.path(release, "person_static.csv")); hh <- read(file.path(release, "household_wave.csv")); pw <- read(file.path(release, "person_wave.csv")); q <- read(file.path(release, "questionnaire.csv")); rr <- read(file.path(release, "response.csv")); sc <- read(file.path(release, "schema.csv")); m <- read(file.path(release, "release_manifest.csv"))
  fst <- read(file.path(fixture, "person_static.csv")); fhh <- read(file.path(fixture, "household_wave.csv")); fpw <- read(file.path(fixture, "person_wave.csv")); fq <- read(file.path(fixture, "questionnaire.csv")); fr <- read(file.path(fixture, "response.csv")); fs <- read(file.path(fixture, "schema.csv")); fm <- read(file.path(fixture, "release_manifest.csv"))
  if (!isTRUE(all.equal(st, fst)) || !isTRUE(all.equal(hh, fhh)) || !isTRUE(all.equal(q, fq)) || !isTRUE(all.equal(rr, fr)) || !isTRUE(all.equal(sc, fs))) fail("more than the justified person-wave cell changed")
  cell_diff <- function(a, b) {
    if (!identical(names(a), names(b)) || nrow(a) != nrow(b)) return(Inf)
    sum(vapply(seq_along(a), function(i) { x <- a[[i]]; y <- b[[i]]; sum(is.na(x) != is.na(y) | (!is.na(x) & !is.na(y) & as.character(x) != as.character(y))) }, integer(1)))
  }
  i <- which(fpw$pid == "P000040" & fpw$wave == 2019L)
  if (cell_diff(pw, fpw) != 1L || length(i) != 1L || pw$income_imp[i] != 1L) fail("repair must change exactly income_imp at P000040::2019")
  pw_key <- paste(pw$pid, pw$wave, sep = "::"); hh_key <- paste(hh$hid, hh$wave, sep = "::"); q_key <- paste(q$wave, q$item_id, sep = "::"); response_pw <- paste(rr$pid, rr$wave, sep = "::"); response_q <- paste(rr$wave, rr$item_id, sep = "::")
  expected_waves <- 2019:2022; eligible_long <- st$pid[st$sample_cohort == "baseline_2019" & st$entry_wave == 2019 & st$final_observed_wave == 2022]; long_rows <- pw[pw$pid %in% eligible_long & !is.na(pw$long_weight_2019_2022), c("pid", "long_weight_2019_2022")]; long_rows <- long_rows[!duplicated(long_rows$pid), , drop = FALSE]
  canonical <- c(unique_household_wave = !anyDuplicated(hh_key), unique_person_wave = !anyDuplicated(pw_key), unique_person_static = !anyDuplicated(st$pid), unique_questionnaire = !anyDuplicated(q_key), unique_response = !anyDuplicated(paste(rr$pid, rr$wave, rr$item_id, sep = "::")), wave_sets = all(setequal(unique(pw$wave), expected_waves), setequal(unique(hh$wave), expected_waves)), foreign_keys = all(pw$pid %in% st$pid) && all(paste(pw$hid, pw$wave, sep = "::") %in% hh_key), age = all(pw$age == pw$wave - st$birth_year[match(pw$pid, st$pid)]), household_size = all(vapply(seq_len(nrow(hh)), function(j) sum(pw$hid == hh$hid[j] & pw$wave == hh$wave[j]) == hh$hhsize_reported[j], logical(1))), origin = all(st$origin_hid %in% hh$hid), move_flags = all(pw$moved_since_prior_wave %in% c(0, 1)) && all(hh$move_event_flag %in% c(0, 1)), positive_weights = all(pw$person_xs_weight > 0 & is.finite(pw$person_xs_weight)) && all(hh$hh_xs_weight > 0 & is.finite(hh$hh_xs_weight)), weight_targets = all(abs(tapply(pw$person_xs_weight, pw$wave, sum) - 10000) < .01) && all(abs(tapply(hh$hh_xs_weight, hh$wave, sum) - 5000) < .01), longitudinal_presence = all(is.na(pw$long_weight_2019_2022) | is.finite(pw$long_weight_2019_2022)), longitudinal_constancy = all(tapply(pw$long_weight_2019_2022, pw$pid, function(x) length(unique(x[!is.na(x)])) <= 1L)), longitudinal_target = abs(sum(long_rows$long_weight_2019_2022) - 10000) < .01, response_links = all(response_pw %in% pw_key) && all(response_q %in% q_key), response_cardinality = all(vapply(seq_len(nrow(pw)), function(j) sum(response_pw == pw_key[j]) == sum(q$wave == pw$wave[j]), logical(1))), response_shape = all(rr$answer_status %in% c("answered", "no_answer", "not_applicable")) && all(rr$answered %in% c(0, 1)))
  employed <- pw$employment_status == "employed"; observed <- employed & !is.na(pw$income_raw); missing <- employed & is.na(pw$income_raw); ineligible <- !employed
  canonical <- c(canonical, income_consistency = all(pw$income_imp[observed] == 0L) && all(pw$income_final[observed] == pw$income_raw[observed]) && all(pw$income_imp[missing] == 1L) && all(pw$income_missing_code[missing] == "no_answer") && all(is.na(pw$income_raw[ineligible])) && all(pw$income_final[ineligible] == 0))
  if (!all(canonical)) fail(paste("canonical invariant failures:", paste(names(canonical)[!canonical], collapse = ", ")))
  provenance <- c("release_id", "generator_version", "seed", "generated_utc", "r_version", "r_platform", "fabricatr_version", "simstudy_version", "data_table_version", "digest_version", "renv_version", "lockfile_sha256", "generator_sha256", "generator_inputs_sha256", "source_provenance")
  release_metadata <- c("table_name", "file_name", "target_total", "target_unit")
  scalar_equal <- function(x, y) identical(ifelse(is.na(x), "", as.character(x)), ifelse(is.na(y), "", as.character(y)))
  manifest_shape <- identical(names(m), names(fm)) && nrow(m) == nrow(fm) && nrow(m) == 6L &&
    identical(as.character(m$release_id), rep(paste0(as.character(fm$release_id[[1]]), "-participant-repair"), nrow(m))) &&
    identical(as.character(m$defect_profile), rep("participant_repair_inconsistent_imputation_flag", nrow(m))) &&
    all(as.character(m$expected_validation_status) == "pass")
  metadata_ok <- all(vapply(c(provenance[-1L], release_metadata), function(n) scalar_equal(m[[n]], fm[[n]]), logical(1)))
  # The repaired release remains the same declared source contract: only the
  # participant release label/profile/status and byte-derived row/hash fields
  # may change. In particular, platform and defect provenance are semantic,
  # not free-text decorations.
  if (!manifest_shape || !metadata_ok) fail("manifest label/status/provenance contract failed (including r_platform and defect_profile)")
  if (any(vapply(seq_len(nrow(m)), function(j) { p <- file.path(release, m$file_name[j]); !file.exists(p) || nrow(read(p)) != m$row_count[j] || digest::digest(file = p, algo = "sha256", serialize = FALSE) != m$sha256[j] }, logical(1)))) fail("manifest row counts or hashes do not match release bytes")
  summary <- read(file.path(base, "outputs", "income-summary.csv")); expected <- data.frame(wave = 2019:2022, n_employed = c(52L, 46L, 57L, 56L), unweighted_mean_income = c(2292.115, 2486.304, 2292.982, 2528.929), weighted_mean_income = c(2244.679, 2431.116, 2255.280, 2526.796), stringsAsFactors = FALSE)
  summary_ok <- identical(names(summary), names(expected)) && nrow(summary) == nrow(expected) &&
    identical(as.integer(summary$wave), as.integer(expected$wave)) &&
    identical(as.integer(summary$n_employed), as.integer(expected$n_employed))
  for (field in c("unweighted_mean_income", "weighted_mean_income")) {
    summary_ok <- summary_ok && all(is.finite(summary[[field]])) && all(abs(as.numeric(summary[[field]]) - as.numeric(expected[[field]])) <= 1e-6)
  }
  if (!summary_ok) fail("income summary does not match stated estimand within strict absolute tolerance")

  # Replay both participant scripts in a checker-controlled fresh lab.  The
  # submitted release and summary are not evidence by themselves: a repair
  # must create them from a fresh copy of the immutable defective fixture.
  replay_lab <- tempfile("lab4-replay-")
  dir.create(replay_lab, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(replay_lab, "fixture", "release"), recursive = TRUE)
  dir.create(file.path(replay_lab, "code"), recursive = TRUE)
  replay_copy <- file.path(replay_lab, "fixture", "release")
  for (n in required) file.copy(file.path(fixture, n), file.path(replay_copy, n), overwrite = TRUE)
  replay_repair <- file.path(replay_lab, "code", "repair_release.R")
  replay_summary <- file.path(replay_lab, "code", "summarize_income.R")
  file.copy(repair_script, replay_repair, overwrite = TRUE)
  file.copy(summary_script, replay_summary, overwrite = TRUE)
  replay_release <- file.path(replay_lab, "repaired-release")
  replay_output <- file.path(replay_lab, "income-summary.csv")
  run_r <- function(script, argv) {
    out <- suppressWarnings(system2("Rscript", c(script, argv), stdout = TRUE, stderr = TRUE))
    status <- attr(out, "status")
    list(status = if (is.null(status)) 0L else as.integer(status), output = out)
  }
  repair_run <- run_r(replay_repair, replay_release)
  summary_run <- if (identical(repair_run$status, 0L)) run_r(replay_summary, c(replay_release, replay_output)) else list(status = 1L, output = character())
  replay_ok <- identical(repair_run$status, 0L) && identical(summary_run$status, 0L) &&
    all(file.exists(file.path(replay_release, required))) && file.exists(replay_output)
  if (!replay_ok) {
    fail("repair/summary scripts did not create a complete release from a fresh fixture")
  } else {
    hash_file <- function(p) digest::digest(file = p, algo = "sha256", serialize = FALSE)
    same_release <- all(vapply(required, function(n) hash_file(file.path(replay_release, n)) == hash_file(file.path(release, n)), logical(1)))
    same_summary <- hash_file(replay_output) == hash_file(file.path(base, "outputs", "income-summary.csv"))
    if (!same_release || !same_summary) fail("submitted artefacts do not equal the deterministic script replay")
  }
}
if (length(bad)) { cat(paste0("FAIL release: ", bad, "\n"), sep = ""); quit(status = 1L) }
cat("PASS release: repaired release, manifest, and summary verified\n")
