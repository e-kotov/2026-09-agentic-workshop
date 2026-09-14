#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
lab_root <- dirname(dirname(normalizePath(script_path, mustWork = TRUE)))
work_root <- if (length(args)) normalizePath(args[[1]], mustWork = FALSE) else file.path(lab_root, "work")
release_root <- file.path(lab_root, "fixture", "release")

if (!dir.exists(release_root)) stop("missing immutable fixture/release", call. = FALSE)
dir.create(work_root, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(work_root, "derived"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(work_root, "qa"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(work_root, "tests"), recursive = TRUE, showWarnings = FALSE)
read_csv <- function(name) utils::read.csv(file.path(release_root, name), stringsAsFactors = FALSE,
                                            na.strings = c("", "NA"), check.names = FALSE)
key <- function(x, cols) do.call(paste, c(x[cols], sep = "::"))
row_signature <- function(x) {
  v <- vapply(x, function(z) if (is.na(z)) "<NA>" else as.character(z), character(1))
  paste(v, collapse = "\001")
}

person_wave <- read_csv("person_wave.csv")
person_static <- read_csv("person_static.csv")
household_wave <- read_csv("household_wave.csv")
pw_key <- key(person_wave, c("pid", "wave"))
duplicate_keys <- unique(pw_key[duplicated(pw_key) | duplicated(pw_key, fromLast = TRUE)])
if (!length(duplicate_keys)) stop("no duplicate person-wave key found; intended precondition changed", call. = FALSE)
proof <- lapply(duplicate_keys, function(k) {
  rows <- person_wave[pw_key == k, , drop = FALSE]
  identical_rows <- length(unique(apply(rows, 1, row_signature))) == 1L
  if (!identical_rows) stop(paste("duplicate rows disagree:", k), call. = FALSE)
  bits <- strsplit(k, "::", fixed = TRUE)[[1]]
  data.frame(pid = bits[[1]], wave = as.integer(bits[[2]]), input_count = nrow(rows),
             rows_identical = TRUE, action = "retain_first", stringsAsFactors = FALSE)
})
proof <- do.call(rbind, proof)
utils::write.csv(proof, file.path(work_root, "qa", "duplicate-proof.csv"), row.names = FALSE, quote = TRUE)

repaired <- person_wave[!duplicated(pw_key), , drop = FALSE]
utils::write.csv(repaired, file.path(work_root, "derived", "person_wave.csv"), row.names = FALSE, quote = TRUE)

if (anyDuplicated(person_static$pid)) stop("person_static right-hand key is not unique", call. = FALSE)
hh_key <- key(household_wave, c("hid", "wave"))
if (anyDuplicated(hh_key)) stop("household_wave right-hand key is not unique", call. = FALSE)
static_index <- match(repaired$pid, person_static$pid)
household_index <- match(key(repaired, c("hid", "wave")), hh_key)
if (anyNA(static_index) || anyNA(household_index)) stop("orphan key in repaired person-wave", call. = FALSE)
static_part <- person_static[static_index, c("sample_cohort", "entry_wave", "final_observed_wave"), drop = FALSE]
household_part <- household_wave[household_index, c("region4", "hhsize_reported", "hh_xs_weight"), drop = FALSE]
joined <- data.frame(
  pid = repaired$pid, wave = repaired$wave, hid = repaired$hid,
  age = repaired$age, employment_status = repaired$employment_status,
  income_final = repaired$income_final, income_imp = repaired$income_imp,
  person_xs_weight = repaired$person_xs_weight,
  sample_cohort = static_part$sample_cohort, entry_wave = static_part$entry_wave,
  final_observed_wave = static_part$final_observed_wave,
  region4 = household_part$region4, hhsize_reported = household_part$hhsize_reported,
  hh_xs_weight = household_part$hh_xs_weight,
  stringsAsFactors = FALSE, check.names = FALSE
)
if (nrow(joined) != nrow(repaired)) stop("join multiplied or dropped rows", call. = FALSE)
utils::write.csv(joined, file.path(work_root, "derived", "person_household_wave.csv"), row.names = FALSE, quote = TRUE)

join_qa <- data.frame(
  join = c("person_static", "household_wave"), right_key_unique = c(TRUE, TRUE),
  left_rows = c(nrow(repaired), nrow(repaired)), joined_rows = c(nrow(joined), nrow(joined)),
  unmatched = c(sum(is.na(static_index)), sum(is.na(household_index))),
  row_inflation = c(nrow(joined) - nrow(repaired), nrow(joined) - nrow(repaired)),
  stringsAsFactors = FALSE
)
utils::write.csv(join_qa, file.path(work_root, "qa", "join-qa.csv"), row.names = FALSE, quote = TRUE)

waves <- 2019:2022
wave_qa <- do.call(rbind, lapply(waves, function(w) {
  x <- repaired[repaired$wave == w, , drop = FALSE]
  data.frame(wave = w, row_count = nrow(x), unique_person_count = length(unique(x$pid)),
             duplicate_key_count = sum(duplicated(key(x, c("pid", "wave")))),
             person_weight_sum = round(sum(x$person_xs_weight), 2), stringsAsFactors = FALSE)
}))
utils::write.csv(wave_qa, file.path(work_root, "qa", "wave-qa.csv"), row.names = FALSE, quote = TRUE)
template <- file.path(lab_root, "task", "test_panel_contract_template.R")
if (!file.copy(template, file.path(work_root, "tests", "test_panel_contract.R"), overwrite = TRUE)) {
  stop("could not copy participant test template", call. = FALSE)
}
message("PASS build: proved ", nrow(person_wave) - nrow(repaired), " identical duplicate row; wrote repaired table, joins, and QA")
