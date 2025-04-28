# Makefile for KnightBrowser.app

APP_NAME := KnightBrowser
SRC      := KnightBrowser.m
EXEC     := $(APP_NAME).app/Contents/MacOS/$(APP_NAME)
PLIST    := Info.plist

.PHONY: all bundle run clean

all: bundle

# 1) Compile the Objective-C source into the .app bundle
$(EXEC): $(SRC)
	@echo "→ Compiling $(SRC) → $(EXEC)"
	@mkdir -p $(APP_NAME).app/Contents/MacOS
	clang -fobjc-arc $(SRC) -o $(EXEC) \
	      -framework Cocoa -framework WebKit

# 2) Bundle step: copy Info.plist into place
bundle: $(EXEC) $(PLIST)
	@echo "→ Bundling .app with Info.plist"
	@mkdir -p $(APP_NAME).app/Contents
	@cp $(PLIST) $(APP_NAME).app/Contents/

# 3) Launch via `open`
run: bundle
	@echo "→ Launching $(APP_NAME).app"
	open $(APP_NAME).app

# 4) Clean up generated bundle
clean:
	@echo "→ Cleaning up"
	@rm -rf $(APP_NAME).app
