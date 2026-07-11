# homelab-doctor

面向 OpenWrt/GL.iNet、OpenClash/Mihomo、AdGuard Home、OpenVPN与家庭服务的只读跨层网络诊断工具集。

它关注的不是单点 `ping`，而是完整证据链：

```text
DNS → Fake-IP → 网关/路由 → Clash规则 → VPN → 防火墙 → 最终服务
```

## 当前状态

`0.1.0-dev`，Shell-first MVP。当前只提供 OpenWrt路由器综合探针，不执行自动修复。

## 快速开始

```sh
cp config/example.conf config/local.conf
$EDITOR config/local.conf

bin/homelab-doctor --config config/local.conf config validate
bin/homelab-doctor --config config/local.conf doctor router
```

配置使用简单 `KEY=value` 格式，但不会被 Shell `source`；未知配置项和不安全字符会被拒绝。

## 当前检查项

- AdGuard Home、OpenClash、OpenVPN进程；
- DNS 53、OpenClash DNS 7874；
- split-DNS 期望答案；
- 最终 HTTPS服务；
- OpenClash域名与 LAN DIRECT规则；
- OpenVPN DNS PUSH与客户端子网路由；
- conntrack使用率；
- `[OK]`、`[WARN]`、`[!]` 汇总结论。

## 测试

```sh
tests/test.sh
shellcheck -s sh bin/homelab-doctor lib/*.sh probes/openwrt/*.sh tests/*.sh
```

## 产品路线

1. DNS、Mihomo、OpenVPN模块拆分；
2. JSON/JUnit与脱敏诊断包；
3. 多节点并行编排；
4. Go 单文件控制端；
5. 只告警监控；
6. 经显式确认、可回滚的修复模式。

## 与私人 homelab 仓的边界

本项目只保存通用代码、脱敏测试和公开文档。真实家庭拓扑、IP、域名、证书、订阅和事故原始日志应留在私有基础设施仓库。

## License

许可证尚未选择；公开发布前必须补充。
