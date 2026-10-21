#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "TSRootListController.h"
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>
#import <errno.h>
#import "TSEditorController.h"

extern char **environ;

@interface TSRootListController ()
@property (nonatomic, copy) NSString *projectName;
@property (nonatomic, copy) NSString *lastProjectPath;
@property (nonatomic, copy) NSString *lastDebPath;
@end

@implementation TSRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"TweakStudio";
    self.projectName = [[NSUserDefaults standardUserDefaults] stringForKey:@"TSProjectName"] ?: @"HelloTweak";
    self.lastProjectPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"TSLastProjectPath"];
    self.lastDebPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"TSLastDebPath"];
    if (!self.lastProjectPath || ![NSFileManager.defaultManager fileExistsAtPath:self.lastProjectPath]) {
        NSArray<NSString *> *projects = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[self workspacePath] error:nil];
        NSDate *latestDate = [NSDate distantPast];
        for (NSString *project in projects) {
            NSString *candidate = [[self workspacePath] stringByAppendingPathComponent:project];
            BOOL isDirectory = NO;
            if (![NSFileManager.defaultManager fileExistsAtPath:candidate isDirectory:&isDirectory] || !isDirectory) continue;
            NSDate *modified = [[NSFileManager.defaultManager attributesOfItemAtPath:candidate error:nil] objectForKey:NSFileModificationDate] ?: [NSDate distantPast];
            if ([modified compare:latestDate] == NSOrderedDescending) { latestDate = modified; self.lastProjectPath = candidate; self.projectName = project; }
        }
    }
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[PSSpecifier groupSpecifierWithName:@"Workspace"]];
    PSSpecifier *name = [PSSpecifier preferenceSpecifierNamed:@"Project name" target:self set:@selector(setProjectName:specifier:) get:@selector(projectNameForSpecifier:) detail:nil cell:PSEditTextCell edit:nil];
    [name setProperty:@"TSProjectName" forKey:@"key"];
    [name setProperty:@"Starts with a letter" forKey:@"placeholder"];
    [items addObject:name];
    [items addObject:[self button:@"New tweak project" action:@selector(createTweakProject)]];
    [items addObject:[self button:@"New app project" action:@selector(createAppProject)]];
    [items addObject:[self button:@"Choose existing project" action:@selector(chooseProject)]];
    [items addObject:[self button:@"Edit project source" action:@selector(editProject)]];

    [items addObject:[PSSpecifier groupSpecifierWithName:@"Build"]];
    [items addObject:[self button:@"Set up Theos + iOS SDK" action:@selector(setupTheos)]];
    [items addObject:[self button:@"Build current project (.deb)" action:@selector(buildProject)]];
    [items addObject:[self button:@"Share latest package" action:@selector(sharePackage)]];

    [items addObject:[PSSpecifier groupSpecifierWithName:@"About"]];
    PSSpecifier *about = [PSSpecifier preferenceSpecifierNamed:@"TweakStudio 0.3 · Rootless project workspace" target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
    [items addObject:about];
    PSSpecifier *folder = [PSSpecifier preferenceSpecifierNamed:@"Projects are saved in Documents/TweakStudio/Projects" target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
    [items addObject:folder];
    _specifiers = items;
    return _specifiers;
}

- (PSSpecifier *)button:(NSString *)title action:(SEL)selector {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:title target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    specifier.buttonAction = selector;
    return specifier;
}

- (void)setProjectName:(id)value specifier:(PSSpecifier *)specifier {
    self.projectName = [value isKindOfClass:NSString.class] ? value : @"";
    [[NSUserDefaults standardUserDefaults] setObject:self.projectName forKey:@"TSProjectName"];
}

- (id)projectNameForSpecifier:(PSSpecifier *)specifier {
    return self.projectName ?: @"HelloTweak";
}

- (NSString *)workspacePath {
    return @"/var/mobile/Documents/TweakStudio/Projects";
}

- (NSString *)validatedProjectName {
    NSString *name = [self.projectName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length == 0 || name.length > 36) return nil;
    NSCharacterSet *letters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    if ([name rangeOfCharacterFromSet:letters].location != 0) return nil;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"];
    if ([name rangeOfCharacterFromSet:allowed.invertedSet].location != NSNotFound) return nil;
    return name;
}

- (void)createTweakProject { [self createProjectOfType:@"tweak"]; }
- (void)createAppProject { [self createProjectOfType:@"app"]; }

- (void)createProjectOfType:(NSString *)type {
    NSString *name = [self validatedProjectName];
    if (!name) { [self alert:@"Invalid project name" message:@"Start with a letter, then use up to 35 letters, numbers, or underscores."]; return; }
    NSString *path = [[self workspacePath] stringByAppendingPathComponent:name];
    NSFileManager *fm = NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:path]) { [self alert:@"Project already exists" message:path]; return; }
    NSError *error = nil;
    [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) { [self alert:@"Could not create project" message:error.localizedDescription]; return; }

    NSString *bundleID = [NSString stringWithFormat:@"com.example.%@", [name.lowercaseString stringByReplacingOccurrencesOfString:@"-" withString:@"_"]];
    NSString *makefile = nil, *control = nil, *source = nil;
    NSString *sourceFile = nil;
    if ([type isEqualToString:@"tweak"]) {
        makefile = [NSString stringWithFormat:@"THEOS ?= $(HOME)/theos\nTARGET := iphone:clang:latest:15.0\nARCHS := arm64 arm64e\nTHEOS_PACKAGE_SCHEME := rootless\nINSTALL_TARGET_PROCESSES := SpringBoard\ninclude $(THEOS)/makefiles/common.mk\nTWEAK_NAME := %@\n%@_FILES := Tweak.xm\ninclude $(THEOS_MAKE_PATH)/tweak.mk\n", name, name];
        control = [NSString stringWithFormat:@"Package: %@\nName: %@\nVersion: 0.1.0\nArchitecture: iphoneos-arm64\nDescription: Rootless tweak project\nMaintainer: Developer\nSection: Tweaks\n", bundleID, name];
        source = [NSString stringWithFormat:@"#import <Foundation/Foundation.h>\n\n%%ctor {\n    NSLog(@\"[%@] Loaded. Replace this starter with your tweak.\");\n}\n", name];
        sourceFile = @"Tweak.xm";
        NSString *filter = @"{ Filter = { Bundles = (\"com.apple.springboard\"); }; }\n";
        [filter writeToFile:[path stringByAppendingPathComponent:[name stringByAppendingString:@".plist"]] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        makefile = [NSString stringWithFormat:@"THEOS ?= $(HOME)/theos\nTARGET := iphone:clang:latest:15.0\nARCHS := arm64\ninclude $(THEOS)/makefiles/common.mk\nAPPLICATION_NAME := %@\n%@_FILES := main.m\n%@_FRAMEWORKS := UIKit\ninclude $(THEOS_MAKE_PATH)/application.mk\n", name, name, name];
        control = [NSString stringWithFormat:@"Package: %@\nName: %@\nVersion: 0.1.0\nArchitecture: iphoneos-arm64\nDescription: UIKit app project\nMaintainer: Developer\nSection: Applications\n", bundleID, name];
        source = @"#import <UIKit/UIKit.h>\n\n@interface AppDelegate : UIResponder <UIApplicationDelegate>\n@property (nonatomic, strong) UIWindow *window;\n@end\n\n@implementation AppDelegate\n- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {\n    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];\n    UIViewController *vc = [UIViewController new];\n    vc.view.backgroundColor = UIColor.systemBackgroundColor;\n    UILabel *label = [[UILabel alloc] initWithFrame:vc.view.bounds];\n    label.text = @\"Your app starts here\";\n    label.textAlignment = NSTextAlignmentCenter;\n    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;\n    [vc.view addSubview:label];\n    self.window.rootViewController = vc;\n    [self.window makeKeyAndVisible];\n    return YES;\n}\n@end\n\nint main(int argc, char *argv[]) { @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); } }\n";
        sourceFile = @"main.m";
        NSString *info = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>%@</string><key>CFBundleName</key><string>%@</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>1.0</string></dict></plist>\n", bundleID, name];
        [info writeToFile:[path stringByAppendingPathComponent:@"Info.plist"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    [makefile writeToFile:[path stringByAppendingPathComponent:@"Makefile"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [control writeToFile:[path stringByAppendingPathComponent:@"control"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [source writeToFile:[path stringByAppendingPathComponent:sourceFile] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSString *readme = [NSString stringWithFormat:@"# %@\n\nTweakStudio %@ starter project.\n\nEdit the source from Settings → TweakStudio, then tap Build current project.\n\nTheos path: `~/theos`. For tweak projects, packages are rootless and target iOS 15+.\n", name, type];
    [readme writeToFile:[path stringByAppendingPathComponent:@"README.md"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    self.lastProjectPath = path;
    [[NSUserDefaults standardUserDefaults] setObject:path forKey:@"TSLastProjectPath"];
    [self alert:@"Project created" message:[NSString stringWithFormat:@"%@ starter saved at:\n%@\n\nOpen Edit project source to change %@.", type.capitalizedString, path, sourceFile]];
}

- (void)editProject {
    if (!self.lastProjectPath || ![NSFileManager.defaultManager fileExistsAtPath:self.lastProjectPath]) { [self alert:@"No project yet" message:@"Create a tweak or app project first."]; return; }
    TSEditorController *editor = [[TSEditorController alloc] initWithProjectPath:self.lastProjectPath];
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)chooseProject {
    NSArray *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[self workspacePath] error:nil];
    NSMutableArray *projects = [NSMutableArray array];
    for (NSString *name in names) {
        NSString *path = [[self workspacePath] stringByAppendingPathComponent:name];
        BOOL isDirectory = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) [projects addObject:name];
    }
    if (projects.count == 0) { [self alert:@"No projects" message:@"Create a tweak or app project first."]; return; }
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"Choose a project" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *name in projects) {
        [picker addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            self.lastProjectPath = [[self workspacePath] stringByAppendingPathComponent:name];
            [[NSUserDefaults standardUserDefaults] setObject:self.lastProjectPath forKey:@"TSLastProjectPath"];
            self.projectName = name;
            [[NSUserDefaults standardUserDefaults] setObject:name forKey:@"TSProjectName"];
            [self reloadSpecifiers];
        }]];
    }
    [picker addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)setupTheos {
    NSString *cmd = @"set -e; export PATH=\"/var/jb/usr/bin:/var/jb/bin:$PATH\"; WORKSPACE=/var/mobile/Documents/TweakStudio; THEOS=\"$WORKSPACE/theos\"; mkdir -p \"$WORKSPACE\"; if [ ! -f \"$THEOS/makefiles/common.mk\" ]; then git clone --depth 1 --recursive https://github.com/theos/theos.git \"$THEOS\"; fi; THEOS=\"$THEOS\" \"$THEOS/bin/install-sdk\" latest; mkdir -p \"$WORKSPACE/tools\" \"$WORKSPACE/bin\"; if [ ! -f \"$WORKSPACE/tools/allemande/main.cpp\" ]; then git clone --depth 1 https://github.com/p0358/allemande.git \"$WORKSPACE/tools/allemande\"; fi; clang++ -std=c++20 -O2 -o \"$WORKSPACE/bin/allemande\" \"$WORKSPACE/tools/allemande/main.cpp\"; chmod 755 \"$WORKSPACE/bin/allemande\"";
    [self runCommand:cmd title:@"Preparing Theos and the iOS SDK…"];
}

- (void)buildProject {
    if (!self.lastProjectPath || ![NSFileManager.defaultManager fileExistsAtPath:self.lastProjectPath]) { [self alert:@"No project yet" message:@"Create a project first."]; return; }
    NSString *cmd = [NSString stringWithFormat:@"export THEOS=/var/mobile/Documents/TweakStudio/theos; export PATH=\"/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin:$PATH\"; /var/jb/usr/libexec/tweakstudio/build-project '%@'", self.lastProjectPath];
    [self runCommand:cmd title:@"Building project…"];
}

- (void)runCommand:(NSString *)command title:(NSString *)title {
    UIAlertController *progress = [UIAlertController alertControllerWithTitle:title message:@"This may take a few minutes. Keep TweakStudio open." preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progress animated:YES completion:nil];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int fds[2];
        if (pipe(fds) != 0) { dispatch_async(dispatch_get_main_queue(), ^{ [progress dismissViewControllerAnimated:YES completion:^{ [self alert:@"Could not start" message:@"Unable to create the build output pipe."]; }]; }); return; }
        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_adddup2(&actions, fds[1], STDOUT_FILENO);
        posix_spawn_file_actions_adddup2(&actions, fds[1], STDERR_FILENO);
        posix_spawn_file_actions_addclose(&actions, fds[0]);
        posix_spawn_file_actions_addclose(&actions, fds[1]);
        const char *argv[] = {"bash", "-lc", command.UTF8String, NULL};
        pid_t pid = 0;
        int spawnError = posix_spawn(&pid, "/var/jb/bin/bash", &actions, NULL, (char * const *)argv, environ);
        posix_spawn_file_actions_destroy(&actions);
        close(fds[1]);
        NSMutableData *data = [NSMutableData data];
        if (spawnError == 0) {
            char buffer[2048]; ssize_t n;
            while ((n = read(fds[0], buffer, sizeof(buffer))) > 0) [data appendBytes:buffer length:(NSUInteger)n];
        }
        close(fds[0]);
        int status = 0;
        if (spawnError == 0) waitpid(pid, &status, 0);
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            [progress dismissViewControllerAnimated:YES completion:^{
                BOOL success = spawnError == 0 && WIFEXITED(status) && WEXITSTATUS(status) == 0;
                if (success && [title containsString:@"Building"]) {
                    self.lastDebPath = [self newestDebInProject:self.lastProjectPath];
                    if (self.lastDebPath) [[NSUserDefaults standardUserDefaults] setObject:self.lastDebPath forKey:@"TSLastDebPath"];
                }
                NSString *summary = spawnError ? [NSString stringWithFormat:@"Could not start command (error %d). Check that bash is installed.", spawnError] : (success ? @"Completed successfully." : @"The command failed. See output below.");
                NSString *tail = output.length > 3000 ? [output substringFromIndex:output.length - 3000] : output;
                NSString *message = tail.length ? [NSString stringWithFormat:@"%@\n\n%@", summary, tail] : summary;
                UIAlertController *result = [UIAlertController alertControllerWithTitle:(success ? @"Done" : @"Setup / build failed") message:message preferredStyle:UIAlertControllerStyleAlert];
                [result addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:result animated:YES completion:nil];
            }];
        });
    });
}

- (NSString *)newestDebInProject:(NSString *)path {
    NSString *packages = [path stringByAppendingPathComponent:@"packages"];
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:packages error:nil];
    NSString *newest = nil; NSDate *newestDate = [NSDate distantPast];
    for (NSString *file in files) {
        if (![file.pathExtension.lowercaseString isEqualToString:@"deb"]) continue;
        NSString *candidate = [packages stringByAppendingPathComponent:file];
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:candidate error:nil];
        NSDate *date = attributes[NSFileModificationDate] ?: [NSDate distantPast];
        if ([date compare:newestDate] == NSOrderedDescending) { newest = candidate; newestDate = date; }
    }
    return newest;
}

- (void)sharePackage {
    NSString *path = self.lastDebPath;
    if (!path || ![NSFileManager.defaultManager fileExistsAtPath:path]) path = [self newestDebInProject:self.lastProjectPath ?: @""];
    if (!path) { [self alert:@"No package yet" message:@"Build a project first. The generated .deb will be saved in its packages folder."]; return; }
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    [self presentViewController:share animated:YES completion:nil];
}

- (void)alert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
