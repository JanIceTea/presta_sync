import SwiftUI

struct ProductListView: View {
    @Bindable var viewModel: ProductListViewModel
    @Binding var selectedProductId: Int?
    @State private var expandedProducts: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.errorMessage = nil
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
                .background(.red.opacity(0.1))
            }

            if viewModel.products.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Products",
                    systemImage: "cart",
                    description: Text("Fetch products from your PrestaShop store using the toolbar button.")
                )
            } else {
                List {
                    ForEach(viewModel.filteredProducts) { product in
                        productRow(product)
                    }
                }
                .overlay(alignment: .bottom) {
                    statusBar
                }
            }
        }
        .navigationTitle("Products")
        .searchable(text: $viewModel.searchText, prompt: "Filter products...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task { await viewModel.fetchProducts() }
                } label: {
                    Label("Fetch Products", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)

                Button {
                    viewModel.saveJSON()
                } label: {
                    Label("Save JSON", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.products.isEmpty)
            }
        }
    }

    // MARK: - Product Row

    @ViewBuilder
    private func productRow(_ product: Product) -> some View {
        let isSelected = selectedProductId == product.id

        if product.combinations.isEmpty {
            HStack {
                Text(product.name)
                    .font(.headline)
                Spacer()
                Text(formatPrice(product.price))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                actionButtons(for: product)
            }
            .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : nil)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack {
                        Image(systemName: expandedProducts.contains(product.id) ? "chevron.down" : "chevron.right")
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        VStack(alignment: .leading) {
                            Text(product.name)
                                .font(.headline)
                            Text("\(product.combinations.count) combinations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatPrice(product.price))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedProducts.contains(product.id) {
                                expandedProducts.remove(product.id)
                            } else {
                                expandedProducts.insert(product.id)
                            }
                        }
                    }

                    actionButtons(for: product)
                }

                if expandedProducts.contains(product.id) {
                    ForEach(product.combinations) { combination in
                        Divider()
                        HStack {
                            Text(combination.name)
                                .font(.subheadline)
                            Spacer()
                            Text(formatPrice(combination.price))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Button(role: .destructive) {
                                viewModel.removeCombination(productId: product.id, combinationId: combination.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.leading, 24)
                        .padding(.vertical, 4)
                    }
                }
            }
            .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : nil)
            .contextMenu {
                Button(role: .destructive) {
                    viewModel.removeProduct(id: product.id)
                } label: {
                    Label("Remove Product", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(for product: Product) -> some View {
        HStack(spacing: 4) {
            Button {
                selectedProductId = product.id
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                viewModel.removeProduct(id: product.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Text("\(viewModel.productCount) products")
            Text("·")
            Text("\(viewModel.combinationCount) combinations")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func formatPrice(_ price: Double) -> String {
        String(format: "%.2f", price)
    }
}
