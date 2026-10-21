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
TweakStudioPrefs_RESOURCE_DIRS = TweakStudioPrefs/Resources

include $(THEOS_MAKE_PATH)/bundle.mk

APPLICATION_NAME = TweakStudioApp
TweakStudioApp_ARCHS = arm64
TweakStudioApp_FILES = TweakStudioApp/main.m TweakStudioPrefs/TSRootListController.m TweakStudioPrefs/TSEditorController.m
TweakStudioApp_FRAMEWORKS = UIKit Foundation
TweakStudioApp_PRIVATE_FRAMEWORKS = Preferences
TweakStudioApp_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
TweakStudioApp_RESOURCE_DIRS = TweakStudioApp/Resources
TweakStudioApp_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk
