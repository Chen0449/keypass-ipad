import UIKit

/// 纯手写 frame 布局的键盘面板。
/// 用 UIStackView + Auto Layout 做「按权重分配宽度」容易在层叠压缩时走形，
/// 这里直接按权重算 frame，行为可预测。
final class KeyboardPlaneView: UIView {

    var onAction: ((KeyAction) -> Void)?

    private var page: KeyboardPage = .letters
    private var shiftOn: Bool = false
    private var rows: [KeyRow] = []
    private var buttons: [[KeyButton]] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        rebuild()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(page: KeyboardPage, shift: Bool) {
        self.page = page
        self.shiftOn = shift
        rebuild()
        setNeedsLayout()
    }

    private func rebuild() {
        for row in buttons {
            for button in row {
                button.removeFromSuperview()
            }
        }
        buttons.removeAll(keepingCapacity: true)

        rows = KeyboardLayouts.rows(page: page, shift: shiftOn)

        for row in rows {
            var rowButtons: [KeyButton] = []
            for def in row.keys {
                let button = KeyButton(keyDef: def)
                button.addAction(UIAction { [weak self] _ in
                    self?.onAction?(def.action)
                }, for: .touchUpInside)
                addSubview(button)
                rowButtons.append(button)
            }
            buttons.append(rowButtons)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !rows.isEmpty, rows.count == buttons.count else { return }

        let padX: CGFloat = 6
        // 底部要给 iPad 的手势条留位置，否则最后一行按键会被压到屏幕边缘外
        let padTop: CGFloat = 6
        let padBottom: CGFloat = 6 + max(safeAreaInsets.bottom, 0)
        let gapX: CGFloat = 6
        let gapY: CGFloat = 8

        let rowCount = CGFloat(rows.count)
        let availableHeight = bounds.height - padTop - padBottom - gapY * max(0, rowCount - 1)
        let rowHeight = max(26, availableHeight / max(1, rowCount))

        var y = padTop
        for (rowIndex, row) in rows.enumerated() {
            let rowButtons = buttons[rowIndex]
            guard rowButtons.count == row.keys.count else { continue }

            let usableWidth = bounds.width - padX * 2 - row.sideInset * 2
            let gaps = gapX * CGFloat(max(0, row.keys.count - 1))
            let keysWidth = max(0, usableWidth - gaps)
            let totalWeight = row.keys.reduce(CGFloat(0)) { $0 + $1.weight }

            var x = padX + row.sideInset
            for (keyIndex, def) in row.keys.enumerated() {
                let ratio = totalWeight > 0 ? def.weight / totalWeight : 0
                let width = keysWidth * ratio
                rowButtons[keyIndex].frame = CGRect(x: x, y: y, width: width, height: rowHeight).integral
                x += width + gapX
            }
            y += rowHeight + gapY
        }
    }
}
