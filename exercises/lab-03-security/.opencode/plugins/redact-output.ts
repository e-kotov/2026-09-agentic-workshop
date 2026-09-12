/**
 * Lab-only teaching plugin. OpenCode's tool.execute.after hook runs after a
 * tool result is produced and before that result is returned to the session.
 * It masks harmless teaching patterns; it is not access control.
 */
export const RedactOutput = async () => ({
  "tool.execute.after": async (input: { tool: string }, output: { output: string }) => {
    if (input.tool !== "bash" && input.tool !== "read") return
    output.output = output.output
      .replace(/(token=)[^\s]+/gi, "$1[REDACTED]")
      .replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, "[EMAIL-REDACTED]")
  },
})
