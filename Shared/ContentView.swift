//
//  ContentView.swift
//  Shared
//
//  Created by Timothy Dillman on 6/14/22.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    var body: some View {
        if viewModel.loading {
            ProgressView()
                .progressViewStyle(.circular)
        } else {
            ScrollView {
                ForEach(viewModel.posts, id: \.id) { post in
                    VStack(alignment: .leading) {
                        HStack { Spacer() }
                        Text(post.title)
                            .font(.title)
                        Text(post.body)
                            .font(.body)
                        Divider()
                    }
                }
            }
        }
    }
}

import PorkChop
class ContentViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var loading: Bool = false
    private var networking: PRKChopNetworking = .init()
    
    init() {
        Task {
            await fetchPosts()
        }
    }
    
    @MainActor
    func fetchPosts() async {
        loading = true
        do {
            posts = try await Post.all(networkProvider: networking) ?? []
        } catch {
            print(error.localizedDescription)
        }
        loading = false
    }
}

extension ContentViewModel {
    // MARK: - Base URL Setup
    struct APIRepo {
        static let baseURL: URL = "https://jsonplaceholder.typicode.com"
    }
    
    
    // MARK: - Post
    struct Post: Codable, ResourceRouteProvider {
        let userID, id: Int
        let title, body: String
    
        enum CodingKeys: String, CodingKey {
            case userID = "userId"
            case id, title, body
        }
        
        static func all<T>(networkProvider: PRKChopNetworking) async throws -> T? where T : Decodable {
            let request = networkProvider.createRequest(url: APIRepo.baseURL.appendingPathComponent("posts"), httpMethod: .get, body: PRKChopEmptyBody())
            return try await networkProvider
                .make(for: request)
                .tryTransform(type: [Post].self) as? T
        }
    }
}

protocol ResourceRouteProvider {
    static func all<T: Decodable>(networkProvider: PRKChopNetworking) async throws -> T?
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
