#!/usr/bin/env Rscript

read_release_csv <- function(path) {
  utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    na.strings = "",
    check.names = FALSE,
    strip.white = FALSE
  )
}

validate_release <- function(release_dir, invariants_path, quiet = FALSE) {
  required <- c(
    "person_static.csv", "household_wave.csv", "person_wave.csv",
    "questionnaire.csv", "response.csv", "schema.csv", "release_manifest.csv"
  )
  rows <- list()
  record <- function(check_id, pass, detail) {
    rows[[length(rows) + 1L]] <<- data.frame(
      check_id = check_id,
      status = if (isTRUE(pass)) "PASS" else "FAIL",
      detail = as.character(detail),
      stringsAsFactors = FALSE
    )
  }

  present <- file.exists(file.path(release_dir, required))
  record("required_files", all(present), paste0(sum(present), "/", length(required), " present"))
  if (!all(present)) return(do.call(rbind, rows))

  person_static <- read_release_csv(file.path(release_dir, "person_static.csv"))
  household_wave <- read_release_csv(file.path(release_dir, "household_wave.csv"))
  person_wave <- read_release_csv(file.path(release_dir, "person_wave.csv"))
  questionnaire <- read_release_csv(file.path(release_dir, "questionnaire.csv"))
  response <- read_release_csv(file.path(release_dir, "response.csv"))
  schema <- read_release_csv(file.path(release_dir, "schema.csv"))
  manifest <- read_release_csv(file.path(release_dir, "release_manifest.csv"))

  duplicate_count <- function(x) sum(duplicated(x))
  hh_key <- paste(household_wave$hid, household_wave$wave, sep = "::")
  pw_key <- paste(person_wave$pid, person_wave$wave, sep = "::")
  q_key <- paste(questionnaire$wave, questionnaire$item_id, sep = "::")
  response_pw_key <- paste(response$pid, response$wave, sep = "::")
  response_q_key <- paste(response$wave, response$item_id, sep = "::")
  response_key <- paste(response$pid, response$wave, response$item_id, sep = "::")

  record("unique_household_wave", duplicate_count(hh_key) == 0,
         paste(duplicate_count(hh_key), "duplicate keys"))
  record("unique_person_wave", duplicate_count(pw_key) == 0,
         paste(duplicate_count(pw_key), "duplicate keys"))
  record("unique_person_static", duplicate_count(person_static$pid) == 0,
         paste(duplicate_count(person_static$pid), "duplicate IDs"))
  record("unique_questionnaire", duplicate_count(q_key) == 0,
         paste(duplicate_count(q_key), "duplicate keys"))
  record("unique_response", duplicate_count(response_key) == 0,
         paste(duplicate_count(response_key), "duplicate keys"))

  orphan_people <- sum(!person_wave$pid %in% person_static$pid)
  orphan_households <- sum(!paste(person_wave$hid, person_wave$wave, sep = "::") %in% hh_key)
  record("foreign_keys", orphan_people == 0 && orphan_households == 0,
         paste(orphan_people, "person and", orphan_households, "household orphans"))

  linked_sizes <- aggregate(
    person_wave$pid,
    by = list(hid = person_wave$hid, wave = person_wave$wave),
    FUN = function(x) length(unique(x))
  )
  names(linked_sizes)[3] <- "linked_size"
  size_compare <- merge(
    household_wave[, c("hid", "wave", "hhsize_reported")],
    linked_sizes,
    by = c("hid", "wave"),
    all = TRUE
  )
  bad_size <- is.na(size_compare$hhsize_reported) | is.na(size_compare$linked_size) |
    size_compare$hhsize_reported != size_compare$linked_size
  record("household_size", !any(bad_size), paste(sum(bad_size), "mismatches"))

  static_index <- match(person_wave$pid, person_static$pid)
  expected_age <- person_wave$wave - person_static$birth_year[static_index]
  inside_window <- person_wave$wave >= person_static$entry_wave[static_index] &
    person_wave$wave <= person_static$final_observed_wave[static_index]
  observed_wave_sets <- split(person_wave$wave, person_wave$pid)
  gap_count <- sum(vapply(observed_wave_sets, function(x) {
    x <- sort(unique(x))
    length(x) > 1L && any(diff(x) != 1L)
  }, logical(1)))
  bad_age <- is.na(expected_age) | person_wave$age != expected_age |
    person_wave$age < 18 | person_wave$age > 90
  record("age_and_window", !any(bad_age) && all(inside_window, na.rm = FALSE) && gap_count == 0,
         paste(sum(bad_age), "age issues;", sum(!inside_window), "window issues;", gap_count, "gaps"))

  move_issues <- 0L
  for (pid in unique(person_wave$pid)) {
    x <- person_wave[person_wave$pid == pid, ]
    x <- x[order(x$wave), ]
    expected_move <- c(0L, as.integer(x$hid[-1] != x$hid[-nrow(x)]))
    if (length(expected_move) != nrow(x) || any(x$moved_since_prior_wave != expected_move)) {
      move_issues <- move_issues + 1L
    }
  }
  record("move_mechanics", move_issues == 0, paste(move_issues, "person trajectories disagree"))

  positive_finite <- function(x) all(is.finite(x) & x > 0)
  weights_ok <- positive_finite(person_wave$person_xs_weight) &&
    positive_finite(household_wave$hh_xs_weight)
  record("positive_weights", weights_ok, if (weights_ok) "all positive and finite" else "invalid weight found")

  person_totals <- aggregate(person_wave$person_xs_weight, list(wave = person_wave$wave), sum)$x
  household_totals <- aggregate(household_wave$hh_xs_weight, list(wave = household_wave$wave), sum)$x
  targets_ok <- all(abs(person_totals - 10000) < 0.01) &&
    all(abs(household_totals - 5000) < 0.01)
  record("weight_targets", targets_ok,
         paste("person", paste(round(person_totals, 3), collapse = "/"),
               "; household", paste(round(household_totals, 3), collapse = "/")))

  eligible_long <- person_static$pid[
    person_static$sample_cohort == "baseline_2019" & person_static$entry_wave == 2019 &
      person_static$final_observed_wave == 2022
  ]
  should_have_long <- person_wave$pid %in% eligible_long
  long_ok <- all(is.finite(person_wave$long_weight_2019_2022[should_have_long]) &
                   person_wave$long_weight_2019_2022[should_have_long] > 0) &&
    all(is.na(person_wave$long_weight_2019_2022[!should_have_long]))
  record("longitudinal_weight", long_ok,
         paste(sum(should_have_long), "eligible rows;", sum(!is.na(person_wave$long_weight_2019_2022)), "weighted rows"))

  employed <- person_wave$employment_status == "employed"
  eligible_observed <- employed & !is.na(person_wave$income_raw)
  eligible_missing <- employed & is.na(person_wave$income_raw)
  ineligible <- !employed
  inc_response <- response[response$item_id == "INC", ]
  inc_response_index <- match(
    paste(inc_response$pid, inc_response$wave, sep = "::"), pw_key
  )
  inc_response_value <- suppressWarnings(as.numeric(inc_response$value))
  inc_response_ok <- length(inc_response_index) == nrow(person_wave) &&
    !anyNA(inc_response_index) &&
    all(ifelse(
      !is.na(person_wave$income_raw[inc_response_index]),
      inc_response$answer_status == "answered" &
        inc_response_value == person_wave$income_raw[inc_response_index],
      ifelse(
        person_wave$employment_status[inc_response_index] == "employed",
        inc_response$answer_status == "no_answer",
        inc_response$answer_status == "not_applicable"
      )
    ))
  income_ok <-
    all(person_wave$income_imp[eligible_observed] == 0L) &&
    all(person_wave$income_final[eligible_observed] == person_wave$income_raw[eligible_observed]) &&
    all(is.na(person_wave$income_missing_code[eligible_observed])) &&
    all(person_wave$income_imp[eligible_missing] == 1L) &&
    all(is.finite(person_wave$income_final[eligible_missing]) & person_wave$income_final[eligible_missing] >= 0) &&
    all(person_wave$income_missing_code[eligible_missing] == "no_answer") &&
    all(is.na(person_wave$income_raw[ineligible])) &&
    all(person_wave$income_final[ineligible] == 0) &&
    all(person_wave$income_imp[ineligible] == 0L) &&
    all(person_wave$income_missing_code[ineligible] == "not_applicable") &&
    inc_response_ok
  record("income_consistency", income_ok,
         paste(sum(eligible_observed), "observed;", sum(eligible_missing), "imputed;", sum(ineligible), "not applicable"))

  orphan_responses <- sum(!response_pw_key %in% pw_key) + sum(!response_q_key %in% q_key)
  record("response_links", orphan_responses == 0, paste(orphan_responses, "orphan response links"))

  response_person_index <- match(response_pw_key, pw_key)
  response_employment <- person_wave$employment_status[response_person_index]
  answered_shape <- ifelse(
    response$answered == 1L,
    response$answer_status == "answered" & !is.na(response$value) & is.na(response$missing_code),
    response$answer_status %in% c("no_answer", "not_applicable") &
      is.na(response$value) & !is.na(response$missing_code) &
      response$missing_code == response$answer_status
  )
  emp_rows <- response$item_id == "EMP"
  inc_rows <- response$item_id == "INC"
  lsat_rows <- response$item_id == "LSAT"
  trn_rows <- response$item_id == "TRN"
  emp_values_ok <- all(response$value[emp_rows] %in% c(
    "employed", "unemployed", "education", "retired", "not_in_labor_force"
  ))
  inc_numeric <- suppressWarnings(as.numeric(response$value[inc_rows]))
  inc_eligible <- response_employment[inc_rows] == "employed"
  inc_rule_ok <- all(response$answer_status[inc_rows][!inc_eligible] == "not_applicable") &&
    all(is.na(inc_numeric) | (inc_numeric >= 0 & inc_numeric <= 25000))
  lsat_numeric <- suppressWarnings(as.numeric(response$value[lsat_rows]))
  lsat_ok <- all(is.na(lsat_numeric) | (lsat_numeric >= 0 & lsat_numeric <= 10))
  trn_numeric <- suppressWarnings(as.numeric(response$value[trn_rows]))
  trn_eligible <- response_employment[trn_rows] %in% c("employed", "education")
  trn_max <- ifelse(response$wave[trn_rows] < 2021, 60, 80)
  trn_ok <- all(response$answer_status[trn_rows][!trn_eligible] == "not_applicable") &&
    all(is.na(trn_numeric) | (trn_numeric >= 0 & trn_numeric <= trn_max))
  questionnaire_rules_ok <- all(answered_shape) && emp_values_ok && inc_rule_ok && lsat_ok && trn_ok
  record("questionnaire_rules", questionnaire_rules_ok,
         if (questionnaire_rules_ok) "codes ranges eligibility and missing statuses agree" else "rule disagreement found")

  analytical_tables <- list(
    person_static = person_static,
    household_wave = household_wave,
    person_wave = person_wave,
    questionnaire = questionnaire,
    response = response
  )
  actual_fields <- unlist(lapply(names(analytical_tables), function(table_name) {
    paste(table_name, names(analytical_tables[[table_name]]), sep = "::")
  }), use.names = FALSE)
  documented_fields <- paste(schema$table_name, schema$column_name, sep = "::")
  missing_docs <- setdiff(actual_fields, documented_fields)
  extra_docs <- setdiff(documented_fields, actual_fields)
  record("schema_coverage", length(missing_docs) == 0 && length(extra_docs) == 0,
         paste(length(missing_docs), "missing and", length(extra_docs), "extra dictionary fields"))

  prohibited_pattern <- "(^|_)(name|address|email|free_text|source_id|source_identifier)($|_)"
  prohibited_columns <- grep(prohibited_pattern, actual_fields, value = TRUE, ignore.case = TRUE)
  record("no_prohibited_fields", length(prohibited_columns) == 0,
         paste(length(prohibited_columns), "prohibited columns"))

  manifest_files <- file.path(release_dir, manifest$file_name)
  expected_manifest_files <- setdiff(required, "release_manifest.csv")
  manifest_coverage_ok <- setequal(manifest$file_name, expected_manifest_files) &&
    !anyDuplicated(manifest$file_name)
  actual_counts <- vapply(manifest_files, function(path) nrow(read_release_csv(path)), integer(1))
  count_ok <- manifest_coverage_ok && all(actual_counts == manifest$row_count)
  record("manifest_counts", count_ok,
         paste(sum(actual_counts != manifest$row_count), "count mismatches; coverage", manifest_coverage_ok))

  if (!requireNamespace("digest", quietly = TRUE)) {
    record("manifest_checksums", FALSE, "digest package unavailable")
  } else {
    actual_hashes <- vapply(manifest_files, function(path) {
      digest::digest(file = path, algo = "sha256", serialize = FALSE)
    }, character(1), USE.NAMES = FALSE)
    hash_ok <- all(actual_hashes == manifest$sha256)
    record("manifest_checksums", hash_ok, paste(sum(actual_hashes != manifest$sha256), "checksum mismatches"))
  }

  report <- do.call(rbind, rows)
  declared <- read_release_csv(invariants_path)$check_id
  undeclared <- setdiff(report$check_id, declared)
  unimplemented <- setdiff(declared, report$check_id)
  if (length(undeclared) || length(unimplemented)) {
    stop(
      "Validator/invariants mismatch. Undeclared: ", paste(undeclared, collapse = ", "),
      "; unimplemented: ", paste(unimplemented, collapse = ", "), call. = FALSE
    )
  }
  if (!quiet) print(report, row.names = FALSE)
  report
}

if (sys.nframe() == 0L) {
  argv <- commandArgs(trailingOnly = TRUE)
  script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
  root_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
  release_dir <- if (length(argv)) argv[[1]] else file.path(root_dir, "fixtures", "clean")
  report <- validate_release(release_dir, file.path(root_dir, "invariants.csv"))
  if (any(report$status == "FAIL")) quit(status = 1L)
}
