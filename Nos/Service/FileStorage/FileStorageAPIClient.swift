import Dependencies
import Foundation
import Logger

/// A client for a File Storage API, as defined in [NIP-96](https://github.com/nostr-protocol/nips/blob/master/96.md)
protocol FileStorageAPIClient {
    /// Fetches and caches server info for the file storage API.
    func refreshServerInfo()

    /// Uploads the file at the given URL.
    func upload(fileAt fileURL: URL) async throws -> URL
}

enum HTTPMethod: String {
    case delete = "DELETE"
    case post = "POST"
}

/// Defines a set of errors that may be thrown from a `FileStorageAPIClient`.
enum FileStorageAPIClientError: Error {
    case invalidResponseURL(String)
    case decodingError
    case invalidURLRequest
    case uploadFailed(String)
}

/// A `FileStorageAPIClient` that uses nostr.build for uploading files.
class NostrBuildAPIClient: FileStorageAPIClient {
    /// The `URLSession` to fetch data from the API.
    @Dependency(\.urlSession) var urlSession

    @Dependency(\.currentUser) var currentUser

    /// The URL string used to get server info.
    private static let serverInfoURLString = "https://nostr.build/.well-known/nostr/nip96.json"

    /// Cached server info which contains the API URL for uploading files.
    var serverInfo: FileStorageServerInfoResponseJSON?

    /// The `JSONDecoder` to use for decoding responses from the API.
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: - FileStorageAPIClient protocol

    func refreshServerInfo() {
        Task {
            do {
                serverInfo = try await fetchServerInfo()
                Log.debug("Refreshed file storage server info cache with data: \(String(describing: serverInfo))")
            } catch {
                Log.debug("Error refreshing file storage server info cache: \(error)")
            }
        }
    }

    func upload(fileAt fileURL: URL) async throws -> URL {
        let (request, data) = try uploadRequest(fileAt: fileURL)
        let (responseData, _) = try await URLSession.shared.upload(for: request, from: data)

        let response = try decoder.decode(FileStorageUploadResponseJSON.self, from: responseData)
        guard let urlString = response.nip94Event?.urlString else {
            throw FileStorageAPIClientError.uploadFailed(response.message ?? String(describing: response))
        }
        guard let url = URL(string: urlString) else {
            throw FileStorageAPIClientError.invalidResponseURL(urlString)
        }
        
        return url
    }

    // MARK: - Internal

    /// Fetches server info from the file storage API.
    /// - Returns: the decoded JSON containing server info for the file storage API.
    func fetchServerInfo() async throws -> FileStorageServerInfoResponseJSON {
        guard let url = URL(string: Self.serverInfoURLString) else {
            throw FileStorageAPIClientError.invalidURLRequest
        }

        let urlRequest = URLRequest(url: url)
        let (responseData, _) = try await urlSession.data(for: urlRequest)
        do {
            return try decoder.decode(FileStorageServerInfoResponseJSON.self, from: responseData)
        } catch {
            throw FileStorageAPIClientError.decodingError
        }
    }

    func uploadRequest(fileAt fileURL: URL) throws -> (URLRequest, Data) {
        guard let apiUrl = serverInfo?.apiUrl,
            let uploadURL = URL(string: apiUrl) else {
            throw FileStorageAPIClientError.uploadFailed("Missing API URL")
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let filename = fileURL.lastPathComponent

        var header = ""
        header.append("\r\n--\(boundary)\r\n")
        header.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        header.append("Content-Type: image/jpg\r\n\r\n")

        var footer = ""
        footer.append("\r\n--\(boundary)--\r\n")

        guard let headerData = header.data(using: .utf8), 
            let footerData = footer.data(using: .utf8) else {
            throw FileStorageAPIClientError.uploadFailed("Encoding error")
        }

        let fileData = try Data(contentsOf: fileURL)

        var data = Data()
        data.append(headerData)
        data.append(fileData)
        data.append(footerData)

        guard let keyPair = currentUser.keyPair else {
            throw FileStorageAPIClientError.uploadFailed("missing key pair")
        }

        let authorizationHeader = try buildAuthorizationHeader(
            url: uploadURL,
            method: .post,
            payload: data,
            keyPair: keyPair
        )
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")

        return (request, data)
    }

    private func buildAuthorizationHeader(
        url: URL,
        method: HTTPMethod,
        payload: Data?,
        keyPair: KeyPair
    ) throws -> String {
        var tags = [
            ["method", method.rawValue],
            ["u", url.absoluteString],
        ]
        if let payload {
            tags.append(["payload", payload.sha256().toHexString()])
        }
        var jsonEvent = JSONEvent(
            pubKey: keyPair.publicKeyHex,
            kind: .auth,
            tags: tags,
            content: ""
        )
        try jsonEvent.sign(withKey: keyPair)
        let jsonObject = jsonEvent.dictionary
        let requestData = try JSONSerialization.data(withJSONObject: jsonObject)
        return "Nostr \(requestData.base64EncodedString())"
    }
}
