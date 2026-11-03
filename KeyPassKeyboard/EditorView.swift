import UIKit

/// 条目编辑页。整个键盘是自定义视图，所以表单里的文字也由自家键盘输入：
/// 点一下某个格子把它设为「当前输入目标」，之后按键盘就往里打字。
final class EditorView: UIView {

    enum Field: Int, CaseIterable {
        case title
        case username
        case password
        case note

        var caption: String {
            switch self {
            case .title: return "名称"
            case .username: return "账号"
            case .password: return "密码"
            case .note: return "备注"
            }
        }

        var placeholder: String {
            switch self {
            case .title: return "给这组起个名字，比如「学校教务」"
            case .username: return "点这里再打字"
            case .password: return "点这里再打字"
            case .note: return "可选"
            }
        }
    }

    private(set) var draft = Credential()
    private(set) var activeField: Field = .title

    private let formStack = UIStackView()
    private var boxes: [Field: UIView] = [:]
    private var valueLabels: [Field: UILabel] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        render()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 对外

    func load(_ credential: Credential?) {
        draft = credential ?? Credential()
        activeField = .title
        render()
    }

    func currentDraft() -> Credential {
        draft
    }

    func insertText(_ text: String) {
        setValue(value(for: activeField) + text, for: activeField)
        render()
    }

    func deleteBackward() {
        var value = value(for: activeField)
        guard !value.isEmpty else { return }
        value.removeLast()
        setValue(value, for: activeField)
        render()
    }

    /// 键盘上按「换行」时切到下一个格子，最后一格回到第一格。
    func focusNext() {
        let all = Field.allCases
        if let index = all.firstIndex(of: activeField), index + 1 < all.count {
            activeField = all[index + 1]
        } else {
            activeField = .title
        }
        render()
    }

    // MARK: - 取值

    private func value(for field: Field) -> String {
        switch field {
        case .title: return draft.title
        case .username: return draft.username
        case .password: return draft.password
        case .note: return draft.note
        }
    }

    private func setValue(_ value: String, for field: Field) {
        switch field {
        case .title: draft.title = value
        case .username: draft.username = value
        case .password: draft.password = value
        case .note: draft.note = value
        }
        draft.updatedAt = Date()
    }

    // MARK: - 构建

    private func setup() {
        formStack.axis = .vertical
        formStack.spacing = 8
        formStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(formStack)

        NSLayoutConstraint.activate([
            formStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            formStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            formStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            formStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8)
        ])

        for field in Field.allCases {
            let caption = UILabel()
            caption.text = field.caption
            caption.font = .systemFont(ofSize: 12, weight: .medium)
            caption.textColor = .secondaryLabel
            caption.textAlignment = .right
            caption.widthAnchor.constraint(equalToConstant: 34).isActive = true

            let box = UIView()
            box.tag = field.rawValue
            box.isUserInteractionEnabled = true
            box.layer.cornerRadius = 7
            box.layer.cornerCurve = .continuous
            box.layer.borderWidth = 1
            box.layer.borderColor = UIColor.separator.cgColor
            box.backgroundColor = .secondarySystemBackground
            box.heightAnchor.constraint(equalToConstant: 34).isActive = true
            box.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))

            let valueLabel = UILabel()
            valueLabel.font = .systemFont(ofSize: 15)
            valueLabel.lineBreakMode = .byTruncatingTail
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(valueLabel)
            NSLayoutConstraint.activate([
                valueLabel.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 8),
                valueLabel.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8),
                valueLabel.centerYAnchor.constraint(equalTo: box.centerYAnchor)
            ])

            let row = UIStackView(arrangedSubviews: [caption, box])
            row.axis = .horizontal
            row.spacing = 6
            row.alignment = .fill
            formStack.addArrangedSubview(row)

            boxes[field] = box
            valueLabels[field] = valueLabel
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let rawValue = gesture.view?.tag, let field = Field(rawValue: rawValue) else { return }
        activeField = field
        render()
    }

    private func render() {
        for field in Field.allCases {
            guard let box = boxes[field], let label = valueLabels[field] else { continue }
            let isActive = field == activeField
            box.layer.borderWidth = isActive ? 2 : 1
            box.layer.borderColor = isActive ? UIColor.systemBlue.cgColor : UIColor.separator.cgColor

            let value = value(for: field)
            if value.isEmpty {
                label.text = field.placeholder
                label.textColor = .tertiaryLabel
            } else {
                label.text = value
                label.textColor = .label
            }
        }
    }
}
