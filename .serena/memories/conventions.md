# Code Conventions

Follows Airbnb Swift Style Guide. Key rules:

## Architecture
- `@main` in `App/SignLanguageApp.swift`
- Views in `Features/<Name>/`
- Shared utilities in `Core/<subdir>/`

## SwiftUI
- `@State` properties: `private`
- View properties: `internal` (not `private`)
- Prefer `some View` opaque return types

## Naming
- UpperCamelCase for types/protocols
- lowerCamelCase for everything else
- Booleans: `is`, `has`, `does` prefix
- Event handlers: past-tense (`didTapSubmit`, `willAppear`)
- Acronyms lowercased in camelCase: `urlString`, `idToken`

## Style
- `final class` default
- No `unowned`, use `weak`
- No `print`/`debugPrint` — use `os.Logger`
- `static func` over `class func`
- `isEmpty` over `count == 0`
- Guard for precondition validation early in scope

Refer to `mem:tech_stack` for framework details.
