#!/usr/bin/env bash
# Install (or update) Folio, my PDF reader, on Linux Mint:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/install-folio.sh)
#
# Run it again any time to update to the latest version.
set -e

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not with sudo."
    exit 1
fi

echo "==> Installing what Folio needs (Python, Qt, MuPDF, Tesseract OCR)"
sudo apt install -y curl python3-pyqt6 python3-fitz tesseract-ocr tesseract-ocr-eng

echo "==> Downloading Folio"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
curl -fsSL https://github.com/NevamindHaze/folio/archive/refs/heads/main.tar.gz | tar -xz -C "$WORK"

echo "==> Installing Folio"
sh "$WORK/folio-main/install.sh"

read -r -p "Make Folio your default PDF app? [Y/n] " reply </dev/tty || reply=""
if [[ ! ${reply:-Y} =~ ^[Nn] ]]; then
    xdg-mime default folio.desktop application/pdf
    echo "Done: PDFs now open in Folio."
fi
