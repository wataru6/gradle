# 自定义 Gradle 9.3.1（macOS x86_64）

本仓库在官方 Gradle 源码中使用自编译的 `native-platform`，修复 macOS 上根据 CPU 品牌字符串判断架构时，无法识别 `12th Gen Intel...` 等新代际 Intel 名称和 AMD 名称的问题。这些 CPU 仍属于已有的 `x86_64` 架构。

## 当前版本基线

| 组件 | 官方标签 | 官方提交 |
| --- | --- | --- |
| `gradle/` | [`v9.3.1`](https://github.com/gradle/gradle/releases/tag/v9.3.1) | `44f4e8d3122ee6e7cbf5a248d7e20b4ca666bda3` |
| `native-platform/` | [`0.22-milestone-29`](https://github.com/gradle/native-platform/tree/0.22-milestone-29) | `e999afaf8692fb66e9016e0a3b0519a05981753e` |
| 自定义依赖坐标 | `net.rubygrapefruit:native-platform:0.22-milestone-29-custom` | 本仓库源码编译 |

导入的 GitHub 源码归档及 SHA-256：

- `https://codeload.github.com/gradle/gradle/tar.gz/refs/tags/v9.3.1`
  — `50459cce74c28f86dfe4dc99c444812689bea40202984760230348e389533a27`
- `https://codeload.github.com/gradle/native-platform/tar.gz/refs/tags/0.22-milestone-29`
  — `5ba424fd825f834c9fb7ba53a6a459b17123b687cea284a3137f98cd2f0b13cc`

Gradle 9.1.0 使用的是 `0.22-milestone-28`；9.3.1 升级到了 `0.22-milestone-29`，所以这里同时更新了两份源码。CPU 修复保留在：

`native-platform/native-platform/src/main/java/net/rubygrapefruit/platform/internal/MutableSystemInfo.java`

可重放的补丁另存于 `ci/patches/native-platform-cpu-detection.patch`。回归测试覆盖新旧 Intel、AMD、Apple、原有架构别名和未知 CPU。

另外，`ci/patches/native-platform-build-dependencies.patch` 移除了 milestone-29 在 native-platform 库中引入的 `implementation gradleApi()`，并将 JUnit API 限定到测试依赖。Gradle API JAR 包含另一份 native-platform 类，会覆盖待测试的自定义实现，导致新 Intel 和 AMD 的 6 个回归用例失败。测试日志会输出 `MutableSystemInfo` 实际加载的 JAR 路径，Actions 同时保留 HTML/XML 测试报告。

## 在 GitHub Actions 构建

1. 将本地升级分支的修改提交并推送，例如：

   ```bash
   git add README.md .github ci gradle native-platform
   git commit -m "Upgrade custom Gradle to 9.3.1 and native-platform milestone-29"
   git push -u origin codex/gradle-9.3.1
   ```

2. 推送 `codex/gradle-9.3.1` 分支的源码或构建配置修改后，会自动启动 Actions 构建。
3. 如需手动重跑，打开仓库的 **Actions → Build custom Gradle macOS amd64 → Run workflow**，选择 **`codex/gradle-9.3.1`** 分支，保留依赖版本 **`0.22-milestone-29-custom`**。选择 `master` 会构建该分支原有的 9.1.0 源码。
4. 成功后下载 `custom-gradle-9.3.1-macos-amd64-bin` artifact，并解开 GitHub artifact 的外层 ZIP。实际发行包是其中的 **`gradle-9.3.1-bin.zip`**，旁边附有 SHA-256 文件。

工作流支持升级分支 push 自动触发和手动触发。它在 `macos-15-intel` 上先用 JDK 8 编译和测试 native-platform，再用 JDK 17 构建 Gradle。验证步骤会比较发行包内两个 native-platform JAR 与刚编译的 JAR 的字节内容，并运行发行包的 `--version` 和空项目 `help`。

这个构建流程只发布本机的 `osx-amd64` 原生库，产物面向 macOS x86_64。

## 在本机编译

需要 macOS x86_64、Xcode Command Line Tools、JDK 8 和 JDK 17，并能够下载 Gradle 和 Maven 依赖。在仓库根目录运行：

```bash
export NATIVE_PLATFORM_VERSION=0.22-milestone-29-custom
export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)
export PATH="$JAVA_HOME/bin:$PATH"
bash ci/build-native-platform-macos-amd64.sh

export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export PATH="$JAVA_HOME/bin:$PATH"
bash ci/build-gradle-custom-macos-amd64.sh
```

输出路径：

```text
gradle/packaging/distributions-full/build/distributions/gradle-9.3.1-bin.zip
gradle/packaging/distributions-full/build/distributions/gradle-9.3.1-bin.zip.sha256
```

构建时脚本临时修改 `nativePlatformVersion`、注入本地 Maven 仓库，并在退出时恢复 Gradle 源码中的版本声明。`--dependency-verification off` 沿用原有定制构建设置，因为官方校验元数据不包含本地生成的依赖。

`gradle/version.txt` 和 `-PfinalRelease=true` 决定产物版本。源码中的 Wrapper 是上游用于编译 Gradle 本身的引导工具：Gradle 9.3.1 官方源码使用 `9.3.0-rc-3` Wrapper，这是上游原有配置。仅修改 Wrapper 地址或 `version.txt` 不能完成源码升级。

## 在其他项目中使用

解压实际发行包后可直接调用：

```bash
/path/to/gradle-9.3.1/bin/gradle --version
/path/to/gradle-9.3.1/bin/gradle build
```

也可以把实际发行包上传到自己的 Release 或下载服务器，再修改使用方项目的 `gradle/wrapper/gradle-wrapper.properties`：

```properties
distributionUrl=https\://your-download-host/gradle-9.3.1-bin.zip
distributionSha256Sum=<本次构建生成的 SHA-256>
```

使用自定义发行包自己的校验值；GitHub Actions artifact 的外层 ZIP 和官方 Gradle 发行包都不是这个文件。

## 后续升级方式

当前仓库是两份源码快照组成的仓库，与 `gradle/gradle` 上游没有共同的 Git 提交历史，也没有名为 `9.3.1` 的本地跟踪分支。因此本次采用 **新建版本分支 → 导入官方发布标签源码 → 重放定制补丁 → 构建验证**。

后续升级时：

1. 从当前工作创建新的版本分支，选定官方稳定发布标签 `vX.Y.Z`，记录其提交 ID。
2. 比对旧版上游和本地源码，保存定制差异；用目标标签完整更新 `gradle/`，包含上游删除的旧文件。
3. 查看 `gradle/packaging/distributions-dependencies/build.gradle.kts` 的 `nativePlatformVersion`，将 `native-platform/` 更新到对应版本。保留本地回归测试。
4. 先确认目标版本是否已修复 CPU 判断和测试依赖冲突；仍需修复时，在仓库根目录重放相应补丁：

   ```bash
   git apply --check --directory=native-platform ci/patches/native-platform-cpu-detection.patch
   git apply --directory=native-platform ci/patches/native-platform-cpu-detection.patch
   git apply --check --directory=native-platform ci/patches/native-platform-build-dependencies.patch
   git apply --directory=native-platform ci/patches/native-platform-build-dependencies.patch
   ```

   当前源码已经包含补丁，无需再次应用。

5. 更新 `ci/` 脚本和根目录 workflow 的自定义依赖版本、产物版本，以及本文的上游基线，然后运行构建和验证。

若以后经常跟进上游，可单独维护具有上游历史的 Gradle fork，或将两份源码作为 Git subtree/submodule 管理。针对现有仓库，按发布标签更新源码能保留已经跑通的 Actions 流程。
