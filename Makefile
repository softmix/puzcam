#!make
include .env

EXTENSION := $(shell grep "name" manifest.json | sed -n 's/.*"name":.*"\(.*\)",.*/\1/p')
VERSION := $(shell grep "version" manifest.json | grep -Po '([0-9]+\.){2}[0-9]+')
ID := $(shell grep "id" manifest.json | sed -n 's/.*"id":.*"\(.*\)",.*/\1/p')
LINK := https://github.com/softmix/$(EXTENSION)/releases/download/$(VERSION)/$(EXTENSION).xpi

.PHONY: tag clean

tag:
	$(shell jq '.addons[].updates[].version="$(VERSION)"' updates.json | sponge updates.json)
	$(shell jq '.addons[].updates[].update_link="$(LINK)"' updates.json | sponge updates.json)

ifeq ($(shell (git status --porcelain | grep -q .) && echo dirty || echo clean),dirty)
	$(error git state not clean)
endif

clean:
	rm -rf web-ext-artifacts

build: clean tag
	web-ext sign --channel="unlisted" --id="$(ID)"

release: tag
	cp web-ext-artifacts/*.xpi $(EXTENSION).xpi
	hub release create -a $(EXTENSION).xpi $(VERSION) -m "$(VERSION)"
