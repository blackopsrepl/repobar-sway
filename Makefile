PREFIX ?= $(HOME)/.local
APP_HOME ?= $(PREFIX)/share/repobar
BIN_DIR ?= $(PREFIX)/bin

.PHONY: help test check install-user uninstall

help:
	@printf '%s\n' \
		'repobar targets:' \
		'  test                Run Ruby tests' \
		'  check               Syntax, tests, and CLI smoke' \
		'  install-user        Install app under ~/.local' \
		'  uninstall           Remove the installed app and link'

test:
	ruby -Itest test/run.rb

check:
	@ruby -wc $$(rg --files bin lib test) >/dev/null || exit 1
	ruby -Itest test/run.rb
	bin/repobar config validate

install-user:
	mkdir -p "$(APP_HOME)" "$(BIN_DIR)"
	cp -R bin lib frontend README.md AGENTS.md docs "$(APP_HOME)/"
	ln -sf "$(APP_HOME)/bin/repobar" "$(BIN_DIR)/repobar"
	chmod +x "$(APP_HOME)/bin/repobar"

uninstall:
	rm -rf "$(APP_HOME)"
	rm -f "$(BIN_DIR)/repobar"
