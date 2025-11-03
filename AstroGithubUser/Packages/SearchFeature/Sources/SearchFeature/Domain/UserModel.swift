//
//  UserModel.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

public struct UserResponse: Decodable, Equatable {
    public let totalCount: Int
    public let items: [User]
    
    public enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
    
    public init(totalCount: Int = 0, items: [User] = []) {
        self.totalCount = totalCount
        self.items = items
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
        self.items = try container.decodeIfPresent([User].self, forKey: .items) ?? []
    }
}

public struct User: Decodable, Equatable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let login: String
    public let avatarURL: String
    public var isLiked: Bool = false
    
    public enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarURL = "avatar_url"
    }
    
    public init(
        id: Int,
        login: String,
        avatarURL: String
    ) {
        self.id = id
        self.login = login
        self.avatarURL = avatarURL
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        self.login = try container.decodeIfPresent(String.self, forKey: .login) ?? ""
        self.avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL) ?? ""
    }
}
