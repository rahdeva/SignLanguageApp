# Task Completion Verification

When a coding task is done:

1. Build: `xcodebuild -scheme StellaApp -destination 'generic/platform=iOS Simulator' -configuration Debug build`
   - Confirm `** BUILD SUCCEEDED **` in output
2. If tests exist: `xcodebuild -scheme StellaApp -destination 'platform=iOS Simulator,name=iPhone 17' test`
   - Confirm `** TEST SUCCEEDED **`
3. No SwiftLint or formatter configured for this project yet
