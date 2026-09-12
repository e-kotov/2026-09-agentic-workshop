input <- "task/metadata.csv"
output <- "work/corrected-metadata.csv"
if (!file.exists(output)) stop("create work/corrected-metadata.csv first")
x <- read.csv(input, stringsAsFactors = FALSE)
y <- read.csv(output, stringsAsFactors = FALSE)
stopifnot(identical(names(x), names(y)), nrow(x) == nrow(y))
target <- y$variable == "employment" & y$value == 9
stopifnot(sum(target) == 1L)
stopifnot(identical(paste(x$variable, x$value), paste(y$variable, y$value)))
expected <- x
expected$label[expected$variable == "employment" & expected$value == 9] <- "missing"
stopifnot(identical(y, expected))
message("metadata invariant passed")
