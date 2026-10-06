//
//  ContentView.swift
//  PrestaProductSync
//
//  Created by J Trutzschler on 29/09/2026.
//

import SwiftUI

enum SidebarItem: String, Identifiable, CaseIterable {
    case products = "Products"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .products: return "list.bullet"
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
            case .settings:
                SettingsView(viewModel: settingsViewModel)
            case nil:
                Text("Select an item from the sidebar")
                    .foregroundStyle(.secondary)
            }
        } detail: {
            if let detailViewModel {
                ProductDetailView(viewModel: detailViewModel)
            } else {
                Text("Select a product to view details")
                    .foregroundStyle(.secondary)
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
    }
}

#Preview {
    ContentView()
}
