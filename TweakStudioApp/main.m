#import <UIKit/UIKit.h>
#import "TSTweakStudioUI.h"
#import "TSStudioCore.h"

@interface TweakStudioAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end

@implementation TweakStudioAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=[TSTweakStudioTabController new];
    [self.window makeKeyAndVisible];
    return YES;
}
- (void)applicationDidEnterBackground:(UIApplication *)application { [TSLocalModelManager.shared stopModel]; }
- (void)applicationWillTerminate:(UIApplication *)application { [TSLocalModelManager.shared stopModel]; }
@end

int main(int argc,char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(TweakStudioAppDelegate.class)); }
}
