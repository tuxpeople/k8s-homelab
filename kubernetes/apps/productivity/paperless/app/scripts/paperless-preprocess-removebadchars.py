#!/usr/bin/env python3
import os
import sys
import fitz  # PyMuPDF
import tempfile
import subprocess

# Konfiguration
BAD_CHARS = ['\x8a', '']  # Zeichen mit falscher Kodierung (z. B. Windows-1252 für Umlaute)

def contains_bad_text(pdf_path):
    try:
        doc = fitz.open(pdf_path)
        for page in doc:
            text = page.get_text()
            if any(char in text for char in BAD_CHARS):
                print(f"[WARN] Seite enthält potenziell defekten Text: {repr(text.strip()[:100])}", file=sys.stderr)
                return True
        return False
    except Exception as e:
        print(f"[ERROR] Fehler beim Lesen von PDF: {e}", file=sys.stderr)
        return False

def remove_text_layer(pdf_path):
    tmp_output = tempfile.NamedTemporaryFile(delete=False, suffix=".pdf")
    tmp_output.close()
    tmp_path = tmp_output.name

    try:
        # Rastert das PDF in ein reines Bild-PDF (ohne eingebetteten Text)
        subprocess.run([
            "gs",
            "-o", tmp_path,
            "-sDEVICE=pdfwrite",
            "-dFILTERTEXT",  # <- entfernt Textinhalte
            "-dFILTERIMAGE=false",  # <- Bilder bleiben erhalten
            "-dCompatibilityLevel=1.4",
            "-dNOPAUSE",
            "-dQUIET",
            "-dBATCH",
            "-f", pdf_path
        ], check=True)

        # Ersetze das Original mit dem bereinigten PDF
        os.replace(tmp_path, pdf_path)
        print(f"[INFO] Eingebetteter Text entfernt aus: {pdf_path}", file=sys.stderr)
        return pdf_path

    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Ghostscript Fehler: {e}", file=sys.stderr)
        return pdf_path

def main():
    input_path = os.environ.get("DOCUMENT_WORKING_PATH")

    if not input_path or not os.path.isfile(input_path):
        print("[ERROR] Ungültiger oder nicht gesetzter Pfad in DOCUMENT_WORKING_PATH.", file=sys.stderr)
        sys.exit(1)

    if contains_bad_text(input_path):
        remove_text_layer(input_path)

    # Immer Pfad zurückgeben – Paperless erwartet stdout
    print(input_path)

if __name__ == "__main__":
    main()
