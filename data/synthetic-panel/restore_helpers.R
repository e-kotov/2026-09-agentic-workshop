configure_build_toolchain <- function() {
  # Discover the installed GCC runtime rather than pinning a Homebrew cellar
  # version. This workaround is only needed on macOS R builds that retain an
  # obsolete /opt/gfortran path.
  gfortran <- Sys.which("gfortran")
  if (!nzchar(gfortran)) return(invisible(NULL))
  brew <- Sys.which("brew")
  gcc_prefix <- if (nzchar(brew)) {
    out <- suppressWarnings(system2(brew, "--prefix gcc", stdout = TRUE, stderr = FALSE))
    if (length(out) && dir.exists(out[[1]])) out[[1]] else dirname(dirname(normalizePath(gfortran, mustWork = FALSE)))
  } else dirname(dirname(normalizePath(gfortran, mustWork = FALSE)))
  candidates <- Sys.glob(file.path(gcc_prefix, "lib", "gcc", "current", "gcc", "*", "*", "libemutls_w.a"))
  if (!length(candidates)) return(invisible(NULL))
  emutls <- candidates[[1]]
  makevars <- tempfile("synthetic-panel-makevars-")
  writeLines(paste0("FLIBS = -L", dirname(emutls), " -L", gcc_prefix, "/lib/gcc/current -lgfortran -lquadmath -lemutls_w"), makevars)
  Sys.setenv(R_MAKEVARS_USER = makevars)
  invisible(makevars)
}

normal_package_version <- function(x) gsub("[^0-9A-Za-z]", "", as.character(x))

locked_dependency_versions <- function(root_dir) {
  path <- file.path(root_dir, "dependencies.csv")
  if (!file.exists(path)) stop("dependencies.csv is required for exact renv bootstrap", call. = FALSE)
  deps <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  row <- deps[deps$component == "renv", , drop = FALSE]
  if (nrow(row) != 1L || !nzchar(row$version[[1]])) stop("dependencies.csv must declare one renv version", call. = FALSE)
  row$version[[1]]
}

sha256_file <- function(path) {
  if (requireNamespace("digest", quietly = TRUE)) return(digest::digest(file = path, algo = "sha256", serialize = FALSE))
  for (tool in c("shasum", "sha256sum")) {
    exe <- Sys.which(tool)
    if (!nzchar(exe)) next
    out <- system2(exe, c("-a", "256", path), stdout = TRUE, stderr = FALSE)
    if (length(out)) return(strsplit(out[[1]], "[[:space:]]+")[[1]][1])
  }
  stop("cannot verify renv bootstrap checksum: digest/shasum unavailable", call. = FALSE)
}

locked_descriptions <- function(lockfile) {
  lock <- renv::lockfile_read(lockfile)
  vapply(lock$Packages, `[[`, character(1), "Version")
}

# Bootstrap only the exact renv package named by the generator lock. This is
# before the one lock-driven restore and is not a restore fallback for others.
bootstrap_exact_renv <- function(root_dir, lockfile, lib) {
  expected_renv <- locked_dependency_versions(root_dir)
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  if (length(list.files(lib, all.files = TRUE, no.. = TRUE))) stop("renv bootstrap library must be empty", call. = FALSE)
  metadata_path <- file.path(root_dir, "renv-bootstrap.csv")
  if (!file.exists(metadata_path)) stop("verified renv bootstrap metadata is missing", call. = FALSE)
  metadata <- utils::read.csv(metadata_path, stringsAsFactors = FALSE, check.names = FALSE)
  row <- metadata[metadata$package == "renv" & normal_package_version(metadata$version) == normal_package_version(expected_renv), , drop = FALSE]
  if (nrow(row) != 1L || !nzchar(row$file_name[[1]]) || !grepl("^[0-9a-f]{64}$", row$sha256[[1]])) stop("renv-bootstrap.csv lacks one exact version/checksum record", call. = FALSE)
  archive <- file.path(root_dir, row$file_name[[1]])
  if (!file.exists(archive) || sha256_file(archive) != row$sha256[[1]]) stop("version-specific renv bootstrap archive is missing or has the wrong SHA-256", call. = FALSE)
  archive_files <- utils::untar(archive, list = TRUE)
  if (any(grepl("(^|/)libs/|[.](so|dll|dylib|o|a)$", archive_files, ignore.case = TRUE))) stop("renv bootstrap archive contains compiled/binary content; expected CRAN source archive", call. = FALSE)
  utils::install.packages(archive, lib = lib, repos = NULL, type = "source", dependencies = FALSE)
  local_description <- file.path(lib, "renv", "DESCRIPTION")
  if (!file.exists(local_description)) stop("exact renv bootstrap did not materialize local DESCRIPTION", call. = FALSE)
  actual_renv <- as.character(read.dcf(local_description)[1, "Version"])
  if (normal_package_version(actual_renv) != normal_package_version(expected_renv)) stop("bootstrap renv version differs from dependencies.csv: expected ", expected_renv, ", got ", actual_renv, call. = FALSE)
  .libPaths(c(lib, .libPaths()))
  if (!requireNamespace("renv", quietly = TRUE) || !startsWith(normalizePath(find.package("renv"), mustWork = FALSE), normalizePath(lib, mustWork = FALSE))) stop("exact renv bootstrap did not resolve from disposable library", call. = FALSE)
  lock <- renv::lockfile_read(lockfile)
  locked_renv <- lock$Packages$renv$Version
  if (is.null(locked_renv) || normal_package_version(locked_renv) != normal_package_version(actual_renv)) stop("bootstrap renv version differs from renv.lock", call. = FALSE)
  invisible(actual_renv)
}

