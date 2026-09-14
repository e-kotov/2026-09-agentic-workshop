#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
lab_root <- dirname(dirname(normalizePath(script_path, mustWork = TRUE)))
base <- file.path(lab_root, "work")
if (length(args)) {
  if (length(args) == 2L && args[[1]] == "--base") base <- normalizePath(args[[2]], mustWork = FALSE)
  else stop("usage: Rscript checks/check_data.R [--base PATH]", call. = FALSE)
}
release <- file.path(lab_root, "fixture", "release")
read_csv <- function(path) utils::read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA"), check.names = FALSE)
key <- function(x, cols) do.call(paste, c(x[cols], sep = "::"))
failures <- character()
fail <- function(message) failures <<- c(failures, message)
required <- c("person_static.csv", "household_wave.csv", "person_wave.csv")
if (!all(file.exists(file.path(release, required)))) fail("immutable fixture is incomplete")
if (!all(file.exists(c(file.path(base, "derived", "person_wave.csv"),
                       file.path(base, "derived", "person_household_wave.csv"),
                       file.path(base, "qa", "duplicate-proof.csv"),
                       file.path(base, "qa", "join-qa.csv"),
                       file.path(base, "qa", "wave-qa.csv"),
                       file.path(base, "tests", "test_panel_contract.R"))))) {
  fail("one or more data artefacts are missing")
}
if (!length(failures)) {
  pw0 <- read_csv(file.path(release, "person_wave.csv"))
  static <- read_csv(file.path(release, "person_static.csv"))
  hh <- read_csv(file.path(release, "household_wave.csv"))
  pkey0 <- key(pw0, c("pid", "wave"))
  dup <- unique(pkey0[duplicated(pkey0) | duplicated(pkey0, fromLast = TRUE)])
  if (length(dup) != 1L || dup[[1]] != "P000001::2019") fail("fixture duplicate precondition is not P000001::2019")
  dup_rows <- pw0[pkey0 == dup[[1]], , drop = FALSE]
  row_sig <- apply(dup_rows, 1, function(x) paste(ifelse(is.na(x), "<NA>", x), collapse = "\001"))
  if (length(unique(row_sig)) != 1L) fail("fixture duplicate rows are not identical")

  repaired <- read_csv(file.path(base, "derived", "person_wave.csv"))
  expected <- pw0[!duplicated(pkey0), , drop = FALSE]
  if (!isTRUE(all.equal(repaired, expected, check.attributes = TRUE))) fail("person_wave is not stable-first deduplication")
  if (nrow(repaired) != 513L || anyDuplicated(key(repaired, c("pid", "wave")))) fail("repaired person_wave has wrong row/key contract")

  proof <- read_csv(file.path(base, "qa", "duplicate-proof.csv"))
  proof_cols <- c("pid", "wave", "input_count", "rows_identical", "action")
  if (!identical(names(proof), proof_cols) || nrow(proof) != 1L ||
      proof$pid[[1]] != "P000001" || proof$wave[[1]] != 2019L || proof$input_count[[1]] != 2L ||
      !isTRUE(proof$rows_identical[[1]]) || proof$action[[1]] != "retain_first") fail("duplicate-proof.csv does not prove identical retain-first action")

  static_key <- static$pid
  hh_key <- key(hh, c("hid", "wave"))
  if (anyDuplicated(static_key)) fail("person_static right key is duplicated")
  if (anyDuplicated(hh_key)) fail("household_wave right key is duplicated")
  static_i <- match(repaired$pid, static_key)
  hh_i <- match(key(repaired, c("hid", "wave")), hh_key)
  if (anyNA(static_i) || anyNA(hh_i)) fail("join has orphan keys")
  joined <- read_csv(file.path(base, "derived", "person_household_wave.csv"))
  join_cols <- c("pid", "wave", "hid", "age", "employment_status", "income_final", "income_imp", "person_xs_weight", "sample_cohort", "entry_wave", "final_observed_wave", "region4", "hhsize_reported", "hh_xs_weight")
  if (!identical(names(joined), join_cols)) fail("joined output columns are reordered, extra, or ambiguous")
  expected_join <- data.frame(
    pid = repaired$pid, wave = repaired$wave, hid = repaired$hid, age = repaired$age,
    employment_status = repaired$employment_status, income_final = repaired$income_final,
    income_imp = repaired$income_imp, person_xs_weight = repaired$person_xs_weight,
    sample_cohort = static$sample_cohort[static_i], entry_wave = static$entry_wave[static_i],
    final_observed_wave = static$final_observed_wave[static_i], region4 = hh$region4[hh_i],
    hhsize_reported = hh$hhsize_reported[hh_i], hh_xs_weight = hh$hh_xs_weight[hh_i],
    stringsAsFactors = FALSE, check.names = FALSE
  )
  if (nrow(joined) != nrow(repaired) || !isTRUE(all.equal(joined, expected_join, check.attributes = TRUE))) fail("joined output changed row count or values")
  join_qa <- read_csv(file.path(base, "qa", "join-qa.csv"))
  expected_join_qa <- data.frame(join = c("person_static", "household_wave"), right_key_unique = TRUE,
                                 left_rows = 513L, joined_rows = 513L, unmatched = 0L,
                                 row_inflation = 0L, stringsAsFactors = FALSE)
  if (!isTRUE(all.equal(join_qa, expected_join_qa, check.attributes = TRUE))) fail("join-qa.csv does not prove one-to-one joins")
  wave_qa <- read_csv(file.path(base, "qa", "wave-qa.csv"))
  expected_wave_qa <- data.frame(wave = 2019:2022, row_count = c(130L, 122L, 137L, 124L),
                                 unique_person_count = c(130L, 122L, 137L, 124L), duplicate_key_count = 0L,
                                 person_weight_sum = c(10000, 10000, 10000, 10000), stringsAsFactors = FALSE)
  if (!isTRUE(all.equal(wave_qa, expected_wave_qa, tolerance = 0.01, check.attributes = TRUE))) fail("wave-qa.csv counts or person-weight totals are wrong")

}
if (length(failures)) {
  cat(paste0("FAIL data: ", failures, "\n"), sep = "")
  quit(status = 1L)
}
cat("PASS data: duplicate proof, stable dedupe, safe joins, and wave QA verified; participant test retained as non-authoritative learning artefact\n")
