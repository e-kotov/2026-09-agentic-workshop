#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
lab_root <- dirname(dirname(normalizePath(script_path, mustWork = TRUE)))
base <- file.path(lab_root, "work")
if (length(args) == 2L && args[[1]] %in% c("--cumulative", "--base")) {
  base <- normalizePath(args[[2]], mustWork = FALSE)
} else if (length(args) == 1L) {
  base <- normalizePath(args[[1]], mustWork = FALSE)
} else if (length(args) > 0L) {
  stop("usage: Rscript checks/check_lab2.R [--cumulative PATH]", call. = FALSE)
}
release <- file.path(lab_root, "fixture", "release")
expected_hashes <- c(
  household_wave.csv = "3c5eec09c11c4f13391f2366366938082e3b31bd6f473296cdce64a292a5243a",
  person_static.csv = "518f9220146b5e6afddd80cbdd61f57b3522a6f06e54533cc3c0e77cb581596b",
  person_wave.csv = "25d11465f31694b814b7d14feebd211b7946c679cb87e0d694cddc050133cb53",
  questionnaire.csv = "48bf1693afa4eeb11c0053fe275a95c022434d9006d98b3cbd97e098a067c8e4",
  release_manifest.csv = "a053e38bc272a8627b3bad43e315f8160d98f945aa9c2e6a73fc9d9705c07e92",
  response.csv = "67e45b4388808e0b014c84d55a30eb042f23180c131ad765146d56c5da8408af",
  schema.csv = "7cc4c3cf407494ce80806b71ebcc7e6669fb978d187fedc5590befd5965dd393"
)
if (!requireNamespace("digest", quietly = TRUE)) stop("digest package is required for fixture immutability check", call. = FALSE)
actual_hashes <- vapply(names(expected_hashes), function(name) {
  path <- file.path(release, name)
  if (!file.exists(path)) "MISSING" else digest::digest(file = path, algo = "sha256", serialize = FALSE)
}, character(1))
if (!identical(unname(actual_hashes), unname(expected_hashes))) {
  bad <- names(expected_hashes)[actual_hashes != unname(expected_hashes)]
  cat("FAIL immutable fixture changed:", paste(bad, collapse = ", "), "\n")
  quit(status = 1L)
}

pw <- utils::read.csv(file.path(release, "person_wave.csv"), stringsAsFactors = FALSE, na.strings = "", check.names = FALSE)
pw_key <- paste(pw$pid, pw$wave, sep = "::")
duplicate_ok <- nrow(pw) == 514L && sum(duplicated(pw_key)) == 1L && sum(pw_key == "P000001::2019") == 2L
weights <- tapply(pw$person_xs_weight, pw$wave, sum)
weights_fail <- length(weights) == 4L && any(abs(as.numeric(weights[as.character(2019:2022)]) - 10000) >= 0.01)
income_fail <- duplicate_ok && any(pw$pid == "P000001" & pw$wave == 2019)
if (!duplicate_ok || !weights_fail || !income_fail) {
  cat("FAIL intended fixture precondition changed\n")
  quit(status = 1L)
}
cat("PASS precondition: fixture fails unique_person_wave, weight_targets, income_consistency\n")
first <- file.path(base, "derived", "person_wave.csv")
if (!file.exists(first)) {
  cat("FAIL incomplete: ", if (identical(base, file.path(lab_root, "work"))) "work/derived/person_wave.csv" else file.path(base, "derived", "person_wave.csv"), " is missing\n", sep = "")
  quit(status = 1L)
}
participant_test <- file.path(base, "tests", "test_panel_contract.R")
if (!file.exists(participant_test)) {
  cat("FAIL incomplete: participant test is missing\n")
  quit(status = 1L)
}
cat("INFO participant test is retained for learning/review only; immutable checker code is the acceptance oracle\n")

