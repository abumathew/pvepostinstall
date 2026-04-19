SHELL := /bin/bash

init:
	cp -n .env.example .env || true
	chmod +x bootstrap.sh scripts/*.sh

run:
	./bootstrap.sh

verify:
	./scripts/verify.sh
