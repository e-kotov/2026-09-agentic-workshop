input <- read.csv("fixture/records.csv", stringsAsFactors = FALSE)
keys <- paste(input$household_id, input$person_id, input$wave, sep = "::")
output <- input[!duplicated(keys), , drop = FALSE]
write.csv(output, "project/output.csv", row.names = FALSE)
message("generated project/output.csv from immutable fixture/records.csv")
