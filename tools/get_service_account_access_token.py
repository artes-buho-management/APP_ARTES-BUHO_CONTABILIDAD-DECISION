#!/usr/bin/env python3
import argparse
import sys

from google.oauth2 import service_account
from google.auth.transport.requests import Request


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--keyPath", required=True)
    parser.add_argument("--scopes", required=True)
    args = parser.parse_args()

    scopes = [s.strip() for s in args.scopes.split(",") if s.strip()]
    if not scopes:
        print("ERROR: scopes vacios", file=sys.stderr)
        return 1

    creds = service_account.Credentials.from_service_account_file(
        args.keyPath, scopes=scopes
    )
    creds.refresh(Request())
    token = creds.token or ""
    if not token:
        print("ERROR: token vacio", file=sys.stderr)
        return 1

    print(token)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