# Launch a fresh R process. It loads exact local renv first and performs one
# lock-driven restore with rebuild=TRUE; no post-restore install is allowed.
materialize_locked_library <- function(root_dir, lockfile, lib) {
  expected <- locked_descriptions(lockfile)
  configure_build_toolchain()
  child_script <- tempfile("synthetic-panel-restore-child-", fileext = ".R")
  expected_code <- paste(capture.output(dput(expected)), collapse = "\n")
  code <- c(
    paste0("root_dir <- ", shQuote(root_dir)),
    paste0("lockfile <- ", shQuote(lockfile)),
    paste0("lib <- ", shQuote(lib)),
    paste0("expected <- ", expected_code),
    ".libPaths(c(lib))",
    "if (!requireNamespace('renv', quietly=TRUE)) stop('fresh restore child could not load local renv')",
    "renv_path <- normalizePath(find.package('renv'), mustWork=TRUE)",
    "if (!startsWith(renv_path, normalizePath(lib, mustWork=TRUE))) stop('fresh restore child loaded renv outside disposable library')",
    "quarantine <- tempfile('synthetic-panel-base-library-'); dir.create(quarantine)",
    "unlockBinding('.Library', baseenv()); assign('.Library', quarantine, baseenv()); lockBinding('.Library', baseenv())",
    "project_dir <- file.path(lib, 'project'); dir.create(project_dir)",
    "restore_lib <- file.path(lib, 'packages'); dir.create(restore_lib)",
    ".libPaths(c(restore_lib, lib), include.site=FALSE)",
    "options(renv.config.pak.enabled=FALSE)",
    "renv::restore(project=project_dir, lockfile=lockfile, library=restore_lib, packages=names(expected), rebuild=TRUE, clean=TRUE, transactional=FALSE, prompt=FALSE)",
    "managed <- renv::paths$library(project=project_dir)",
    ".libPaths(unique(c(restore_lib, managed, lib)), include.site=FALSE)",
    ".libPaths(unique(c(restore_lib, file.path(restore_lib, '.renv', '1'), list.dirs(file.path(restore_lib, '.renv'), recursive=TRUE, full.names=TRUE), lib)), include.site=FALSE)",
    "paths <- vapply(names(expected), function(p) { x <- find.package(p, quiet=TRUE); if (length(x)) x else NA_character_ }, character(1))",
    "if (any(is.na(paths)) || any(!startsWith(normalizePath(paths[!is.na(paths)], mustWork=TRUE), normalizePath(lib, mustWork=TRUE)))) stop(paste('locked package resolves outside disposable library or is missing:', paste(names(expected)[is.na(paths) | (!is.na(paths) & !startsWith(normalizePath(paths, mustWork=FALSE), normalizePath(lib, mustWork=FALSE)))], collapse=', '), ' libpaths=', paste(.libPaths(), collapse='|'))) ",
    "description_path <- file.path(paths, 'DESCRIPTION')",
    "if (!all(file.exists(description_path))) stop('not every locked package has a local DESCRIPTION after restore')",
    "actual <- vapply(description_path, function(path) as.character(read.dcf(path)[1, 'Version']), character(1))",
    "if (any(gsub('[^0-9A-Za-z]', '', actual) != gsub('[^0-9A-Za-z]', '', expected))) stop('restored package versions differ from renv.lock')",
    "if (!identical(length(description_path), 21L)) stop('expected exactly 21 locked package records')"
  )
  writeLines(code, child_script)
  status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", child_script), env = c(paste0("R_LIBS_USER=", lib), "R_LIBS_SITE="))
  if (!identical(status, 0L)) stop("fresh child lock-driven restore failed", call. = FALSE)
  invisible(expected)
}
