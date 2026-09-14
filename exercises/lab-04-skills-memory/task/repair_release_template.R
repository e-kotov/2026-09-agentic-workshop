#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
candidate <- normalizePath(dirname(script_path), mustWork = TRUE)
while (!dir.exists(file.path(candidate, "fixture", "release")) && dirname(candidate) != candidate) candidate <- dirname(candidate)
lab_root <- candidate
work <- file.path(lab_root, "work")
out <- if (length(args)) normalizePath(args[[1]], mustWork = FALSE) else file.path(work, "release")
source_release <- file.path(lab_root, "fixture", "release")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
files <- list.files(source_release, pattern = "\\.csv$", full.names = FALSE)
for (file in files) file.copy(file.path(source_release, file), file.path(out, file), overwrite = TRUE)
read_csv <- function(path) utils::read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA"), check.names = FALSE)
pw_path <- file.path(out, "person_wave.csv")
pw <- read_csv(pw_path)
i <- which(pw$pid == "P000040" & pw$wave == 2019L)
if (length(i) != 1L || pw$income_imp[[i]] != 0L || pw$employment_status[[i]] != "employed" || !is.na(pw$income_raw[[i]]) || pw$income_missing_code[[i]] != "no_answer") stop("unexpected repair precondition", call. = FALSE)
pw$income_imp[[i]] <- 1L
utils::write.csv(pw, pw_path, row.names = FALSE, quote = TRUE)

manifest_path <- file.path(out, "release_manifest.csv")
manifest <- read_csv(manifest_path)
manifest$release_id <- paste0(as.character(manifest$release_id[[1]]), "-participant-repair")
manifest$defect_profile <- "participant_repair_inconsistent_imputation_flag"
manifest$expected_validation_status <- "pass"
for (i in seq_len(nrow(manifest))) {
  path <- file.path(out, manifest$file_name[[i]])
  if (!file.exists(path)) stop("manifest file missing: ", manifest$file_name[[i]], call. = FALSE)
  manifest$row_count[[i]] <- nrow(read_csv(path))
  manifest$sha256[[i]] <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
}
utils::write.csv(manifest, manifest_path, row.names = FALSE, quote = TRUE)
message("PASS repair: changed income_imp for P000040::2019 and regenerated all manifest counts/hashes")
