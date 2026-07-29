import Foundation

public struct CosensePageClient: Sendable {
    public init() {}

    public func exists(
        project: String,
        pageTitle: String,
        credential: CosenseCredential? = nil,
        cookies: [HTTPCookie] = []
    ) async -> Bool {
        guard let url = Self.APIURL(
            project: project,
            pageTitle: pageTitle
        ) else {
            return false
        }

        do {
            var request: URLRequest
            if cookies.isEmpty {
                request = credential?.authenticatedRequest(url: url)
                    ?? URLRequest(url: url)
            } else {
                request = URLRequest(url: url)
                request.httpShouldHandleCookies = false
                for (field, value) in HTTPCookie.requestHeaderFields(
                    with: cookies
                ) {
                    request.setValue(value, forHTTPHeaderField: field)
                }
            }
            let (data, response) = try await URLSession.shared.data(
                for: request
            )
            guard let HTTPResponse = response as? HTTPURLResponse else {
                return false
            }
            return (200..<300).contains(HTTPResponse.statusCode)
                && Self.responseRepresentsExistingPage(data)
        } catch {
            return false
        }
    }

    static func responseRepresentsExistingPage(_ data: Data) -> Bool {
        struct PageState: Decodable {
            let persistent: Bool?
            let commitId: String?
        }

        guard let state = try? JSONDecoder().decode(
            PageState.self,
            from: data
        ) else {
            return false
        }
        return state.persistent == true || state.commitId != nil
    }

    public static func APIURL(
        project: String,
        pageTitle: String
    ) -> URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        guard
            let encodedProject = project.addingPercentEncoding(
                withAllowedCharacters: allowed
            ),
            let encodedTitle = pageTitle.replacingOccurrences(
                of: " ",
                with: "_"
            )
            .addingPercentEncoding(withAllowedCharacters: allowed)
        else {
            return nil
        }

        return URL(
            string: "https://scrapbox.io/api/pages/\(encodedProject)/\(encodedTitle)"
        )
    }
}
