# Firestore schema

The data model for the app, the seed script (#10) and the security rules (#12, #17, #18, #23).
Only synthetic data goes in these collections.

## Overview

```
patients/{patientId}                current state of one patient
patients/{patientId}/history/{eventId}   one immutable entry per transfer
locations/{locationId}              places a patient can be in
users/{uid}                         staff profile
```

Rules that apply everywhere:

- **Location and status are separate fields.** `Discharged` is a status, not a location. A discharged patient keeps their last `currentLocation`.
- **All `Timestamp` fields written by the app are server time.** They use `FieldValue.serverTimestamp()`, and the rules require them to equal `request.time` (#18).
- **The location shown is the last recorded one, not live tracking.** It changes only when a transfer is confirmed.

## `patients/{patientId}`

The document ID equals `patientId`. Its format is defined in #8. It is opaque and contains no personal or clinical information.

| Field | Type | Required | Allowed values and meaning |
|---|---|---|---|
| `patientId` | string | yes | Same as the document ID |
| `name` | string | yes | Display name |
| `age` | int | yes | 0 or higher |
| `condition` | string | yes | Short free text |
| `admissionDate` | Timestamp | yes | When the patient was admitted. Set by the seed script. |
| `currentLocation` | string | yes | Document ID in `locations` (#18) |
| `status` | string | yes | See [Status values](#status-values) |
| `lastUpdated` | Timestamp | yes | Last change of any kind |
| `locationUpdatedAt` | Timestamp | yes | Last change of `currentLocation`. A status change does not touch it. |
| `version` | int | yes | Starts at 1. Goes up by 1 on every transfer and status change (#35). |

### Status values

Stored exactly as written here, including capitals and spaces:

- `Admitted`
- `In Treatment`
- `Ready for Discharge`
- `Discharged`

## `patients/{patientId}/history/{eventId}`

One document per transfer. Clients can only create these, as part of a transfer. Nobody can update or delete them (#23).

A subcollection fits better than a top-level `locationHistory`: the history screen (#24) only ever reads one patient, the query needs no composite index, and the rules can tie an entry to its patient through the path.

| Field | Type | Required | Allowed values and meaning |
|---|---|---|---|
| `eventId` | string | yes | UUID v4, same as the document ID. Generated once per confirmation dialog, and retries reuse it (#34). |
| `patientId` | string | yes | Same as `{patientId}` in the path |
| `fromLocation` | string | yes | Document ID in `locations`. Read inside the transaction, never taken from client state (#22). |
| `toLocation` | string | yes | Document ID in `locations`. Must differ from `fromLocation`. |
| `timestamp` | Timestamp | yes | Server time of the transfer |
| `updatedBy` | string | yes | `uid` of the nurse. Must equal `request.auth.uid` (#18). |
| `updatedByName` | string | yes | `displayName` of the nurse at the time of the transfer. Must equal their `users/{uid}.displayName`. |

`updatedByName` is here because the history screen shows the actor's name (#24), but the rules in #12 do not let staff read each other's `users` documents. Copying the name also keeps history correct if a name changes later, and it works from the offline cache.

## `locations/{locationId}`

Read-only for clients. Written by the seed script (#10).

| Field | Type | Required | Allowed values and meaning |
|---|---|---|---|
| `name` | string | yes | Display name, for example `Radiology` |

The document ID is a stable lowercase slug matching `^[a-z0-9-]+$`, for example `er`, `ward-a`, `radiology`, `laboratory`. Patients and history store this ID, so screens look up `name` for display.

## `users/{uid}`

The document ID is the Firebase Auth `uid`. Written by the seed script (#10). Clients can read their own document and cannot write to it.

| Field | Type | Required | Allowed values and meaning |
|---|---|---|---|
| `displayName` | string | yes | Name shown in the movement history |
| `email` | string | yes | Sign-in email |
| `role` | string | yes | `nurse` or `doctor`. Copy of the custom claim, for reference only. |

**The source of truth for the role is the `role` custom claim on the ID token.** The app (`UserRole.fromClaim`) and the rules (`request.auth.token.role`) both read the claim. Any other value counts as no role and gets no access.

## What each operation writes

| Field | Transfer (nurse) | Status change (doctor) |
|---|---|---|
| `currentLocation` | new location | unchanged |
| `locationUpdatedAt` | server time | unchanged |
| `status` | unchanged | new status |
| `lastUpdated` | server time | server time |
| `version` | + 1 | + 1 |
| New `history` document | yes, in the same atomic write | no |

### Order of checks in a transfer

A retry after a lost response must not look like a conflict, so check in this order, inside the transaction:

1. If `history/{eventId}` already exists, the transfer already happened. Report success and write nothing (#34).
2. If `version` differs from `expectedVersion`, reject as a conflict (#35).
3. Otherwise, write the patient update and the history entry together (#22).

## Indexes

`firestore.indexes.json` is empty on purpose, because no query needs a composite index:

| Query | Used by | Index |
|---|---|---|
| All `patients`, ordered by `name` | Patient list (#26) | Automatic, single field |
| `history` of one patient, ordered by `timestamp` descending | Movement history (#24) | Automatic, single field |
| All `locations` | Transfer flow (#21) | None |

Search and filters (#27) run in the app on the patient list it already has. Firestore has no case-insensitive search, and the list is about 15 patients. If #27 moves filtering to the server, add its composite indexes to this file.

## Example documents

Synthetic data. The `patientId` format here is a placeholder until #8 is done.

```jsonc
// patients/HPT-EXAMPLE1
{
  "patientId": "HPT-EXAMPLE1",
  "name": "Test Patient 01",
  "age": 54,
  "condition": "Observation",
  "admissionDate": "2026-11-02T08:30:00Z",
  "currentLocation": "ward-a",
  "status": "In Treatment",
  "lastUpdated": "2026-11-03T14:05:00Z",
  "locationUpdatedAt": "2026-11-03T14:05:00Z",
  "version": 4
}

// patients/HPT-EXAMPLE1/history/6f1c2c1e-3b7a-4c55-9a3e-2d3f7b9e1a10
{
  "eventId": "6f1c2c1e-3b7a-4c55-9a3e-2d3f7b9e1a10",
  "patientId": "HPT-EXAMPLE1",
  "fromLocation": "radiology",
  "toLocation": "ward-a",
  "timestamp": "2026-11-03T14:05:00Z",
  "updatedBy": "nurse-uid-1",
  "updatedByName": "Test Nurse"
}
```
