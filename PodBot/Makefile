APP_NAME := podbot
BUILD_DIR := build
SOURCES := main.swift Utils.swift Model.swift PodcastXMLParser.swift
DESKTOP_BIN := $(HOME)/Desktop/$(APP_NAME)

.PHONY: all build install clean

all: $(BUILD_DIR)/$(APP_NAME)

install: all
	cp -fX "$(BUILD_DIR)/$(APP_NAME)" "$(DESKTOP_BIN)"
	@echo "Installed $(APP_NAME) to $(DESKTOP_BIN)"

build: all

$(BUILD_DIR)/$(APP_NAME): $(SOURCES)
	mkdir -p "$(BUILD_DIR)"
	swiftc $(SOURCES) -o "$(BUILD_DIR)/$(APP_NAME)"

clean:
	rm -rf "$(BUILD_DIR)"
