import Foundation

/// Heuristics that turn "node, PID 48211" into "Vite — frontend-admin".
enum DevDetector {
    static let devExecutables: Set<String> = [
        "node", "bun", "deno", "python", "python3", "ruby", "java", "dotnet", "php", "go",
        "postgres", "mysqld", "mongod", "redis-server", "memcached", "nginx", "caddy", "httpd",
        "com.docker.backend", "docker", "vpnkit-bridge", "esbuild", "hugo", "cargo", "air",
        "beam.smp", "rabbitmq-server", "minio", "ollama"
    ]

    /// Matched against the last path component of each argument, in order.
    static let frameworks: [(needle: String, name: String)] = [
        ("vite", "Vite"), ("next", "Next.js"), ("next-server", "Next.js"), ("nuxt", "Nuxt"), ("nuxi", "Nuxt"),
        ("astro", "Astro"), ("storybook", "Storybook"), ("webpack", "webpack"), ("react-scripts", "Create React App"),
        ("remix", "Remix"), ("expo", "Expo"), ("ng", "Angular"), ("svelte-kit", "SvelteKit"),
        ("nest", "NestJS"), ("nodemon", "nodemon"), ("tsx", "tsx"), ("json-server", "json-server"),
        ("strapi", "Strapi"), ("uvicorn", "Uvicorn"), ("gunicorn", "Gunicorn"), ("flask", "Flask"),
        ("manage.py", "Django"), ("rails", "Rails"), ("puma", "Puma"), ("artisan", "Laravel"),
        ("jekyll", "Jekyll"), ("http.server", "Python http.server"), ("wrangler", "Wrangler"),
        ("firebase", "Firebase Emulator"), ("supabase", "Supabase")
    ]

    static func classify(_ p: inout PortProcess) {
        p.kind = kind(of: p)
        p.projectHint = projectHint(of: p)
        p.displayName = friendlyName(of: p)
    }

    static func kind(of p: PortProcess) -> PortProcess.Kind {
        if devExecutables.contains(p.executableName.lowercased()) { return .dev }
        guard let path = p.executablePath else { return p.isCurrentUser ? .dev : .system }

        if path.hasPrefix("/System/") || path.hasPrefix("/usr/libexec/") || path.hasPrefix("/usr/sbin/")
            || path.hasPrefix("/Library/Apple/") { return .system }
        if path.contains("/bin/Debug/") || path.contains("/target/debug/") || path.contains("/target/release/")
            || path.hasPrefix("/opt/homebrew/") || path.hasPrefix("/usr/local/") { return .dev }
        if path.contains(".app/") { return .app }
        if path.hasPrefix(NSHomeDirectory()) { return .dev }
        return p.isCurrentUser ? .dev : .system
    }

    static func friendlyName(of p: PortProcess) -> String {
        let tokens = p.arguments.map { ($0 as NSString).lastPathComponent.lowercased() }
        for token in tokens {
            if let fw = frameworks.first(where: { token == $0.needle || token.hasPrefix($0.needle + ".") || token.hasPrefix($0.needle + " ") }) {
                return fw.name
            }
        }
        if p.executableName == "dotnet", let dll = p.arguments.first(where: { $0.hasSuffix(".dll") }) {
            return ((dll as NSString).lastPathComponent as NSString).deletingPathExtension
        }
        if let bundle = p.appBundlePath {
            return ((bundle as NSString).lastPathComponent as NSString).deletingPathExtension
        }
        return p.executableName
    }

    /// The project folder the server was started from, when the path or arguments reveal it.
    static func projectHint(of p: PortProcess) -> String? {
        let markers = ["/node_modules/", "/bin/Debug/", "/bin/Release/", "/target/debug/", "/target/release/", "/.venv/", "/vendor/"]
        let candidates = [p.executablePath].compactMap { $0 } + p.arguments
        for arg in candidates {
            for marker in markers {
                if let r = arg.range(of: marker) {
                    return (String(arg[..<r.lowerBound]) as NSString).lastPathComponent
                }
            }
        }
        return nil
    }
}
