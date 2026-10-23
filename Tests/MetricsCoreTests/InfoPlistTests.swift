import Foundation
import Testing

/// Ключи обновлятеля в Resources/Info.plist: ошибка в них молча отключает автообновления у всех пользователей.
@Suite struct InfoPlistTests {
    let plist: [String: Any] = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Info.plist")
        let data = try! Data(contentsOf: url)
        return try! PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
    }()

    @Test func updaterKeys() {
        #expect(plist["SUFeedURL"] as? String == "https://github.com/aesarva/ochre/releases/latest/download/appcast.xml")
        #expect(plist["SUEnableAutomaticChecks"] as? Bool == true)
        #expect(plist["SUScheduledCheckInterval"] as? Int == 86400)
        #expect((plist["SUPublicEDKey"] as? String)?.isEmpty == false)
    }
}
