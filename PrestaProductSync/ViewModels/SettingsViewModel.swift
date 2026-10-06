import Foundation
import Observation

enum ConnectionStatus: Equatable {
    case untested
    case testing
    case success
    case failure(String)
}

@Observable
@MainActor
final class SettingsViewModel {
    var shopURL: String = ""
    var clientID: String = ""
    var clientSecret: String = ""
    var connectionStatus: ConnectionStatus = .untested
    var isSaved = false

    private let apiService = PrestaShopAPIService()

    init() {
        loadFromKeychain()
    }

    func loadFromKeychain() {
        shopURL = KeychainService.retrieve(for: .shopURL) ?? ""
        clientID = KeychainService.retrieve(for: .clientID) ?? ""
        clientSecret = KeychainService.retrieve(for: .clientSecret) ?? ""
    }

    func save() {
        do {
            try KeychainService.save(shopURL, for: .shopURL)
            try KeychainService.save(clientID, for: .clientID)
            try KeychainService.save(clientSecret, for: .clientSecret)
            isSaved = true
            connectionStatus = .untested
        } catch {
            connectionStatus = .failure("Failed to save: \(error.localizedDescription)")
        }
    }

    func testConnection() async {
        connectionStatus = .testing

        do {
            try await apiService.testConnection()
            connectionStatus = .success
        } catch {
            connectionStatus = .failure(error.localizedDescription)
        }
    }

    var canTest: Bool {
        !shopURL.isEmpty && !clientID.isEmpty && !clientSecret.isEmpty
    }
}
