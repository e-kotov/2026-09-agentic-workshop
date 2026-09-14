library(targets)
tar_option_set()
list(
  tar_target(upstream_file, "input/person_wave.csv", format = "file"),
  tar_target(person_wave, {
    x <- read.csv(upstream_file, stringsAsFactors = FALSE, check.names = FALSE)
    x <- x[!duplicated(paste(x$pid, x$wave, sep = "::")), , drop = FALSE]
    dir.create("out", showWarnings = FALSE)
    write.csv(x, "out/person_wave.csv", row.names = FALSE)
    "out/person_wave.csv"
  }, format = "file"),
  tar_target(wave_qa, {
    x <- read.csv(person_wave, stringsAsFactors = FALSE, check.names = FALSE)
    z <- do.call(rbind, lapply(2019:2022, function(w) {
      y <- x[x$wave == w, , drop = FALSE]
      data.frame(wave = w, row_count = nrow(y), person_weight_sum = sum(y$person_xs_weight))
    }))
    write.csv(z, "out/wave-qa.csv", row.names = FALSE)
    "out/wave-qa.csv"
  }, format = "file")
)
