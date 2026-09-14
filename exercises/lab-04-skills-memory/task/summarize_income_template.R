#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
candidate <- normalizePath(dirname(script_path), mustWork = TRUE)
while (!dir.exists(file.path(candidate, "fixture", "release")) && dirname(candidate) != candidate) candidate <- dirname(candidate)
lab_root <- candidate
work <- file.path(lab_root, "work")
release <- if (length(args)) normalizePath(args[[1]], mustWork = TRUE) else file.path(work, "release")
out <- if (length(args) >= 2L) normalizePath(args[[2]], mustWork = FALSE) else file.path(work, "outputs", "income-summary.csv")
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
pw <- read.csv(file.path(release, "person_wave.csv"), stringsAsFactors = FALSE, na.strings = c("", "NA"), check.names = FALSE)
keep <- pw$employment_status == "employed" & pw$response_status == "interviewed"
rows <- lapply(2019:2022, function(w) {
  x <- pw[keep & pw$wave == w, , drop = FALSE]
  data.frame(wave = w, n_employed = nrow(x),
             unweighted_mean_income = round(mean(x$income_final), 3),
             weighted_mean_income = round(sum(x$income_final * x$person_xs_weight) / sum(x$person_xs_weight), 3),
             stringsAsFactors = FALSE)
})
summary <- do.call(rbind, rows)
utils::write.csv(summary, out, row.names = FALSE, quote = TRUE)
message("PASS summary: wrote interviewed-employed unweighted and person-weighted income means")
