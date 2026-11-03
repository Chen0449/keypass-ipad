import UIKit

/// 键盘扩展主控制器。
///
/// 布局（Codex 审查 2026-11-04 修正）：
///
///     view
///     ├── pageHost        ← 上半部分：密码库页 / 编辑页的内容
///     └── planeView       ← 键盘面板，**打字页和编辑页共用同一块**
///
/// 之前把键盘面板塞在 keysContainer 里，进编辑页一隐藏容器键盘就没了，编辑页根本没法输入。
/// 现在面板独立在底部，`pageHost` 占剩下的高度；进密码库页时把面板高度压到 0。
final class KeyboardViewController: UIInputViewController {

    private enum Page {
        case keys
        case vault
        case editor
    }

    private struct PageMetrics {
        let total: CGFloat
        let plane: CGFloat
    }

    private let store = VaultStore.shared
    private var items: [Credential] = []
    private var editingID: UUID?

    private var page: Page = .keys {
        didSet { applyPage(animated: true) }
    }

    private var planePage: KeyboardPage = .letters
    private var shiftOn = false

    private let pageHost = UIView()
    private let vaultContainer = UIView()
    private let editorContainer = UIView()

    private let planeView = KeyboardPlaneView()
    private let vaultView = VaultListView()
    private let editorView = EditorView()

    private let vaultTitleLabel = UILabel()
    private let editorTitleLabel = UILabel()

    private var heightConstraint: NSLayoutConstraint!
    private var planeHeightConstraint: NSLayoutConstraint!
    private var titleRestoreWorkItem: DispatchWorkItem?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.16, alpha: 1)
                : UIColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1)
        }

        buildLayout()
        bindActions()
        reloadVault()

        planePage = .letters
        shiftOn = false
        planeView.render(page: planePage, shift: shiftOn)

        applyPage(animated: false)
        updateHeight(animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadVault()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateHeight(animated: false)
    }

    // MARK: - 高度

    private var metrics: PageMetrics {
        let isWide = view.bounds.width > 620
        switch page {
        case .keys:
            let total: CGFloat = isWide ? 336 : 268
            return PageMetrics(total: total, plane: total)
        case .vault:
            return PageMetrics(total: isWide ? 430 : 356, plane: 0)
        case .editor:
            return PageMetrics(total: isWide ? 448 : 396, plane: isWide ? 176 : 168)
        }
    }

    private func updateHeight(animated: Bool) {
        guard let heightConstraint = heightConstraint, let planeHeightConstraint = planeHeightConstraint else { return }
        let target = metrics
        let heightChanged = abs(heightConstraint.constant - target.total) > 0.5
        let planeChanged = abs(planeHeightConstraint.constant - target.plane) > 0.5
        guard heightChanged || planeChanged else { return }

        heightConstraint.constant = target.total
        planeHeightConstraint.constant = target.plane

        if animated {
            UIView.animate(withDuration: 0.15) {
                self.view.layoutIfNeeded()
            }
        } else {
            view.setNeedsLayout()
        }
    }

    // MARK: - 布局

    private func buildLayout() {
        pageHost.translatesAutoresizingMaskIntoConstraints = false
        pageHost.clipsToBounds = true
        view.addSubview(pageHost)

        planeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(planeView)

        heightConstraint = view.heightAnchor.constraint(equalToConstant: 268)
        heightConstraint.priority = UILayoutPriority(999)
        planeHeightConstraint = planeView.heightAnchor.constraint(equalToConstant: 268)
        planeHeightConstraint.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            heightConstraint,
            planeHeightConstraint,

            pageHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageHost.topAnchor.constraint(equalTo: view.topAnchor),
            pageHost.bottomAnchor.constraint(equalTo: planeView.topAnchor),

            planeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            planeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            planeView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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

        // 密码库页：顶栏 + 列表
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

        // 编辑页：顶栏 + 表单（表单文字由下面那块共用键盘输入）
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

    // MARK: - 标题提示（到期后重新算，不用旧字符串覆盖）

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

    // MARK: - 页面切换

    private func applyPage(animated: Bool) {
        pageHost.isHidden = page == .keys
        planeView.isHidden = page == .vault
        vaultContainer.isHidden = page != .vault
        editorContainer.isHidden = page != .editor

        if page != .vault {
            planeView.render(page: planePage, shift: shiftOn)
        }
        updateHeight(animated: animated)
    }

    private func reloadVault() {
        items = store.load()
        vaultView.reload(items, notice: store.problem)
        vaultTitleLabel.text = normalVaultTitle
    }

    // MARK: - 按键处理

    private func handle(_ action: KeyAction) {
        switch action {
        case .text(let text):
            type(text)
            if shiftOn, page != .vault, text.count == 1, text.first?.isLetter == true {
                shiftOn = false
                planeView.render(page: planePage, shift: shiftOn)
            }
        case .shift:
            shiftOn.toggle()
            planeView.render(page: planePage, shift: shiftOn)
        case .backspace:
            backspace()
        case .space:
            type(" ")
        case .newline:
            if page == .editor {
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
        case .toggleVault:
            if page == .vault {
                page = .keys
            } else {
                reloadVault()
                page = .vault
            }
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
            // 落盘失败就别假装保存成功、别退出编辑页
            editorTitleLabel.text = "保存失败：\(store.problem ?? "磁盘写入失败")"
            return
        }

        self.editingID = nil
        reloadVault()
        page = .vault
    }
}
