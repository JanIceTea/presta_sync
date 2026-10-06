import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("PrestaShop Connection") {
                TextField("Shop URL", text: $viewModel.shopURL, prompt: Text("https://your-shop.com"))
                    .textContentType(.URL)
                    .autocorrectionDisabled()

                TextField("Client ID", text: $viewModel.clientID)
                    .autocorrectionDisabled()

                SecureField("Client Secret", text: $viewModel.clientSecret)
            }

            Section {
                HStack {
                    Button("Save") {
                        viewModel.save()
                    }

                    Button("Test Connection") {
                        Task {
                            await viewModel.testConnection()
                        }
                    }
                    .disabled(!viewModel.canTest)

                    Spacer()

                    connectionStatusView
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch viewModel.connectionStatus {
        case .untested:
            EmptyView()
        case .testing:
            ProgressView()
                .controlSize(.small)
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .help(message)
        }
    }
}
