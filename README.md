# KeyPass · 自带密码库的 iPad 键盘

一个 iOS 自定义键盘（Keyboard Extension）+ 宿主 App：

- 键盘里点「🔑 密码库」就能看到保存好的条目
- 每组账号密码都能**自定义名称**（名称留空时自动用账号当标题）
- 点「账号」/「密码」直接把内容 `insertText` 进当前输入框，不用来回复制粘贴
- 条目在键盘内部增删改，**不依赖 App Group**，免费证书 / 全能签重签也能用

> ⚠️ 诚实说明：这份代码是在 Windows 上写的，**没有经过 Xcode 编译验证**。
> 第一次必须先让 CI（或 Mac）编译一遍，把编译错误修掉再签名安装。见第 2 节。

---

## 1. 目录结构

```
keypass-ipad/
├── project.yml                    XcodeGen 工程描述（不手写 .xcodeproj）
├── Shared/                        宿主与键盘共用的模型与存储
│   ├── Credential.swift           条目模型（id / 名称 / 账号 / 密码 / 备注）
│   ├── VaultStore.swift           AES-GCM 加密的本地密码库
│   └── KeychainItem.swift         Keychain 读写（失败自动退化成受保护的密钥文件）
├── KeyPassKeyboard/               键盘扩展（主体）
│   ├── KeyboardViewController.swift   三页路由：打字 / 密码库 / 编辑
│   ├── KeyboardLayout.swift           字母 · 数字 · 符号三套布局数据
│   ├── KeyboardPlaneView.swift        手写 frame 的键盘面板
│   ├── KeyButton.swift                按键样式
│   ├── VaultListView.swift            密码库列表 + 单元格
│   └── EditorView.swift               条目编辑表单
├── KeyPassHost/                   宿主 App（只做引导页，见第 6 节）
├── scripts/build-unsigned.sh      Mac 本地打未签名 IPA
└── .github/workflows/build-ipa.yml   GitHub Actions 出未签名 IPA
```

---

## 2. 把源码变成能装的 IPA

iOS 的二进制只能在 macOS 上产出，两条路选一条。

### 路线 A：GitHub Actions（没有 Mac 时用这条）

1. 在 GitHub 新建一个**公开**仓库（公开仓库的 macOS runner 不消耗 Actions 额度）
2. 把本目录内容推上去（`project.yml`、`.github/`、各源码目录都在根目录）
3. push 后进 Actions → `build-unsigned-ipa` → 等 5~10 分钟
4. 下载 artifact `KeyPass-unsigned-ipa`，里面就是 `KeyPass-unsigned.ipa`

这一步同时完成**编译验证**：日志里能看到 Swift 编译错误。有错就把 `xcodebuild` 那段日志整段发给 Codex / 我，按报错修。

### 路线 B：借一台 Mac

```bash
brew install xcodegen
cd keypass-ipad
bash scripts/build-unsigned.sh
# 产物: out/KeyPass-unsigned.ipa
```

或者直接 `xcodegen generate` 后用 Xcode 打开 `KeyPass.xcodeproj`，选真机跑一次。

---

## 3. 用全能签签名安装

1. 把 `KeyPass-unsigned.ipa` 传到 iPad（AirDrop / 文件 App / 局域网）
2. 全能签「导入 IPA」→ 选自己的证书 → 签名 → 安装
3. 安装后先点开一次「密码键盘」App（引导页），再去做第 4 节的键盘设置

**签名时要保留插件**：这个 IPA 里有一个 `Payload/KeyPassHost.app/PlugIns/KeyPassKeyboard.appex`，
那是键盘本体，被签名工具丢掉的话装出来的 App 里就没有键盘。签完可以自查：

```
Payload/KeyPassHost.app/PlugIns/KeyPassKeyboard.appex/KeyPassKeyboard   ← 这个可执行文件必须存在
```

---

## 4. 开启键盘

设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → 第三方键盘 → **密码键盘**
→ 点开「密码键盘」→ 打开 **允许完全访问**

打字时：长按左下角 🌐 → 选「密码键盘」。要换回系统键盘，再按 🌐。

---

## 5. 键盘内操作速查

| 位置 | 操作 | 结果 |
|---|---|---|
| 底行「🔑 密码库」 | 点 | 打开密码库列表 |
| 列表行「账号」/「密码」 | 点 | 把该字段打进当前输入框（不关列表，方便接着点下一个） |
| 列表行「⋯」 | 点 | 复制账号 / 复制密码 / 编辑 / 删除 |
| 列表行 | 左滑 | 删除 |
| 顶栏「＋」 | 点 | 新建条目 |
| 顶栏「⋯」 | 点 | 导出到剪贴板 / 从剪贴板导入（备份用） |
| 顶栏「⌨︎」 | 点 | 回到打字页 |
| 编辑页 | 点某个格子 | 把它设为当前输入目标，之后按键就写进这一格 |
| 编辑页 | 按「换行」 | 跳到下一格 |

---

## 6. 数据存在哪 / 怎么备份

- 位置：键盘扩展沙盒 `Library/Application Support/KeyPassVault/vault.bin`（AES-GCM 加密，
  密钥优先放 Keychain，Keychain 被侧载破坏时退化成 `vault.key` 文件 + iOS 数据保护）
- **本 App 看不到键盘里的数据**：两个容器要互通必须有 App Group 权限，免费证书拿不到，
  所以管理界面做在键盘里，宿主 App 只做引导页
- **卸载 / 换证书重装 = 数据清空**，免费证书还有 7 天有效期，到期重签也可能丢
  → 定期在键盘里「⋯ → 导出到剪贴板」，把 JSON 贴进备忘录

