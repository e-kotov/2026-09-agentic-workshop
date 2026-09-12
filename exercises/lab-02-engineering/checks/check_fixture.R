input <- read.csv("fixture/records.csv", stringsAsFactors = FALSE)
output_path <- "project/output.csv"
if (!file.exists(output_path)) stop("generate project/output.csv first")
input_keys <- paste(input$household_id, input$person_id, input$wave, sep = "::")
if (!anyDuplicated(input_keys)) stop("teaching precondition changed: fixture should contain a duplicate")
output <- read.csv(output_path, stringsAsFactors = FALSE)
keys <- paste(output$household_id, output$person_id, output$wave, sep = "::")
if (anyDuplicated(keys)) stop("repaired output still has duplicate keys")
if (any(!nzchar(output$household_id)) || any(!nzchar(output$person_id))) stop("missing key")
if (nrow(output) != 3L) stop("expected three unique records in repaired output")
expected <- input[!duplicated(input_keys), , drop = FALSE]
stopifnot(identical(output, expected))
message("input precondition: duplicate detected; repaired output contract passed")
