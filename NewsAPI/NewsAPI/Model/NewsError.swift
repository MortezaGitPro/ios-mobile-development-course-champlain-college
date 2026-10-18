import Foundation

/// Domain errors provide useful messages instead of exposing raw system errors.
enum NewsError: LocalizedError {
    case badURL
    case invalidResponse
    case apiKeyMissing
    case unsupportedCountry
    case unsupportedCategory
    case http(Int, server: String?)
    case api(String?)
    case decoding
    case network(URLError.Code)
    case storageRead
    case storageWrite

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "The news address could not be created."
        case .invalidResponse:
            return "The news service returned an unexpected response."
        case .apiKeyMissing:
            return "Add your NewsAPI key to Resources/Secrets.plist and build again."
        case .unsupportedCountry:
            return "This app uses the U.S. edition supported by NewsAPI top headlines."
        case .unsupportedCategory:
            return "Choose a supported news category in Settings."
        case .http(let status, let server):
            if status == 429 {
                return "NewsAPI's request limit has been reached. Please try again later."
            }
            if let server, !server.isEmpty {
                return "NewsAPI (HTTP \(status)): \(server)"
            }
            if status == 401 || status == 403 {
                return "NewsAPI rejected access. Check your API key and account permissions."
            }
            return "The news service returned HTTP \(status). Please try again later."
        case .api(let message):
            return message ?? "The news service could not process this request."
        case .decoding:
            return "The news data could not be read. Please try again later."
        case .network(let code):
            switch code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "Check your internet connection. You can still open saved articles."
            case .timedOut:
                return "The request took too long. Check your connection and try again."
            default:
                return "Could not connect to the news service. Please try again."
            }
        case .storageRead:
            return "The saved articles could not be read. Existing saved data has been kept."
        case .storageWrite:
            return "The article could not be saved on this device. Please try again."
        }
    }
}
