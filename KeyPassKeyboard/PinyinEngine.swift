import Foundation

/// 内置拼音引擎（全拼，词级候选）。
///
/// 词库随扩展打包（`pinyin_dict.txt`，约 658 KB，20k 键 / 69k 词），
/// 懒加载 + 一行一字符串解析，占内存大约 3 MB —— 键盘扩展的内存上限只有 30~40 MB，
/// 所以这里刻意不建 `[String: [String]]` 大字典。
final class PinyinEngine {

    static let shared = PinyinEngine()

    private struct Row {
        let key: String       // 大写拼音串，音节用空格分隔，如 "NI HAO"
        let value: String     // 逗号分隔的候选词
    }

    private var rows: [Row] = []
    private var syllables: Set<String> = []
    /// 简拼索引：首字母串 → "词,词,词"（只收 2~3 音节的词，控制内存）
    private var initialsIndex: [String: String] = [:]
    private var loaded = false
    private let loadLock = NSLock()

    /// 后台预热：658 KB→1.1 MB 的词库解析约 100~200 ms，别卡在第一次按键上
    func warmUp() {
        loadIfNeeded()
    }

    private func loadIfNeeded() {
        loadLock.lock()
        defer { loadLock.unlock() }
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "pinyin_dict", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        var parsed: [Row] = []
        parsed.reserveCapacity(36000)
        var syllableSet = Set<String>()

        for line in text.split(separator: "\n") {
            guard let barIndex = line.firstIndex(of: "|") else { continue }
            let key = String(line[line.startIndex..<barIndex])
            let value = String(line[line.index(after: barIndex)...])
            guard !key.isEmpty, !value.isEmpty else { continue }
            parsed.append(Row(key: key, value: value))
            if !key.contains(" ") {
                syllableSet.insert(key.lowercased())
            }
        }

        rows = parsed
        syllables = syllableSet

        // 简拼索引单独一个文件（按词频排过序，避免字母序靠前的生僻词抢位）
        if let shortURL = Bundle.main.url(forResource: "pinyin_short", withExtension: "txt"),
           let shortText = try? String(contentsOf: shortURL, encoding: .utf8) {
            var table: [String: String] = [:]
            table.reserveCapacity(8000)
            for line in shortText.split(separator: "\n") {
                guard let barIndex = line.firstIndex(of: "|") else { continue }
                let abbr = String(line[line.startIndex..<barIndex]).lowercased()
                let value = String(line[line.index(after: barIndex)...])
                guard !abbr.isEmpty, !value.isEmpty else { continue }
                table[abbr] = value
            }
            initialsIndex = table
        }
    }

    /// 简拼候选："nh" → 你好 / 你会 …
    func shortCandidates(for input: String, limit: Int = 8) -> [String] {
        loadIfNeeded()
        guard input.count >= 2, input.allSatisfy({ $0.isASCII && $0.isLetter }) else { return [] }
        guard let raw = initialsIndex[input.lowercased()] else { return [] }

        var out: [String] = []
        var seen = Set<String>()
        for word in raw.split(separator: ",") {
            let text = String(word)
            if seen.insert(text).inserted { out.append(text) }
            if out.count >= limit { break }
        }
        return out
    }

    // MARK: - 切音节

    /// "nihao" → ["ni", "hao"]；切不出来返回 nil（拼音还没打完整）
    func split(_ input: String) -> [String]? {
        loadIfNeeded()
        let chars = Array(input.lowercased())
        guard !chars.isEmpty else { return nil }

        var result: [String] = []
        var index = 0
        while index < chars.count {
            var matched: String?
            var length = min(6, chars.count - index)
            while length >= 1 {
                let candidate = String(chars[index..<(index + length)])
                if syllables.contains(candidate) {
                    matched = candidate
                    break
                }
                length -= 1
            }
            guard let piece = matched else { return nil }
            result.append(piece)
            index += piece.count
        }
        return result
    }

    // MARK: - 候选词

    /// 依输入串给出候选词，最多 `limit` 个。全拼优先，全拼不通时退回简拼。
    func candidates(for input: String, limit: Int = 24) -> [String] {
        loadIfNeeded()
        guard !input.isEmpty,
              input.allSatisfy({ $0.isASCII && $0.isLetter }) else { return [] }

        var collected: [String] = []
        var seen = Set<String>()

        if let parts = split(input) {
            let key = parts.joined(separator: " ").uppercased()
            if let start = lowerBound(of: key) {
                var index = start
                while index < rows.count, collected.count < limit {
                    let row = rows[index]
                    guard row.key == key || row.key.hasPrefix(key + " ") else { break }
                    for word in row.value.split(separator: ",") {
                        let text = String(word)
                        if seen.insert(text).inserted {
                            collected.append(text)
                        }
                        if collected.count >= limit { break }
                    }
                    index += 1
                }
            }
        }

        // 简拼兜底（"nh" → 你好）；全拼已经出词时只补到 limit
        if collected.count < 8 {
            for word in shortCandidates(for: input, limit: limit) {
                guard collected.count < limit else { break }
                if seen.insert(word).inserted {
                    collected.append(word)
                }
            }
        }

        return collected
    }

    /// 首个候选（空格 / 换行时上屏用）
    func firstCandidate(for input: String) -> String? {
        candidates(for: input, limit: 1).first
    }

    // MARK: - 二分

    private func lowerBound(of key: String) -> Int? {
        guard !rows.isEmpty else { return nil }
        if key <= rows[0].key { return 0 }
        if key > rows[rows.count - 1].key { return nil }

        var low = 0
        var high = rows.count - 1
        while low < high {
            let mid = (low + high) / 2
            if rows[mid].key < key {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}
