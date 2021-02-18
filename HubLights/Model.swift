//
//  Model.swift
//  HubLights
//
//  Created by Marc Prud'hommeaux on 2/17/21.
//

import Foundation
import OSLog

private let log = Logger()

/// The application model
struct Model : Hashable, Codable {
    var configs: [Config] = []
}

/// Permit storage in AppStorage via stringified JSON
struct ColdStorage<Wrapped: Codable> : RawRepresentable {
    var store: Wrapped

    init(_ store: Wrapped) {
        self.store = store
    }

    init?(rawValue: String) {
        do {
            store = try JSONDecoder().decode(Wrapped.self, from: rawValue.data(using: .utf8) ?? .init())
        } catch {
            log.info("\(error as NSError)")
            return nil
        }
    }

    var rawValue: String {
        do {
            return String(data: try JSONEncoder().encode(store), encoding: .utf8) ?? "{}"
        } catch {
            log.info("\(error as NSError)")
            return "{}"
        }
    }
}

extension ColdStorage : Equatable where Wrapped : Equatable { }
extension ColdStorage : Hashable where Wrapped : Hashable { }
extension ColdStorage : Encodable where Wrapped : Encodable { }
extension ColdStorage : Decodable where Wrapped : Decodable { }

/// A configuration for a single HubLights check
struct Config : Hashable, Identifiable, Codable {
    var id = UUID()
    var enabled: Bool?
    var title: String?
    var org: String?
    var repo: String?
    var branch: String?
    var checkInterval: Double?
    var status: CheckSuitesAPIResponse?
}


extension Model {
    /// Returns the config for the given UUID, or an empty one if not found
    subscript(config id: UUID) -> Config {
        get {
            configs.first(where: { $0.id == id }) ?? .init()
        }

        set {
            configs = configs.map {
                $0.id == id ? newValue : $0
            }
        }
    }
}


extension Config {
    var titleDefaulted: String {
        get { title[defaulting: ""] }
        set { title[defaulting: ""] = newValue }
    }

    var enabledDefaulted: Bool {
        get { enabled[defaulting: false] }
        set { enabled[defaulting: false] = newValue }
    }

    /// The check interval, defaulting to a minimum value of 30.0
    var checkIntervalDefaulted: Double {
        get { max(checkInterval[defaulting: 30.0], 30.0) }
        set { checkInterval[defaulting: 30.0] = max(newValue, 30.0) }
    }


    var listItemTitle: String {
        if let title = self.title { return title }

        return [self.org, self.repo, self.branch].compactMap({ $0 }).joined(separator: "/")
    }

    /// The URL for checking the services
    var serviceURL: URL? {
        guard let org = org else { return nil }
        return URL.githubAPI
            .appendingPathComponent("repos")
            .appendingPathComponent(org)
            .appendingPathComponent(repo ?? org)
            .appendingPathComponent("commits")
            .appendingPathComponent(branch ?? "main")
            .appendingPathComponent("check-suites")
    }
}

extension Optional where Wrapped : Hashable {
    subscript(defaulting defaultValue: Wrapped) -> Wrapped {
        get { self ?? defaultValue }
        set { self = newValue == defaultValue ? .none : .some(newValue) }
    }
}


final class StatusHolder : ObservableObject {
    @Published var results: [UUID: Data] = [:]
}

extension StatusHolder {
    func check(_ config: Config) {
        self.results[config.id] = nil

        if let url = config.serviceURL {
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data {
                    DispatchQueue.main.async {
                        self.results[config.id] = data
                    }
                }
            }
            .resume()
        }
    }
}
