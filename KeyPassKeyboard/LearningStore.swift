import Foundation

/// 用户选词记忆：让候选排序越用越顺手。
///
/// 只记「拼音输入串 → 选过的词 → 次数」，存在 UserDefaults 里（很小的 JSON）。
/// 不记录正文内容，不联网。
final class LearningStore {

    static let shared = LearningStore()

    private let defaultsKey = "kp.learning"
    private let maxKeys = 800
    private var table: [String: [String: Int]] = [:]
    private var loaded = false

    func record(composer: String, word: String) {
        guard !composer.isEmpty, !word.isEmpty else { return }
        loadIfNeeded()
        var bucket = table[composer] ?? [:]
        bucket[word] = (bucket[word] ?? 0) + 1
        table[composer] = bucket

        if table.count > maxKeys {
            // 简单裁剪：丢掉计数最低的一批，避免无限膨胀
            let ranked = table.sorted { lhs, rhs in
                lhs.value.values.reduce(0, +) > rhs.value.values.reduce(0, +)
            }
            table = Dictionary(uniqueKeysWithValues: ranked.prefix(maxKeys).map { ($0.key, $0.value) })
        }
        persist()
    }

    /// 按学过的次数重排候选
    func rerank(_ candidates: [String], for composer: String) -> [String] {
        loadIfNeeded()
        guard let bucket = table[composer], !bucket.isEmpty else { return candidates }

        let origin = Dictionary(uniqueKeysWithValues: candidates.enumerated().map { ($1, $0) })
        return candidates.sorted { lhs, rhs in
            let leftScore = bucket[lhs] ?? 0
            let rightScore = bucket[rhs] ?? 0
            if leftScore != rightScore { return leftScore > rightScore }
            return (origin[lhs] ?? 0) < (origin[rhs] ?? 0)
        }
    }

    // MARK: - 持久化

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) else {
            return
        }
        table = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(table) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
