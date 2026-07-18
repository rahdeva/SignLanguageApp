# Suggested Commands

## Build
```bash
cd SignLanguageApp
xcodebuild -scheme SignLanguageApp -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

## Run Tests
```bash
cd SignLanguageApp
xcodebuild -scheme SignLanguageApp -destination 'platform=iOS Simulator,name=iPhone 17' test
```

System note (Darwin): All standard unix commands work identically.
