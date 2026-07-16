# c4-xcode (SignLanguageApp)

iOS app for sign language. SwiftUI + @Observable pattern.
Xcode project using `PBXFileSystemSynchronizedRootGroup` — no pbxproj edits needed for new files.

## Source map
```
SignLanguageApp/SignLanguageApp/
├── App/
│   └── SignLanguageApp.swift     # @main entry
├── Core/
│   └── Logging/
│       └── AppLogger.swift       # os.Logger wrapper
├── Features/
│   └── Content/
│       └── ContentView.swift     # root content view
└── Assets.xcassets/
```

Target: iOS 26.5, Swift 5.
