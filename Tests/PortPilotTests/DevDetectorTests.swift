import XCTest
@testable import PortPilotCore

final class DevDetectorTests: XCTestCase {
    private func classify(_ exe: String, _ args: [String], cwd: String? = nil, currentUser: Bool = true) -> PortProcess {
        var p = PortProcess(pid: 42, command: (exe as NSString).lastPathComponent, user: currentUser ? NSUserName() : "root")
        p.executablePath = exe
        p.arguments = args
        p.workingDirectory = cwd
        p.isCurrentUser = currentUser
        DevDetector.classify(&p)
        return p
    }

    func testVite() {
        let p = classify("/opt/homebrew/bin/node", ["node", "/Users/dev/code/frontend-admin/node_modules/.bin/vite"])
        XCTAssertEqual(p.displayName, "Vite")
        XCTAssertEqual(p.projectHint, "frontend-admin")
        XCTAssertEqual(p.kind, .dev)
    }

    func testViteFromNpxCacheUsesWorkingDirectory() {
        let p = classify("/opt/homebrew/bin/node",
                         ["node", "/Users/dev/.npm/_npx/9ed06546b0653f96/node_modules/.bin/vite"],
                         cwd: "/Users/dev/code/landing")
        XCTAssertEqual(p.displayName, "Vite")
        XCTAssertEqual(p.projectHint, "landing")
    }

    func testNext() {
        let p = classify("/opt/homebrew/bin/node", ["node", "/Users/dev/web/shop/node_modules/.bin/next", "dev"])
        XCTAssertEqual(p.displayName, "Next.js")
        XCTAssertEqual(p.projectHint, "shop")
    }

    func testNextServerProcessTitle() {
        // Next.js rewrites its process title, so argv no longer contains a path.
        let p = classify("/opt/homebrew/bin/node", ["next-server (v14.2.3)"], cwd: "/Users/dev/web/shop")
        XCTAssertEqual(p.displayName, "Next.js")
        XCTAssertEqual(p.projectHint, "shop")
    }

    func testDotnetDll() {
        let p = classify("/usr/local/share/dotnet/dotnet", ["dotnet", "bin/Debug/net8.0/MyApi.dll"], cwd: "/Users/dev/src/MyApi")
        XCTAssertEqual(p.displayName, "MyApi")
        XCTAssertEqual(p.projectHint, "MyApi")
        XCTAssertEqual(p.kind, .dev)
    }

    func testDotnetAppHost() {
        let exe = "/Users/dev/src/service-scope/Api/bin/Debug/net8.0/Api"
        let p = classify(exe, [exe], cwd: "/Users/dev/src/service-scope/Api/bin/Debug/net8.0")
        XCTAssertEqual(p.displayName, "Api")
        XCTAssertEqual(p.projectHint, "Api")
        XCTAssertEqual(p.kind, .dev)
    }

    func testDjangoManagePy() {
        let p = classify("/opt/homebrew/bin/python3", ["python3", "manage.py", "runserver"], cwd: "/Users/dev/code/blog")
        XCTAssertEqual(p.displayName, "Django")
        XCTAssertEqual(p.projectHint, "blog")
    }

    func testMacApp() {
        let exe = "/Applications/Figma.app/Contents/MacOS/Figma"
        let p = classify(exe, [exe], cwd: "/")
        XCTAssertEqual(p.displayName, "Figma")
        XCTAssertNil(p.projectHint)
        XCTAssertEqual(p.kind, .app)
    }

    func testSystemBinary() {
        let p = classify("/usr/libexec/rapportd", ["/usr/libexec/rapportd"], cwd: "/")
        XCTAssertEqual(p.displayName, "rapportd")
        XCTAssertNil(p.projectHint)
        XCTAssertEqual(p.kind, .system)
    }

    func testOtherUserWithoutDetailsIsSystem() {
        var unknown = PortProcess(pid: 98, command: "mystery", user: "root")
        unknown.isCurrentUser = false
        DevDetector.classify(&unknown)
        XCTAssertEqual(unknown.kind, .system)
        XCTAssertEqual(unknown.displayName, "mystery")
    }
}

final class BundleNameTests: XCTestCase {
    func testXcodePythonIsPythonNotXcode() {
        var p = PortProcess(pid: 1, command: "Python", user: NSUserName())
        p.executablePath = "/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python"
        p.arguments = ["Python", "-m", "http.server", "8765"]
        DevDetector.classify(&p)
        XCTAssertEqual(p.appBundlePath?.hasSuffix("/Python.app"), true)
        XCTAssertEqual(p.displayName, "Python http.server")
        XCTAssertEqual(p.kind, .dev)
    }

    func testHelperAppUsesOuterBundle() {
        var p = PortProcess(pid: 1, command: "Code Helper", user: NSUserName())
        p.executablePath = "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)"
        DevDetector.classify(&p)
        XCTAssertEqual(p.displayName, "Visual Studio Code")
        XCTAssertEqual(p.kind, .app)
    }
}
