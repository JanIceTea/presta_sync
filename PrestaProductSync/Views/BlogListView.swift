import SwiftUI

struct BlogListView: View {
    @Bindable var viewModel: BlogListViewModel
    @Binding var selectedPostId: String?
    var onCreatePost: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") { viewModel.errorMessage = nil }
                        .buttonStyle(.borderless)
                }
                .padding(8)
                .background(.red.opacity(0.1))
            }

            if viewModel.posts.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Blog Posts",
                    systemImage: "doc.text",
                    description: Text("Fetch blog posts using the toolbar button.")
                )
            } else {
                List(selection: $selectedPostId) {
                    ForEach(viewModel.filteredPosts) { post in
                        blogPostRow(post)
                            .tag(post.id)
                    }
                }
                .overlay(alignment: .bottom) { statusBar }
            }
        }
        .navigationTitle("Blog")
        .searchable(text: $viewModel.searchText, prompt: "Filter blog posts...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    onCreatePost()
                } label: {
                    Label("New Post", systemImage: "plus")
                }
                Button {
                    Task { await viewModel.fetchPosts() }
                } label: {
                    Label("Fetch Posts", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
    }

    @ViewBuilder
    private func blogPostRow(_ post: BlogPost) -> some View {
        let title = post.translations["en"]?.title
            ?? post.translations["de"]?.title
            ?? post.translations.values.first?.title
            ?? post.id

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(post.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if post.draft {
                        Text("DRAFT")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
            Spacer()
            Button(role: .destructive) {
                Task { await viewModel.deletePost(id: post.id) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private var statusBar: some View {
        HStack {
            Text("\(viewModel.posts.count) posts")
            if let date = viewModel.lastFetchedAt {
                Text("·")
                Text("Fetched \(date.formatted(.relative(presentation: .named)))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
