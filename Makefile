.SUFFIXES: .haml .html
.haml.html:
	haml -f html5 -t ugly $< $@

.SUFFIXES: .sass .css
.sass.css:
	compass compile $< -c $(CSS_DIR)/config.rb

.SUFFIXES: .sass .min.css
.sass.min.css:
	compass compile --environment production $< -c $(CSS_DIR)/config.rb
	mv $*.css $@

.SUFFIXES: .yaml .json
.yaml.json:
	node_modules/.bin/yaml2json $< > $@


all: chrome-apps


ENDPOINTS_LIB=submodule/dart_echo_v1_api_client
RESOURCE_DIR_PATH=web lib
RESOURCE_DIR=$(foreach dir,$(shell find $(RESOURCE_DIR_PATH) -type d),$(dir))
HAML=$(foreach dir,$(RESOURCE_DIR),$(wildcard $(dir)/*.haml))
HTML=$(HAML:.haml=.html)
SASS=$(foreach dir,$(RESOURCE_DIR),$(wildcard $(dir)/*.sass))
CSS=$(SASS:.sass=.css)
MINCSS=$(SASS:.sass=.min.css)
YAML=$(shell find web -type f -name "[^.]*.yaml")
JSON=$(YAML:.yaml=.json)
RESOURCE=$(HTML) $(CSS) $(MINCSS) $(JSON)
VERSION=lib/version

pubserve: $(VERSION) $(ENDPOINTS_LIB) $(RESOURCE)
	pub serve --port 8080 --no-dart2js

pubserve-force-poll: $(VERSION) $(ENDPOINTS_LIB) $(RESOURCE)
	pub serve --port 8080 --no-dart2js --force-poll

DISCOVERY=assets/echo-v1.discovery
$(ENDPOINTS_LIB):
	@if [ -d submodule/discovery_api_dart_client_generator ]; then\
		(cd submodule/discovery_api_dart_client_generator && pub install);\
		submodule/discovery_api_dart_client_generator/bin/generate.dart --no-prefix -i $(DISCOVERY) -o submodule;\
	fi;

lib:
	mkdir -p lib

VERSION_STRING=$(shell git describe --always --dirty=+)
PROJECT_SINCE=1415232000 #2014/11/06
AUTO_COUNT_SINCE=$(shell echo $$(((`date -u +%s`-$(PROJECT_SINCE))/(24*60*60))))
AUTO_COUNT_LOG=$(shell git log --since=midnight --oneline|wc -l|tr -d " ")
$(VERSION): lib web/manifest.json
	@if [ "$(VERSION_STRING)" != "$(strip $(shell [ -f $@ ] && cat $@))" ] ; then\
		echo 'echo $(VERSION_STRING) > $@' ;\
		echo $(VERSION_STRING) > $@ ;\
	fi;
	echo $(AUTO_COUNT_SINCE) days since `date -u -r $(PROJECT_SINCE) +%Y-%m-%d`, $(AUTO_COUNT_LOG) commits from midnight.
	sed -i "" -e "s/\$${AUTO_COUNT}/$(AUTO_COUNT_SINCE).$(AUTO_COUNT_LOG)/" web/manifest.json


DART_JS=web/main.dart.js
chrome-apps: $(VERSION) $(ENDPOINTS_LIB) $(RESOURCE)


scaffold:
	@read -p "your project name([a-z0-9-]): " name &&\
	if [ "$$name" == "" ] ; then\
		echo no given.;\
		exit;\
	fi;\
	sed -i "" s/dart-chrome-app/$$name/g\
		pubspec.yaml\
		web/index.html\
		web/manifest.json\
	;


clean:
	rm -f $(VERSION) $(RESOURCE)

clean-all: clean
	rm -f pubspec.lock $(DART_JS)
	rm -rf $(ENDPOINTS_LIB) packages
	find . -name "*.sw?" -delete
	find . -name .DS_Store -delete
	find . -name packages -type l -delete
	find . -type d -name .sass-cache |xargs rm -rf

.PHONY: $(VERSION)
