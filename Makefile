.PHONY: test lint secrets check

test:
	./tests/test.sh

lint:
	shellcheck -S warning -s sh bin/homelab-doctor lib/*.sh probes/openwrt/*.sh tests/*.sh tests/fixtures/*.sh scripts/*.sh

secrets:
	./scripts/check-sensitive.sh

# 本地与 CI 共用入口。
check: test lint secrets
