#!/bin/bash
# copy-pdf.sh: Run by Quarto after project render finishes

# Ensure build target folder exists
mkdir -p _book/assets

# Copy PDF if it exists
if [ -f "_book/Beyond-the-Chatbox.pdf" ]; then
  # Copy to build output folder (which gets pushed to gh-pages by GitHub Actions)
  cp "_book/Beyond-the-Chatbox.pdf" "_book/assets/Beyond-the-Chatbox.pdf"
  echo "[copy-pdf.sh] Successfully copied Beyond-the-Chatbox.pdf to _book/assets/"
else
  echo "[copy-pdf.sh] Warning: _book/Beyond-the-Chatbox.pdf not found."
fi
