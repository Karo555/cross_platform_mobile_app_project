# core/

Code shared by every feature that has nothing to do with one specific screen or with Firebase.

Put here:
- theme (colors, text styles)
- constants (for example the list of patient statuses)
- error and result types
- small helpers (date formatting, `patientId` format check)

Don't put here: screens, widgets for one feature, or anything that talks to Firebase (that goes in `data/`).
