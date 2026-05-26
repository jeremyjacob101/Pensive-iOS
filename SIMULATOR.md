# SIMULATOR.md

This is the canonical simulator/test runbook for this repo.
Use this exact flow in every future chat.

## 1) One-Time Project Sync

Run:
```bash
xcodegen generate
```

Reason: ensures new files are actually in `Pensive.xcodeproj`.

## 2) Required Simulator Target

Always use:
- Device: `iPhone 17`
- Destination flag: `-destination 'platform=iOS Simulator,name=iPhone 17'`

Never use test destination `Any iOS Simulator Device`.

## 3) Stable Test Flags (Always)

Use these flags for all test runs:
- `-derivedDataPath /private/tmp/PensiveDerivedData`
- `-parallel-testing-enabled NO`
- `-maximum-parallel-testing-workers 1`

These avoid prior failures from:
- restricted write paths under `~/Library/Developer/Xcode/DerivedData`
- test runner collisions
- simulator preflight instability

## 4) Canonical Commands

Build sanity:
```bash
xcodebuild -scheme Pensive \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/PensiveDerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  build
```

Required unit tests:
```bash
xcodebuild -scheme Pensive \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/PensiveDerivedData \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -only-testing:PensiveTests test
```

Required UI smoke test:
```bash
xcodebuild -scheme Pensive \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/PensiveDerivedData \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -only-testing:PensiveUITests/PensiveUITests/testLaunchShowsRootView test
```

## 5) Codex Sandbox + Escalation Rule (Mandatory)

When running from Codex, simulator/Xcode operations can fail under sandbox constraints even when commands are correct.

Common symptom signatures:
- `CoreSimulatorService connection became invalid`
- `Unable to deliver request ... not connected to CoreSimulatorService`
- `DVTFilePathFSEvents` or simulator logging permission errors

Action:
- Immediately rerun the same `xcodebuild`/`simctl` command with escalated permissions in Codex.
- Do not change command flags first; preserve the canonical command from this document.
- Keep using `/private/tmp/PensiveDerivedData` and sequential test execution.

## 6) If Simulator Fails To Launch App (Preflight Busy)

Symptom usually includes:
- `SBMainWorkspace ... Busy (Application failed preflight checks)`

Recovery sequence:
```bash
xcrun simctl shutdown 'iPhone 17' || true
xcrun simctl erase 'iPhone 17'
xcrun simctl boot 'iPhone 17'
```

Then rerun the same test command with the stable flags above.

## 7) SweetPad Setup

This repo keeps SweetPad config in:
- `.vscode/settings.json`
- `.vscode/tasks.json`

Use the provided tasks directly for build/test runs to avoid drift.

## 8) Non-Negotiables

- Run unit and UI commands sequentially, not in parallel.
- Keep `iPhone 17` destination unless SWIFT.md explicitly changes it.
- Keep `/private/tmp/PensiveDerivedData` unless permissions model changes.
- If adding/removing files, rerun `xcodegen generate` before tests.
- If simulator tooling fails due to sandbox constraints, rerun with Codex escalation using the same command.
