SHELL := /bin/bash

init:
	cp -n .env.example .env || true
	chmod +x bootstrap.sh scripts/*.sh

run:
	./bootstrap.sh

verify:
	bash -c 'source scripts/common.sh; load_config "$$PWD"; bash scripts/verify.sh'


test:
	bash -n bootstrap.sh
	@for script in scripts/*.sh vendor/*.sh; do bash -n "$$script" || exit; done
	python3 -m unittest discover -s tests -v
