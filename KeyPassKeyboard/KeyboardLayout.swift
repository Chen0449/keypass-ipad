import UIKit

/// 按键动作
enum KeyAction: Equatable {
    case text(String)
    case shift
    case backspace
    case space
    case newline
    case letters
    case numbers
    case symbols
    case nextInputMode
    case toggleVault
}

enum KeyStyle {
    case normal
    case special
    case accent
}

struct KeyDef {
    let title: String
    let weight: CGFloat
    let style: KeyStyle
    let action: KeyAction
}

struct KeyRow {
    let keys: [KeyDef]
    /// 左右额外内缩（让 9 键那行窄一点，视觉上接近系统键盘）
    let sideInset: CGFloat
}

enum KeyboardPage {
    case letters
    case numbers
    case symbols
}

enum KeyboardLayouts {

    static func rows(page: KeyboardPage, shift: Bool) -> [KeyRow] {
        switch page {
        case .letters: return letterRows(shift: shift)
        case .numbers: return numberRows()
        case .symbols: return symbolRows()
        }
    }

    // MARK: - 字母页

    private static func letter(_ character: String, shift: Bool) -> KeyDef {
        let output = shift ? character.uppercased() : character
        return KeyDef(title: output, weight: 1, style: .normal, action: .text(output))
    }

    private static func letterRows(shift: Bool) -> [KeyRow] {
        let row1 = "qwertyuiop".map { letter(String($0), shift: shift) }
        let row2 = "asdfghjkl".map { letter(String($0), shift: shift) }

        var row3: [KeyDef] = [
            KeyDef(title: "⇧", weight: 1.45, style: shift ? .accent : .special, action: .shift)
        ]
        row3 += "zxcvbnm".map { letter(String($0), shift: shift) }
        row3.append(KeyDef(title: "⌫", weight: 1.45, style: .special, action: .backspace))

        return [
            KeyRow(keys: row1, sideInset: 0),
            KeyRow(keys: row2, sideInset: 16),
            KeyRow(keys: row3, sideInset: 0),
            KeyRow(keys: bottomRow(switchTitle: "123", switchAction: .numbers), sideInset: 0)
        ]
    }

    // MARK: - 数字页

    private static func numberRows() -> [KeyRow] {
        let row1 = "1234567890".map {
            KeyDef(title: String($0), weight: 1, style: .normal, action: .text(String($0)))
        }
        let row2 = ["-", "/", ":", ";", "(", ")", "¥", "&", "@", "\""].map {
            KeyDef(title: $0, weight: 1, style: .normal, action: .text($0))
        }
        let row3: [KeyDef] = [
            KeyDef(title: "#+=", weight: 1.5, style: .special, action: .symbols),
            KeyDef(title: ".", weight: 1, style: .normal, action: .text(".")),
            KeyDef(title: ",", weight: 1, style: .normal, action: .text(",")),
            KeyDef(title: "?", weight: 1, style: .normal, action: .text("?")),
            KeyDef(title: "!", weight: 1, style: .normal, action: .text("!")),
            KeyDef(title: "'", weight: 1, style: .normal, action: .text("'")),
            KeyDef(title: "⌫", weight: 1.5, style: .special, action: .backspace)
        ]
        return [
            KeyRow(keys: row1, sideInset: 0),
            KeyRow(keys: row2, sideInset: 0),
            KeyRow(keys: row3, sideInset: 0),
            KeyRow(keys: bottomRow(switchTitle: "ABC", switchAction: .letters), sideInset: 0)
        ]
    }

    // MARK: - 符号页

    private static func symbolRows() -> [KeyRow] {
        let row1 = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map {
            KeyDef(title: $0, weight: 1, style: .normal, action: .text($0))
        }
        let row2 = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"].map {
            KeyDef(title: $0, weight: 1, style: .normal, action: .text($0))
        }
        let row3: [KeyDef] = [
            KeyDef(title: "123", weight: 1.5, style: .special, action: .numbers),
            KeyDef(title: ".", weight: 1, style: .normal, action: .text(".")),
            KeyDef(title: ",", weight: 1, style: .normal, action: .text(",")),
            KeyDef(title: "?", weight: 1, style: .normal, action: .text("?")),
            KeyDef(title: "!", weight: 1, style: .normal, action: .text("!")),
            KeyDef(title: "'", weight: 1, style: .normal, action: .text("'")),
            KeyDef(title: "⌫", weight: 1.5, style: .special, action: .backspace)
        ]
        return [
            KeyRow(keys: row1, sideInset: 0),
            KeyRow(keys: row2, sideInset: 0),
            KeyRow(keys: row3, sideInset: 0),
            KeyRow(keys: bottomRow(switchTitle: "ABC", switchAction: .letters), sideInset: 0)
        ]
    }

    // MARK: - 公共底行

    private static func bottomRow(switchTitle: String, switchAction: KeyAction) -> [KeyDef] {
        [
            KeyDef(title: switchTitle, weight: 1.3, style: .special, action: switchAction),
            KeyDef(title: "🔑 密码库", weight: 2.1, style: .accent, action: .toggleVault),
            KeyDef(title: "空格", weight: 4.0, style: .normal, action: .space),
            // 明确写「中/英」而不是 🌐 图标：点一下切到系统键盘（系统中文拼音），再点切回来
            KeyDef(title: "中/英", weight: 1.5, style: .special, action: .nextInputMode),
            KeyDef(title: "换行", weight: 1.7, style: .special, action: .newline)
        ]
    }
}
