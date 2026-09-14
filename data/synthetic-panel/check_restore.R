#!/usr/bin/env Rscript

script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
root_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
read_release_csv <- function(path) utils::read.csv(path, stringsAsFactors = FALSE,
                                                    check.names = FALSE)
source(file.path(root_dir, "restore_helpers.R"))
lockfile <- file.path(root_dir, "renv.lock")
lib <- tempfile("synthetic-panel-empty-lib-")
dir.create(lib, recursive = TRUE)
if (length(list.files(lib, all.files = TRUE, no.. = TRUE))) stop("restore library was not empty", call. = FALSE)
bootstrap_exact_renv(root_dir, lockfile, lib)
expected <- locked_descriptions(lockfile)
materialize_locked_library(root_dir, lockfile, lib)
descriptions <- list.files(lib, pattern = "^DESCRIPTION$", recursive = TRUE, full.names = TRUE, all.files = TRUE)
fabricatr_description <- descriptions[basename(dirname(descriptions)) == "fabricatr"]
if (length(fabricatr_description) != 1L) stop("renv restore did not expose its disposable package library", call. = FALSE)
generator_lib <- dirname(dirname(fabricatr_description[[1]]))

# G1: copy only generator code and declarations into a directory outside the
# repository. No fixtures or private files are available to this process.
staging <- tempfile("synthetic-panel-source-free-")
dir.create(staging, recursive = TRUE)
allowlist <- c("generate.R", "defect_profiles.csv", "invariants.csv", "dependencies.csv", "renv.lock", "renv-bootstrap.csv")
ok <- file.copy(file.path(root_dir, allowlist), staging, overwrite = TRUE)
if (!all(ok)) stop("failed to construct isolated generator allowlist", call. = FALSE)
out <- file.path(staging, "out")
cmd <- file.path(R.home("bin"), "Rscript")
status <- system2(cmd, c("--vanilla", file.path(staging, "generate.R"), paste0("--output-dir=", out)), env = c(paste0("R_LIBS_USER=", paste(generator_lib, lib, sep = .Platform$path.sep)), "R_LIBS_SITE="))
if (!identical(status, 0L)) stop("isolated source-free generation failed", call. = FALSE)
profiles <- read_release_csv(file.path(staging, "defect_profiles.csv"))
expected_files <- file.path(c("clean", file.path("defects", profiles$profile)), "release_manifest.csv")
if (!all(file.exists(file.path(out, expected_files)))) stop("isolated generation did not produce all releases", call. = FALSE)
cat("PASS G1 isolated source-free generation\n")
cat("PASS G2 empty-library restore:", length(expected), "locked package records\n")
