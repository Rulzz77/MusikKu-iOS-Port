import Foundation

enum MusikKuErrorMessage {
    static func indonesianMessage(for error: Error, fallback: String) -> String {
        indonesianMessage(for: error, fallback: fallback, depth: 0)
    }

    private static func indonesianMessage(for error: Error, fallback: String, depth: Int) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed:
                return "Tidak dapat terhubung ke internet. Periksa koneksi lalu coba lagi."
            case .timedOut:
                return "Koneksi terlalu lama. Coba lagi."
            case .secureConnectionFailed, .serverCertificateUntrusted:
                return "Koneksi aman ke layanan musik gagal. Coba lagi nanti."
            case .badServerResponse, .cannotParseResponse, .cannotDecodeContentData:
                return "Layanan musik mengirim respons yang tidak dapat dibaca. Coba lagi nanti."
            default:
                break
            }
        }

        if error is DecodingError {
            return "Data katalog tidak dapat dibaca. Coba lagi nanti."
        }

        // AVPlayer and URL loading errors often wrap the underlying URLError.
        if depth < 2,
           let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
            return indonesianMessage(for: underlying, fallback: fallback, depth: depth + 1)
        }

        return fallback
    }
}
