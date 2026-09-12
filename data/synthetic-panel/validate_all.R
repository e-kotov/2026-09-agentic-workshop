#!/usr/bin/env Rscript

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
root_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
local_lib <- file.path(root_dir, "_r-lib")
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
source(file.path(root_dir, "validate.R"))

invariants_path <- file.path(root_dir, "invariants.csv")
clean_report <- validate_release(
  file.path(root_dir, "fixtures", "clean"), invariants_path, quiet = TRUE
)
if (any(clean_report$status == "FAIL")) {
  print(clean_report, row.names = FALSE)
  stop("Clean fixture failed validation.", call. = FALSE)
}
cat("PASS clean: all", nrow(clean_report), "checks passed\n")

expected <- list(
  duplicate_person_wave = "unique_person_wave",
  duplicate_questionnaire_item = "unique_questionnaire",
  orphan_household = c("foreign_keys", "household_size"),
  zero_person_weight = "positive_weights",
  inconsistent_imputation_flag = "income_consistency",
  stale_manifest_checksum = "manifest_checksums"
)

for (profile in names(expected)) {
  report <- validate_release(
    file.path(root_dir, "fixtures", "defects", profile), invariants_path, quiet = TRUE
  )
  failed <- report$check_id[report$status == "FAIL"]
  absent <- setdiff(expected[[profile]], failed)
  if (length(absent)) {
    print(report, row.names = FALSE)
    stop(profile, " did not fail intended check(s): ", paste(absent, collapse = ", "), call. = FALSE)
  }
  cat("EXPECTED FAIL", profile, ":", paste(failed, collapse = ", "), "\n")
}
