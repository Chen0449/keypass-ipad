import UIKit

/// 拼音候选条：横向滚动的一排候选词，点一下上屏。
final class CandidateBarView: UIView {

    var onPick: ((String) -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var words: [String] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    func update(_ newWords: [String]) {
        guard newWords != words else { return }
        words = newWords

        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, word) in newWords.enumerated() {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
            var container = AttributeContainer()
            container.font = UIFont.systemFont(ofSize: 16, weight: index == 0 ? .semibold : .regular)
            configuration.attributedTitle = AttributedString(word, attributes: container)
            button.configuration = configuration
            button.tintColor = .label
            button.backgroundColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.30, alpha: 1)
                    : UIColor.white
            }
            button.layer.cornerRadius = 6
            button.layer.cornerCurve = .continuous
            button.addAction(UIAction { [weak self] _ in
                self?.onPick?(word)
            }, for: .touchUpInside)
            button.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(button)
        }

        scrollView.setContentOffset(.zero, animated: false)
    }

    var hasWords: Bool { !words.isEmpty }
}
