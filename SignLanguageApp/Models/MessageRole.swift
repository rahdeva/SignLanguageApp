//
//  MessageRole.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import Foundation

enum MessageRole: String, Codable, Sendable {
    /// Sign language (Teman Tuli) — bubble on the left.
    case sign
    /// Speech-to-text (Caregiver) — bubble on the right.
    case speech
}
