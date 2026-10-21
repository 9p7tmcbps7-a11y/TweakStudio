#import "TSProjectService.h"
#import "TSStudioCore.h"
#import <spawn.h>
#import <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>

extern char **environ;

@implementation TSProjectService
+ (NSArray<NSString *> *)projectNames {
    [TSStudioPaths prepareDirectories];
    NSArray *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:TSStudioPaths.projectsPath error:nil] ?: @[];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *name in names) {
        BOOL directory = NO; NSString *path = [TSStudioPaths.projectsPath stringByAppendingPathComponent:name];
        if ([NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&directory] && directory && ![name hasPrefix:@"."]) [out addObject:name];
    }
    return [out sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}
+ (NSString *)createProjectNamed:(NSString *)rawName type:(NSString *)type error:(NSError **)error {
    NSString *name = [rawName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSCharacterSet *first = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"];
    if (!name.length || name.length > 36 || [name rangeOfCharacterFromSet:first].location != 0 || [name rangeOfCharacterFromSet:allowed.invertedSet].location != NSNotFound || ![@[@"tweak", @"app"] containsObject:type]) {
        if (error) *error = [NSError errorWithDomain:@"TweakStudio.Project" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Use a project name starting with a letter and containing only letters, numbers, or underscores."}]; return nil;
    }
    [TSStudioPaths prepareDirectories];
    NSString *path = [TSStudioPaths.projectsPath stringByAppendingPathComponent:name];
    if ([NSFileManager.defaultManager fileExistsAtPath:path]) { if (error) *error = [NSError errorWithDomain:@"TweakStudio.Project" code:2 userInfo:@{NSLocalizedDescriptionKey:@"A project with this name already exists."}]; return nil; }
    if (![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]) return nil;
    NSString *bundleID = [NSString stringWithFormat:@"com.example.%@", name.lowercaseString];
    NSString *makefile, *control, *primary;
    if ([type isEqualToString:@"tweak"]) {
        makefile = [NSString stringWithFormat:@"THEOS ?= $(HOME)/theos\nTARGET := iphone:clang:latest:15.0\nARCHS := arm64\nTHEOS_PACKAGE_SCHEME := rootless\ninclude $(THEOS)/makefiles/common.mk\nTWEAK_NAME := %@\n%@_FILES := Tweak.xm\ninclude $(THEOS_MAKE_PATH)/tweak.mk\n", name, name];
        control = [NSString stringWithFormat:@"Package: %@\nName: %@\nVersion: 0.1.0\nArchitecture: iphoneos-arm64\nDescription: Rootless iOS tweak\nMaintainer: Developer\nSection: Tweaks\n", bundleID, name];
        primary = [NSString stringWithFormat:@"#import <Foundation/Foundation.h>\n\n%%ctor {\n    NSLog(@\"[%@] Loaded.\");\n}\n", name];
        [@"{ Filter = { Bundles = (\"com.apple.springboard\"); }; }\n" writeToFile:[path stringByAppendingPathComponent:[name stringByAppendingString:@".plist"]] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [primary writeToFile:[path stringByAppendingPathComponent:@"Tweak.xm"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        makefile = [NSString stringWithFormat:@"THEOS ?= $(HOME)/theos\nTARGET := iphone:clang:latest:15.0\nARCHS := arm64\nTHEOS_PACKAGE_SCHEME := rootless\ninclude $(THEOS)/makefiles/common.mk\nAPPLICATION_NAME := %@\n%@_FILES := main.m\n%@_FRAMEWORKS := UIKit\ninclude $(THEOS_MAKE_PATH)/application.mk\n", name, name, name];
        control = [NSString stringWithFormat:@"Package: %@\nName: %@\nVersion: 0.1.0\nArchitecture: iphoneos-arm64\nDepends: firmware (>= 15.0), uikittools\nDescription: UIKit app\nMaintainer: Developer\nSection: Applications\n", bundleID, name];
        primary = [NSString stringWithFormat:@"#import <UIKit/UIKit.h>\n\n@interface AppDelegate : UIResponder <UIApplicationDelegate>\n@property(nonatomic,strong) UIWindow *window;\n@end\n@implementation AppDelegate\n- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {\n self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];\n UIViewController *controller = [UIViewController new]; controller.view.backgroundColor = UIColor.systemBackgroundColor;\n UILabel *label = [[UILabel alloc] initWithFrame:controller.view.bounds]; label.text = @\"%@ starts here\"; label.textAlignment = NSTextAlignmentCenter; label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; [controller.view addSubview:label];\n self.window.rootViewController = controller; [self.window makeKeyAndVisible]; return YES;\n}\n@end\nint main(int argc, char *argv[]) { @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); } }\n", name];
        [primary writeToFile:[path stringByAppendingPathComponent:@"main.m"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSString *resources=[path stringByAppendingPathComponent:@"Resources"]; [NSFileManager.defaultManager createDirectoryAtPath:resources withIntermediateDirectories:YES attributes:nil error:nil];
        NSArray *iconNames=@[@"AppIcon29x29",@"AppIcon40x40",@"AppIcon57x57",@"AppIcon60x60",@"AppIcon76x76",@"AppIcon83.5x83.5"];
        NSDictionary *primaryIcon=@{@"CFBundleIconFiles":iconNames,@"UIPrerenderedIcon":@NO};
        NSDictionary *info = @{@"CFBundleExecutable":name,@"CFBundleIdentifier":bundleID,@"CFBundleName":name,@"CFBundleDisplayName":name,@"CFBundlePackageType":@"APPL",@"CFBundleVersion":@"1",@"CFBundleShortVersionString":@"1.0",@"LSRequiresIPhoneOS":@YES,@"MinimumOSVersion":@"15.0",@"UIDeviceFamily":@[@1,@2],@"CFBundleIcons":@{@"CFBundlePrimaryIcon":primaryIcon},@"CFBundleIcons~ipad":@{@"CFBundlePrimaryIcon":primaryIcon}};
        [info writeToFile:[resources stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
        NSArray *iconFiles=@[@"AppIcon29x29@2x.png",@"AppIcon29x29@3x.png",@"AppIcon40x40@2x.png",@"AppIcon40x40@3x.png",@"AppIcon57x57@2x.png",@"AppIcon60x60@2x.png",@"AppIcon60x60@3x.png",@"AppIcon76x76@2x.png",@"AppIcon83.5x83.5@2x.png"];
        for(NSString *icon in iconFiles){NSString *source=[NSBundle.mainBundle pathForResource:icon.stringByDeletingPathExtension ofType:@"png"];if(source){NSString *target=[resources stringByAppendingPathComponent:icon];[NSFileManager.defaultManager copyItemAtPath:source toPath:target error:nil];}}
        NSString *debian=[path stringByAppendingPathComponent:@"layout/DEBIAN"];[NSFileManager.defaultManager createDirectoryAtPath:debian withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *postinst=[NSString stringWithFormat:@"#!/bin/sh\n/var/jb/usr/bin/uicache -p /var/jb/Applications/%@.app >/dev/null 2>&1 || true\nexit 0\n",name];NSString *hook=[debian stringByAppendingPathComponent:@"postinst"];[postinst writeToFile:hook atomically:YES encoding:NSUTF8StringEncoding error:nil];[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0755} ofItemAtPath:hook error:nil];
    }
    [makefile writeToFile:[path stringByAppendingPathComponent:@"Makefile"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [control writeToFile:[path stringByAppendingPathComponent:@"control"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSString *metadata = [NSString stringWithFormat:@"{\n  \"name\": \"%@\",\n  \"type\": \"%@\",\n  \"created\": \"%@\"\n}\n", name, type, [NSDate.date description]];
    [metadata writeToFile:[path stringByAppendingPathComponent:@".tweakstudio-project.json"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSString *readme = [NSString stringWithFormat:@"# %@\n\nCreated with TweakStudio. Open the AI tab, select a local model, and describe what you want to build. Review proposed file changes before applying them.\n", name];
    [readme writeToFile:[path stringByAppendingPathComponent:@"README.md"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [TSStudioPaths setCurrentProject:path]; [TSActivityLog record:[NSString stringWithFormat:@"Created %@ project %@", type, name] category:@"project"];
    return path;
}
+ (NSString *)newestDebForProject:(NSString *)path {
    NSString *folder = [path stringByAppendingPathComponent:@"packages"];
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:folder error:nil] ?: @[];
    NSString *best = nil; NSDate *date = [NSDate distantPast];
    for (NSString *file in files) if ([file.pathExtension.lowercaseString isEqualToString:@"deb"]) {
        NSString *candidate = [folder stringByAppendingPathComponent:file];
        NSDate *modified = [NSFileManager.defaultManager attributesOfItemAtPath:candidate error:nil][NSFileModificationDate] ?: [NSDate distantPast];
        if ([modified compare:date] == NSOrderedDescending) { date = modified; best = candidate; }
    }
    return best;
}
+ (BOOL)isSafeRelativeProjectFile:(NSString *)relativePath {
    if (![relativePath isKindOfClass:NSString.class] || !relativePath.length || relativePath.length > 180 || [relativePath hasPrefix:@"/"] || [relativePath containsString:@"\\"] || [relativePath containsString:@".."] || [relativePath containsString:@":"]) return NO;
    NSArray *parts = [relativePath componentsSeparatedByString:@"/"];
    if (parts.count > 3) return NO;
    for (NSString *part in parts) if (!part.length || [part isEqualToString:@"."] || [part hasPrefix:@"."]) return NO;
    NSString *lower = relativePath.lowercaseString;
    if ([lower containsString:@".theos"] || [lower containsString:@"packages/"] || [lower containsString:@".git/"] || [lower containsString:@"debian/"] || [lower containsString:@"postinst"] || [lower containsString:@"preinst"] || [lower containsString:@"prerm"] || [lower containsString:@"postrm"]) return NO;
    NSSet *allowed = [NSSet setWithArray:@[@"m",@"mm",@"xm",@"x",@"h",@"hpp",@"plist",@"strings",@"json",@"md",@"txt"]];
    return [@[@"makefile",@"control"] containsObject:lower] || [allowed containsObject:lower.pathExtension];
}
@end

@implementation TSBuildService
+ (void)buildProject:(NSString *)path completion:(void (^)(BOOL, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int fds[2]; if (pipe(fds) != 0) { dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, @"Unable to create build output pipe."); }); return; }
        posix_spawn_file_actions_t actions; posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_adddup2(&actions, fds[1], STDOUT_FILENO); posix_spawn_file_actions_adddup2(&actions, fds[1], STDERR_FILENO);
        posix_spawn_file_actions_addclose(&actions, fds[0]); posix_spawn_file_actions_addclose(&actions, fds[1]);
        const char *argv[] = {"build-project", path.fileSystemRepresentation, NULL}; pid_t pid = 0;
        const char *script = "/var/jb/usr/libexec/tweakstudio/build-project";
        int spawnError = posix_spawn(&pid, script, &actions, NULL, (char * const *)argv, environ);
        posix_spawn_file_actions_destroy(&actions); close(fds[1]);
        NSMutableData *outputData = [NSMutableData data];
        if (!spawnError) { char buffer[4096]; ssize_t count; while ((count = read(fds[0], buffer, sizeof(buffer))) > 0) { if (outputData.length < 2*1024*1024) [outputData appendBytes:buffer length:(NSUInteger)count]; } }
        close(fds[0]); int status=0; if (!spawnError) waitpid(pid,&status,0);
        NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] ?: @"";
        BOOL ok = !spawnError && WIFEXITED(status) && WEXITSTATUS(status)==0;
        NSString *logPath = [[TSStudioPaths.workspacePath stringByAppendingPathComponent:@"Logs"] stringByAppendingPathComponent:@"latest-build.log"];
        [output writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [TSActivityLog record:[NSString stringWithFormat:@"Build %@ for %@ (%lu bytes of output).", ok?@"succeeded":@"failed", path.lastPathComponent, (unsigned long)outputData.length] category:ok?@"build":@"error"];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, output); });
    });
}
+ (void)setupToolchain:(void (^)(BOOL, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        [TSStudioPaths prepareDirectories];
        int fds[2]; if(pipe(fds)!=0){dispatch_async(dispatch_get_main_queue(),^{completion(NO,@"Unable to create setup output pipe.");});return;}
        posix_spawn_file_actions_t actions;posix_spawn_file_actions_init(&actions);posix_spawn_file_actions_adddup2(&actions,fds[1],STDOUT_FILENO);posix_spawn_file_actions_adddup2(&actions,fds[1],STDERR_FILENO);posix_spawn_file_actions_addclose(&actions,fds[0]);posix_spawn_file_actions_addclose(&actions,fds[1]);
        const char *argv[]={"bash","-lc","exec /var/jb/usr/libexec/tweakstudio/setup-theos",NULL};pid_t pid=0;const char *shell="/var/jb/bin/bash";int spawnError=posix_spawn(&pid,shell,&actions,NULL,(char * const *)argv,environ);posix_spawn_file_actions_destroy(&actions);close(fds[1]);NSMutableData *data=[NSMutableData data];
        if(!spawnError){char buffer[4096];ssize_t count;while((count=read(fds[0],buffer,sizeof(buffer)))>0){if(data.length<2*1024*1024)[data appendBytes:buffer length:(NSUInteger)count];}}
        close(fds[0]);int status=0;if(!spawnError)waitpid(pid,&status,0);NSString *output=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]?:@"";BOOL success=!spawnError&&WIFEXITED(status)&&WEXITSTATUS(status)==0;
        NSString *logPath=[[TSStudioPaths.workspacePath stringByAppendingPathComponent:@"Logs"]stringByAppendingPathComponent:@"latest-setup.log"];[output writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];[TSActivityLog record:[NSString stringWithFormat:@"Theos/SDK setup %@ (%lu bytes of output).",success?@"succeeded":@"failed",(unsigned long)data.length] category:success?@"setup":@"error"];
        dispatch_async(dispatch_get_main_queue(),^{completion(success,output);});
    });
}
@end
