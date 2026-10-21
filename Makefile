ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = TweakStudioPrefs
TweakStudioPrefs_FILES = TweakStudioPrefs/TSRootListController.m TweakStudioPrefs/TSEditorController.m
TweakStudioPrefs_FRAMEWORKS = UIKit Foundation
TweakStudioPrefs_PRIVATE_FRAMEWORKS = Preferences
TweakStudioPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
TweakStudioPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
