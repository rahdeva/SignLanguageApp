# Suggested Commands

## Build
```bash
cd StellaApp
xcodebuild -scheme StellaApp -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

## Run Tests
```bash
cd StellaApp
xcodebuild -scheme StellaApp -destination 'platform=iOS Simulator,name=iPhone 17' test
```

System note (Darwin): All standard unix commands work identically.
