#!/usr/bin/env Rscript

# This template is copied to work/tests by build_repair.R. It is deliberately
# small: mutate the input and it must go red, rather than merely report that a
# script ran.
args <- commandArgs(trailingOnly = TRUE)
script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
candidate <- normalizePath(dirname(script_path), mustWork = TRUE)
while (!dir.exists(file.path(candidate, "fixture", "release")) && dirname(candidate) != candidate) candidate <- dirname(candidate)
lab_root <- candidate
input_path <- if (length(args)) args[[1]] else file.path(lab_root, "fixture", "release", "person_wave.csv")
static_path <- if (length(args) >= 2L) args[[2]] else file.path(lab_root, "fixture", "release", "person_static.csv")
household_path <- if (length(args) >= 3L) args[[3]] else file.path(lab_root, "fixture", "release", "household_wave.csv")
if (!file.exists(input_path)) stop("missing person-wave input: ", input_path, call. = FALSE)
pw <- read.csv(input_path, stringsAsFactors = FALSE, na.strings = c("", "NA"), check.names = FALSE)
st <- read.csv(static_path, stringsAsFactors = FALSE, na.strings = c("", "NA"), check.names = FALSE)
hh <- read.csv(household_path, stringsAsFactors = FALSE, na.strings = c("", "NA"), check.names = FALSE)
key <- function(x, cols) do.call(paste, c(x[cols], sep = "::"))
pw_key <- key(pw, c("pid", "wave"))
if (anyDuplicated(pw_key)) stop("FAIL duplicate (pid, wave) key in input", call. = FALSE)
if (nrow(pw) != 513L) stop("FAIL expected 513 repaired person-wave rows", call. = FALSE)
if (any(!is.finite(pw$person_xs_weight)) || any(pw$person_xs_weight <= 0)) stop("FAIL non-positive person weight", call. = FALSE)
totals <- tapply(pw$person_xs_weight, pw$wave, sum)
if (!all(abs(as.numeric(totals[as.character(2019:2022)]) - 10000) < 0.01)) stop("FAIL wave person weights do not sum to 10000", call. = FALSE)
st_key <- st$pid
hh_key <- key(hh, c("hid", "wave"))
if (anyDuplicated(st_key)) stop("FAIL person_static right key is not unique", call. = FALSE)
if (anyDuplicated(hh_key)) stop("FAIL household_wave right key is not unique", call. = FALSE)
st_i <- match(pw$pid, st_key)
hh_i <- match(key(pw, c("hid", "wave")), hh_key)
if (anyNA(st_i) || anyNA(hh_i)) stop("FAIL orphan person or household key", call. = FALSE)
if (length(st_i) != nrow(pw) || length(hh_i) != nrow(pw)) stop("FAIL join cardinality changed", call. = FALSE)
message("PASS participant panel contract: unique keys, target weights, and one-to-one joins")
