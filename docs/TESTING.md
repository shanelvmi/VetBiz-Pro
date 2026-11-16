# Running the tests (STAB1)

Use `tool/run_tests.ps1` (PowerShell), from the repository root:

| Command | What it does |
|---|---|
| `powershell -File tool/run_tests.ps1` | The whole suite at a fixed concurrency (the machine's core count), then one summary line (passed, skipped, failed, seconds) and each failing test by file. |
| `powershell -File tool/run_tests.ps1 -Changed` | Only the test files changed since the last commit (tracked or new). Quick, but the gate is the whole suite. |
| `powershell -File tool/run_tests.ps1 -Record <one test file> -Define PH5A_RECORD` | Records that ONE file's fixtures (defines: PH5A, PH6, PH7A, PH7B, PH8A, PH8B `_RECORD`, `WRITE_SHAPES`). |

Rules it enforces:

- **One flutter command at a time.** It refuses to start, in one line, while
  another `flutter test` or `flutter analyze` runs: two at once crash the
  Dart VM and report dozens of false failures.
- **Record one file at a time.** A fixture (`test/fixtures/*.json`) is
  written only with an explicit record define. The recorders also lock the
  file (`test/helpers/fixture_lock.dart`) and print a warning if another
  file is recording.
- **A normal run never writes a fixture.** `test/flutter_test_config.dart`
  fails any test file that changed one (`test/helpers/fixture_guard.dart`).

When a test waits for the app (`ph5SettleUntil`, `waitUntil`), it fails by
name if the wait never finishes, rather than reading a half-loaded screen.
Wait for what the test needs (a seeded value shown), not for a fixed time.
