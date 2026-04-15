SHELL := /bin/bash

init:
	cp -n .env.example .env || true
	chmod +x bootstrap.sh scripts/*.sh

run:
	sudo ./bootstrap.sh

verify:
	sudo ./scripts/verify.sh
