# 交给 Codex 的活（复制粘贴版）

工程目录：`D:\dsh\00-项目\keypass-ipad`（Swift 写的 iOS 键盘扩展 + 宿主 App，11 个 `.swift` 文件 + XcodeGen 配置）

---

## 0. 怎么开一轮（操作步骤）

1. Codex 桌面版 → **打开文件夹** `D:\dsh\00-项目\keypass-ipad`（第一次会问「是否信任」，选信任）
2. 新建对话。**不用粘代码**，它自己能读这个文件夹里的文件
3. 模型 / 推理强度按第 0.5 节选
4. 复制下面「第一轮」那个代码块，整段粘贴发出
5. 它要装东西、跑命令时会请求授权 —— 允许（它 sandbox 是 danger-full-access）
6. 跑完把它**整段回复**复制给我，别删别改（为什么见第 0.6 节）

---

## 0.5 模型和推理强度（按你账号实际能用的）

本机 Codex 缓存里的模型清单（`~\.codex\models_cache.json`，共 10 个）：

`gpt-6.1-sol` · `gpt-6-astra` · `gpt-6.1-terra` · `gpt-6-sol` · `gpt-6-luna` · `gpt-5.6-sol` · `gpt-5.6-terra` · `gpt-5.6-luna` · `gpt-reserve` · `codex-auto-review`

可选推理强度：`low / medium / high / xhigh / max / ultra`（**没有 minimal**）

| 轮次 | 模型 | 推理强度 | 说明 |
|---|---|---|---|
| 第一轮 代码审查 | `gpt-6.1-sol` | `high` | 你 `config.toml` 现在就是这个组合，直接用，不用改 |
| 第一轮遇到疑难（2 次没谈拢） | `gpt-6.1-sol` | `xhigh` | 只在真的卡住时升，烧额度 |
| 第二轮 语法体检 | `gpt-6.1-sol` | `medium` | 机械活，跑命令读报错 |
| 第三轮 配置体检 | `gpt-6.1-terra` 或 `gpt-6.1-sol` | `medium` | 便宜一档够用 |

> 别用 `max` / `ultra` 跑这些活：收益远小于额度消耗。

---

## 0.6 「原始输出」是什么意思

`swiftc` 这类编译器对每个文件会吐这种行：

```
Shared/VaultStore.swift:137:23: error: value of type 'AES.GCM.SealedBox' has no member 'combined'
```

**我要的就是这段原文**——它带「文件:行:列 + 错误类型」，我能直接定位改。
如果让 Codex「总结一下」，它可能只说「有几处小问题」或者自己顺手改了，那我就没法知道到底哪行、
也失去了判断它是不是乱改的依据。所以：**整段复制，不要摘要，不要让它边审边改**。

---

## 0.7 省额度玩法（Plus 必读）

**先搞清一件事**：Codex 每一轮都会把**之前整段对话重新发一遍**。所以真正的成本不是「问了几次」，
而是「这个对话有多长」。一个聊了 30 轮的长对话，第 30 轮可能比一个新开的第 1 轮贵十几倍。

**三条铁律**

| 铁律 | 原因 |
|---|---|
| **一个对话只干一件事，干完就新开** | 短对话 × 3 比长对话 × 1 便宜得多；额度重置后也能从干净上下文接着干 |
| **不许它装东西、不许它自己探索** | 装 Swift 要下 1~2 GB，加上命令输出全进上下文，一轮就能吃掉一大截。目录/文件直接点名给它 |
| **档位不超过 `high`** | 审查用 `high` 足够；`xhigh` 以上留给真卡住的时候。明确清单 + `medium` 常常比模糊任务 + `high` 更准更省 |

**最低额度版提示词**（一条消息、不加任何命令、出一张表就结束）：

````text
只读任务：不要改文件，不要安装任何软件，不要执行命令。

