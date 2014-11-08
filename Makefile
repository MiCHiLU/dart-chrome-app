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


RELEASE_DIR=release
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

resource: $(VERSION) $(RESOURCE)


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


DART_JS=$(BUILD_DIR)/web/main.dart.precompiled.js
js-serve: $(VERSION) $(ENDPOINTS_LIB) $(RESOURCE)
	make $(DART_JS)
	cd $(RELEASE_RESOURCE_SRC_DIR) && python -m SimpleHTTPServer


RELEASE_RESOURCE=\
	$(foreach path,$(HTML) $(VERSION),$(subst lib,web/packages/dart-chrome-app,$(path)))\
	$(JSON)\
	$(shell find web -name "*.png")\
	web/js/browser_dart_csp_safe.js\
	web/js/main.js\
	web/packages/browser/dart.js\
	web/packages/chrome/bootstrap.js\
	web/packages/polymer/src/js/polymer/polymer.js\
	web/packages/web_components/dart_support.js\
	web/packages/web_components/platform.js\

RELEASE_CHROME_APPS_RESOURCE=$(RELEASE_RESOURCE) web/main.dart

RELEASE_CHROME_APPS=$(RELEASE_DIR)/chrome-apps
RELEASE_RESOURCE_DIR=
RELEASE_CHROME_APPS_RESOURCE_DIR=$(foreach path,$(RELEASE_RESOURCE_DIR),$(addprefix $(RELEASE_CHROME_APPS)/,$(path)))
BUILD_DIR=build
RELEASE_RESOURCE_SRC_DIR=$(BUILD_DIR)/web
RELEASE_CHROME_APPS_RESOURCE_SRC=$(addprefix $(BUILD_DIR)/,$(RELEASE_CHROME_APPS_RESOURCE))
RELEASE_CHROME_APPS_RESOURCE_DST=$(foreach path,$(RELEASE_CHROME_APPS_RESOURCE_SRC),$(subst $(RELEASE_RESOURCE_SRC_DIR),$(RELEASE_CHROME_APPS),$(path)))
chrome-apps: $(VERSION) $(ENDPOINTS_LIB) $(RESOURCE) $(RELEASE_CHROME_APPS) $(DART_JS) $(RELEASE_CHROME_APPS_RESOURCE_DST)
	@if [ "$(strip $(RELEASE_CHROME_APPS_RESOURCE_DIR))" != "" ]; then\
		make $(RELEASE_CHROME_APPS_RESOURCE_DIR);\
	fi;
	@if [ $(DART_JS) -nt $(RELEASE_CHROME_APPS)/main.dart.precompiled.js ]; then\
		echo "cp $(DART_JS) $(RELEASE_CHROME_APPS)/main.dart.precompiled.js";\
		cp $(DART_JS) $(RELEASE_CHROME_APPS)/main.dart.precompiled.js;\
	fi;
	$(foreach path,$(shell find $(RELEASE_RESOURCE_SRC_DIR) -name "*.html.*.js"),$(shell\
		if [ $(path) -nt $(subst $(RELEASE_RESOURCE_SRC_DIR),$(RELEASE_CHROME_APPS),$(path)) ]; then\
			cp $(path) $(subst $(RELEASE_RESOURCE_SRC_DIR),$(RELEASE_CHROME_APPS),$(path));\
		fi;\
	))
	$(foreach path,$(shell find $(RELEASE_RESOURCE_SRC_DIR) -name "*.html_bootstrap.dart.precompiled.js"),$(shell\
		if [ $(path) -nt $(subst .precompiled.js,.js,$(subst $(RELEASE_RESOURCE_SRC_DIR),$(RELEASE_CHROME_APPS),$(path))) ]; then\
			cp $(path) $(subst .precompiled.js,.js,$(subst $(RELEASE_RESOURCE_SRC_DIR),$(RELEASE_CHROME_APPS),$(path)));\
		fi;\
	))
	cd $(RELEASE_DIR) && zip -r -9 -FS chrome-apps.zip chrome-apps

$(RELEASE_CHROME_APPS): $(RELEASE_DIR)
	mkdir -p $@

$(RELEASE_DIR):
	mkdir $@

$(RELEASE_CHROME_APPS_RESOURCE_DST): $(RELEASE_CHROME_APPS_RESOURCE_SRC) $(DART_JS)
	@if [ ! -d $(dir $@) ]; then\
		mkdir -p $(dir $@);\
	fi;
	@if [ $(subst $(RELEASE_CHROME_APPS),$(RELEASE_RESOURCE_SRC_DIR),$@) -nt $@ ]; then\
		cp $(subst $(RELEASE_CHROME_APPS),$(RELEASE_RESOURCE_SRC_DIR),$@) $@;\
	fi;

$(RELEASE_DIR)/%: %
	@mkdir -p $(dir $@)
	@if [ -d $< ]; then\
		echo "cp -r $< $@";\
		cp -r $< $@;\
	else\
		if [ $< -nt $@ ]; then\
		  echo "cp $< $@";\
		  cp $< $@;\
		fi;\
	fi;

DART=$(foreach dir,$(RESOURCE_DIR),$(wildcard $(dir)/*.dart))
$(DART_JS): pubspec.yaml $(DART)
	pub build

$(RELEASE_CHROME_APPS_RESOURCE_DIR): $(foreach path,$(RELEASE_RESOURCE_DIR),$(addprefix $(RELEASE_RESOURCE_SRC_DIR)/,$(path)))
	cp -r $(subst $(RELEASE_CHROME_APPS),$(RELEASE_RESOURCE_SRC_DIR),$@) $@
	rm -f $(foreach path,$(shell find release/chrome-apps -type f -name *.min.css),$(subst .min.css,.css,$(path)))
	rm -f $(foreach path,$(shell find release/chrome-apps -type f -name *.min.js),$(subst .min.js,.js,$(path)))


RESOURCE_SUFFIX_FOR_BUILD = html css json js
RESOURCE_DIR_FOR_BUILD = web web/js web/view web/packages/dart-chrome-app/component web/packages/dart-chrome-app/routing web/packages/dart-chrome-app/service
RESOURCE_FOR_BUILD = $(foreach suffix,$(RESOURCE_SUFFIX_FOR_BUILD),$(foreach dir,$(RESOURCE_DIR_FOR_BUILD),$(wildcard $(dir)/*.$(suffix))))
BUILD_RESOURCE = $(addprefix build/,$(RESOURCE_FOR_BUILD))

build/%: %
	@mkdir -p $(dir $@)
	cp $< $@


clean:
	rm -f $(VERSION) $(RESOURCE)
	rm -rf $(BUILD_DIR) $(RELEASE_DIR)
	git checkout release/ios/config.xml

clean-all: clean
	rm -f pubspec.lock pubspec.yaml.orig pubspec.yaml.rej
	rm -rf $(ENDPOINTS_LIB) packages
	find . -name "*.sw?" -delete
	find . -name .DS_Store -delete
	find . -name packages -type l -delete
	find . -type d -name .sass-cache |xargs rm -rf

.PHONY: $(VERSION)
