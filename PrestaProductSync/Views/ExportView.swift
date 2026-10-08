import SwiftUI

struct ExportView: View {
    var products: [Product]
    @Bindable var viewModel: ExportViewModel

    var body: some View {
        Group {
            if products.isEmpty {
                ContentUnavailableView(
                    "No Products Loaded",
                    systemImage: "tray",
                    description: Text("Fetch products from the Products tab first.")
                )
            } else {
                List {
                    ForEach(products) { product in
                        Toggle(isOn: Binding(
                            get: { viewModel.isSelected(product) },
                            set: { _ in viewModel.toggle(product) }
                        )) {
                            HStack {
                                Text(product.name)
                                Spacer()
                                Text("ID: \(product.id)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                        .disabled(viewModel.isExporting)
                    }
                }
            }
        }
        .navigationTitle("Export Products")
        .toolbar {
            ToolbarItemGroup {
                if !products.isEmpty {
                    Button("Select All") {
                        viewModel.selectAll(from: products)
                    }
                    .disabled(viewModel.isExporting)

                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                    .disabled(viewModel.isExporting)

                    Text("\(viewModel.selectedProductIds.count)/\(products.count) selected")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Button {
                        Task { await viewModel.exportMarkdown(products: products) }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.selectedProductIds.isEmpty || viewModel.isExporting)
                }
            }
        }
        .overlay {
            if viewModel.isExporting, let progress = viewModel.exportProgress {
                VStack(spacing: 12) {
                    ProgressView(
                        "Exporting \(progress.current)/\(progress.total)...",
                        value: Double(progress.current),
                        total: Double(progress.total)
                    )
                    .progressViewStyle(.linear)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 300)
            }
        }
        .alert("Export Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
