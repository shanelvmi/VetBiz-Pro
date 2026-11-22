# Running the tests (STAB1)

Use `tool/run_tests.ps1` (PowerShell), from the repository root:

| Command | What it does |
|---|---|
| `powershell -File tool/run_tests.ps1` | The whole suite at a fixed concurrency (the machine's core count), then one summary line (passed, skipped, failed, seconds) and each failing test by file. |
| `powershell -File tool/run_tests.ps1 -Changed` | Only the test files changed since the last commit (tracked or new). Quick, but the gate is the whole suite. |
| `powershell -File tool/run_tests.ps1 -Record <one test file> -Define PH5A_RECORD` | Records that ONE file's fixtures (defines: PH5A, PH6, PH7A, PH7B, PH8A, PH8B `_RECORD`, `WRITE_SHAPES`). |

It prints the free memory at start and refuses a concurrency above the
core count when under 6 GB are free.

**No orphan processes.** It records the run in `build/run_tests.lock` (its
pid, the start time, every process already running) and stops everything
the run started (`tool/run_tests_cleanup.ps1`: dart, dartvm,
dartaotruntime, flutter_tester and their cmd) on a normal end, an error or
Ctrl+C, and through a hidden watcher when the script itself is killed (the
memory guard once stopped only the shell, and the test processes ran on for
days). What it stopped is in `build/run_tests_tree.txt`.

Manual check (STAB1, done on 2026-11-16): start the full suite with a
sleeping PowerShell standing in for run_tests.ps1, its lock and the
watcher; after 40 s six flutter processes were running (three
flutter_tester); kill the stand-in; 10 s later none were left, the lock was
gone and the tree file listed seven processes stopped. To repeat it, run
`powershell -File tool/run_tests.ps1`, then stop that PowerShell from
another window (`Stop-Process -Id <its pid>`): no flutter_tester may remain
(`Get-Process flutter_tester`).

A **stale lock** (UX3): when `build/run_tests.lock` names a process that no
longer runs (the machine slept, the window was closed) and no flutter test or
analyze is running, the script removes the lock, says so in one line
(`removed a stale build/run_tests.lock (pid N no longer runs); continuing.`)
and runs. It does not run the cleanup for that lock (it would stop any
flutter process started since, a `flutter run` included). Manual check
(2026-11-22): a lock naming pid 999999, then `run_tests.ps1 -Changed`: the
line above, the run went on, the lock was gone; a lock naming a live
(sleeping) PowerShell: refused as before (exit 2), the lock kept.

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
