#!/usr/bin/env python3
import os
import sys
import fitz  # PyMuPDF
import subprocess
import tempfile

def has_form_fields(pdf_path):
    try:
        doc = fitz.open(pdf_path)
        return doc.is_form_pdf
    except Exception as e:
        print(f"[ERROR] Fehler beim Öffnen von PDF: {e}", file=sys.stderr)
        return False

def flatten_with_ghostscript(input_path):
    # Ghostscript kann nicht direkt in dieselbe Datei schreiben, daher temporär
    tmp_output = tempfile.NamedTemporaryFile(delete=False, suffix=".pdf")
    tmp_output.close()
    tmp_path = tmp_output.name

    try:
        subprocess.run([
            "gs",
            "-o", tmp_path,
            "-sDEVICE=pdfwrite",
            "-dCompatibilityLevel=1.4",
            "-dPDFSETTINGS=/printer",
            "-dNOPAUSE",
            "-dQUIET",
            "-dBATCH",
            "-dPrinted=true",
            "-f", input_path
        ], check=True)

        # Ersetze Original mit bereinigtem PDF
        os.replace(tmp_path, input_path)

        return input_path
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Ghostscript Fehler: {e}", file=sys.stderr)
        return input_path

def main():
    input_path = os.environ.get("DOCUMENT_WORKING_PATH")

    if not input_path or not os.path.isfile(input_path):
        print("[ERROR] Ungültiger oder nicht gesetzter Pfad in DOCUMENT_WORKING_PATH.", file=sys.stderr)
        sys.exit(1)

    if has_form_fields(input_path):
        print(f"[INFO] Formularfelder erkannt – bereinige: {input_path}", file=sys.stderr)
        flatten_with_ghostscript(input_path)
    else:
        print(f"[INFO] Keine Formularfelder – keine Aktion nötig: {input_path}", file=sys.stderr)

    # Wichtig: Nur der finale Pfad auf stdout
    print(input_path)

if __name__ == "__main__":
    main()
