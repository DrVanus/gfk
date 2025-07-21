import SwiftUI

struct AllCryptoNewsView: View {
    @Binding var savedScrollID: String?
    @EnvironmentObject var vm: CryptoNewsFeedViewModel

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage {
            VStack(spacing: 16) {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await vm.loadAllNews() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            ScrollViewReader { proxy in
                List(vm.articles) { article in
                    NavigationLink(destination: NewsWebView(url: article.url)) {
                        HStack(alignment: .center, spacing: 12) {
                            AsyncImage(url: article.urlToImage) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 120, height: 70)
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure:
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFill()
                                        .foregroundColor(.gray)
                                        .background(Color.gray.opacity(0.2))
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: 120, height: 70)
                            .aspectRatio(16/9, contentMode: .fill)
                            .clipped()
                            .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(article.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                HStack(spacing: 8) {
                                    Text(article.sourceName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(article.relativeTime)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .id(article.id)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        savedScrollID = article.id
                    })
                    .buttonStyle(PlainButtonStyle())
                    .onAppear {
                        if article.id == vm.articles.last?.id {
                            Task { await vm.loadMoreNews() }
                        }
                    }
                }
                .onAppear {
                    if let id = savedScrollID {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
                .refreshable {
                    await vm.loadAllNews()
                }
                .listStyle(PlainListStyle())
                .onDisappear {
                    savedScrollID = vm.articles.first?.id
                }
            }
        }
    }

    var body: some View {
        content
            .navigationTitle("Crypto News")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: BookmarksView()
                        .environmentObject(vm)) {
                        Image(systemName: "bookmark")
                            .foregroundColor(.yellow)
                    }
                }
            }
            .onAppear {
                Task {
                    await vm.loadAllNews()
                }
            }
            .accentColor(.white)
    }
}

struct AllCryptoNewsView_Previews: PreviewProvider {
    @State static var previewID: String? = nil
    static var previews: some View {
        AllCryptoNewsView(savedScrollID: $previewID)
            .environmentObject(CryptoNewsFeedViewModel())
    }
}
