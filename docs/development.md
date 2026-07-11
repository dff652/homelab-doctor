# 开发指南

## 开发原则

homelab-doctor 是只读诊断工具。所有贡献必须遵守以下边界：

- 默认不修改远程设备，不重启服务，不清理缓存；
- 不实现隐式修复；未来修复必须显式使用 `--fix`，并提供备份、diff、确认、幂等和回滚；
- 不 `source` 用户配置，所有远程参数必须经过白名单校验；
- 路由器侧脚本兼容 POSIX Shell 与 OpenWrt BusyBox；
- 单个诊断命令只建立一次 SSH连接，通过 stdin执行，不安装常驻 Agent；
- 不提交真实地址、域名、设备标识、日志、私钥、token或订阅链接；
- Shell-first 阶段不增加非必要运行时依赖。

## 本地环境

最低开发环境：

- POSIX兼容的 `/bin/sh`；
- `make`；
- ShellCheck；
- Git；
- OpenSSH客户端仅用于可选的真实设备集成测试。

运行完整本地检查：

```sh
make check
git diff --check
```

fixture与命令桩必须能够覆盖健康、警告和故障状态，测试不得依赖真实路由器或互联网。

## 分支与提交

其他开发人员从最新 `main` 创建短生命周期分支：

```text
feat/<topic>
fix/<topic>
docs/<topic>
test/<topic>
```

每个提交只处理一个清晰目标。提交前检查：

1. `make check` 通过；
2. `git diff --check` 通过；
3. 新判断有对应 fixture；
4. 文档与命令行为同步；
5. diff 中没有真实基础设施信息。

## 模块边界

- `bin/homelab-doctor`：参数解析和命令分发；
- `lib/config.sh`：配置读取与白名单验证；
- `lib/doctor.sh`：模块选择、探针拼装和一次 SSH执行；
- `probes/openwrt/common.sh`：远程输出、计数和通用原语；
- `probes/openwrt/*.sh`：独立只读诊断模块；
- `tests/fixtures/`：完全脱敏的命令桩与状态 fixture；
- `tests/test.sh`：CLI、模块语义、退出状态和 SSH次数测试。

模块不得自行解析本地配置、建立 SSH连接或改变汇总格式。新增模块由 `lib/doctor.sh` 选择和聚合。

## 输出与退出状态

- `[OK]`：检查得到明确的健康证据；
- `[WARN]`：检查无法完成、能力缺失或存在非阻断风险；
- `[!]`：得到明确的故障证据；
- 仅有 `[WARN]` 时返回 0；存在任意 `[!]` 时返回非零；
- SSH连接失败应与远程模块的 `[!]` 明确区分。

在结构化输出实现前，不随意修改现有文本和 `SUMMARY ok=N warn=N fail=N` 格式。

## 真实设备集成测试

改动远程探针后，使用 gitignored 的 `config/*.local.conf` 做一次只读测试。只在评审记录中保留模块计数和退出状态，不粘贴真实输出。

测试后必须：

1. 删除临时配置；
2. 确认 `git status --ignored` 中没有待发布配置；
3. 扫描当前树和可达 Git历史中的敏感模式；
4. 记录设备类型、固件类别和脱敏汇总，不记录地址与域名。

## 交付说明模板

开发人员提交评审时提供：

```text
目标：
影响模块：
行为变化：
新增测试：
make check：
git diff --check：
只读集成测试（如适用）：
安全与脱敏检查：
已知限制：
提交号：
```

最终评审重点是证据链、只读边界、BusyBox兼容性、退出状态、脱敏和回归测试，而不只检查代码风格。
