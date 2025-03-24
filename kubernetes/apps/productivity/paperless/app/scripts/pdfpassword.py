#!/usr/bin/env python
# https://piep.tech/posts/automatic-password-removal-in-paperless-ngx/

import pikepdf
import os

def unlock_pdf(file_path):
    password = None
    print("reading passwords")
    with open("/usr/src/paperless/scripts/passwords.txt", "r") as f:
        passwords = f.readlines()
    for p in passwords:
        password = p.strip()
        try:
            with pikepdf.open(file_path, password=password, allow_overwriting_input=True) as pdf:
                print("password is working:" + password)
                pdf.save(file_path)
                break
        except pikepdf.PasswordError:
            print("password isn't working:" + password)
            continue
    if password is None:
        print("Empty password file")

file_path = os.environ.get('DOCUMENT_WORKING_PATH')
unlock_pdf(file_path)
