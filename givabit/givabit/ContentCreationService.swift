import Foundation

// MARK: - Content Creation Service Error
enum ContentCreationError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case encodingError(Error)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server endpoint URL is invalid."
        case .networkError(let error):
            return "A network error occurred: \(error.localizedDescription)"
        case .httpError(let statusCode, _):
            return "The server responded with an HTTP error: \(statusCode)."
        case .decodingError(let error):
            return "Failed to decode the server response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode the request data: \(error.localizedDescription)"
        case .unknownError:
            return "An unknown error occurred."
        }
    }
}

// MARK: - Content Creation Service
class ContentCreationService {
    // Define the endpoint URL directly or make it configurable
    private let createLinkURLString = "https://givabit-server-krlus.ondigitalocean.app/create-gated-link"

    func createLink(requestData: CreateContentRequest, completion: @escaping (Result<Void, ContentCreationError>) -> Void) {
        guard let url = URL(string: createLinkURLString) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(requestData)
            request.httpBody = jsonData
            
            // For debugging: Print the JSON body being sent
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Sending JSON to \(createLinkURLString): \(jsonString)")
            }
            
        } catch {
            completion(.failure(.encodingError(error)))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unknownError))
                return
            }

            // Check for successful HTTP status codes (e.g., 200 OK, 201 Created)
            // Adjust the range if your API uses different success codes.
            if (200...299).contains(httpResponse.statusCode) {
                // Assuming successful creation doesn't necessarily return a body or we don't need to decode it.
                // If the server sends back data (e.g., the created link object), you would decode it here.
                print("Content created successfully. Status Code: \(httpResponse.statusCode)")
                completion(.success(()))
            } else {
                // HTTP error
                print("HTTP Error: \(httpResponse.statusCode)")
                if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                    print("Error Response Body: \(responseString)")
                }
                completion(.failure(.httpError(statusCode: httpResponse.statusCode, data: data)))
            }
        }.resume()
    }
} 