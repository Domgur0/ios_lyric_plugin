ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = iOSLyricPrefs
iOSLyricPrefs_FILES = LPPRootListController.m
iOSLyricPrefs_FRAMEWORKS = UIKit
iOSLyricPrefs_PRIVATE_FRAMEWORKS = Preferences
iOSLyricPrefs_INSTALL_PATH = /Library/PreferenceBundles
iOSLyricPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
