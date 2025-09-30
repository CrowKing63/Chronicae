import Foundation

struct VisionWebAppAsset {
    let contentType: String
    let base64: String
    let hash: String

    var data: Data? {
        Data(base64Encoded: base64)
    }

    var string: String? {
        guard let data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum VisionWebApp {
    static var generatedAt: String? {
        VisionWebAppGenerated.generatedAt
    }

    static var buildFingerprint: String? {
        VisionWebAppGenerated.buildFingerprint
    }

    static var indexHTML: String {
        assetString(forNormalizedPath: "index.html") ?? fallbackHTML
    }

    static var html: String {
        indexHTML
    }

    static func response(for requestPath: String) -> HTTPResponse {
        let normalized = normalize(requestPath)
        if let asset = asset(forNormalizedPath: normalized), let data = asset.data {
            var headers = ["Content-Type": asset.contentType]
            headers["Cache-Control"] = cacheControl(for: normalized)
            headers["ETag"] = "\"\(asset.hash)\""
            if let generatedAt {
                headers["Last-Modified"] = generatedAt
            }
            return HTTPResponse(statusCode: 200,
                                reasonPhrase: "OK",
                                headers: headers,
                                body: data)
        }

        if normalized == "index.html" {
            return HTTPResponse.text(fallbackHTML, contentType: "text/html; charset=utf-8")
        }

        return HTTPResponse.notFound()
    }

    private static func normalize(_ requestPath: String) -> String {
        let pathComponent: Substring
        if let questionIndex = requestPath.firstIndex(of: "?") {
            pathComponent = requestPath[..<questionIndex]
        } else {
            pathComponent = Substring(requestPath)
        }

        guard pathComponent.hasPrefix("/web-app") else {
            let trimmed = pathComponent.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return trimmed.isEmpty ? "index.html" : trimmed
        }

        let suffix = pathComponent.dropFirst("/web-app".count)
        let normalized = suffix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalized.isEmpty ? "index.html" : normalized
    }

    private static func asset(forNormalizedPath path: String) -> VisionWebAppAsset? {
        VisionWebAppGenerated.assets[path]
    }

    private static func assetString(forNormalizedPath path: String) -> String? {
        guard let asset = asset(forNormalizedPath: path) else { return nil }
        return asset.string
    }

    private static func cacheControl(for path: String) -> String {
        switch path {
        case "index.html", "precache-manifest.json", "sw.js":
            return "no-cache, no-store, must-revalidate"
        default:
            return "public, max-age=31536000, immutable"
        }
    }

    private static let fallbackHTML = """
    <!DOCTYPE html>
    <html lang=\"ko\">
    <head>
        <meta charset=\"utf-8\" />
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
        <title>Chronicae Web</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 48px; }
        main { max-width: 640px; margin: 0 auto; }
        h1 { font-size: 2.2rem; }
        code { background: #f2f4ff; padding: 2px 6px; border-radius: 6px; }
        </style>
    </head>
    <body>
        <main>
            <h1>Chronicae Vision Web</h1>
            <p>전용 SPA 번들이 아직 임베드되지 않았습니다.</p>
            <ol>
                <li><code>cd vision-spa</code></li>
                <li><code>npm install</code></li>
                <li><code>npm run build && npm run embed</code></li>
            </ol>
            <p>위 작업 후 앱을 다시 실행하면 최신 SPA가 로드됩니다.</p>
        </main>
    </body>
    </html>
    """

    private static let fallbackCSS = "body { margin: 0; }"

    private static let fallbackJS = "console.warn('SPA 빌드가 필요합니다. vision-spa/README.md를 확인하세요.');"
}
