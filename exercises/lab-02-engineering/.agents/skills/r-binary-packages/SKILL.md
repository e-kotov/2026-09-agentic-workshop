---
name: r-binary-packages
description: Use when an R package is missing on Linux and the participant asks to diagnose or install it from the environment's configured compatible binary repository.
---

# R binary packages on Linux

1. Inspect `R.version$platform` and `getOption("repos")` first; a dry diagnostic is enough when installation is not requested.
2. Preserve the image's configured P3M repository. Never hard-code the Linux `__linux__/noble` URL on a macOS host, rewrite site-wide R profiles, or add credentials.
3. Use ordinary `install.packages()` (or `install2.r` where provided) and let the configured repository resolve a compatible binary. Do not force a source build or use `sudo`.
4. If no compatible binary is available, stop and report the exact failure before attempting source compilation or adding system libraries.
5. This skill covers installation mechanics only. It does not approve data access, network uploads, or package code; never upload private/restricted SOEP rows or documentation to an LLM or package service.

After installation, verify with a minimal `Rscript` load/version check and record the environment change. Keep installation outside the exercise artefact when possible.
