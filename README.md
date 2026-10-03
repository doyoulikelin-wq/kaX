# kaX

**记录身体，分享变化。** 一个以测量、身份展示和轻社交为中心的原生 iOS 应用。

## 运行

使用 Xcode 16 或更新版本打开 `KaX.xcodeproj`，选择 `KaX` scheme 和一个 iPhone 模拟器后运行。本次开发和验证环境为 Xcode 26.3 / iOS 26.3；最低系统版本为 iOS 17。

工程没有第三方依赖，无需安装包管理器、配置服务器或填写密钥。真机运行需要在 Xcode 的 Signing & Capabilities 中选择开发者 Team。

## 已实现

- **动态**：发现 / 关注、测量卡片与文字动态、点赞、评论、个人动态、关注、系统分享。
- **测量**：身体尺寸、卧推基准记录、5 秒肌电演示采集、取消 / 重采 / 保存、来源与历史详情。
- **排行**：示例用户和个人记录的卧推估算 1RM / 体重比较，全部 / 关注筛选。
- **我的**：编辑资料、选择展示指标、身份卡 PNG 分享、身体档案、最近测量、JSON 导出、带确认的本机重置。
- **体验**：系统字体、语义色、克制的绿色强调色、深色模式、大字号支持、iPhone / iPad 自适应宽度。

当前版本是可运行的**本机功能底座**。首次启动包含明确标记的示例数据；手动保存的数据标记为手动记录，模拟肌电标记为演示数据。社交操作会持久化到当前设备，没有远程账号、多人服务器或真实 BLE 连接。身体尺寸目前为人工输入，尚未实现参照卡视觉测量；肌电不会被解释为增肌潜力或损伤概率。

## 界面预览

以下为模拟器实际运行截图，内容中保留演示来源标记。

<p>
  <img src="docs/screenshots/feed.png" width="220" alt="动态" />
  <img src="docs/screenshots/measurement.png" width="220" alt="测量" />
  <img src="docs/screenshots/ranking.png" width="220" alt="排行" />
  <img src="docs/screenshots/profile.png" width="220" alt="我的" />
</p>

[导出的身份卡图片](docs/screenshots/identity-card.png) · [深色大字号截图](docs/screenshots/dark-large-feed.png) · [小屏测量](docs/screenshots/compact-measurement.png) · [系统分享](docs/screenshots/native-share.png)

## 结构

```text
KaX/
  App/                     应用入口、依赖创建、四个主导航
  Core/
    Models.swift           资料、记录、来源、动态、评论、排名快照
    AppStore.swift         主线程状态和事务式用户操作
    Repository.swift       存储契约、JSON 原子持久化、版本保护
    MeasurementDevice.swift 设备契约、确定性演示设备、未接入适配器
    ScoreCalculator.swift  有边界检查的计算规则
    SampleData.swift       明确标记的演示样本
  Features/
    Social/                动态、发布、评论、个人动态
    Measurement/           手动记录、设备状态、肌电会话
    Ranking/               榜单、筛选、比较规则
    Profile/               身份卡、资料、导出、设置
  DesignSystem/            语义色与复用组件
  Resources/               应用图标、强调色
KaXTests/                  领域、存储、状态、设备测试
KaXUITests/                端到端流程与界面截图
docs/architecture.md       接口边界、后续接入方式
docs/validation.md         本轮验证结果与范围
```

详见 [架构说明](docs/architecture.md) 与 [验证记录](docs/validation.md)。

## 测试

```sh
# 自动选择已启动的 iPhone 模拟器，或第一个可用 iPhone
./scripts/test.sh

# 指定模拟器 UUID
./scripts/test.sh <SIMULATOR_UDID>
```

测试结果保存在 `build/TestResults/`，UI 测试截图随 `.xcresult` 保存。`build/` 不进入版本库。

`.xcodeproj` 已提交，可直接打开。若需要重新生成工程配置，运行 `python3 scripts/generate_project.py`。工程使用文件系统同步组，新增 Swift 文件时无需手工修改文件引用。