读这两个目录里的 9 个 .swift 文件：D:\dsh\00-项目\keypass-ipad\Shared\（3 个）
和 D:\dsh\00-项目\keypass-ipad\KeyPassKeyboard\（6 个）。其他文件不用看。

目标：找出「Xcode 真机编译会失败」或「键盘扩展（Keyboard Extension）里不允许」的地方。

只输出一张表，5 列：严重程度 | 文件:行 | 问题 | 依据 | 最小改法
最多 15 行，按严重程度从高到低。没问题的方面不要写。
最后单独一行：估计还要改 N 处才能编译通过。
````

**额度用完了怎么办** —— 不影响主线：

- 真正的一关是「能不能编译出 IPA」，那走 GitHub Actions 的 mac 机器，**不花 ChatGPT 额度**
- 代码审查我这边可以自己顶（读源码 + 查 Apple 文档），Codex 只是第二双眼睛
- 所以顺序建议：**先跑最低额度版审查** → 我改 → 再上 GitHub 编译。别把额度花在装工具链上

---

## 1. 第一轮 · 代码审查（版本 B：完整版，额度够用时才用）

> 版本 A（0.7 节那个 10 行的）通常就够了，而且是**首选**。
> 下面这个版本会读参考实现 + 跑命令，产出更扎实，但**贵**：只在你额度充裕、或者版本 A 的结论
> 你觉得不够硬的时候用。

````text
先读工程根目录的 README.md 和 参考项目.md 了解背景，再动手。

任务：审查这个 iOS 自定义键盘（Keyboard Extension）工程，找出在 Xcode 真机编译 / 运行阶段
会出问题的地方。代码没经过编译器验证，我要一份按严重程度排序的问题清单。

先读这几份同类项目的真实实现（用 web 抓或 curl，能读到就引用）：
1. https://raw.githubusercontent.com/jev-chat/jev-chat-jarvis-ios/master/project.yml
2. https://raw.githubusercontent.com/jev-chat/jev-chat-jarvis-ios/master/Keyboard/Sources/KeyboardViewController.swift
3. https://raw.githubusercontent.com/azooKey/azooKey/main/Keyboard/Info.plist
4. https://raw.githubusercontent.com/azooKey/azooKey/main/Keyboard/Keyboard.entitlements
把它们怎么处理键盘高度、Info.plist、扩展限制弄清楚，再逐条对照我们的代码。

必须逐个确认（有结论给结论，没把握就标「不确定」+ 原因，别猜）：
1. 键盘高度：KeyboardViewController 里给 view.heightAnchor 加 999 优先级约束、在 viewWillLayoutSubviews
   里改 constant，可靠吗？和参考实现的做法有什么差别？
2. 键盘扩展里能不能用 UITableView + UIContextualAction（左滑删除）？
3. UIButton 的 menu / showsMenuAsPrimaryAction 在扩展里可用吗？
4. UIPasteboard 的读和写分别需不需要「允许完全访问」？读会不会触发 iOS 16+ 的粘贴授权弹窗？
5. 「允许完全访问」关闭时，扩展自己沙盒里写 Library/Application Support 还能用吗？
6. 侧载重签（免费证书 / 全能签）的 App 上，Keychain 的 SecItemAdd 会不会返回 -34018？
   VaultStore 里退化成文件存密钥的降级路径成不成立？
7. NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).KeyboardViewController 写法对不对？
8. 有没有用到键盘扩展里被禁止的 API（UIApplication.shared、open URL、模态弹窗 present）？
9. SwiftUI 宿主 App 里 UIApplication.shared.open(openSettingsURLString) 在 iOS 15 正常吗？
10. 逐文件找编译期会报错的地方：类型不匹配、闭包捕获 self、switch 不完备、Codable 合成失败、
    可用性标注（@available / iOS 版本）不满足等。

