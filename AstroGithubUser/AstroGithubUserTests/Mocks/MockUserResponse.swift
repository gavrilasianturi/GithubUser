//
//  MockUserResponse.swift
//  AstroGithubUser
//
//  Created by ByteDance on 02/11/25.
//

import Foundation

@testable import AstroGithubUser

internal final class MockUserResponse {
    internal static let normal = UserResponse(
        totalCount: 1000,
        items: [
            User(id: 1, login: "satu", avatarURL: "avatar-satu"),
            User(id: 2, login: "dua", avatarURL: "avatar-dua"),
            User(id: 3, login: "tiga", avatarURL: "avatar-tiga"),
            User(id: 4, login: "empat", avatarURL: "avatar-empat"),
            User(id: 5, login: "lima", avatarURL: "avatar-lima")
        ]
    )
    
    internal static let empty = UserResponse(
        totalCount: 0,
        items: []
    )
}
