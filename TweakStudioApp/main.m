#import <UIKit/UIKit.h>
#import "../TweakStudioPrefs/TSRootListController.h"

@interface TweakStudioAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation TweakStudioAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    TSRootListController *workspace = [TSRootListController new];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:workspace];
    navigation.navigationBar.prefersLargeTitles = YES;
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(TweakStudioAppDelegate.class));
    }
}
