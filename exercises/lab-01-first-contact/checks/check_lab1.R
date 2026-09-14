#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0L) {
  cumulative_path <- NULL
} else if (length(args) == 2L && identical(args[[1L]], "--cumulative")) {
  cumulative_path <- args[[2L]]
} else {
  stop("usage: Rscript checks/check_lab1.R [--cumulative PATH]", call. = FALSE)
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- if (length(script_arg)) sub("^--file=", "", script_arg[[1L]]) else "checks/check_lab1.R"
lab_root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
fixture_dir <- file.path(lab_root, "fixture", "release")
work_dir <- file.path(lab_root, "work")

failures <- character()
fail <- function(text) failures <<- c(failures, text)
need_file <- function(path, label) {
  if (!file.exists(path)) {
    fail(sprintf("%s is missing: %s", label, path))
    FALSE
  } else TRUE
}

fixture_files <- c(
  "household_wave.csv", "person_static.csv", "person_wave.csv",
  "questionnaire.csv", "response.csv", "release_manifest.csv", "schema.csv"
)
expected_fixture_sha256 <- c(
  household_wave.csv = "3c5eec09c11c4f13391f2366366938082e3b31bd6f473296cdce64a292a5243a",
  person_static.csv = "518f9220146b5e6afddd80cbdd61f57b3522a6f06e54533cc3c0e77cb581596b",
  person_wave.csv = "f907c45c0dc2add565565187910f66c6d54e387eae34009811ffd90b088600d3",
  questionnaire.csv = "6e302424925f079eb86e8901fa439a86aca51c683469f8c97f68ad07338f2950",
  response.csv = "67e45b4388808e0b014c84d55a30eb042f23180c131ad765146d56c5da8408af",
  release_manifest.csv = "413a92eae7f3472e0fa900396afad82bd33c61ccceff230b13452ad1ee859ad6",
  schema.csv = "7cc4c3cf407494ce80806b71ebcc7e6669fb978d187fedc5590befd5965dd393"
)

for (filename in fixture_files) {
  path <- file.path(fixture_dir, filename)
  need_file(path, "fixture file")
}

sha256sum_cmd <- Sys.which("sha256sum")
if (!nzchar(sha256sum_cmd)) {
  fail("cannot verify immutable fixture: sha256sum is unavailable")
} else {
  for (filename in fixture_files) {
    path <- file.path(fixture_dir, filename)
    if (file.exists(path)) {
      line <- system2(sha256sum_cmd, shQuote(path), stdout = TRUE)
      actual <- strsplit(line[[1L]], "[[:space:]]+")[[1L]][[1L]]
      if (!identical(actual, expected_fixture_sha256[[filename]])) fail(sprintf("fixture changed: %s", filename))
    }
  }
}

q_path <- file.path(fixture_dir, "questionnaire.csv")
if (file.exists(q_path)) {
  q <- read.csv(q_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  key <- paste(q$wave, q$item_id, sep = "::")
  dup <- which(key == "2019::EMP")
  if (length(dup) != 2L || nrow(q) != 17L || sum(duplicated(key)) != 1L) {
    fail("starting fixture is not the expected 17-row duplicate questionnaire")
  } else if (!identical(as.list(q[dup[[1L]], , drop = FALSE]), as.list(q[dup[[2L]], , drop = FALSE]))) {
    fail("2019::EMP duplicate rows disagree; do not silently deduplicate")
  } else {
    message("PASS precondition: fixture has one duplicate (wave, item_id) key: 2019::EMP")
  }
}

out_path <- file.path(work_dir, "corrected-questionnaire.csv")
if (!file.exists(out_path)) {
  fail("incomplete: work/corrected-questionnaire.csv is missing")
} else if (file.exists(q_path)) {
  out <- tryCatch(read.csv(out_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""), error = function(e) NULL)
  if (is.null(out)) {
    fail("corrected-questionnaire.csv cannot be read as CSV")
  } else {
    key <- paste(q$wave, q$item_id, sep = "::")
    expected <- q[!duplicated(key), , drop = FALSE]
    if (!identical(names(q), names(out))) fail("corrected questionnaire columns differ from fixture")
    if (nrow(out) != 16L) fail(sprintf("corrected questionnaire must have 16 rows (found %d)", nrow(out)))
    out_key <- paste(out$wave, out$item_id, sep = "::")
    if (anyDuplicated(out_key)) fail("corrected questionnaire still has duplicate (wave, item_id) keys")
    if (!identical(out, expected)) fail("corrected questionnaire is not the stable-first repair; other rows/order changed")
  }
}

provenance_path <- file.path(work_dir, "provenance.md")
if (!file.exists(provenance_path)) {
  fail("incomplete: work/provenance.md is missing")
} else {
  provenance <- paste(readLines(provenance_path, warn = FALSE), collapse = "\n")
  if (nchar(trimws(provenance)) < 40L || grepl("TODO|TBD|placeholder", provenance, ignore.case = TRUE)) fail("provenance.md is empty or placeholder text")
  if (!grepl("fixture/release/questionnaire[.]csv", provenance, fixed = FALSE)) fail("provenance.md must name fixture/release/questionnaire.csv")
  if (!grepl("2019::EMP", provenance, fixed = TRUE)) fail("provenance.md must name defect key 2019::EMP")
  if (!grepl("removed one exact duplicate; retained one declaration", provenance, fixed = TRUE)) fail("provenance.md must state the exact transformation")
  if (!grepl("Rscript checks/check_lab1[.]R", provenance, fixed = FALSE)) fail("provenance.md must name the checker command")
}

observations_path <- file.path(work_dir, "session-observations.md")
if (!file.exists(observations_path)) {
  fail("incomplete: work/session-observations.md is missing")
} else {
  lines <- readLines(observations_path, warn = FALSE)
  headings <- c("Observed", "Inferred", "Permission", "Verification")
  for (heading in headings) {
    idx <- which(trimws(lines) == heading)
    if (length(idx) != 1L) {
      fail(sprintf("session-observations.md must contain one heading: %s", heading))
    } else {
      next_idx <- which(seq_along(lines) > idx[[1L]] & trimws(lines) %in% headings)
      end <- if (length(next_idx)) next_idx[[1L]] - 1L else length(lines)
      body <- if ((idx[[1L]] + 1L) > end) "" else trimws(paste(lines[(idx[[1L]] + 1L):end], collapse = " "))
      if (!nzchar(body) || grepl("TODO|TBD|fill in", body, ignore.case = TRUE)) fail(sprintf("session-observations.md heading is empty or placeholder: %s", heading))
    }
  }
}

if (!is.null(cumulative_path) && length(failures) == 0L) {
  destination_input <- if (grepl("^/", cumulative_path)) cumulative_path else file.path(lab_root, cumulative_path)
  destination <- normalizePath(destination_input, mustWork = FALSE)
  if (!dir.exists(destination)) fail(sprintf("cumulative destination is missing: %s", destination))
  else {
    allowed <- c("corrected-questionnaire.csv", "provenance.md", "session-observations.md", ".gitkeep")
    actual_files <- list.files(destination, all.files = TRUE, no.. = TRUE)
    extras <- setdiff(actual_files, allowed)
    if (length(extras)) fail(sprintf("cumulative destination contains unapproved files: %s", paste(extras, collapse = ", ")))
    for (filename in allowed[allowed != ".gitkeep"]) {
      source <- file.path(work_dir, filename)
      copied <- file.path(destination, filename)
      if (!file.exists(copied) || !identical(unname(tools::md5sum(source)), unname(tools::md5sum(copied)))) fail(sprintf("cumulative payload differs or is missing: %s", filename))
    }
  }
}

if (length(failures)) {
  for (failure in unique(failures)) message("FAIL ", failure)
  quit(status = 1L)
}

if (!is.null(cumulative_path)) message("PASS cumulative path: reviewed Lab 1 payload matches standalone artefacts")
message("PASS lab 1: duplicate questionnaire item repaired; provenance and session observations present")
