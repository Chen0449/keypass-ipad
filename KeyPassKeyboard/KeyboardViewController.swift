import UIKit

/// 键盘扩展主控制器。
///
/// 布局（行高固定，总高由内容算出来，不留空白）：
///
///     view
///     ├── pageHost      ← 密码库页 / 编辑页的内容
///     ├── candidateBar  ← 拼音候选条（只在拼写中显示）
///     └── planeView     ← 键位面板（打字页 / 编辑页共用）
///
/// 中文：内置全拼引擎（`PinyinEngine`）。字母先进 composer，候选条出词，
/// 点词 / 空格 / 换行上屏。底行「中/英」切本键盘的中英模式，「🌐」切到系统键盘。
final class KeyboardViewController: UIInputViewController {

    private enum Page {
        case keys
        case vault
        case editor
    }

    private enum PersistKey {
        static let page = "kp.page"
        static let draft = "kp.draft"
        static let editing = "kp.editing"
        static let chinese = "kp.chinese"
    }

    private let store = VaultStore.shared
    private let pinyin = PinyinEngine.shared

    private var items: [Credential] = []
    private var editingID: UUID?

    private var page: Page = .keys {
        didSet { applyPage() }
    }

    private var planePage: KeyboardPage = .letters
    private var shiftOn = false

    private var chineseMode = true
    private var composer = ""

    private let pageHost = UIView()
    private let vaultContainer = UIView()
    private let editorContainer = UIView()

    private let candidateBar = CandidateBarView()
    private let planeView = KeyboardPlaneView()
    private let vaultView = VaultListView()
    private let editorView = EditorView()

    private let vaultTitleLabel = UILabel()
    private let editorTitleLabel = UILabel()

    private var heightConstraint: NSLayoutConstraint!
    private var planeHeightConstraint: NSLayoutConstraint!
    private var planeBottomConstraint: NSLayoutConstraint!
    private var candidateHeightConstraint: NSLayoutConstraint!
    private var titleRestoreWorkItem: DispatchWorkItem?

    // MARK: - 尺寸（照系统键盘的比例：行高固定，总高由行数算）

    private var rowHeight: CGFloat { view.bounds.width > 620 ? 50 : 44 }
    /// 6 上内边距 + 4 行 + 3 个 8pt 间隙 + 6 下内边距
    private var planeHeight: CGFloat { 12 + 4 * rowHeight + 24 }
    private var candidateBarHeight: CGFloat { 40 }
    private var editorFormHeight: CGFloat { 212 }

