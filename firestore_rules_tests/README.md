# Firestore rules tests

Allowed / denied checks for `../firestore.rules`, run against the **Firebase emulator** -
never against the real project (the project id starts with `demo-`, so it is fully offline).

Run these **before** `firebase deploy --only firestore:rules`.

```bash
# once
cd firestore_rules_tests
npm install

# every time (from the repository root)
cd ..
firebase emulators:exec --only firestore --project demo-vetbiz-rules "npm --prefix firestore_rules_tests test"
```

Needs Node 18+ and Java 11+ (the Firestore emulator is a Java program).

Tests marked `[STAGE 2]` describe behaviour that should be refused but still isn't. They are
flagged "todo", so they are listed but don't fail the run. When the Stage 2 rules land they should
start passing, and the `todo` flag can be removed.
