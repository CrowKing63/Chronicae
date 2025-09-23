import Foundation

enum WebAssets {
    static let indexHTML: String = {
        return """
        <!DOCTYPE html>
        <html lang=\"ko\">
        <head>
            <meta charset=\"utf-8\" />
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
            <title>Chronicae</title>
            <link rel=\"stylesheet\" href=\"/static/style.css\" />
        </head>
        <body>
            <main class=\"container\">
                <section class=\"hero\">
                    <h1>Chronicae Server</h1>
                    <p>iMac에서 실행 중인 개인용 RAG 메모 서버</p>
                    <div class=\"status-card\">
                        <h2>서버 상태</h2>
                        <dl>
                            <div>
                                <dt>실행 상태</dt>
                                <dd id=\"status\">확인 중...</dd>
                            </div>
                            <div>
                                <dt>포트</dt>
                                <dd id=\"port\">-</dd>
                            </div>
                            <div>
                                <dt>업타임</dt>
                                <dd id=\"uptime\">-</dd>
                            </div>
                        </dl>
                        <button id=\"refresh\">새로고침</button>
                    </div>
                </section>
                <section class=\"links\">
                    <h2>빠른 실행</h2>
                    <ul>
                        <li><a href=\"/web-app\">Vision Pro 웹앱 열기</a></li>
                        <li><a href=\"/api/status\">API 상태(JSON)</a></li>
                        <li><a href=\"/docs\">API 문서 보기</a></li>
                    </ul>
                </section>
            </main>
            <script src=\"/static/app.js\"></script>
        </body>
        </html>
        """
    }()

    static let appJS: String = {
        return """
        async function fetchStatus() {
          try {
            const res = await fetch('/api/status');
            if (!res.ok) throw new Error('Failed to fetch');
            const data = await res.json();
            document.getElementById('status').textContent = data.state ?? 'unknown';
            document.getElementById('port').textContent = data.port ?? '-';
            document.getElementById('uptime').textContent = data.uptime ?? '-';
          } catch (error) {
            document.getElementById('status').textContent = '오류';
            console.error(error);
          }
        }

        document.getElementById('refresh').addEventListener('click', fetchStatus);
        fetchStatus();
        """
    }()

    static let styleCSS: String = {
        return """
        :root {
            color-scheme: dark light;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #0b0d10;
            color: #f0f4ff;
        }

        body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .container {
            width: min(720px, 90vw);
            display: grid;
            gap: 32px;
            padding: 48px;
            background: rgba(15, 18, 24, 0.92);
            border-radius: 24px;
            box-shadow: 0 24px 60px rgba(0, 0, 0, 0.35);
            backdrop-filter: blur(20px);
        }

        .hero h1 {
            font-size: 2.8rem;
            margin-bottom: 0.2rem;
        }

        .status-card {
            margin-top: 24px;
            padding: 24px;
            border-radius: 18px;
            background: rgba(32, 40, 52, 0.85);
            border: 1px solid rgba(82, 162, 255, 0.35);
        }

        .status-card dl {
            margin: 0;
            display: grid;
            gap: 16px;
        }

        .status-card dd {
            margin: 0;
            font-size: 1.2rem;
            font-weight: 600;
        }

        #refresh {
            margin-top: 16px;
            padding: 12px 18px;
            border: none;
            border-radius: 12px;
            background: linear-gradient(120deg, #4f9cff, #22d1ee);
            color: white;
            font-size: 1rem;
            cursor: pointer;
        }

        #refresh:hover {
            opacity: 0.85;
        }

        .links ul {
            list-style: none;
            margin: 0;
            padding: 0;
            display: grid;
            gap: 12px;
        }

        .links a {
            color: #8cc8ff;
            text-decoration: none;
        }

        .links a:hover {
            text-decoration: underline;
        }
        """
    }()
}
