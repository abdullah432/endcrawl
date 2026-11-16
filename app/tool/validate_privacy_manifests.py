#!/usr/bin/env python3
"""Check ITMS-91064 tracking rules in source, an xcarchive, or an exported IPA.

Apple TN3181 requires nonempty domains when tracking is true, as well as
tracking=true when domains are present. Read XML and binary property lists.
"""
import argparse
from pathlib import Path
import plistlib
import re
import zipfile


def validate(data):
    errors = []
    tracking = data.get("NSPrivacyTracking")
    domains = data.get("NSPrivacyTrackingDomains", [])
    if tracking is not None and type(tracking) is not bool:
        errors.append("NSPrivacyTracking must be a Boolean")
    if not isinstance(domains, list):
        return errors + ["NSPrivacyTrackingDomains must be an array"]
    if tracking is True and not domains:
        errors.append("ITMS-91064: tracking=true requires at least one tracking domain")
    if domains and tracking is not True:
        errors.append("ITMS-91064: tracking domains require tracking=true")
    for domain in domains:
        if not isinstance(domain, str) or not re.fullmatch(
            r"(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+"
            r"[A-Za-z]{2,63}", domain
        ):
            errors.append(f"Invalid tracking domain: {domain!r}")
    return errors


def manifests(path):
    if path.suffix == ".ipa":
        with zipfile.ZipFile(path) as archive:
            for name in archive.namelist():
                if name.endswith(".xcprivacy"):
                    yield name, archive.read(name)
    elif path.is_dir():
        for file in sorted(path.rglob("*.xcprivacy")):
            yield str(file), file.read_bytes()
    else:
        yield str(path), path.read_bytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    count = failed = 0
    for name, raw in manifests(args.path):
        count += 1
        try:
            data = plistlib.loads(raw)
            errors = validate(data)
        except (ValueError, TypeError, AttributeError, plistlib.InvalidFileException) as error:
            errors = [f"Invalid property list: {error}"]
        for error in errors:
            failed += 1
            print(f"{name}: {error}")
    print(f"Checked {count} privacy manifest(s); {failed} issue(s).")
    return 1 if failed or count == 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
