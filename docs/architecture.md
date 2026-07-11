# 架构

## 当前形态：Shell-first 模块化 MVP

```text
控制端 CLI
  ├─ 安全解析本地配置（不 source）
  ├─ 校验地址、域名、URL与 SSH参数
  ├─ 按命令拼装公共层与所需模块
  └─ 通过一次 SSH stdin 流式发送只读探针
        ↓
OpenWrt/BusyBox 探针
  ├─ common：输出、计数、端口与 DNS解析原语
  ├─ dns：DNS / split-DNS
  ├─ mihomo：OpenClash运行态、DIRECT与 Fake-IP Filter
  ├─ openvpn：路由与 DNS PUSH
  └─ system/service：最终服务连通性与 conntrack
```

控制端不向路由器安装常驻 Agent；探针每次经 SSH发送并执行。

## 模块与执行协议

- `doctor dns`、`doctor mihomo`、`doctor openvpn` 只拼装对应模块；
- `doctor router` 按 DNS → Mihomo → OpenVPN → system/service 顺序聚合；
- 公共层和模块只定义 POSIX Shell函数，控制端在脚本末尾追加入口调用；
- 所有模块共享 `[OK]`、`[WARN]`、`[!]` 计数和最终摘要；
- `[!]` 使远程脚本返回非零，仅有 `[WARN]` 时返回零；
- fixture测试通过 PATH命令桩和脱敏文件替代路由器命令与运行配置。

模块文件不负责 SSH、配置解析或输出格式编排。这个边界允许未来 Go控制端继续拼装和发送现有探针，而无需改变路由器侧协议。

## 安全边界

- 默认只读，不清缓存、不重启、不写配置。
- 配置文件使用白名单解析，不作为 Shell代码 source。
- 单模块与聚合模式都只建立一次 SSH连接，不在路由器落盘。
- 示例配置只使用 RFC 5737 文档地址。
- 私钥、密码、token、订阅与真实拓扑不得进入公开仓库。
- 未来修复命令必须显式 `--fix`，并具备备份、diff、确认和回滚。

## 后续演进

当模块输出语义、并发和结构化输出需求稳定后，引入 Go 控制端：

- 保持现有探针协议兼容；
- 增加 YAML、JSON、JUnit输出；
- 并行执行多个节点；
- 生成脱敏诊断包；
- 提供跨平台单文件发布。
