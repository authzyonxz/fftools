# FFPatch launcher — MH_EXECUTE stub (Theos tool target)
export THEOS ?= $(HOME)/theos
export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64
export DEBUG = 0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = ffpatch_launcher
ffpatch_launcher_FILES = main.c
ffpatch_launcher_CFLAGS = -std=gnu17

include $(THEOS_MAKE_PATH)/tool.mk
