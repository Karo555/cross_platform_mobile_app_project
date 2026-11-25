"""Seed script (#10): synthetic locations, patients and test accounts.

This is the trusted setup process from the spec (Sec. 3.5): it is the only
place where roles are assigned. It uses the Firebase Admin SDK, which bypasses
the security rules, so it must never run inside the app.

ONLY SYNTHETIC DATA. Every name, age and condition below is made up.

Usage (from the project root):

    python tools/seed.py              # local emulators (default)
    python tools/seed.py --reset      # also overwrite existing patients
    python tools/seed.py --cloud      # the real project, see README

Running it again does not duplicate anything: every document has a fixed ID,
accounts are looked up by email first, and existing patients are left as they
are (so transfers made while testing survive) unless --reset is given.
"""

import argparse
import os
import sys
from datetime import datetime, timedelta, timezone

PROJECT_ID = "patient-tracker-cpma"

# Password of every test account in the EMULATOR. It only works there, which
# is why it can be written down. For --cloud the password comes from the
# SEED_PASSWORD environment variable and is never stored in the repo.
EMULATOR_PASSWORD = "test1234"

# Location slugs (document IDs) and display names. See docs/schema.md.
LOCATIONS = {
    "er": "ER",
    "ward-a": "Ward A",
    "ward-b": "Ward B",
    "icu": "ICU",
    "radiology": "Radiology",
    "laboratory": "Laboratory",
    "surgery": "Surgery",
}

# Test accounts. The role becomes the `role` custom claim on the ID token,
# which the app and the rules read. None means signed in but no role, to test
# the "No access" screen and the rules' rejection.
ACCOUNTS = [
    {"email": "nurse1@test.local", "name": "Nora Nurse", "role": "nurse"},
    {"email": "nurse2@test.local", "name": "Ned Nurse", "role": "nurse"},
    {"email": "doctor1@test.local", "name": "Dana Doctor", "role": "doctor"},
    {"email": "doctor2@test.local", "name": "Dev Doctor", "role": "doctor"},
    {"email": "norole1@test.local", "name": "Rory Norole", "role": None},
]

# Patient ID format is decided in #8. Until then: "HPT-" + 6 characters.
# All IDs live here, so changing the format means changing only this list.
# (patient ID, name, age, condition, location, status, admitted days ago)
PATIENTS = [
    ("HPT-000001", "Alma Example", 67, "Hip fracture", "surgery", "In Treatment", 3),
    ("HPT-000002", "Bruno Sample", 45, "Chest pain", "er", "Admitted", 0),
    ("HPT-000003", "Clara Placeholder", 29, "Appendicitis", "ward-a", "Ready for Discharge", 4),
    ("HPT-000004", "Dario Mock", 81, "Pneumonia", "icu", "In Treatment", 6),
    ("HPT-000005", "Elif Fictional", 52, "Kidney stones", "radiology", "In Treatment", 1),
    ("HPT-000006", "Felix Dummy", 34, "Broken wrist", "ward-b", "Ready for Discharge", 2),
    ("HPT-000007", "Greta Synthetic", 73, "Stroke observation", "icu", "Admitted", 1),
    ("HPT-000008", "Hugo Testcase", 19, "Concussion", "er", "In Treatment", 0),
    ("HPT-000009", "Ines Madeup", 60, "Blood test follow-up", "laboratory", "Admitted", 2),
    ("HPT-000010", "Jonas Notreal", 41, "Asthma attack", "ward-a", "In Treatment", 3),
    ("HPT-000011", "Kira Invented", 88, "Dehydration", "ward-b", "Admitted", 5),
    ("HPT-000012", "Lars Fakename", 37, "Knee surgery", "surgery", "Admitted", 1),
    ("HPT-000013", "Mona Demo", 26, "Allergic reaction", "ward-a", "Discharged", 7),
    ("HPT-000014", "Nils Fixture", 55, "Diabetes check", "laboratory", "In Treatment", 2),
    ("HPT-000015", "Olga Stub", 70, "Heart monitoring", "ward-b", "In Treatment", 4),
]


def parse_args():
    parser = argparse.ArgumentParser(description="Seed synthetic test data.")
    parser.add_argument("--cloud", action="store_true",
                        help="seed the real Firebase project instead of the emulators")
    parser.add_argument("--reset", action="store_true",
                        help="overwrite existing patients with the seed values")
    parser.add_argument("--host", default="localhost",
                        help="where the emulators run (default: localhost)")
    return parser.parse_args()


