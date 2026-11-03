import SwiftUI
import UIKit

/// 用**系统键盘**录中文条目，然后一次性"复制全部"，
/// 回目标 App 的键盘里点「⋯ → 从剪贴板导入」。
///
/// 为什么要绕这一圈：键盘扩展里没有系统输入法可用（iOS 不给），
/// 而宿主 App 里是标准 TextField，系统中文键盘随便打，还不用付费证书的 App Group。
struct HostVaultEditor: View {

    @AppStorage("host.entries") private var storedJSON: String = "[]"

    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var note = ""
    @State private var status = ""

    private var entries: [Credential] {
        guard let data = storedJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([Credential].self, from: data) else { return [] }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("① 在这儿用中文录条目")
                .font(.subheadline.weight(.semibold))
            Text("这里用的是系统键盘，中文随便打。录好点「复制全部」，再回聊天/网页的输入框打开密码键盘 → 🔑 密码库 → ⋯ → 从剪贴板导入。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            inputRow("名称（可中文）", text: $title)
            inputRow("账号", text: $username)
            inputRow("密码", text: $password)
            inputRow("备注", text: $note)

            HStack(spacing: 10) {
                Button {
                    add()
                } label: {
                    Label("加入列表", systemImage: "plus.circle")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Button {
                    copyAll()
                } label: {
                    Label("复制全部 JSON", systemImage: "doc.on.doc")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }

            if entries.isEmpty {
                Text("列表还是空的")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entries) { entry in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.displayName).font(.footnote.weight(.medium))
                                if !entry.username.isEmpty {
                                    Text(entry.username).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                remove(entry)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        Divider()
                    }
                }
            }

            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func inputRow(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
        }
    }

    // MARK: - 动作

    private func add() {
        let entry = Credential(title: title, username: username, password: password, note: note)
        guard !entry.isEmpty else {
            status = "名称 / 账号 / 密码 至少填一个"
            return
        }
        var list = entries
        list.insert(entry, at: 0)
        persist(list)
        title = ""; username = ""; password = ""; note = ""
        status = "已加入，当前 \(list.count) 条"
    }

    private func remove(_ entry: Credential) {
        var list = entries
        list.removeAll { $0.id == entry.id }
        persist(list)
        status = "已删除，剩 \(list.count) 条"
    }

    private func copyAll() {
        var list = entries
        if list.isEmpty {
            let single = Credential(title: title, username: username, password: password, note: note)
            guard !single.isEmpty else {
                status = "列表是空的，先在下面填一条"
                return
            }
            list = [single]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(list), let text = String(data: data, encoding: .utf8) else {
            status = "编码失败"
            return
        }
        UIPasteboard.general.string = text
        status = "已复制 \(list.count) 条。去键盘里点 ⋯ → 从剪贴板导入"
    }

    private func persist(_ list: [Credential]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(list),
              let text = String(data: data, encoding: .utf8) else { return }
        storedJSON = text
    }
}
