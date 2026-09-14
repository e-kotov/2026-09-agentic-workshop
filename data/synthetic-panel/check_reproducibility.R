#!/usr/bin/env Rscript

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
root_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
source(file.path(root_dir, "restore_helpers.R"))
lockfile <- file.path(root_dir, "renv.lock")
lib <- tempfile("synthetic-panel-repro-lib-")
dir.create(lib, recursive = TRUE)
bootstrap_exact_renv(root_dir, lockfile, lib)
materialize_locked_library(root_dir, lockfile, lib)
descriptions <- list.files(lib, pattern = "^DESCRIPTION$", recursive = TRUE, full.names = TRUE, all.files = TRUE)
fabricatr_description <- descriptions[basename(dirname(descriptions)) == "fabricatr"]
if (length(fabricatr_description) != 1L) stop("renv restore did not expose its disposable package library", call. = FALSE)
generator_lib <- dirname(dirname(fabricatr_description[[1]]))

cmd <- file.path(R.home("bin"), "Rscript")
source_files <- c("generate.R", "defect_profiles.csv", "invariants.csv", "dependencies.csv", "renv.lock", "renv-bootstrap.csv")

stage_source <- function() {
  stage <- tempfile("synthetic-panel-repro-stage-")
  dir.create(stage, recursive = TRUE)
  copied <- file.copy(file.path(root_dir, source_files), stage, overwrite = TRUE)
  if (!all(copied)) stop("failed to stage the complete generator source/config", call. = FALSE)
  stage
}

run_staged <- function(stage) {
  out <- file.path(stage, "out")
  status <- system2(cmd, c("--vanilla", file.path(stage, "generate.R"), paste0("--output-dir=", out)), env = c(paste0("R_LIBS_USER=", paste(generator_lib, lib, sep = .Platform$path.sep)), "R_LIBS_SITE="))
  if (!identical(status, 0L)) stop("staged generation failed", call. = FALSE)
  if (!all(file.exists(file.path(stage, c("schema.csv", "questionnaire.csv"))))) stop("staged generation omitted root canonical metadata", call. = FALSE)
  if (!dir.exists(file.path(out, "clean")) || !dir.exists(file.path(out, "defects"))) stop("staged generation omitted release output tree", call. = FALSE)
}

hash_files <- function(base, files) {
  files <- sort(files)
  setNames(vapply(files, function(path) digest::digest(file = file.path(base, path), algo = "sha256", serialize = FALSE), character(1)), files)
}

generated_hashes <- function(stage) {
  out_files <- list.files(file.path(stage, "out"), recursive = TRUE, all.files = FALSE, full.names = FALSE)
  out_files <- out_files[!file.info(file.path(stage, "out", out_files))$isdir]
  if (length(out_files) != 49L) stop("expected 49 release files in staged output tree", call. = FALSE)
  hash_files(stage, c("schema.csv", "questionnaire.csv", file.path("out", out_files)))
}

tracked_files <- list.files(file.path(root_dir, "fixtures"), recursive = TRUE, all.files = FALSE, full.names = FALSE)
tracked_files <- tracked_files[!file.info(file.path(root_dir, "fixtures", tracked_files))$isdir]
if (length(tracked_files) != 49L) stop("expected 49 tracked fixture files", call. = FALSE)
canonical <- hash_files(root_dir, c("schema.csv", "questionnaire.csv", file.path("fixtures", tracked_files)))
names(canonical) <- sub("^fixtures/", "out/", names(canonical))

stage1 <- stage_source()
stage2 <- stage_source()
run_staged(stage1)
run_staged(stage2)
hash1 <- generated_hashes(stage1)
hash2 <- generated_hashes(stage2)
if (length(hash1) != 51L) stop("expected 51 staged canonical files including root metadata", call. = FALSE)
if (!identical(names(hash1), names(hash2)) || !identical(unname(hash1), unname(hash2))) stop("two separately staged generations differ", call. = FALSE)
if (!identical(names(hash1), names(canonical)) || !identical(unname(hash1), unname(canonical))) stop("staged output differs from tracked canonical fixtures/metadata", call. = FALSE)

# Generation was run only in disposable stages; repository canonical files must
# remain byte-identical throughout this check.
canonical_after <- hash_files(root_dir, c("schema.csv", "questionnaire.csv", file.path("fixtures", tracked_files)))
names(canonical_after) <- sub("^fixtures/", "out/", names(canonical_after))
if (!identical(canonical, canonical_after)) stop("repository canonical artifacts changed during isolated generation", call. = FALSE)
cat("PASS G3 two separately staged runs: ", length(hash1), " files (49 releases + 2 root metadata)\n", sep = "")
cat("PASS G4 tracked fixture and canonical metadata equality\n")
