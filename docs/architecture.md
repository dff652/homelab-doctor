# 架构

## 当前形态：Shell-first MVP

```text
控制端 CLI
  ├─ 安全解析本地配置（不 source）
  ├─ 校验地址、域名、URL与 SSH参数
  └─ SSH stdin 流式发送只读探针
        ↓
OpenWrt/BusyBox 探针
  ├─ DNS / split-DNS
  ├─ OpenClash运行规则
  ├─ OpenVPN路由与 DNS PUSH
  ├─ 服务连通性
  └─ conntrack健康度
```

控制端不向路由器安装常驻 Agent；探针每次经 SSH发送并执行。

## 安全边界

- 默认只读，不清缓存、不重启、不写配置。
- 配置文件使用白名单解析，不作为 Shell代码 source。
- 示例配置只使用 RFC 5737 文档地址。
- 私钥、密码、token、订阅与真实拓扑不得进入公开仓库。
- 未来修复命令必须显式 `--fix`，并具备备份、diff、确认和回滚。

## 后续演进

当模块、并发和结构化输出需求稳定后，引入 Go 控制端：

- 保持现有探针协议兼容；
- 增加 YAML、JSON、JUnit输出；
- 并行执行多个节点；
- 生成脱敏诊断包；
- 提供跨平台单文件发布。
