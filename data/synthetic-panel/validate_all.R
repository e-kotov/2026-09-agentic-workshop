#!/usr/bin/env Rscript

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
root_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
source(file.path(root_dir, "validate.R"))

invariants_path <- file.path(root_dir, "invariants.csv")
invariants <- read_release_csv(invariants_path)
if (anyDuplicated(invariants$check_id) || any(!nzchar(invariants$check_id))) stop("invariants.csv has duplicate/blank IDs", call. = FALSE)
clean_report <- validate_release(file.path(root_dir, "fixtures", "clean"), invariants_path, quiet = TRUE)
if (nrow(clean_report) != nrow(invariants) || !setequal(clean_report$check_id, invariants$check_id) || any(clean_report$status != "PASS")) stop("Clean fixture failed dynamic invariant gate.", call. = FALSE)
cat("PASS clean: all", nrow(clean_report), "declared checks passed\n")

profiles <- read_release_csv(file.path(root_dir, "defect_profiles.csv"))
defect_root <- file.path(root_dir, "fixtures", "defects")
actual_profiles <- list.dirs(defect_root, full.names = FALSE, recursive = FALSE)
if (!setequal(actual_profiles, profiles$profile)) stop("Defect directories and defect_profiles.csv disagree", call. = FALSE)
for (i in seq_len(nrow(profiles))) {
  profile <- profiles$profile[i]
  report <- validate_release(file.path(defect_root, profile), invariants_path, quiet = TRUE)
  actual <- sort(report$check_id[report$status == "FAIL"])
  declared <- sort(strsplit(profiles$intended_failed_checks[i], "\\|", fixed = FALSE)[[1]])
  if (!setequal(actual, declared) || length(actual) != length(declared)) {
    stop(profile, " exact failure set mismatch; declared=", paste(declared, collapse = ","), "; actual=", paste(actual, collapse = ","), call. = FALSE)
  }
  cat("EXPECTED FAIL", profile, ":", paste(actual, collapse = ", "), "\n")
}
cat("PASS defects:", nrow(profiles), "declared profiles matched exact failure sets\n")
