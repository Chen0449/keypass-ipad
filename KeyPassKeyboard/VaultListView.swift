import UIKit

/// 密码库列表页：点「账号 / 密码」直接往当前输入框里打字，⋯ 里放复制、编辑、删除。
final class VaultListView: UIView, UITableViewDataSource, UITableViewDelegate {

    var onFillUsername: ((Credential) -> Void)?
    var onFillPassword: ((Credential) -> Void)?
    var onEdit: ((Credential) -> Void)?
    var onDelete: ((Credential) -> Void)?
    var onCopy: ((String) -> Void)?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private var items: [Credential] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reload(_ newItems: [Credential], notice: String? = nil) {
        items = newItems
        tableView.reloadData()

        if let notice = notice, !notice.isEmpty {
            emptyLabel.text = notice
            emptyLabel.isHidden = false
        } else {
            emptyLabel.text = "还没有条目 —— 点右上角 ＋ 新建一组"
            emptyLabel.isHidden = !items.isEmpty
        }
    }

    private func setup() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CredentialCell.self, forCellReuseIdentifier: CredentialCell.reuseID)
        tableView.rowHeight = 56
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        tableView.keyboardDismissMode = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)

        emptyLabel.text = "还没有条目 —— 点右上角 ＋ 新建一组"
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CredentialCell.reuseID, for: indexPath)
        guard let cell = cell as? CredentialCell else { return cell }
        guard indexPath.row < items.count else { return cell }

        let item = items[indexPath.row]
        cell.configure(with: item)
        cell.onFillUsername = { [weak self] in self?.onFillUsername?(item) }
        cell.onFillPassword = { [weak self] in self?.onFillPassword?(item) }
        cell.onCopyUsername = { [weak self] in self?.onCopy?(item.username) }
        cell.onCopyPassword = { [weak self] in self?.onCopy?(item.password) }
        cell.onEdit = { [weak self] in self?.onEdit?(item) }
        cell.onDelete = { [weak self] in self?.onDelete?(item) }
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        guard indexPath.row < items.count else { return nil }
        let item = items[indexPath.row]
        let action = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            self?.onDelete?(item)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [action])
    }
}

// MARK: - 单元格

final class CredentialCell: UITableViewCell {

    static let reuseID = "CredentialCell"

    var onFillUsername: (() -> Void)?
    var onFillPassword: (() -> Void)?
    var onCopyUsername: (() -> Void)?
    var onCopyPassword: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    private let nameLabel = UILabel()
    private let subLabel = UILabel()
    private let userButton = UIButton(type: .system)
    private let passButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onFillUsername = nil
        onFillPassword = nil
        onCopyUsername = nil
        onCopyPassword = nil
        onEdit = nil
        onDelete = nil
    }

    func configure(with item: Credential) {
        nameLabel.text = item.displayName
        subLabel.text = item.subtitle
        subLabel.isHidden = item.subtitle.isEmpty
        rebuildMenu()
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none

        nameLabel.font = .systemFont(ofSize: 15, weight: .medium)
        nameLabel.textColor = .label
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        subLabel.font = .systemFont(ofSize: 11)
        subLabel.textColor = .secondaryLabel
        subLabel.lineBreakMode = .byTruncatingTail
        subLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        configureSmallButton(userButton, title: "账号", tint: .systemBlue)
        configureSmallButton(passButton, title: "密码", tint: .systemBlue)
        configureSmallButton(moreButton, title: "⋯", tint: .secondaryLabel)

        userButton.addAction(UIAction { [weak self] _ in self?.onFillUsername?() }, for: .touchUpInside)
        passButton.addAction(UIAction { [weak self] _ in self?.onFillPassword?() }, for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, subLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .fill

        let row = UIStackView(arrangedSubviews: [textStack, userButton, passButton, moreButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            userButton.widthAnchor.constraint(equalToConstant: 52),
            passButton.widthAnchor.constraint(equalToConstant: 52),
            moreButton.widthAnchor.constraint(equalToConstant: 30),
            userButton.heightAnchor.constraint(equalToConstant: 30),
            passButton.heightAnchor.constraint(equalToConstant: 30),
            moreButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func configureSmallButton(_ button: UIButton, title: String, tint: UIColor) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(tint, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.backgroundColor = tint.withAlphaComponent(0.12)
        button.layer.cornerRadius = 6
        button.layer.cornerCurve = .continuous
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func rebuildMenu() {
        let copyUser = UIAction(title: "复制账号", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
            self?.onCopyUsername?()
        }
        let copyPass = UIAction(title: "复制密码", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
            self?.onCopyPassword?()
        }
        let edit = UIAction(title: "编辑", image: UIImage(systemName: "square.and.pencil")) { [weak self] _ in
            self?.onEdit?()
        }
        let delete = UIAction(title: "删除", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            self?.onDelete?()
        }
        moreButton.menu = UIMenu(children: [copyUser, copyPass, edit, delete])
        moreButton.showsMenuAsPrimaryAction = true
    }
}
