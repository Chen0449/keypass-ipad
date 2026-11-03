import Foundation
import CryptoKit
import Security

/// 密码库持久化。
///
/// 存储位置：本扩展自己沙盒里的 `Library/Application Support/KeyPassVault/vault.bin`
///（不用 App Group —— 免费开发者证书 / 全能签重签拿不到该权限，见 README）。
///
/// 加密：AES-GCM，密钥优先放 Keychain；Keychain 不可用（侧载常见）时退化成
/// `vault.key` 文件，靠 iOS 数据保护（`.completeFileProtectionUnlessOpen`）在设备锁屏时加密。
///
/// 关键原则（Codex 审查 2026-11-04 指出）：
/// - **不把「读不到密钥」当成「没有密钥」**：已有 vault.bin 时绝不自动生成新密钥去覆盖旧密文
/// - **写盘失败要往上抛**：不能让界面显示"已保存"而磁盘上什么都没落
final class VaultStore {

    static let shared = VaultStore()

    /// 最近一次读/写失败的原因，界面可读。成功后清空。
    private(set) var problem: String?

    private let ioQueue = DispatchQueue(label: "com.yg.keypass.vault")
    private var cache: [Credential]?
    private var keyCache: SymmetricKey?

    private let folderName = "KeyPassVault"
    private let blobFileName = "vault.bin"
    private let keyFileName = "vault.key"
    private let keychainAccount = "vault.key"

    private lazy var folderURL: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(self.folderName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    private var blobURL: URL { folderURL.appendingPathComponent(blobFileName) }
    private var keyFileURL: URL { folderURL.appendingPathComponent(keyFileName) }
    private var blobExists: Bool { FileManager.default.fileExists(atPath: blobURL.path) }

    // MARK: - 对外接口

    func load() -> [Credential] {
        ioQueue.sync {
            problem = nil
            return loadUnlocked()
        }
    }

    /// 返回 false 表示没写进磁盘（此时内存缓存也不更新）。
    @discardableResult
    func saveAll(_ items: [Credential]) -> Bool {
        ioQueue.sync {
            problem = nil
            guard persist(items) else { return false }
            cache = items
            return true
        }
    }

    @discardableResult
    func insert(_ item: Credential) -> Bool {
        ioQueue.sync {
            problem = nil
            var items = loadUnlocked()
            items.append(item)
            guard persist(items) else { return false }
            cache = items
            return true
        }
    }

    @discardableResult
    func update(_ item: Credential) -> Bool {
        ioQueue.sync {
            problem = nil
            var items = loadUnlocked()
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item
            } else {
                items.append(item)
            }
            guard persist(items) else { return false }
            cache = items
            return true
        }
    }

    @discardableResult
    func remove(id: UUID) -> Bool {
        ioQueue.sync {
            problem = nil
            var items = loadUnlocked()
            items.removeAll { $0.id == id }
            guard persist(items) else { return false }
            cache = items
            return true
        }
    }

    // MARK: - 备份（剪贴板导出 / 导入）

    func exportJSON() -> String {
        let items = load()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    /// 返回 (新增, 覆盖)；nil 表示解析失败或写入失败（原因见 `problem`）。
    func importJSON(_ text: String) -> (added: Int, updated: Int)? {
        guard let data = text.data(using: .utf8) else {
            problem = "剪贴板里没有文本"
            return nil
        }

        var incoming: [Credential]?
        let isoDecoder = JSONDecoder()
        isoDecoder.dateDecodingStrategy = .iso8601
        incoming = try? isoDecoder.decode([Credential].self, from: data)
        if incoming == nil {
            incoming = try? JSONDecoder().decode([Credential].self, from: data)
        }
        guard let parsed = incoming, !parsed.isEmpty else {
            problem = "内容不是有效的备份 JSON"
            return nil
        }

        var current = load()
        var added = 0
        var updated = 0
        for item in parsed {
            if let index = current.firstIndex(where: { $0.id == item.id }) {
                current[index] = item
                updated += 1
            } else {
                current.append(item)
                added += 1
            }
        }
        guard saveAll(current) else { return nil }
        return (added, updated)
    }

    // MARK: - 读盘 / 写盘

    private func loadUnlocked() -> [Credential] {
        if let cached = cache { return cached }

        guard let blob = try? Data(contentsOf: blobURL), !blob.isEmpty else {
            cache = []
            return []
        }

        guard let key = loadKey(allowCreate: false) else {
            problem = "密钥读不出来（多半是重签后 Keychain 变了）。旧库没解密，也没有被覆盖 —— 先别再新建条目。"
            return []
        }

        guard let box = try? AES.GCM.SealedBox(combined: blob),
              let plain = try? AES.GCM.open(box, using: key) else {
            let moved = quarantine(blobURL)
            problem = moved
                ? "密码库解密失败，已隔离成 vault.bin.damaged-…（数据还在，别急）"
                : "密码库解密失败，隔离也没成功"
            cache = []
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var items = (try? decoder.decode([Credential].self, from: plain)) ?? []
        if items.isEmpty {
            items = (try? JSONDecoder().decode([Credential].self, from: plain)) ?? []
        }
        cache = items
        return items
    }

    private func persist(_ items: [Credential]) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let plain = try? encoder.encode(items) else {
            problem = "数据编码失败，没有写入"
            return false
        }

        guard let key = loadKey(allowCreate: !blobExists) else {
            // 已有旧密文却拿不到密钥 —— 绝不能生成新钥覆盖它
            return false
        }

        guard let sealed = try? AES.GCM.seal(plain, using: key), let blob = sealed.combined else {
            problem = "加密失败，没有写入"
            return false
        }

        do {
            try blob.write(to: blobURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            return true
        } catch {
            problem = "写入失败：\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    private func quarantine(_ url: URL) -> Bool {
        let stamp = Int(Date().timeIntervalSince1970)
        let broken = folderURL.appendingPathComponent("\(blobFileName).damaged-\(stamp)")
        do {
            try FileManager.default.moveItem(at: url, to: broken)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 密钥

    /// allowCreate = false 时，读不到就返回 nil（不生成新钥）。
    private func loadKey(allowCreate: Bool) -> SymmetricKey? {
        if let cached = keyCache { return cached }

        if let data = KeychainItem.read(account: keychainAccount), data.count == 32 {
            let key = SymmetricKey(data: data)
            keyCache = key
            return key
        }

        if let data = try? Data(contentsOf: keyFileURL), data.count == 32 {
            let key = SymmetricKey(data: data)
            keyCache = key
            return key
        }

        guard allowCreate else { return nil }

        var bytes = [UInt8](repeating: 0, count: 32)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            for index in 0..<bytes.count {
                bytes[index] = UInt8.random(in: 0...255)
            }
        }

        let data = Data(bytes)
        var stored = KeychainItem.write(data, account: keychainAccount)
        if !stored {
            do {
                try data.write(to: keyFileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
                stored = true
            } catch {
                problem = "密钥存不进 Keychain 也写不进文件：\(error.localizedDescription)"
                return nil
            }
        }

        let key = SymmetricKey(data: data)
        keyCache = key
        return key
    }
}
