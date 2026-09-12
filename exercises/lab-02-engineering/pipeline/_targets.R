library(targets)

tar_option_set(packages = "utils")
list(
  # Declare the external input explicitly so edits invalidate downstream work.
  tar_target(records_file, "pipeline/input/records.csv", format = "file"),
  tar_target(records, read.csv(records_file, stringsAsFactors = FALSE)),
  tar_target(clean_records, {
    key <- paste(records$household_id, records$person_id, records$wave, sep = "::")
    records[!duplicated(key), , drop = FALSE]
  }),
  tar_target(manifest, {
    dir.create("pipeline/out", showWarnings = FALSE, recursive = TRUE)
    write.csv(clean_records, "pipeline/out/manifest.csv", row.names = FALSE)
    "pipeline/out/manifest.csv"
  }, format = "file")
)
