//
//  LanguagePickerRow.swift
//  SignLanguageApp
//
//  Created by Antigravity on 19/07/26.
//

import SwiftUI

/// A form row that presents a `Picker` for selecting an `AppLanguage`.
struct LanguagePickerRow: View {
    let titleKey: LocalizedStringKey
    @Binding var selection: AppLanguage

    var body: some View {
        Picker(titleKey, selection: $selection) {
            ForEach(AppLanguage.allCases) { language in
                Text(language.displayName).tag(language)
            }
        }
    }
}
