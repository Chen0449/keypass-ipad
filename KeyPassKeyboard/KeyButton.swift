import UIKit

final class KeyButton: UIButton {

    let keyDef: KeyDef

    init(keyDef: KeyDef) {
        self.keyDef = keyDef
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? pressedColor : idleColor
        }
    }

    private var idleColor: UIColor {
        switch keyDef.style {
        case .normal:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.44, alpha: 1)
                    : UIColor.white
            }
        case .special:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.28, alpha: 1)
                    : UIColor(red: 0.68, green: 0.71, blue: 0.76, alpha: 1)
            }
        case .accent:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.15, green: 0.31, blue: 0.53, alpha: 1)
                    : UIColor(red: 0.79, green: 0.88, blue: 1.0, alpha: 1)
            }
        }
    }

    private var pressedColor: UIColor {
        switch keyDef.style {
        case .normal:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.63, alpha: 1)
                    : UIColor(white: 0.85, alpha: 1)
            }
        case .special:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.42, alpha: 1)
                    : UIColor(red: 0.80, green: 0.83, blue: 0.87, alpha: 1)
            }
        case .accent:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.24, green: 0.45, blue: 0.72, alpha: 1)
                    : UIColor(red: 0.66, green: 0.80, blue: 1.0, alpha: 1)
            }
        }
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = true
        backgroundColor = idleColor
        setTitle(keyDef.title, for: .normal)
        setTitleColor(.label, for: .normal)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.5
        titleLabel?.lineBreakMode = .byClipping
        switch keyDef.style {
        case .normal:
            titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .regular)
        case .special:
            titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        case .accent:
            titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        }
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        accessibilityLabel = keyDef.title
    }
}
