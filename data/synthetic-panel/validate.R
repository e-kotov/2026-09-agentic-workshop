#!/usr/bin/env Rscript

# Release validator. The report emitted here is evidence from this run; the
# generated manifest contains only expected status claims.

read_release_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "",
                  check.names = FALSE, strip.white = FALSE)
}

validate_release <- function(release_dir, invariants_path, quiet = FALSE) {
  required <- c("person_static.csv", "household_wave.csv", "person_wave.csv",
                "questionnaire.csv", "response.csv", "schema.csv",
                "release_manifest.csv")
  rows <- list()
  record <- function(check_id, pass, detail) {
    rows[[length(rows) + 1L]] <<- data.frame(
      check_id = check_id, status = if (isTRUE(pass)) "PASS" else "FAIL",
      detail = as.character(detail), stringsAsFactors = FALSE
    )
  }
  count_dup <- function(x) sum(duplicated(x))
  has_cols <- function(x, cols) all(cols %in% names(x))
  safe_all <- function(x) length(x) > 0L && all(x %in% TRUE, na.rm = FALSE)
  root_dir <- dirname(normalizePath(invariants_path, mustWork = TRUE))
  expected_waves <- 2019:2022
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
  needed <- list(
    person_static = c("pid", "birth_year", "sex_reported", "education", "sample_cohort", "entry_wave", "final_observed_wave", "exit_reason", "origin_hid"),
    household_wave = c("hid", "wave", "region4", "hhsize_reported", "response_status", "household_origin", "move_event_flag", "hh_xs_weight"),
    person_wave = c("pid", "wave", "hid", "age", "employment_status", "response_mode", "response_status", "moved_since_prior_wave", "income_raw", "income_final", "income_imp", "income_missing_code", "person_xs_weight", "long_weight_2019_2022"),
    questionnaire = c("wave", "item_id", "instrument", "variable", "value_type", "allowed_codes", "minimum", "maximum", "required_if", "label", "metadata_version"),
    response = c("pid", "wave", "item_id", "value", "answer_status", "missing_code", "source_mode", "answered"),
    schema = c("table_name", "column_name", "storage_type", "nullable", "key_role", "description", "allowed_values", "unit"),
    manifest = c("release_id", "defect_profile", "generator_version", "seed", "generated_utc", "r_version", "r_platform", "fabricatr_version", "simstudy_version", "data_table_version", "digest_version", "renv_version", "lockfile_sha256", "generator_sha256", "generator_inputs_sha256", "source_provenance", "table_name", "file_name", "row_count", "sha256", "expected_validation_status", "target_total", "target_unit")
  )
  objects <- list(person_static = person_static, household_wave = household_wave,
                  person_wave = person_wave, questionnaire = questionnaire,
                  response = response, schema = schema, manifest = manifest)
  shape <- vapply(names(needed), function(nm) {
    has_cols(objects[[nm]], needed[[nm]])
  }, logical(1))
  if (!all(shape)) {
    declared <- read_release_csv(invariants_path)$check_id
    for (id in setdiff(declared, vapply(rows, `[[`, character(1), "check_id"))) record(id, FALSE, "required columns missing")
    report <- do.call(rbind, rows)
    if (!quiet) print(report, row.names = FALSE)
    return(report)
  }

  hh_key <- paste(household_wave$hid, household_wave$wave, sep = "::")
  pw_key <- paste(person_wave$pid, person_wave$wave, sep = "::")
  q_key <- paste(questionnaire$wave, questionnaire$item_id, sep = "::")
  response_pw_key <- paste(response$pid, response$wave, sep = "::")
  response_q_key <- paste(response$wave, response$item_id, sep = "::")
  response_key <- paste(response$pid, response$wave, response$item_id, sep = "::")
  record("unique_household_wave", count_dup(hh_key) == 0, paste(count_dup(hh_key), "duplicate keys"))
  record("unique_person_wave", count_dup(pw_key) == 0, paste(count_dup(pw_key), "duplicate keys"))
  record("unique_person_static", count_dup(person_static$pid) == 0, paste(count_dup(person_static$pid), "duplicate IDs"))
  record("unique_questionnaire", count_dup(q_key) == 0, paste(count_dup(q_key), "duplicate keys"))
  record("unique_response", count_dup(response_key) == 0, paste(count_dup(response_key), "duplicate keys"))
  id_format_ok <- all(grepl("^P[0-9]{6}$", person_static$pid)) && all(grepl("^P[0-9]{6}$", person_wave$pid)) && all(grepl("^P[0-9]{6}$", response$pid)) && all(grepl("^H[0-9]{4}$", household_wave$hid)) && all(grepl("^H[0-9]{4}$", person_static$origin_hid)) && all(grepl("^H[0-9]{4}$", person_wave$hid))
  record("opaque_identifier_format", id_format_ok, if (id_format_ok) "H####/P###### opaque identifier contract" else "identifier format is not exact H####/P######")

  wave_sets <- c(person_wave = setequal(unique(person_wave$wave), expected_waves), household_wave = setequal(unique(household_wave$wave), expected_waves), questionnaire = setequal(unique(questionnaire$wave), expected_waves), response = setequal(unique(response$wave), expected_waves))
  record("wave_sets", all(wave_sets), paste(names(wave_sets)[!wave_sets], collapse = ", "))
  static_index <- match(person_wave$pid, person_static$pid)
  expected_age <- person_wave$wave - person_static$birth_year[static_index]
  bad_age <- is.na(expected_age) | person_wave$age != expected_age | person_wave$age < 18 | person_wave$age > 90
  inside_window <- !is.na(static_index) & person_wave$wave >= person_static$entry_wave[static_index] & person_wave$wave <= person_static$final_observed_wave[static_index]
  window_issues <- cohort_issues <- exit_issues <- 0L
  for (pid in unique(person_static$pid)) {
    st <- person_static[person_static$pid == pid, , drop = FALSE][1, ]
    obs <- sort(unique(person_wave$wave[person_wave$pid == pid]))
    window_issues <- window_issues + as.integer(!identical(obs, st$entry_wave:st$final_observed_wave))
    cohort_issues <- cohort_issues + as.integer((st$sample_cohort == "baseline_2019" && st$entry_wave != 2019) || (st$sample_cohort == "refreshment_2021" && st$entry_wave != 2021))
    exit_issues <- exit_issues + as.integer((st$final_observed_wave < 2022 && st$exit_reason != "panel_attrition") || (st$final_observed_wave == 2022 && st$exit_reason != "still_observed_end"))
  }
  record("age_and_window", !any(bad_age) && safe_all(inside_window) && window_issues == 0L, paste(sum(bad_age), "age issues;", sum(!inside_window), "window issues;", window_issues, "sequence issues"))
  record("observation_windows", window_issues == 0L && cohort_issues == 0L && exit_issues == 0L, paste(window_issues, "sequence;", cohort_issues, "cohort;", exit_issues, "exit issues"))

  orphan_people <- sum(!person_wave$pid %in% person_static$pid)
  orphan_households <- sum(!paste(person_wave$hid, person_wave$wave, sep = "::") %in% hh_key)
  record("foreign_keys", orphan_people == 0 && orphan_households == 0, paste(orphan_people, "person and", orphan_households, "household orphans"))
  linked_sizes <- aggregate(person_wave$pid, by = list(hid = person_wave$hid, wave = person_wave$wave), FUN = function(x) length(unique(x)))
  names(linked_sizes)[3] <- "linked_size"
  size_compare <- merge(household_wave[, c("hid", "wave", "hhsize_reported")], linked_sizes, by = c("hid", "wave"), all = TRUE)
  bad_size <- is.na(size_compare$hhsize_reported) | is.na(size_compare$linked_size) | size_compare$hhsize_reported != size_compare$linked_size
  record("household_size", !any(bad_size), paste(sum(bad_size), "mismatches"))
  origin_issues <- 0L
  for (pid in unique(person_static$pid)) {
    st <- person_static[person_static$pid == pid, , drop = FALSE][1, ]
    x <- person_wave[person_wave$pid == pid, , drop = FALSE]
    if (!nrow(x) || x$hid[which.min(x$wave)] != st$origin_hid || !paste(st$origin_hid, st$entry_wave, sep = "::") %in% hh_key) origin_issues <- origin_issues + 1L
  }
  hh_first <- tapply(household_wave$wave, household_wave$hid, min)
  origin_by_person_wave <- person_static$origin_hid[match(person_wave$pid, person_static$pid)]
  first_household_row <- match(names(hh_first), household_wave$hid)
  first_hids <- names(hh_first)
  first_split <- vapply(first_hids, function(hid) {
    w <- hh_first[[hid]]
    idx <- person_wave$hid == hid & person_wave$wave == w
    any(origin_by_person_wave[idx] != hid) && any(person_wave$moved_since_prior_wave[idx] == 1L)
  }, logical(1))
  names(first_split) <- first_hids
  hh_expected_origin <- ifelse(first_split, "split_off", ifelse(hh_first == 2019, "baseline", "refreshment"))
  names(hh_expected_origin) <- names(hh_first)
  hh_origin_issues <- sum(as.character(household_wave$household_origin) != hh_expected_origin[household_wave$hid])
  baseline_issues <- sum(person_static$sample_cohort == "baseline_2019" & (person_static$entry_wave != 2019 | hh_first[person_static$origin_hid] != 2019)) +
    sum(household_wave$household_origin == "baseline" & hh_first[household_wave$hid] != 2019)
  refreshment_issues <- sum(person_static$sample_cohort == "refreshment_2021" & (person_static$entry_wave != 2021 | hh_first[person_static$origin_hid] != 2021)) +
    sum(household_wave$household_origin == "refreshment" & hh_first[household_wave$hid] != 2021)
  split_issues <- sum(household_wave$household_origin == "split_off" & !first_split[household_wave$hid]) +
    sum(first_split[household_wave$hid] & household_wave$household_origin != "split_off")
  record("origin_baseline", baseline_issues == 0L, paste(baseline_issues, "baseline origin issues"))
  record("origin_refreshment", refreshment_issues == 0L, paste(refreshment_issues, "refreshment origin issues"))
  record("origin_split", split_issues == 0L, paste(split_issues, "split-off origin issues"))
  record("membership_origin", origin_issues == 0L && hh_origin_issues == 0L, paste(origin_issues, "person origin issues;", hh_origin_issues, "household origin issues"))

  move_issues <- 0L
  for (pid in unique(person_wave$pid)) {
    x <- person_wave[person_wave$pid == pid, , drop = FALSE]
    x <- x[order(x$wave), , drop = FALSE]
    expected_move <- c(0L, as.integer(x$hid[-1] != x$hid[-nrow(x)]))
    if (any(x$moved_since_prior_wave != expected_move)) move_issues <- move_issues + 1L
  }
  hh_move_expected <- vapply(seq_len(nrow(household_wave)), function(i) any(person_wave$hid == household_wave$hid[i] & person_wave$wave == household_wave$wave[i] & person_wave$moved_since_prior_wave == 1L), logical(1))
  move_hh_issues <- sum(hh_move_expected != (household_wave$move_event_flag == 1L))
  first_appearance_flag_issues <- sum((household_wave$move_event_flag == 1L) != (first_split[household_wave$hid] & household_wave$wave == hh_first[household_wave$hid]))
  inward_move_issues <- sum(person_wave$moved_since_prior_wave == 1L & !(first_split[person_wave$hid] & person_wave$wave == hh_first[person_wave$hid]))
  record("move_mechanics", move_issues == 0L && move_hh_issues == 0L && first_appearance_flag_issues == 0L && inward_move_issues == 0L, paste(move_issues, "person trajectories;", move_hh_issues, "household flags;", first_appearance_flag_issues, "first-appearance flags;", inward_move_issues, "inward moves"))
  record("movement_agreement", move_hh_issues == 0L && origin_issues == 0L, paste(move_hh_issues, "household move;", origin_issues, "origin/membership issues"))

  positive_finite <- function(x) length(x) > 0L && all(is.finite(x) & x > 0)
  weights_ok <- positive_finite(person_wave$person_xs_weight) && positive_finite(household_wave$hh_xs_weight)
  record("positive_weights", weights_ok, if (weights_ok) "all positive and finite" else "invalid weight found")
  person_totals <- tapply(person_wave$person_xs_weight, person_wave$wave, sum)
  household_totals <- tapply(household_wave$hh_xs_weight, household_wave$wave, sum)
  targets_ok <- all(abs(as.numeric(person_totals[as.character(expected_waves)]) - 10000) < 0.01) && all(abs(as.numeric(household_totals[as.character(expected_waves)]) - 5000) < 0.01)
  record("weight_targets", targets_ok, paste("person", paste(round(person_totals, 3), collapse = "/"), "; household", paste(round(household_totals, 3), collapse = "/")))
  eligible_long <- person_static$pid[person_static$sample_cohort == "baseline_2019" & person_static$entry_wave == 2019 & person_static$final_observed_wave == 2022]
  should_have_long <- person_wave$pid %in% eligible_long
  long_presence_ok <- all(is.finite(person_wave$long_weight_2019_2022[should_have_long]) & person_wave$long_weight_2019_2022[should_have_long] > 0) && all(is.na(person_wave$long_weight_2019_2022[!should_have_long]))
  long_constancy <- tapply(person_wave$long_weight_2019_2022[should_have_long], person_wave$pid[should_have_long], function(x) length(unique(x)) == 1L)
  long_constancy_ok <- length(long_constancy) > 0L && all(long_constancy)
  long_unique <- person_wave[should_have_long, c("pid", "long_weight_2019_2022")]
  long_unique <- long_unique[!duplicated(long_unique$pid), , drop = FALSE]
  long_total_ok <- abs(sum(long_unique$long_weight_2019_2022) - 10000) < 0.01
  record("longitudinal_weight", long_presence_ok, paste(sum(should_have_long), "eligible rows;", sum(!is.na(person_wave$long_weight_2019_2022)), "weighted rows"))
  record("longitudinal_weight_constancy", long_constancy_ok, paste(sum(!long_constancy), "nonconstant person trajectories"))
  record("longitudinal_weight_targets", long_total_ok, paste("eligible total", round(sum(long_unique$long_weight_2019_2022), 3)))

  response_cardinality <- vapply(seq_len(nrow(person_wave)), function(i) sum(response_pw_key == pw_key[i]) == sum(questionnaire$wave == person_wave$wave[i]), logical(1))
  record("response_cardinality", safe_all(response_cardinality), paste(sum(!response_cardinality), "person-wave cardinality failures"))
  orphan_responses <- sum(!response_pw_key %in% pw_key) + sum(!response_q_key %in% q_key)
  record("response_links", orphan_responses == 0, paste(orphan_responses, "orphan response links"))
  response_person_index <- match(response_pw_key, pw_key)
  response_employment <- person_wave$employment_status[response_person_index]
  allowed_status <- response$answer_status %in% c("answered", "no_answer", "not_applicable")
  answer_shape <- ifelse(response$answered == 1L, response$answer_status == "answered" & !is.na(response$value) & is.na(response$missing_code), response$answered == 0L & response$answer_status %in% c("no_answer", "not_applicable") & is.na(response$value) & !is.na(response$missing_code) & response$missing_code == response$answer_status)
  rules_ok <- allowed_status & answer_shape
  eval_eligibility <- function(expression, employment) {
    expression <- if (is.na(expression)) "" else expression
    if (identical(expression, "TRUE")) return(TRUE)
    if (identical(expression, "FALSE")) return(FALSE)
    if (grepl("employment_status == employed", expression, fixed = TRUE)) return(identical(employment, "employed"))
    if (grepl("employment_status in", expression, fixed = TRUE)) return(employment %in% c("employed", "education"))
    FALSE
  }
  for (i in seq_len(nrow(response))) {
    qrow <- questionnaire[questionnaire$wave == response$wave[i] & questionnaire$item_id == response$item_id[i], , drop = FALSE]
    if (!nrow(qrow)) { rules_ok[i] <- FALSE; next }
    qrow <- qrow[1, ]
    eligible <- eval_eligibility(qrow$required_if, response_employment[i])
    if (!eligible && response$answer_status[i] != "not_applicable") rules_ok[i] <- FALSE
    if (eligible && response$answer_status[i] == "not_applicable") rules_ok[i] <- FALSE
    if (response$answer_status[i] == "answered") {
      if (qrow$value_type == "categorical") rules_ok[i] <- rules_ok[i] && response$value[i] %in% strsplit(qrow$allowed_codes, "\\|", fixed = FALSE)[[1]]
      if (qrow$value_type %in% c("integer", "double")) {
        val <- suppressWarnings(as.numeric(response$value[i]))
        rules_ok[i] <- rules_ok[i] && !is.na(val) && (is.na(qrow$minimum) || val >= qrow$minimum) && (is.na(qrow$maximum) || val <= qrow$maximum)
        if (qrow$value_type == "integer") rules_ok[i] <- rules_ok[i] && val == as.integer(val)
      }
    }
  }
  record("questionnaire_rules", safe_all(rules_ok), if (safe_all(rules_ok)) "types codes ranges eligibility and missing statuses agree" else paste(sum(!rules_ok), "rule failures"))
  mode_index_ok <- !is.na(response_person_index)
  mode_ok <- all(response$source_mode %in% c("web", "phone", "paper")) && all(mode_index_ok) && all(response$source_mode == person_wave$response_mode[response_person_index])
  record("mode_agreement", mode_ok, paste(sum(!mode_index_ok), "orphan modes"))
  emp_rows <- response$item_id == "EMP"
  emp_index <- match(paste(response$pid[emp_rows], response$wave[emp_rows], sep = "::"), pw_key)
  emp_agree <- length(emp_index) == sum(emp_rows) && !anyNA(emp_index) && all(response$value[emp_rows] == person_wave$employment_status[emp_index])
  record("employment_agreement", emp_agree, paste(sum(!emp_agree), "employment disagreements"))

  employed <- person_wave$employment_status == "employed"
  eligible_observed <- employed & !is.na(person_wave$income_raw)
  eligible_missing <- employed & is.na(person_wave$income_raw)
  ineligible <- !employed
  inc_response <- response[response$item_id == "INC", , drop = FALSE]
  inc_response_index <- match(paste(inc_response$pid, inc_response$wave, sep = "::"), pw_key)
  inc_response_value <- suppressWarnings(as.numeric(inc_response$value))
  inc_response_ok <- length(inc_response_index) == nrow(person_wave) && !anyNA(inc_response_index) && all(vapply(seq_len(nrow(inc_response)), function(i) { j <- inc_response_index[i]; if (person_wave$employment_status[j] != "employed") return(inc_response$answer_status[i] == "not_applicable"); if (is.na(person_wave$income_raw[j])) return(inc_response$answer_status[i] == "no_answer"); inc_response$answer_status[i] == "answered" && inc_response_value[i] == person_wave$income_raw[j] }, logical(1)))
  imputed_expected <- rep(NA_real_, nrow(person_wave))
  for (wave in sort(unique(person_wave$wave))) for (education in c("low", "medium", "high")) {
    group <- person_wave$wave == wave & person_wave$employment_status == "employed" & person_static$education[match(person_wave$pid, person_static$pid)] == education
    donor <- median(person_wave$income_raw[group], na.rm = TRUE)
    if (!is.finite(donor)) donor <- median(person_wave$income_raw[person_wave$wave == wave], na.rm = TRUE)
    imputed_expected[group & person_wave$income_imp == 1L] <- round(donor / 10) * 10
  }
  imputation_rule_ok <- all(person_wave$income_final[eligible_missing] == imputed_expected[eligible_missing])
  income_ok <- all(person_wave$income_imp[eligible_observed] == 0L) && all(person_wave$income_final[eligible_observed] == person_wave$income_raw[eligible_observed]) && all(is.na(person_wave$income_missing_code[eligible_observed])) && all(person_wave$income_imp[eligible_missing] == 1L) && all(is.finite(person_wave$income_final[eligible_missing]) & person_wave$income_final[eligible_missing] >= 0) && all(person_wave$income_missing_code[eligible_missing] == "no_answer") && all(is.na(person_wave$income_raw[ineligible])) && all(person_wave$income_final[ineligible] == 0) && all(person_wave$income_imp[ineligible] == 0L) && all(person_wave$income_missing_code[ineligible] == "not_applicable") && inc_response_ok && imputation_rule_ok
  record("income_consistency", income_ok, paste(sum(eligible_observed), "observed;", sum(eligible_missing), "imputed;", sum(ineligible), "not applicable"))

  canonical_q_path <- file.path(root_dir, "questionnaire.csv")
  metadata_ok <- file.exists(canonical_q_path) && identical(questionnaire, read_release_csv(canonical_q_path))
  record("questionnaire_metadata", metadata_ok, if (metadata_ok) "questionnaire declarations match canonical contract" else "metadata type/code/range/eligibility/version mismatch")

  canonical_schema_path <- file.path(root_dir, "schema.csv")
  schema_exact <- file.exists(canonical_schema_path) && identical(schema, read_release_csv(canonical_schema_path))
  actual_tables <- list(person_static = person_static, household_wave = household_wave, person_wave = person_wave, questionnaire = questionnaire, response = response)
  schema_issues <- character()
  if (schema_exact) for (i in seq_len(nrow(schema))) {
    decl <- schema[i, ]; x <- actual_tables[[decl$table_name]][[decl$column_name]]
    type_ok <- switch(decl$storage_type, string = is.character(x), integer = is.integer(x), double = is.numeric(x), FALSE)
    nullable_ok <- isTRUE(decl$nullable) || !anyNA(x)
    values <- x[!is.na(x)]
    allowed_decl <- if (is.na(decl$allowed_values)) "" else decl$allowed_values
    unit_decl <- if (is.na(decl$unit)) "" else decl$unit
    allowed_ok <- !nzchar(allowed_decl) || all(as.character(values) %in% strsplit(allowed_decl, "\\|", fixed = FALSE)[[1]])
    unit_required <- decl$column_name %in% c("birth_year", "entry_wave", "final_observed_wave", "wave", "age", "hhsize_reported", "income_raw", "income_final", "person_xs_weight", "long_weight_2019_2022", "hh_xs_weight")
    if (!type_ok || !nullable_ok || !allowed_ok || (unit_required && !nzchar(unit_decl))) schema_issues <- c(schema_issues, paste(decl$table_name, decl$column_name))
  }
  record("schema_semantics", schema_exact && !length(schema_issues), paste(length(schema_issues), "type/nullability/allowed/unit issues"))
  fields <- unlist(lapply(names(actual_tables), function(nm) paste(nm, names(actual_tables[[nm]]), sep = "::")), use.names = FALSE)
  documented <- paste(schema$table_name, schema$column_name, sep = "::")
  record("schema_coverage", setequal(fields, documented) && !anyDuplicated(documented), paste(length(setdiff(fields, documented)), "missing and", length(setdiff(documented, fields)), "extra dictionary fields"))
  prohibited <- grep("(^|_)(name|address|email|free_text|source_id|source_identifier)($|_)", fields, value = TRUE, ignore.case = TRUE)
  cell_text <- unlist(lapply(actual_tables, function(x) as.character(unlist(x, use.names = FALSE))), use.names = FALSE)
  suspicious_content <- any(grepl("^[^[:space:]@]+@[^[:space:]@]+[.][A-Za-z]{2,}$", cell_text)) || any(grepl("^[0-9]{1,5}[[:space:]]+[A-Za-z]+[[:space:]]+(Street|St|Road|Rd|Avenue|Ave|Boulevard|Blvd)$", cell_text, ignore.case = TRUE)) || any(grepl("(password|api[ _-]?key|secret|token)[[:space:]]*[:=]", cell_text, ignore.case = TRUE))
  record("no_prohibited_fields", !length(prohibited) && !suspicious_content, paste(length(prohibited), "prohibited columns;", sum(suspicious_content), "suspicious content cells"))

  manifest_required <- needed$manifest
  manifest_schema_ok <- identical(names(manifest), manifest_required) && nrow(manifest) == length(required) - 1L
  record("manifest_schema", manifest_schema_ok, paste(ncol(manifest), "columns;", nrow(manifest), "rows"))
  files <- setdiff(required, "release_manifest.csv")
  manifest_files <- file.path(release_dir, manifest$file_name)
  coverage_ok <- manifest_schema_ok && setequal(manifest$file_name, files) && !anyDuplicated(manifest$file_name) && all(file.exists(manifest_files))
  actual_counts <- if (coverage_ok) vapply(manifest_files, function(path) nrow(read_release_csv(path)), integer(1)) else rep(NA_integer_, nrow(manifest))
  count_ok <- coverage_ok && all(actual_counts == manifest$row_count)
  record("manifest_counts", count_ok, paste(sum(actual_counts != manifest$row_count, na.rm = TRUE), "count mismatches; coverage", coverage_ok))
  hash_ok <- FALSE
  if (coverage_ok && requireNamespace("digest", quietly = TRUE)) hash_ok <- all(vapply(manifest_files, function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE), character(1)) == manifest$sha256)
  record("manifest_checksums", hash_ok, paste(sum(!is.na(manifest$sha256) & nchar(manifest$sha256) == 64), "declared hashes"))
  provenance_fields <- c("release_id", "defect_profile", "generator_version", "seed", "generated_utc", "r_version", "r_platform", "fabricatr_version", "simstudy_version", "data_table_version", "digest_version", "renv_version", "lockfile_sha256", "generator_sha256", "generator_inputs_sha256", "source_provenance")
  same_fields <- all(vapply(provenance_fields, function(x) length(unique(as.character(manifest[[x]]))) == 1L, logical(1)))
  profile <- basename(normalizePath(release_dir, mustWork = TRUE))
  declared_profiles <- read_release_csv(file.path(root_dir, "defect_profiles.csv"))
  dependencies <- read_release_csv(file.path(root_dir, "dependencies.csv"))
  dep_version <- function(pkg) {
    z <- dependencies$version[dependencies$component == pkg]
    if (length(z) != 1L) "" else as.character(z)
  }
  lock_hash_ok <- file.exists(file.path(root_dir, "renv.lock")) && requireNamespace("digest", quietly = TRUE) && manifest$lockfile_sha256[[1]] == digest::digest(file = file.path(root_dir, "renv.lock"), algo = "sha256", serialize = FALSE)
  generator_hash_ok <- file.exists(file.path(root_dir, "generate.R")) && requireNamespace("digest", quietly = TRUE) && manifest$generator_sha256[[1]] == digest::digest(file = file.path(root_dir, "generate.R"), algo = "sha256", serialize = FALSE)
  input_files <- c("defect_profiles.csv", "invariants.csv", "dependencies.csv", "renv.lock", "renv-bootstrap.csv")
  input_hash_ok <- requireNamespace("digest", quietly = TRUE) && all(file.exists(file.path(root_dir, input_files)))
  if (input_hash_ok) {
    input_hashes <- vapply(input_files, function(name) digest::digest(file = file.path(root_dir, name), algo = "sha256", serialize = FALSE), character(1))
    input_hash_ok <- manifest$generator_inputs_sha256[[1]] == digest::digest(paste(input_files, input_hashes, sep = "=", collapse = "\n"), algo = "sha256", serialize = FALSE)
  }
  declared_row <- declared_profiles[declared_profiles$profile == profile, , drop = FALSE]
  expected_status <- if (profile == "clean") "pass" else if (nrow(declared_row)) paste0("expected_failure:", declared_row$intended_failed_checks[[1]]) else ""
  target_ok <- all(manifest$target_total[manifest$table_name == "person_wave"] == 10000) &&
    all(manifest$target_total[manifest$table_name == "household_wave"] == 5000) &&
    all(is.na(manifest$target_total[!manifest$table_name %in% c("person_wave", "household_wave")])) &&
    all(manifest$target_unit[manifest$table_name == "person_wave"] == "invented person population units per wave") &&
    all(manifest$target_unit[manifest$table_name == "household_wave"] == "invented household population units per wave") &&
    all(is.na(manifest$target_unit[!manifest$table_name %in% c("person_wave", "household_wave")]))
  manifest_key_ok <- !anyDuplicated(paste(manifest$release_id, manifest$table_name, sep = "::")) &&
    setequal(manifest$table_name, c("person_static", "household_wave", "person_wave", "questionnaire", "response", "schema")) &&
    all(manifest$file_name == paste0(manifest$table_name, ".csv"))
  package_versions_ok <- manifest$r_version[[1]] == dep_version("R") && manifest$r_platform[[1]] == dep_version("R_platform") && nzchar(manifest$r_platform[[1]]) && manifest$fabricatr_version[[1]] == dep_version("fabricatr") && manifest$simstudy_version[[1]] == dep_version("simstudy") && manifest$data_table_version[[1]] == dep_version("data.table") && manifest$digest_version[[1]] == dep_version("digest") && manifest$renv_version[[1]] == dep_version("renv")
  provenance_ok <- manifest_schema_ok && same_fields && manifest_key_ok && target_ok && package_versions_ok && lock_hash_ok && generator_hash_ok && input_hash_ok && nrow(declared_row) + as.integer(profile == "clean") == 1L && manifest$defect_profile[[1]] == profile && manifest$seed[[1]] == 20260912 && manifest$generator_version[[1]] == "0.2.0" && manifest$generated_utc[[1]] == "2026-09-12T00:00:00Z" && grepl("^synthetic-panel-0\\.2\\.0$", manifest$release_id[[1]]) && grepl("^source-free: no respondent/source records are generator inputs$", manifest$source_provenance[[1]]) && grepl("^[0-9a-f]{64}$", manifest$lockfile_sha256[[1]]) && grepl("^[0-9a-f]{64}$", manifest$generator_sha256[[1]]) && grepl("^[0-9a-f]{64}$", manifest$generator_inputs_sha256[[1]]) && all(manifest$expected_validation_status == expected_status)
  record("manifest_provenance", provenance_ok, if (provenance_ok) "release/profile/seed/toolchain/lock/source/status declarations agree" else "manifest provenance mismatch")
  seed_features_ok <- setequal(unique(person_wave$wave), expected_waves) && any(person_static$sample_cohort == "refreshment_2021") && any(person_static$final_observed_wave < 2022) && any(person_wave$moved_since_prior_wave == 1L) && any(person_wave$income_imp == 1L)
  record("canonical_seed_features", seed_features_ok, "four waves, refreshment, attrition, mover and imputation features")

  report <- do.call(rbind, rows)
  declared <- read_release_csv(invariants_path)$check_id
  if (anyDuplicated(declared) || any(!nzchar(declared))) stop("invariants.csv has duplicate/blank check IDs", call. = FALSE)
  undeclared <- setdiff(report$check_id, declared)
  unimplemented <- setdiff(declared, report$check_id)
  if (length(undeclared) || length(unimplemented)) stop("Validator/invariants mismatch. Undeclared: ", paste(undeclared, collapse = ", "), "; unimplemented: ", paste(unimplemented, collapse = ", "), call. = FALSE)
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
