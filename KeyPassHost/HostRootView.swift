import SwiftUI
import UIKit

/// 宿主 App 只负责「告诉你怎样把键盘开起来」。
///
/// 为什么不在这里管理条目：密码库存在键盘扩展自己的沙盒里，两个容器要互通必须有
/// App Group 权限，而免费开发者证书 / 全能签重签通常拿不到 —— 所以管理界面就做在键盘内部了。
struct HostRootView: View {

    private struct Step: Identifiable {
        let id: String
        let text: String
    }

    private let steps: [Step] = [
        Step(id: "1", text: "设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → 第三方键盘 → 选择「密码键盘」"),
        Step(id: "2", text: "在键盘列表里点开「密码键盘」，把「允许完全访问」打开。注意：密码库存在键盘自己的容器里，不需要这个权限；需要它的是复制、粘贴到剪贴板导出/导入"),
        Step(id: "3", text: "在任何输入框里长按左下角 🌐 → 选「密码键盘」；底部点「🔑 密码库」管理条目")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    stepList
                    HostVaultEditor()
                    limitCard
                    backupCard
                    settingsButton
                    footer
                }
                .padding(20)
            }
            .navigationTitle("密码键盘")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("自带密码库的 iPad 键盘")
                .font(.title3.weight(.semibold))
            Text("每组账号密码都能自定义名称。键盘里点「账号 / 密码」就把对应内容打进当前输入框，不用来回复制。")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 10) {
                    Text(step.id)
                        .font(.footnote.weight(.bold))
                        .frame(width: 20, height: 20)
                        .background(Color.accentColor.opacity(0.16))
                        .clipShape(Circle())
                    Text(step.text)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var limitCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("一条要提前知道的限制")
                .font(.subheadline.weight(.semibold))
            Text("系统把密码框（输入时显示圆点的那种）锁给自带键盘，任何第三方键盘都进不去，这是 iOS 的硬规则。所以实际用法是：账号点「账号」直接插入；密码点「密码」插到普通输入框，或者用该条目的「⋯ → 复制密码」再长按粘贴。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var backupCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("备份")
                .font(.subheadline.weight(.semibold))
            Text("数据保存在键盘扩展的沙盒里。删 App、换证书重装都会清空，所以请在键盘里点「⋯ → 导出到剪贴板」，把 JSON 贴进备忘录留一份。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var settingsButton: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack {
                Image(systemName: "keyboard")
                Text("打开本 App 的设置")
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }

    private var footer: some View {
        Text("本 App 不含任何网络请求，密码只在本机加密存储。")
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}

struct HostRootView_Previews: PreviewProvider {
    static var previews: some View {
        HostRootView()
    }
}
