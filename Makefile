# FFPatch — dylib target (Theos)
#
#   make            → .theos/obj/debug/ffpatch.dylib
#   make package    → theos deb (not what an IPA needs — use Scripts/build_ipa.sh)
#
# The app itself is this dylib; launcher/main.c is the MH_EXECUTE stub.
# Tested target: arm64, iOS 15.0+ (device runtime 17.0–27.x per SupportPolicy).

export THEOS ?= $(HOME)/theos
export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64
export DEBUG = 0
export FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = ffpatch

ffpatch_FILES = $(wildcard Sources/*.m) \
                $(wildcard Sources/UI/*.m) $(wildcard Sources/Auth/*.m) \
                $(wildcard Sources/Vendor/*.m) \
                $(wildcard Sources/Vendor/*.c)

ffpatch_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore CoreFoundation IOSurface \
                     Security CFNetwork SystemConfiguration
# IOSurface só existe como private framework no iOS: o Theos precisa do caminho
# extra para resolver os headers do kexploit (IOSurfaceRef.h).
ffpatch_PRIVATE_FRAMEWORKS = IOSurface

ffpatch_CFLAGS = -fobjc-arc -std=gnu17 -fblocks -fvisibility=hidden -DFF_ENABLE_ANTIDEBUG=1 \
                 -I$(THEOS_PROJECT_DIR)/Sources \
                 -I$(THEOS_PROJECT_DIR)/Sources/Vendor \
                 -I$(THEOS_PROJECT_DIR)/Sources/Auth \
                 -Wno-deprecated-declarations \
                 -Wno-unused-variable \
                 -Wno-unused-function \
                 -Wno-nullability-completeness \
                 -Wno-incompatible-pointer-types



ffpatch_LDFLAGS = $(THEOS_PROJECT_DIR)/.auth-vm-objects/KAPolicy.o $(THEOS_PROJECT_DIR)/.auth-vm-objects/KAVMRuntime.o  -Wl,-x -Wl,-dead_strip -ObjC -lz -lc++

include $(THEOS_MAKE_PATH)/library.mk

# A dylib sozinha não vira IPA: empacote com Scripts/package_ipa_theos.sh
# (o build_theos.sh já faz isso automaticamente).
after-ffpatch-all::
	@echo "FFPatch: dylib em $(THEOS_OBJ_DIR)/ffpatch.dylib"
	@echo "FFPatch: para gerar a IPA → Scripts/package_ipa_theos.sh"


before-all::
	bash "$(THEOS_PROJECT_DIR)/Scripts/build_auth_vm.sh" "$(THEOS_PROJECT_DIR)/.auth-vm-objects"
