.PHONY: test lint check

test:
	./tests/test.sh

lint:
	shellcheck -S warning -s sh bin/homelab-doctor lib/*.sh probes/openwrt/*.sh tests/*.sh

check: test lint