run_check <- function(path) {
  output <- system2("Rscript", c(path, "--base", base), stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (!is.null(status) && status != 0L) {
    cat(paste(output, collapse = "\n"), "\n", sep = "")
    return(FALSE)
  }
  TRUE
}
if (!run_check(file.path(lab_root, "checks", "check_data.R"))) quit(status = 1L)

recovery <- file.path(base, "git-recovery.txt")
if (!file.exists(recovery)) {
  cat("FAIL incomplete: ", file.path(base, "git-recovery.txt"), " is missing\n", sep = "")
  quit(status = 1L)
}
recovery_text <- paste(readLines(recovery, warn = FALSE), collapse = "\n")
kv <- function(text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  out <- list()
  for (line in lines) {
    hit <- regexpr("=", line, fixed = TRUE)[1]
    if (hit > 1L) out[[substr(line, 1L, hit - 1L)]] <- substr(line, hit + 1L, nchar(line))
  }
  out
}
`%||%` <- function(x, y) if (is.null(x)) y else x
recovery_kv <- kv(recovery_text)
required_recovery <- c("scope", "demo_dir", "baseline_commit", "mutation_commit", "revert_commit", "evidence_commit", "mutation_log", "recovery_log", "mutation_log_sha256", "recovery_log_sha256")
recovery_ok <- all(vapply(required_recovery, function(k) !is.null(recovery_kv[[k]]) && nzchar(recovery_kv[[k]]), logical(1))) &&
  identical(recovery_kv$scope, "standalone-run") && identical(recovery_kv$demo_dir, "recovery-demo") && identical(recovery_kv$mutation_log, "mutation-test.log") && identical(recovery_kv$recovery_log, "recovery-test.log")
standalone <- normalizePath(base, mustWork = FALSE) == normalizePath(file.path(lab_root, "work"), mustWork = FALSE)
git_output <- function(args) {
  out <- tryCatch(suppressWarnings(system2("git", args, stdout = TRUE, stderr = TRUE)), error = function(e) character())
  list(output = out, status = if (is.null(attr(out, "status"))) 0L else as.integer(attr(out, "status")))
}
# Participant Git logs/history remain review artefacts.  Acceptance creates a
# fresh checker-owned repository from the canonical repaired output, applies
# the fixed P000002::2019 weight mutation, runs the immutable contract test,
# reverts it, and runs the test again.  No participant test, log, hash, or
# commit narrative can replace this oracle (in standalone or cumulative mode).
oracle_git <- tempfile("lab2-git-oracle-"); dir.create(oracle_git)
oracle_person <- file.path(oracle_git, "person_wave.csv")
file.copy(first, oracle_person)
invisible(git_output(c("init", "-q", oracle_git))); invisible(git_output(c("-C", oracle_git, "config", "user.email", "lab2-oracle@example.invalid"))); invisible(git_output(c("-C", oracle_git, "config", "user.name", "Lab2-checker-oracle")))
invisible(git_output(c("-C", oracle_git, "add", "person_wave.csv"))); baseline_oracle <- git_output(c("-C", oracle_git, "commit", "-q", "-m", "canonical-baseline"))
oracle_mutator <- tempfile("lab2-mutator-")
writeLines(c("p <- commandArgs(TRUE)[1]", "x <- read.csv(p, stringsAsFactors=FALSE, check.names=FALSE)", "i <- which(x$pid == 'P000002' & x$wave == 2019)", "x$person_xs_weight[i] <- x$person_xs_weight[i] + 1", "write.csv(x, p, row.names=FALSE)"), oracle_mutator)
mutation_oracle <- suppressWarnings(system2("Rscript", c(oracle_mutator, oracle_person), stdout = TRUE, stderr = TRUE))
invisible(git_output(c("-C", oracle_git, "add", "person_wave.csv"))); mutation_commit_oracle <- git_output(c("-C", oracle_git, "commit", "-q", "-m", "canonical-mutation"))
canonical_test <- file.path(lab_root, "task", "test_panel_contract_template.R")
oracle_mutation_test <- suppressWarnings(system2("Rscript", c(canonical_test, oracle_person, file.path(release, "person_static.csv"), file.path(release, "household_wave.csv")), stdout = TRUE, stderr = TRUE)); oracle_mutation_status <- if (is.null(attr(oracle_mutation_test, "status"))) 0L else as.integer(attr(oracle_mutation_test, "status"))
invisible(git_output(c("-C", oracle_git, "revert", "--no-edit", "HEAD"))); oracle_reverted_test <- suppressWarnings(system2("Rscript", c(canonical_test, oracle_person, file.path(release, "person_static.csv"), file.path(release, "household_wave.csv")), stdout = TRUE, stderr = TRUE)); oracle_reverted_status <- if (is.null(attr(oracle_reverted_test, "status"))) 0L else as.integer(attr(oracle_reverted_test, "status"))
oracle_clean <- length(git_output(c("-C", oracle_git, "status", "--porcelain"))$output) == 0L
recovery_oracle_ok <- identical(baseline_oracle$status, 0L) && identical(mutation_commit_oracle$status, 0L) && identical(oracle_mutation_status, 1L) && identical(oracle_reverted_status, 0L) && oracle_clean
if (!recovery_oracle_ok || !recovery_ok) { cat("FAIL Git recovery evidence is incomplete, fabricated, or canonical oracle failed\n"); quit(status = 1L) }

invalidation <- file.path(base, "invalidation-evidence.txt")
if (!file.exists(invalidation)) {
  cat("FAIL incomplete: ", file.path(base, "invalidation-evidence.txt"), " is missing\n", sep = "")
  quit(status = 1L)
}
invalidation_text <- paste(readLines(invalidation, warn = FALSE), collapse = "\n")
invalidation_kv <- kv(invalidation_text)
route_ok <- identical(invalidation_kv$route, "targets") || identical(invalidation_kv$route, "snakemake")
invalidation_ok <- route_ok && identical(invalidation_kv$scope, "standalone-run") && identical(invalidation_kv$unchanged_rebuilt, "0") && identical(invalidation_kv$changed_rebuilt, "person_wave,wave_qa") && identical(invalidation_kv$restored, "true")
if (invalidation_ok) {
  # The participant logs/source copies are review artefacts only. Acceptance
  # below uses canonical lab-owned pipeline sources and fresh outputs; copied
  # outputs, fabricated logs, and source hashes cannot influence the result.
  path_names_ok <- !standalone || (identical(invalidation_kv$pipeline_dir, "pipeline") && identical(invalidation_kv$first_log, "first.log") && identical(invalidation_kv$unchanged_log, "unchanged.log") && identical(invalidation_kv$changed_log, "changed.log"))
  source_ok <- all(file.exists(file.path(lab_root, "pipeline", c("targets.R", "Snakefile", "snakemake_person_wave.py", "snakemake_wave_qa.py", "run_snakemake_compat.py"))))
  # Execute the declared participant route in a checker-controlled fresh tree.
  # Outputs are absent before the first run; the same upstream path is then
  # changed and executed again. This is the sole workflow oracle; participant
  # outputs/logs are not treated as authenticated provenance.
  workflow_replay <- tempfile("lab2-workflow-selected-"); dir.create(workflow_replay); dir.create(file.path(workflow_replay, "input")); dir.create(file.path(workflow_replay, "out"))
  selected_input <- file.path(workflow_replay, "input", "person_wave.csv")
  file.copy(file.path(release, "person_wave.csv"), selected_input)
  selected_source <- file.path(lab_root, "pipeline")
  if (identical(invalidation_kv$route, "targets")) {
    file.copy(file.path(selected_source, "targets.R"), file.path(workflow_replay, "_targets.R"))
    targets_runner <- file.path(workflow_replay, "run_targets.R")
    writeLines(c("setwd(commandArgs(TRUE)[1])", "targets::tar_make(script = '_targets.R')"), targets_runner)
  } else {
    for (n in c("Snakefile", "snakemake_person_wave.py", "snakemake_wave_qa.py", "run_snakemake_compat.py")) file.copy(file.path(selected_source, n), file.path(workflow_replay, n))
  }
  run_selected <- function() {
    if (identical(invalidation_kv$route, "targets")) {
      out <- suppressWarnings(system2("Rscript", c(targets_runner, workflow_replay), stdout = TRUE, stderr = TRUE))
    } else if (nzchar(Sys.which("snakemake"))) {
      out <- suppressWarnings(system2("snakemake", c("--directory", workflow_replay, "--cores", "1", "--snakefile", file.path(workflow_replay, "Snakefile")), stdout = TRUE, stderr = TRUE))
    } else {
      out <- suppressWarnings(system2("python3", c(file.path(workflow_replay, "run_snakemake_compat.py"), file.path(workflow_replay, "input", "person_wave.csv"), file.path(workflow_replay, "out", "person_wave.csv"), file.path(workflow_replay, "out", "wave-qa.csv")), stdout = TRUE, stderr = TRUE))
    }
    list(status = if (is.null(attr(out, "status"))) 0L else as.integer(attr(out, "status")), text = paste(out, collapse = "\n"))
  }
  selected_first <- run_selected(); selected_person_1 <- file.path(workflow_replay, "out", "person_wave.csv"); selected_qa_1 <- file.path(workflow_replay, "out", "wave-qa.csv")
  selected_hash <- function(path) if (file.exists(path)) digest::digest(file = path, algo = "sha256", serialize = FALSE) else "MISSING"
  hash_person_1 <- selected_hash(selected_person_1); hash_qa_1 <- selected_hash(selected_qa_1); mtime_person_1 <- if (file.exists(selected_person_1)) file.info(selected_person_1)$mtime else as.POSIXct(NA); mtime_qa_1 <- if (file.exists(selected_qa_1)) file.info(selected_qa_1)$mtime else as.POSIXct(NA)
  selected_person_initial <- tempfile("lab2-selected-person-initial-"); selected_qa_initial <- tempfile("lab2-selected-qa-initial-"); if (file.exists(selected_person_1)) file.copy(selected_person_1, selected_person_initial); if (file.exists(selected_qa_1)) file.copy(selected_qa_1, selected_qa_initial)
  selected_second <- run_selected(); hash_person_2 <- selected_hash(selected_person_1); hash_qa_2 <- selected_hash(selected_qa_1); mtime_person_2 <- if (file.exists(selected_person_1)) file.info(selected_person_1)$mtime else as.POSIXct(NA); mtime_qa_2 <- if (file.exists(selected_qa_1)) file.info(selected_qa_1)$mtime else as.POSIXct(NA)
  selected_data <- utils::read.csv(selected_input, stringsAsFactors = FALSE, check.names = FALSE); selected_i <- which(selected_data$pid == "P000002" & selected_data$wave == 2019L); selected_data$person_xs_weight[selected_i] <- selected_data$person_xs_weight[selected_i] + 1; utils::write.csv(selected_data, selected_input, row.names = FALSE)
  selected_changed <- run_selected(); hash_person_3 <- selected_hash(selected_person_1); hash_qa_3 <- selected_hash(selected_qa_1); mtime_person_3 <- if (file.exists(selected_person_1)) file.info(selected_person_1)$mtime else as.POSIXct(NA); mtime_qa_3 <- if (file.exists(selected_qa_1)) file.info(selected_qa_1)$mtime else as.POSIXct(NA)
  # The checker-owned compatibility route supplies canonical expected bytes
  # for the initial and changed inputs; the declared engine must produce the
  # same parsed tables and must visibly skip then rebuild.
  expected_dir <- tempfile("lab2-workflow-expected-"); dir.create(expected_dir); expected_input <- file.path(expected_dir, "person_wave.csv"); expected_person <- file.path(expected_dir, "person.csv"); expected_qa <- file.path(expected_dir, "wave-qa.csv"); file.copy(file.path(release, "person_wave.csv"), expected_input); suppressWarnings(system2("python3", c(file.path(lab_root, "pipeline", "run_snakemake_compat.py"), expected_input, expected_person, expected_qa), stdout = TRUE, stderr = TRUE)); expected_data <- utils::read.csv(expected_input, stringsAsFactors = FALSE, check.names = FALSE); expected_i <- which(expected_data$pid == "P000002" & expected_data$wave == 2019L); expected_data$person_xs_weight[expected_i] <- expected_data$person_xs_weight[expected_i] + 1; utils::write.csv(expected_data, expected_input, row.names = FALSE); expected_changed_person <- file.path(expected_dir, "changed-person.csv"); expected_changed_qa <- file.path(expected_dir, "changed-qa.csv"); suppressWarnings(system2("python3", c(file.path(lab_root, "pipeline", "run_snakemake_compat.py"), expected_input, expected_changed_person, expected_changed_qa), stdout = TRUE, stderr = TRUE))
  # The participant pipeline must also leave the outputs that its evidence
  # describes. Compare parsed contents with the checker-owned expected tables.
  output_content <- function(a, b) {
    if (!file.exists(a) || !file.exists(b)) return(FALSE)
    xa <- tryCatch(utils::read.csv(a, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
    xb <- tryCatch(utils::read.csv(b, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
    !is.null(xa) && !is.null(xb) && isTRUE(all.equal(xa, xb, check.attributes = FALSE))
  }
  selected_output_ok <- output_content(selected_person_initial, expected_person) && output_content(selected_qa_initial, expected_qa)
  changed_output_ok <- output_content(selected_person_1, expected_changed_person) && output_content(selected_qa_1, expected_changed_qa)
  skip_state_ok <- identical(selected_first$status, 0L) && identical(selected_second$status, 0L) && identical(hash_person_1, hash_person_2) && identical(hash_qa_1, hash_qa_2) && identical(mtime_person_1, mtime_person_2) && identical(mtime_qa_1, mtime_qa_2)
  rebuild_state_ok <- identical(selected_changed$status, 0L) && !identical(hash_person_2, hash_person_3) && !identical(hash_qa_2, hash_qa_3) && !identical(mtime_person_2, mtime_person_3) && !identical(mtime_qa_2, mtime_qa_3)
  selected_log_ok <- if (identical(invalidation_kv$route, "targets")) grepl("skipped pipeline", tolower(selected_second$text), fixed = TRUE) && grepl("completed", tolower(selected_first$text), fixed = TRUE) && grepl("completed", tolower(selected_changed$text), fixed = TRUE) else if (nzchar(Sys.which("snakemake"))) grepl("nothing to be done|up to date|no jobs", tolower(selected_second$text), perl = TRUE) else grepl("skip: dependencies unchanged", selected_second$text, fixed = TRUE) && grepl("rebuild person_wave", selected_changed$text, fixed = TRUE) && grepl("rebuild wave_qa", selected_changed$text, fixed = TRUE)
  workflow_execution_ok <- source_ok && selected_output_ok && changed_output_ok && skip_state_ok && rebuild_state_ok && selected_log_ok
  # The helper restores the upstream input after the third (changed) run, so
  # the recorded outputs are the changed-run outputs.
  invalidation_ok <- invalidation_ok && path_names_ok && workflow_execution_ok
}
if (!invalidation_ok) { cat("FAIL workflow invalidation evidence is incomplete or ambiguous\n"); quit(status = 1L) }
cat("PASS lab 2: identical duplicate proved before repair; joins, wave QA, tests, Git recovery, and workflow invalidation verified\n")
