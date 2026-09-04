ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = iOSLyricPlugin

iOSLyricPlugin_FILES = Tweak.xm LPLyricModels.m LPLyricFetcher.m LPLyricHUDView.m

iOSLyricPlugin_CFLAGS = -fobjc-arc

iOSLyricPlugin_FRAMEWORKS = UIKit Foundation CoreGraphics MediaPlayer

iOSLyricPlugin_PRIVATE_FRAMEWORKS = MediaRemote

SUBPROJECTS += ioslyricprefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

.PHONY: package-rootless package-roothide package-both

package-rootless:
	$(MAKE) package THEOS_PACKAGE_SCHEME=rootless

package-roothide:
	$(MAKE) package THEOS_PACKAGE_SCHEME=roothide

package-both:
	$(MAKE) clean package-rootless
	$(MAKE) clean package-roothide
