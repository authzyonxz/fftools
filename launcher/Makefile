# External launcher — MH_EXECUTE stub (Theos tool target)
export THEOS ?= $(HOME)/theos
export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64
export DEBUG = 0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = External
External_FILES = main.c
External_CFLAGS = -std=gnu17

include $(THEOS_MAKE_PATH)/tool.mk
