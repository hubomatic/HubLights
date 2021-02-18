//
//  API.swift
//  HubLights
//
//  Created by Marc Prud'hommeaux on 2/17/21.
//

import Foundation

extension URL {
    public static let githubAPI = URL(string: "https://api.github.com")!
}

public extension Decodable {
    @discardableResult static func githubAPI(org: String, repo: String, branch: String, start: Bool = true, callback: @escaping (Result<(Self, URLResponse), Error>) -> ()) -> URLSessionDataTask {

        let url = URL.githubAPI
            .appendingPathComponent("repos")
            .appendingPathComponent(org)
            .appendingPathComponent(repo)
            .appendingPathComponent("commits")
            .appendingPathComponent(branch)
            .appendingPathComponent("check-suites")

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                return callback(.failure(error))
            } else {
                do {
                    debugPrint("data", String(data: data ?? .init(), encoding: .utf8)!)
                    let instance = try JSONDecoder().decode(Self.self, from: data ?? .init())
                    return callback(.success((instance, response ?? .init())))
                } catch {
                    return callback(.failure(error))
                }
            }
        }
        if start {
            task.resume()
        }
        return task
    }
}

public struct CheckAPIResponse : Hashable, Codable {
    public var total_count: Int
    public var check_suites: [CheckSuitesAPIResponse]
}

/// https://docs.github.com/en/rest/reference/checks#check-runs
public struct CheckSuitesAPIResponse : Identifiable, Hashable, Codable {
    public var id: Int64
    public var node_id: String?
    public var head_branch: String?
    public var head_sha: String?
    public var status: Status? // e.g., "completed"
    public var conclusion: Conclusion? // e.g., "failure"
    public var url: URL
    public var before: CommitHash?
    public var after: CommitHash?
    public var completed_at: Date?
    // etc...

    public enum Status : String, Codable {
        case queued, in_progress, completed
    }

    public enum Conclusion : String, Codable {
        case action_required, cancelled, failure, neutral, success, skipped, stale, timed_out
    }
}

public typealias CommitHash = String