约束：
- 只读，不要改任何文件，也不要 git 操作。
- 不要建议引入 KeyboardKit（它已闭源 + 商业许可），不要搬 azooKey 的代码进来。
- 不要建议改成 App Group 共享：免费证书和全能签拿不到该权限，这是故意的设计。
- 输出格式（表格）：严重程度（编译失败 / 运行时崩 / 行为不对 / 建议）| 文件:行 | 问题 | 依据（Apple 文档或参考实现原文）| 最小修改建议
- 最后一句总评：这份代码大概要改几处才能编译通过。
````

---

## 2. 第二轮（可选）· 语法体检 —— 要装 Swift，价值有限

> 先说清楚：`swiftc -parse` **只查语法**（括号、关键字），查不出 UIKit API 用错。
> 我们已经用脚本做过括号平衡检查并通过，所以这一轮只在第一轮审完、还想再篦一遍时才做。
> 装它要下 1~2 GB。真正的编译验证见第 4 节。

````text
任务：给 D:\dsh\00-项目\keypass-ipad 里的 11 个 .swift 文件做纯语法体检，不改业务逻辑。

1. 本机没有 Swift。用 winget 或 swift.org 官方 Windows 安装包装 Swift 6.x，装完确认 swiftc --version 有输出。
   装不上就停下来说明卡在哪、报了什么错。
2. 逐文件跑：swiftc -parse <文件全路径>
   只用 -parse。别用 -typecheck / -c：Windows 没有 UIKit 和 iOS SDK，typecheck 必然失败，那是预期行为。
3. 输出：每个文件一行 PASS 或 FAIL；FAIL 的给「文件名:行号」+ 编译器报错原文（原样，不要改写）。
4. 只修纯语法错误；需要判断 API 语义的一律只列进清单，不要动代码。
````

---

## 3. 第三轮（可选）· 工程配置体检

````text
任务：检查这个 iOS 工程的三份配置能否被 xcodegen + xcodebuild 正确消费，不要重写它们。

文件：
- D:\dsh\00-项目\keypass-ipad\project.yml
- D:\dsh\00-项目\keypass-ipad\.github\workflows\build-ipa.yml
- D:\dsh\00-项目\keypass-ipad\scripts\build-unsigned.sh

检查项：
1. project.yml 是否是合法 XcodeGen schema；两个 target（application + app-extension）字段有没有写错。
2. info: 里手写的 CFBundle* 键和 NSExtension 字典，XcodeGen 会不会重复生成或覆盖？
   扩展 Info.plist 少哪个必需键会导致装完没有键盘？对照 azooKey 的 Keyboard/Info.plist。
3. app embed 扩展的关系写对了吗（是 app 依赖扩展，不是反过来）？
4. workflow 的 xcodebuild 参数能否在 macos-14 runner 上出未签名 IPA；-scheme KeyPassHost
   依赖 project.yml 里 schemes 段，会不会找不到 scheme？
5. 打包判定的产物路径 build/Build/Products/Release-iphoneos/KeyPassHost.app 与 -derivedDataPath build 是否一致。
6. 侧载重签场景：扩展 bundle id 必须以 app bundle id 开头，这里有没有踩坑？

输出：逐条「对的 / 错的 / 不确定」，错的给最小 patch，不要整份重写。
````

---

## 4. 真正的验证：GitHub Actions 编译

`swiftc -parse` 和人工审查都替代不了真编译。真正能证明「能出 IPA」的只有 macOS 上跑一次
`xcodebuild`，而 `.github/workflows/build-ipa.yml` 已经写好了：公开仓库的 macos runner 不花额度。

前提是有一个 GitHub 仓库。本地 `git clone` 到 github 会断流（`RPC failed` 实测），
但 `git push` 和网页上传没验证过，到时候一起试。

---

## 5. 拿到结果之后

把 Codex 的**整段回复**贴回来。我按它的清单改代码，再让它复跑第一轮，直到没问题；
最后一关是第 4 节的真编译。
