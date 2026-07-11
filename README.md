# homelab-doctor

面向 OpenWrt/GL.iNet、OpenClash/Mihomo、AdGuard Home、OpenVPN与家庭服务的只读跨层网络诊断工具集。

它关注的不是单点 `ping`，而是完整证据链：

```text
DNS → Fake-IP → 网关/路由 → Clash规则 → VPN → 防火墙 → 最终服务
```

## 当前状态

`0.2.0-dev`，Shell-first MVP。提供可独立执行和聚合执行的 OpenWrt只读诊断模块，不执行自动修复。

## 快速开始

```sh
cp config/example.conf config/local.conf
$EDITOR config/local.conf

bin/homelab-doctor --config config/local.conf config validate
bin/homelab-doctor --config config/local.conf doctor dns
bin/homelab-doctor --config config/local.conf doctor mihomo
bin/homelab-doctor --config config/local.conf doctor openvpn
bin/homelab-doctor --config config/local.conf doctor firewall
bin/homelab-doctor --config config/local.conf doctor router
```

配置使用简单 `KEY=value` 格式，但不会被 Shell `source`；未知配置项和不安全字符会被拒绝。单模块命令只校验自身所需配置，避免 `doctor dns` 因缺少 VPN 参数失败。

## 诊断模块

- `dns`：AdGuard Home、DNS 53与 split-DNS 期望答案；
- `mihomo`：OpenClash/Mihomo进程、DNS 7874、域名/LAN DIRECT规则与 Fake-IP Filter；
- `openvpn`：OpenVPN进程、DNS PUSH与客户端子网路由；
- `firewall`：fw3/iptables 或 fw4/nftables 规则表与有效规则；
- `system/service`：最终 HTTPS服务与 conntrack使用率；
- `router`：通过一次 SSH stdin执行以上所有模块。

每次诊断输出 `[OK]`、`[WARN]`、`[!]` 和计数摘要。存在 `[!]` 时退出状态非零；仅有警告时仍返回成功，便于先收集完整证据。

## 测试

```sh
make check
```

测试使用脱敏 fixture 和命令桩，不依赖真实路由器；示例地址来自 RFC 5737。

## 产品路线

1. 稳定模块输出语义与边界；
2. JSON/JUnit与脱敏诊断包；
3. 多节点并行编排；
4. Go 单文件控制端；
5. 只告警监控；
6. 经显式确认、可回滚的修复模式。

开发约束与交付模板见 [开发指南](docs/development.md)，分阶段目标见 [目标规划](docs/roadmap.md)，最终验收使用 [Review清单](docs/review-checklist.md)。

## 与私人 homelab 仓的边界

本项目只保存通用代码、脱敏测试和公开文档。真实家庭拓扑、IP、域名、证书、订阅和事故原始日志应留在私有基础设施仓库。

## License

本项目采用 [Apache License 2.0](LICENSE)。
