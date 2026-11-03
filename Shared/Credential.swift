import Foundation

/// 一组账号密码条目。「名称」可自定义，用于在键盘里快速辨认。
struct Credential: Codable, Identifiable, Equatable {

    var id: UUID
    var title: String
    var username: String
    var password: String
    var note: String
    var updatedAt: Date

    init(id: UUID = UUID(),
         title: String = "",
         username: String = "",
         password: String = "",
         note: String = "",
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.note = note
        self.updatedAt = updatedAt
    }

    /// 列表里显示的主标题：自定义名称为空时退化成账号，再退化成「未命名」。
    var displayName: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle }
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUser.isEmpty { return trimmedUser }
        return "未命名"
    }

    /// 副标题：账号 · 备注
    var subtitle: String {
        var parts: [String] = []
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUser.isEmpty { parts.append(trimmedUser) }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNote.isEmpty { parts.append(trimmedNote) }
        return parts.joined(separator: " · ")
    }

    var isEmpty: Bool {
        title.isEmpty && username.isEmpty && password.isEmpty && note.isEmpty
    }
}
