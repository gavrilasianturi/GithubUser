//
//  NetworkError.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Foundation

internal enum NetworkError: LocalizedError {
    case decodeError
    case networkError
    case invalidURL
    case others(String)
    
    internal var errorDescription: String? {
        switch self {
        case .decodeError:
            return "Failed to parse server response"
        case .networkError:
            return "Network connection failed"
        case .invalidURL:
            return "Invalid URL"
        case let .others(message):
            return message
        }
    }
}