def connect(args):
    """Points the Admin SDK at the emulators or the real project."""
    # The SDKs read these variables at import time, so set them first.
    if args.cloud:
        for var in ("FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"):
            os.environ.pop(var, None)
    else:
        os.environ["FIRESTORE_EMULATOR_HOST"] = f"{args.host}:8080"
        os.environ["FIREBASE_AUTH_EMULATOR_HOST"] = f"{args.host}:9099"

    import firebase_admin
    from firebase_admin import credentials

    if args.cloud:
        # A service account key file from the Firebase console. Secret: never
        # commit it (see .gitignore).
        if not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
            sys.exit("--cloud needs GOOGLE_APPLICATION_CREDENTIALS (see README).")
        cred = credentials.ApplicationDefault()
    else:
        # The emulators accept any credentials, so no key file is needed.
        cred = _EmulatorCredential()
    firebase_admin.initialize_app(cred, {"projectId": PROJECT_ID})


def _EmulatorCredential():
    from firebase_admin import credentials
    import google.auth.credentials

    class EmulatorCredential(credentials.Base):
        def get_credential(self):
            return google.auth.credentials.AnonymousCredentials()

    return EmulatorCredential()


def password_for(args):
    if not args.cloud:
        return EMULATOR_PASSWORD
    password = os.environ.get("SEED_PASSWORD", "")
    if len(password) < 12:
        sys.exit("--cloud needs SEED_PASSWORD with at least 12 characters.")
    return password


def confirm_cloud():
    """Writing to the real project must be a deliberate choice."""
    answer = input(f"This writes to the REAL project '{PROJECT_ID}'. "
                   f"Type the project ID to continue: ")
    if answer.strip() != PROJECT_ID:
        sys.exit("Cancelled. Nothing was written.")


def seed_locations(db):
    for location_id, name in LOCATIONS.items():
        db.collection("locations").document(location_id).set({"name": name})
    print(f"locations: {len(LOCATIONS)} written")


def seed_patients(db, reset):
    from google.api_core.exceptions import AlreadyExists

    now = datetime.now(timezone.utc)
    created = kept = 0
    for patient_id, name, age, condition, location, status, days_ago in PATIENTS:
        admitted = now - timedelta(days=days_ago, hours=2)
        data = {
            "patientId": patient_id,
            "name": name,
            "age": age,
            "condition": condition,
            "admissionDate": admitted,
            "currentLocation": location,
            "status": status,
            "lastUpdated": admitted,
            "locationUpdatedAt": admitted,
            "version": 1,
        }
        ref = db.collection("patients").document(patient_id)
        if reset:
            ref.set(data)
            created += 1
        else:
            try:
                ref.create(data)  # fails if the patient already exists
                created += 1
            except AlreadyExists:
                kept += 1
    action = "overwritten" if reset else "created"
    print(f"patients: {created} {action}, {kept} already existed (kept)")


def seed_accounts(db, password):
    from firebase_admin import auth

    for account in ACCOUNTS:
        try:
            user = auth.get_user_by_email(account["email"])
            state = "exists"
        except auth.UserNotFoundError:
            user = auth.create_user(email=account["email"], password=password,
                                    display_name=account["name"])
            state = "created"

        # The role claim is the source of truth (docs/schema.md). Set it on
        # every run, so a changed role here reaches the account.
        role = account["role"]
        auth.set_custom_user_claims(user.uid, {"role": role} if role else None)

        # users/{uid}: the display name for the history, and a copy of the
        # role for reference only.
        profile = {"displayName": account["name"], "email": account["email"]}
        if role:
            profile["role"] = role
        db.collection("users").document(user.uid).set(profile)
        print(f"account {account['email']:<20} {state:<8} role={role}")


def main():
    args = parse_args()
    if args.cloud:
        confirm_cloud()
    password = password_for(args)
    connect(args)

    from firebase_admin import firestore
    db = firestore.client()

    target = f"REAL project {PROJECT_ID}" if args.cloud else f"emulators on {args.host}"
    print(f"Seeding {target}")
    seed_locations(db)
    seed_patients(db, args.reset)
    seed_accounts(db, password)
    print("Done.")


if __name__ == "__main__":
    main()
