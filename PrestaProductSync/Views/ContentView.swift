//
//  ContentView.swift
//  PrestaProductSync
//
//  Created by J Trutzschler on 29/09/2026.
//

import SwiftUI

enum SidebarItem: String, Identifiable, CaseIterable {
    case products = "Products"
    case blog = "Blog"
    case export = "Export"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .products: return "list.bullet"
        case .blog: return "doc.text"
        case .export: return "square.and.arrow.up"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: SidebarItem? = .products
    @State private var productListViewModel = ProductListViewModel()
    @State private var settingsViewModel = SettingsViewModel()
    @State private var selectedProductId: Int?
    @State private var detailViewModel: ProductDetailViewModel?
    @State private var exportViewModel = ExportViewModel()
    @State private var blogListViewModel = BlogListViewModel()
    @State private var selectedBlogPostId: String?
    @State private var blogDetailViewModel: BlogDetailViewModel?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 180)
        } content: {
            switch selectedItem {
            case .products:
                ProductListView(
                    viewModel: productListViewModel,
                    selectedProductId: $selectedProductId
                )
            case .blog:
                BlogListView(
                    viewModel: blogListViewModel,
                    selectedPostId: $selectedBlogPostId,
                    onCreatePost: {
                        selectedBlogPostId = nil
                        let vm = BlogDetailViewModel.newPost()
                        vm.onPostCreated = { newPost in
                            blogListViewModel.addPost(newPost)
                        }
                        blogDetailViewModel = vm
                    }
                )
            case .export:
                ExportView(
                    products: productListViewModel.products,
                    viewModel: exportViewModel
                )
            case .settings:
                SettingsView(viewModel: settingsViewModel)
            case nil:
                Text("Select an item from the sidebar")
                    .foregroundStyle(.secondary)
            }
        } detail: {
            switch selectedItem {
            case .blog:
                if let blogDetailViewModel {
                    BlogDetailView(viewModel: blogDetailViewModel)
                        .id(blogDetailViewModel.postId)
                } else {
                    Text("Select a blog post to view details")
                        .foregroundStyle(.secondary)
                }
            default:
                if let detailViewModel {
                    ProductDetailView(viewModel: detailViewModel)
                } else {
                    Text("Select a product to view details")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: selectedProductId) { _, newValue in
            if let productId = newValue,
               let product = productListViewModel.products.first(where: { $0.id == productId }) {
                let vm = ProductDetailViewModel(productId: productId, productName: product.name)
                detailViewModel = vm
                Task { await vm.loadDetail() }
            } else {
                detailViewModel = nil
            }
        }
        .onChange(of: selectedBlogPostId) { _, newValue in
            if let postId = newValue,
               let cachedPost = blogListViewModel.posts.first(where: { $0.id == postId }) {
                let vm = BlogDetailViewModel(postId: postId)
                vm.loadFromCached(cachedPost)
                blogDetailViewModel = vm
            } else {
                blogDetailViewModel = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
