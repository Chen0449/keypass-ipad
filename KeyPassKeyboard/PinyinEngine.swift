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
    private var loaded = false

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "pinyin_dict", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        var parsed: [Row] = []
        parsed.reserveCapacity(21000)
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

    /// 依输入串给出候选词，最多 `limit` 个。拼音不完整时返回空。
    func candidates(for input: String, limit: Int = 24) -> [String] {
        loadIfNeeded()
        guard !input.isEmpty,
              input.allSatisfy({ $0.isASCII && $0.isLetter }) else { return [] }
        guard let parts = split(input) else { return [] }

        let key = parts.joined(separator: " ").uppercased()
        guard let start = lowerBound(of: key) else { return [] }

        var collected: [String] = []
        var seen = Set<String>()

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
