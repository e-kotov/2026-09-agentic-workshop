#!/bin/bash
# copy-pdf.sh: Run by Quarto after project render finishes

# Ensure build target and source assets folders exist
mkdir -p _book/assets
mkdir -p assets

# Copy PDF if it exists
if [ -f "_book/Beyond-the-Chatbox.pdf" ]; then
  # Copy to build output folder and mirror to source assets
  cp "_book/Beyond-the-Chatbox.pdf" "_book/assets/Beyond-the-Chatbox.pdf"
  cp "_book/Beyond-the-Chatbox.pdf" "assets/Beyond-the-Chatbox.pdf"
  echo "[copy-pdf.sh] Successfully copied Beyond-the-Chatbox.pdf to _book/assets/ and assets/"
elif [ -f "assets/Beyond-the-Chatbox.pdf" ]; then
  cp "assets/Beyond-the-Chatbox.pdf" "_book/assets/Beyond-the-Chatbox.pdf"
  echo "[copy-pdf.sh] Preserved assets/Beyond-the-Chatbox.pdf in _book/assets/"
else
  echo "[copy-pdf.sh] Warning: Beyond-the-Chatbox.pdf not found."
fi