    private var showsCandidates: Bool {
        page != .vault && chineseMode && !composer.isEmpty
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.16, alpha: 1)
                : UIColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1)
        }

        if let saved = UserDefaults.standard.object(forKey: PersistKey.chinese) as? Bool {
            chineseMode = saved
        }

        buildLayout()
        bindActions()
        reloadVault()

        planePage = .letters
        shiftOn = false
        planeView.render(page: planePage, shift: shiftOn)

        // 先恢复上次的页面，再应用布局 —— 顺序反了会把刚恢复的页面覆盖成「打字页」
        restoreState()
        applyPage()

        // 后台把拼音词库读进内存，别让第一次按字母卡顿
        DispatchQueue.global(qos: .userInitiated).async {
            PinyinEngine.shared.warmUp()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadVault()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        applyLayout(animated: false)
    }

    // MARK: - 布局

    private func buildLayout() {
        pageHost.translatesAutoresizingMaskIntoConstraints = false
        pageHost.clipsToBounds = true
        view.addSubview(pageHost)

        candidateBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(candidateBar)

        planeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(planeView)

        heightConstraint = view.heightAnchor.constraint(equalToConstant: 252)
        heightConstraint.priority = UILayoutPriority(999)
        planeHeightConstraint = planeView.heightAnchor.constraint(equalToConstant: 212)
        planeHeightConstraint.priority = UILayoutPriority(999)
        candidateHeightConstraint = candidateBar.heightAnchor.constraint(equalToConstant: 0)
        candidateHeightConstraint.priority = UILayoutPriority(999)
        planeBottomConstraint = planeView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)

        NSLayoutConstraint.activate([
            heightConstraint,
            planeHeightConstraint,
            candidateHeightConstraint,
            planeBottomConstraint,

            pageHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageHost.topAnchor.constraint(equalTo: view.topAnchor),
            pageHost.bottomAnchor.constraint(equalTo: candidateBar.topAnchor),

            candidateBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            candidateBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            candidateBar.bottomAnchor.constraint(equalTo: planeView.topAnchor),

            planeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            planeView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        for container in [vaultContainer, editorContainer] {
            container.translatesAutoresizingMaskIntoConstraints = false
            pageHost.addSubview(container)
            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: pageHost.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: pageHost.trailingAnchor),
                container.topAnchor.constraint(equalTo: pageHost.topAnchor),
                container.bottomAnchor.constraint(equalTo: pageHost.bottomAnchor)
            ])
        }

        // 密码库页
        let backButton = makeBarButton(title: "⌨︎", action: #selector(backToKeys))
        let addButton = makeBarButton(title: "＋", action: #selector(addEntry))
        let backupButton = makeBarButton(title: "⋯", action: nil)
        backupButton.menu = makeBackupMenu()
        backupButton.showsMenuAsPrimaryAction = true

        let vaultBar = makeBar(titleLabel: vaultTitleLabel,
                               title: "密码库",
                               leftButton: backButton,
                               rightButtons: [addButton, backupButton])
        vaultContainer.addSubview(vaultBar)
        vaultView.translatesAutoresizingMaskIntoConstraints = false
        vaultContainer.addSubview(vaultView)
        NSLayoutConstraint.activate([
            vaultBar.topAnchor.constraint(equalTo: vaultContainer.topAnchor),
            vaultBar.leadingAnchor.constraint(equalTo: vaultContainer.leadingAnchor),
            vaultBar.trailingAnchor.constraint(equalTo: vaultContainer.trailingAnchor),
            vaultView.topAnchor.constraint(equalTo: vaultBar.bottomAnchor),
            vaultView.leadingAnchor.constraint(equalTo: vaultContainer.leadingAnchor),
            vaultView.trailingAnchor.constraint(equalTo: vaultContainer.trailingAnchor),
            vaultView.bottomAnchor.constraint(equalTo: vaultContainer.bottomAnchor)
        ])

        // 编辑页
        let cancelButton = makeBarButton(title: "取消", action: #selector(cancelEdit))
        let saveButton = makeBarButton(title: "保存", action: #selector(saveEntry))
        let editorBar = makeBar(titleLabel: editorTitleLabel,
                                title: "新建条目",
                                leftButton: cancelButton,
                                rightButtons: [saveButton])
        editorContainer.addSubview(editorBar)
        editorView.translatesAutoresizingMaskIntoConstraints = false
        editorContainer.addSubview(editorView)
        NSLayoutConstraint.activate([
            editorBar.topAnchor.constraint(equalTo: editorContainer.topAnchor),
            editorBar.leadingAnchor.constraint(equalTo: editorContainer.leadingAnchor),
            editorBar.trailingAnchor.constraint(equalTo: editorContainer.trailingAnchor),
            editorView.topAnchor.constraint(equalTo: editorBar.bottomAnchor),
            editorView.leadingAnchor.constraint(equalTo: editorContainer.leadingAnchor),
            editorView.trailingAnchor.constraint(equalTo: editorContainer.trailingAnchor),
            editorView.bottomAnchor.constraint(equalTo: editorContainer.bottomAnchor)
        ])
    }

    private func makeBar(titleLabel: UILabel,
                         title: String,
                         leftButton: UIButton,
                         rightButtons: [UIButton]) -> UIView {
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        leftButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(leftButton)
        bar.addSubview(titleLabel)

        var constraints: [NSLayoutConstraint] = [
            bar.heightAnchor.constraint(equalToConstant: 38),
            leftButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            leftButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
        ]

        var trailingAnchor = bar.trailingAnchor
        var trailingConstant: CGFloat = -10
        for button in rightButtons.reversed() {
            button.translatesAutoresizingMaskIntoConstraints = false
            bar.addSubview(button)
            constraints.append(button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: trailingConstant))
            constraints.append(button.centerYAnchor.constraint(equalTo: bar.centerYAnchor))
            trailingAnchor = button.leadingAnchor
            trailingConstant = -6
        }

        constraints.append(titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leftButton.trailingAnchor, constant: 8))
        if let leftmostRight = rightButtons.first {
            constraints.append(titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: leftmostRight.leadingAnchor, constant: -8))
        }

        NSLayoutConstraint.activate(constraints)
        return bar
    }

    private func makeBarButton(title: String, action: Selector?) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        if let action = action {
            button.addTarget(self, action: action, for: .touchUpInside)
        }
        return button
    }

    private func applyLayout(animated: Bool) {
        guard let heightConstraint = heightConstraint,
              let planeHeightConstraint = planeHeightConstraint,
              let candidateHeightConstraint = candidateHeightConstraint,
              let planeBottomConstraint = planeBottomConstraint else { return }

        let candidatesHeight = showsCandidates ? candidateBarHeight : 0
        let keyboardHeight = planeHeight + candidatesHeight

        let total: CGFloat
        switch page {
        case .keys:
            total = keyboardHeight
        case .vault:
            total = view.bounds.width > 620 ? 430 : 356
        case .editor:
            total = keyboardHeight + editorFormHeight
        }

        let planeValue = (page == .vault) ? 0 : planeHeight
        let bottomInset = -max(view.safeAreaInsets.bottom, 0)

        let changed = abs(heightConstraint.constant - total) > 0.5
            || abs(planeHeightConstraint.constant - planeValue) > 0.5
            || abs(candidateHeightConstraint.constant - candidatesHeight) > 0.5
            || abs(planeBottomConstraint.constant - bottomInset) > 0.5
        guard changed else { return }

        heightConstraint.constant = total
        planeHeightConstraint.constant = planeValue
        candidateHeightConstraint.constant = candidatesHeight
        planeBottomConstraint.constant = bottomInset

        if animated {
            UIView.animate(withDuration: 0.15) { self.view.layoutIfNeeded() }
        } else {
            view.setNeedsLayout()
        }
    }

    // MARK: - 备份菜单（剪贴板要「允许完全访问」）

    private func makeBackupMenu() -> UIMenu {
        let export = UIAction(title: "导出到剪贴板", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            self?.exportToClipboard()
        }
        let importer = UIAction(title: "从剪贴板导入", image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in
            self?.importFromClipboard()
        }
        return UIMenu(children: [export, importer])
    }

    private func exportToClipboard() {
        guard hasFullAccess else {
            showTemporaryTitle("导出需要「允许完全访问」")
            return
        }
        let json = store.exportJSON()
        UIPasteboard.general.string = json
        showTemporaryTitle("已复制 \(store.load().count) 条 JSON")
    }

    private func importFromClipboard() {
        guard hasFullAccess else {
            showTemporaryTitle("导入需要「允许完全访问」")
            return
        }
        guard let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showTemporaryTitle("剪贴板里没有文本")
            return
        }
        guard let result = store.importJSON(text) else {
            showTemporaryTitle(store.problem ?? "导入失败")
            return
        }
        reloadVault()
        showTemporaryTitle("导入：新增 \(result.added) · 覆盖 \(result.updated)")
    }

    private var normalVaultTitle: String {
        items.isEmpty ? "密码库" : "密码库（\(items.count)）"
    }

    private func showTemporaryTitle(_ text: String) {
        titleRestoreWorkItem?.cancel()
        vaultTitleLabel.text = text
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.vaultTitleLabel.text = self.normalVaultTitle
        }
        titleRestoreWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: item)
    }

    // MARK: - 绑定

    private func bindActions() {
        planeView.onAction = { [weak self] action in
            self?.handle(action)
        }
        candidateBar.onPick = { [weak self] word in
            self?.commit(word)
        }

        vaultView.onFillUsername = { [weak self] item in
            self?.insert(item.username)
        }
        vaultView.onFillPassword = { [weak self] item in
            self?.insert(item.password)
        }
        vaultView.onCopy = { [weak self] text in
            guard let self = self else { return }
            guard !text.isEmpty else { return }
            guard self.hasFullAccess else {
                self.showTemporaryTitle("复制需要「允许完全访问」")
                return
            }
            UIPasteboard.general.string = text
            self.showTemporaryTitle("已复制")
        }
        vaultView.onEdit = { [weak self] item in
            guard let self = self else { return }
            self.editingID = item.id
            self.editorTitleLabel.text = "编辑条目"
            self.editorView.load(item)
            self.page = .editor
        }
        vaultView.onDelete = { [weak self] item in
            guard let self = self else { return }
            if !self.store.remove(id: item.id) {
                self.showTemporaryTitle(self.store.problem ?? "删除失败")
            }
            self.reloadVault()
        }
    }

    // MARK: - 页面

    private func applyPage() {
        pageHost.isHidden = page == .keys
        planeView.isHidden = page == .vault
        candidateBar.isHidden = !showsCandidates
        vaultContainer.isHidden = page != .vault
        editorContainer.isHidden = page != .editor

        if page == .vault {
            composer = ""
            candidateBar.update([])
        }

        planeView.render(page: planePage, shift: shiftOn)
        applyLayout(animated: true)
        saveState()
    }

    private func reloadVault() {
        items = store.load()
        vaultView.reload(items, notice: store.problem)
        vaultTitleLabel.text = normalVaultTitle
    }

    // MARK: - 中文输入

    private func currentCandidates() -> [String] {
        guard chineseMode, !composer.isEmpty else { return [] }
        let base = pinyin.candidates(for: composer)
        return LearningStore.shared.rerank(base, for: composer)
    }

    private func refreshCandidates() {
        candidateBar.update(currentCandidates())
        candidateBar.isHidden = !showsCandidates
        applyLayout(animated: false)
    }

    private func commit(_ word: String) {
        guard !word.isEmpty else { return }
        if !composer.isEmpty {
            LearningStore.shared.record(composer: composer, word: word)
        }
        type(word)
        composer = ""
        candidateBar.update([])
        candidateBar.isHidden = true
        applyLayout(animated: false)
    }

    private func commitCurrent() {
        if let word = currentCandidates().first {
            commit(word)
            return
        }
        // 拼音不成立（比如就想打英文），原样上屏
        let raw = composer
        composer = ""
        candidateBar.update([])
        candidateBar.isHidden = true
        type(raw)
        applyLayout(animated: false)
    }

    private func toggleChinese() {
        chineseMode.toggle()
        UserDefaults.standard.set(chineseMode, forKey: PersistKey.chinese)
        if !chineseMode, !composer.isEmpty {
            commitCurrent()
        }
        refreshCandidates()
    }

    // MARK: - 按键

    private func handle(_ action: KeyAction) {
        switch action {
        case .text(let raw):
            let isLetter = raw.count == 1 && (raw.first?.isASCII ?? false) && (raw.first?.isLetter ?? false)
            if chineseMode, isLetter, page != .vault {
                composer.append(contentsOf: raw.lowercased())
                refreshCandidates()
            } else {
                type(raw)
                if shiftOn, isLetter {
                    shiftOn = false
                    planeView.render(page: planePage, shift: shiftOn)
                }
            }
        case .shift:
            shiftOn.toggle()
            planeView.render(page: planePage, shift: shiftOn)
        case .backspace:
            if !composer.isEmpty {
                composer.removeLast()
                refreshCandidates()
            } else {
                backspace()
            }
        case .space:
            if composer.isEmpty {
                type(" ")
            } else {
                commitCurrent()
            }
        case .newline:
            if !composer.isEmpty {
                commitCurrent()
            } else if page == .editor {
                editorView.focusNext()
            } else {
                type("\n")
            }
        case .letters:
            planePage = .letters
            shiftOn = false
            planeView.render(page: planePage, shift: shiftOn)
        case .numbers:
            planePage = .numbers
            shiftOn = false
            planeView.render(page: planePage, shift: shiftOn)
        case .symbols:
            planePage = .symbols
            shiftOn = false
            planeView.render(page: planePage, shift: shiftOn)
        case .nextInputMode:
            advanceToNextInputMode()
        case .toggleChinese:
            toggleChinese()
        case .toggleVault:
            if page == .vault {
                page = .keys
            } else {
                reloadVault()
                page = .vault
            }
        }

        if page == .editor {
            saveState()
        }
    }

    private func type(_ text: String) {
        if page == .editor {
            editorView.insertText(text)
        } else {
            textDocumentProxy.insertText(text)
        }
    }

    private func backspace() {
        if page == .editor {
            editorView.deleteBackward()
        } else {
            textDocumentProxy.deleteBackward()
        }
    }

    private func insert(_ text: String) {
        guard !text.isEmpty else { return }
        textDocumentProxy.insertText(text)
    }

    // MARK: - 状态续接（切到系统键盘时扩展会被卸载）

    private func saveState() {
        let defaults = UserDefaults.standard
        switch page {
        case .keys:
            defaults.set("keys", forKey: PersistKey.page)
            defaults.removeObject(forKey: PersistKey.draft)
            defaults.removeObject(forKey: PersistKey.editing)
        case .vault:
            defaults.set("vault", forKey: PersistKey.page)
            defaults.removeObject(forKey: PersistKey.draft)
            defaults.removeObject(forKey: PersistKey.editing)
        case .editor:
            defaults.set("editor", forKey: PersistKey.page)
            if let data = try? JSONEncoder().encode(editorView.currentDraft()) {
                defaults.set(data, forKey: PersistKey.draft)
            }
            defaults.set(editingID?.uuidString, forKey: PersistKey.editing)
        }
    }

    private func restoreState() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: PersistKey.page) ?? "keys"

        if saved == "editor",
           let data = defaults.data(forKey: PersistKey.draft),
           let draft = try? JSONDecoder().decode(Credential.self, from: data) {
            if let raw = defaults.string(forKey: PersistKey.editing), let id = UUID(uuidString: raw) {
                editingID = id
                editorTitleLabel.text = "编辑条目"
            } else {
                editingID = nil
                editorTitleLabel.text = "新建条目"
            }
            editorView.load(draft)
            page = .editor
        } else if saved == "vault" {
            reloadVault()
            page = .vault
        }
    }

    // MARK: - 动作

    @objc private func backToKeys() {
        page = .keys
    }

    @objc private func addEntry() {
        editingID = nil
        editorTitleLabel.text = "新建条目"
        editorView.load(nil)
        page = .editor
    }

    @objc private func cancelEdit() {
        editingID = nil
        page = .vault
    }

    @objc private func saveEntry() {
        var draft = editorView.currentDraft()
        guard !draft.isEmpty else { return }

        draft.updatedAt = Date()
        let succeeded: Bool
        if let editingID = editingID {
            draft.id = editingID
            succeeded = store.update(draft)
        } else {
            succeeded = store.insert(draft)
        }

        guard succeeded else {
            editorTitleLabel.text = "保存失败：\(store.problem ?? "磁盘写入失败")"
            return
        }

        self.editingID = nil
        reloadVault()
        page = .vault
    }
}
