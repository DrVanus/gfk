import SwiftUI
import Foundation

/// News categories for filtering the feed
enum NewsCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case bitcoin = "Bitcoin"
    case ethereum = "Ethereum"
    // Add more categories as needed

    var id: String { rawValue }

    /// Query parameter to use when fetching from the News API
    var query: String {
        switch self {
        case .all: return "crypto"
        case .bitcoin: return "bitcoin"
        case .ethereum: return "ethereum"
        }
    }
}

@MainActor
final class CryptoNewsFeedViewModel: ObservableObject {
    @Published var articles: [CryptoNewsArticle] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingPage: Bool = false
    private var currentPage: Int = 1
    @Published var errorMessage: String?

    /// Currently selected news category; will reload feed when changed
    @Published var selectedCategory: NewsCategory = .all {
        didSet {
            Task { await loadAllNews() }
        }
    }

    private let newsService = CryptoNewsService()

    init() {
        Task { await loadAllNews() }
        // Load any saved bookmarks from UserDefaults
        loadBookmarks()
    }

    @MainActor
    func loadAllNews() async {
        isLoading = true
        currentPage = 1
        defer { isLoading = false }

        do {
            let fetched = try await newsService.fetchNews(query: selectedCategory.query, page: 1)
            articles = fetched
            if fetched.isEmpty {
                errorMessage = "No news available"
            } else {
                errorMessage = nil
            }
        } catch {
            articles = []
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func loadMoreNews() async {
        guard !isLoadingPage else { return }
        isLoadingPage = true
        defer { isLoadingPage = false }

        currentPage += 1
        do {
            // Ensure your service has a paginated fetch method
            let fetched = try await newsService.fetchNews(query: selectedCategory.query, page: currentPage)
            articles.append(contentsOf: fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func loadLatestNews() async {
        isLoading = true
        currentPage = 1
        defer { isLoading = false }
        do {
            let fetched = try await newsService.fetchNews(query: selectedCategory.query, page: 1)
            articles = Array(fetched.prefix(5))
            errorMessage = fetched.isEmpty ? "No news available" : nil
        } catch {
            articles = []
            errorMessage = error.localizedDescription
        }
    }

    // Track read/bookmarked articles
    @Published private var readArticleIDs: Set<String> = []
    @Published private var bookmarkedArticleIDs: Set<String> = []

    /// Persistence key for saved bookmarks
    private let bookmarksKey = "bookmarkedArticleIDs"

    // MARK: - Read / Bookmark Actions

    func toggleRead(_ article: CryptoNewsArticle) {
        if isRead(article) {
            readArticleIDs.remove(article.id)
        } else {
            readArticleIDs.insert(article.id)
        }
    }

    func isRead(_ article: CryptoNewsArticle) -> Bool {
        readArticleIDs.contains(article.id)
    }

    func toggleBookmark(_ article: CryptoNewsArticle) {
        if isBookmarked(article) {
            bookmarkedArticleIDs.remove(article.id)
        } else {
            bookmarkedArticleIDs.insert(article.id)
        }
        // Persist the change
        saveBookmarks()
    }

    func isBookmarked(_ article: CryptoNewsArticle) -> Bool {
        bookmarkedArticleIDs.contains(article.id)
    }

    /// Load bookmarked IDs from UserDefaults
    private func loadBookmarks() {
        if let saved = UserDefaults.standard.array(forKey: bookmarksKey) as? [String] {
            bookmarkedArticleIDs = Set(saved)
        }
    }

    /// Save current bookmarked IDs to UserDefaults
    private func saveBookmarks() {
        let ids = Array(bookmarkedArticleIDs)
        UserDefaults.standard.set(ids, forKey: bookmarksKey)
    }
}