---

## 7. 已知限制

| 限制 | 说明 |
|---|---|
| 没有中文输入 | 键盘只做英文/数字/符号，用来填账号密码够用；需要中文就按 🌐 切回系统键盘 |
| 编辑表单不是系统输入框 | 键盘扩展里没法弹系统键盘，所以编辑页的字也是自家键盘敲的 |
| 「允许完全访问」是敏感权限 | 开了它，键盘**在技术上能读到你在任何 App 里敲的内容**。本项目代码里没有任何网络请求、没有上报逻辑，只用 `textDocumentProxy.insertText` 写字符；要放心可以直接审 `KeyPassKeyboard/` 那 7 个文件 |
| 不建议存最关键的东西 | 银行、主邮箱这类建议只放系统「密码」App；这个键盘定位是「填得顺手」 |
| 免费证书有效期 7 天 | 到期要重签；付费开发者账号是 1 年 |

---

## 8. 排错

| 现象 | 原因 / 处理 |
|---|---|
| 密码框里调不出这个键盘 | **iOS 硬规则**：`isSecureTextEntry` 的输入框（显示圆点的密码框）系统强制换回自带键盘，任何第三方键盘都进不去，开「完全访问」也解不开。用法：账号点「账号」插入；密码用「⋯ → 复制密码」再长按粘贴 |
| 编辑页打不了字 | 已修（2026-11-04）：键盘面板改成打字页/编辑页共用一块，早期版本进编辑页键盘会被一起隐藏 |
| 键帽空白没有字 | 已修（2026-11-04）：`KeyButton` 之前只设了字体颜色，漏了 `setTitle` |
| 设置里找不到「密码键盘」 | 装完没启动过宿主 App；或 IPA 里的 appex 没被签名（见第 3 节自查） |
| 键盘能出来但列表永远是空 | 正常：条目要自己在键盘里「＋」新建；导入请看「⋯」菜单 |
| 点「导出到剪贴板」没反应 | 没开「允许完全访问」 |
| 键盘高度怪 / 被压扁 | 改 `KeyboardViewController.targetHeight` 里的数字（键位页 336/268 是 iPad/iPhone）。**下限别低于 210pt**：系统键盘最小高度约 204pt，请求更低会露出系统底衬，顶上多一道灰带 |
| 顶上出现一条灰带 / 键盘比容器矮 | 系统容器可能比我们的 view 高。参照 jev-chat 的兜底做法：等 frame 铺开后再量容器高度补高。**量之前必须 `view.bounds.height < 600` 守卫** —— 刚出现时 frame 是整屏尺寸（如 390×844），拿它算会得 0 并且永远不再量 |
| 键盘一弹起来宿主 App 就崩 | 查 `PrimaryLanguage`：必须是 `en-US`。缺失会崩；写成 `zh-Hans` 在英文系统/听写语言未启用时也崩（真机实证）。见 `project.yml` 里的注释 |
| 想换 bundle id | 改 `project.yml` 里两处 `PRODUCT_BUNDLE_IDENTIFIER`，**扩展的 id 必须以主 App 的 id 开头**（如 `com.yg.keypass` + `com.yg.keypass.keyboard`） |
| 想改名字/图标 | `project.yml` 里的 `CFBundleDisplayName`；图标需要另加 `Assets.xcassets` |

---

## 9. 修复记录

**2026-11-04 · Codex 只读审查后的一轮修复**（它判定「编译期 0 处需改，但运行期有 8 处真问题」）：

| 问题 | 改法 |
|---|---|
| 键帽全是空白（`KeyButton` 只设了字体颜色，从没 `setTitle`） | 补 `setTitle(keyDef.title, for: .normal)` |
| 进编辑页后键盘消失、表单根本打不了字（面板原来塞在被隐藏的 `keysContainer` 里） | 布局重排：`pageHost`（上半内容）+ 底部**打字页与编辑页共用**的 `planeView`，编辑页下压 176pt 给键盘 |
| 密钥读失败被当成"没有密钥"，会造新钥覆盖旧密文 | `loadKey(allowCreate:)`：已有 `vault.bin` 时绝不造新钥，返回错误 |
| 写盘失败只打日志，界面照显示"已保存" | `insert/update/remove/saveAll` 全部返回 `Bool`；失败就留在编辑页显示原因 |
| 剪贴板操作没有权限分支 | 导出/导入/复制前检查 `hasFullAccess`，分别提示"需要完全权限 / 剪贴板为空 / JSON 无效" |
| 只覆盖已有条目的导入被报成"没有数据" | `importJSON` 改返回 `(added, updated)`，nil 表示失败 |
| 连续提示会恢复成旧文字 | 到期重算 `normalVaultTitle`，不再保存旧字符串 |
| `project.yml` 里 `PrimaryLanguage` 注释写得过于绝对 | 改成"本键盘是英文布局 + jev 报告的特定配置故障"，注明 azooKey 用 ja-JP 也正常 |

**未做（故意留）**：`project.yml` 全局关了签名，所以不能在 Xcode 里直接 Run 真机 —— 这是给未签名 IPA 流程让路的取舍，真要真机调试就给 Debug 配置单独设签名。

---

## 10. 后续可以做

- 密码库顶部加 4 位 PIN 锁（现在靠设备锁屏 + 数据保护）
- 长按「密码」= 账号+Tab+密码 一次填完
- 条目排序、搜索框
- 有付费开发者账号后加 App Group，宿主 App 就能直接管理同一份密码库
