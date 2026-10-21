#import "TSStudioCore.h"
#import <UIKit/UIKit.h>
#import <spawn.h>
#import <sys/wait.h>
#import <signal.h>
#import <fcntl.h>
#import <unistd.h>

extern char **environ;

@implementation TSStudioPaths
+ (NSString *)workspacePath { return @"/var/mobile/Documents/TweakStudio"; }
+ (NSString *)projectsPath { return [[self workspacePath] stringByAppendingPathComponent:@"Projects"]; }
+ (NSString *)modelsPath { return [[self workspacePath] stringByAppendingPathComponent:@"Models"]; }
+ (NSString *)skillsPath { return [[self workspacePath] stringByAppendingPathComponent:@"Skills"]; }
+ (NSString *)logsPath { return [[self workspacePath] stringByAppendingPathComponent:@"Logs/activity.jsonl"]; }
+ (NSString *)currentProject { return [[NSUserDefaults standardUserDefaults] stringForKey:@"TSLastProjectPath"] ?: @""; }
+ (void)setCurrentProject:(NSString *)path {
    [[NSUserDefaults standardUserDefaults] setObject:path forKey:@"TSLastProjectPath"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
+ (void)prepareDirectories {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *path in @[[self projectsPath], [self modelsPath], [self skillsPath], [[self workspacePath] stringByAppendingPathComponent:@"Logs"]]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
}
@end

@implementation TSActivityLog
+ (void)record:(NSString *)event category:(NSString *)category {
    [TSStudioPaths prepareDirectories];
    NSDictionary *entry = @{@"time": @([[NSDate date] timeIntervalSince1970]), @"category": category ?: @"info", @"event": event ?: @""};
    NSData *json = [NSJSONSerialization dataWithJSONObject:entry options:NSJSONWritingFragmentsAllowed error:nil];
    if (!json) return;
    NSMutableData *line = [json mutableCopy];
    const uint8_t newline = '\n'; [line appendBytes:&newline length:1];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:TSStudioPaths.logsPath];
    if (!handle) { [NSFileManager.defaultManager createFileAtPath:TSStudioPaths.logsPath contents:nil attributes:nil]; handle = [NSFileHandle fileHandleForWritingAtPath:TSStudioPaths.logsPath]; }
    [handle seekToEndOfFile]; [handle writeData:line]; [handle closeFile];
}
+ (NSArray<NSDictionary *> *)latest:(NSUInteger)limit {
    NSString *text = [NSString stringWithContentsOfFile:TSStudioPaths.logsPath encoding:NSUTF8StringEncoding error:nil];
    if (!text.length) return @[];
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        if (!data.length) continue;
        id value = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
        if ([value isKindOfClass:NSDictionary.class]) [items addObject:value];
    }
    if (items.count > limit) return [items subarrayWithRange:NSMakeRange(items.count-limit, limit)];
    return items;
}
+ (NSString *)plainText {
    NSMutableArray *lines = [NSMutableArray array];
    for (NSDictionary *entry in [self latest:1000]) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[entry[@"time"] doubleValue]];
        NSDateFormatter *formatter = [NSDateFormatter new]; formatter.dateStyle = NSDateFormatterNoStyle; formatter.timeStyle = NSDateFormatterShortStyle;
        [lines addObject:[NSString stringWithFormat:@"%@  [%@] %@", [formatter stringFromDate:date], entry[@"category"] ?: @"info", entry[@"event"] ?: @""]];
    }
    return [lines componentsJoinedByString:@"\n"];
}
@end

@interface TSLocalModelManager ()
@property (nonatomic, readwrite) BOOL running;
@property (nonatomic, copy, readwrite) NSString *loadedModelPath;
@property (nonatomic) pid_t serverPID;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation TSLocalModelManager
+ (instancetype)shared { static TSLocalModelManager *manager; static dispatch_once_t once; dispatch_once(&once, ^{ manager = [TSLocalModelManager new]; }); return manager; }
- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.timeoutIntervalForRequest = 600; config.timeoutIntervalForResource = 900;
        _session = [NSURLSession sessionWithConfiguration:config];
        _serverPID = 0;
    }
    return self;
}
- (NSURL *)endpoint:(NSString *)path { return [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:18222%@", path]]; }
- (void)startModelAtPath:(NSString *)path completion:(void (^)(NSError *))completion {
    [TSStudioPaths prepareDirectories];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) { completion([NSError errorWithDomain:@"TweakStudio.Model" code:10 userInfo:@{NSLocalizedDescriptionKey:@"Choose an imported GGUF model first."}]); return; }
    if (self.serverPID > 0 && [self.loadedModelPath isEqualToString:path]) { int status=0; if(waitpid(self.serverPID,&status,WNOHANG)==0){ self.running=YES; completion(nil); return; } self.serverPID=0; self.running=NO; self.loadedModelPath=nil; }
    if (self.serverPID > 0) [self stopModel];
    NSString *server = @"/var/jb/usr/libexec/tweakstudio/llama-server";
    if (![NSFileManager.defaultManager isExecutableFileAtPath:server]) { completion([NSError errorWithDomain:@"TweakStudio.Model" code:11 userInfo:@{NSLocalizedDescriptionKey:@"The local llama.cpp runner is not installed. Reinstall the TweakStudio AI package."}]); return; }
    [self stopModel];
    NSString *logPath = [[TSStudioPaths.workspacePath stringByAppendingPathComponent:@"Logs"] stringByAppendingPathComponent:@"llama-server.log"];
    int logFD = open(logPath.fileSystemRepresentation, O_CREAT | O_WRONLY | O_APPEND, 0600);
    if (logFD < 0) { completion([NSError errorWithDomain:@"TweakStudio.Model" code:12 userInfo:@{NSLocalizedDescriptionKey:@"Could not open the local model log."}]); return; }
    posix_spawn_file_actions_t actions; posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, logFD, STDOUT_FILENO); posix_spawn_file_actions_adddup2(&actions, logFD, STDERR_FILENO); posix_spawn_file_actions_addclose(&actions, logFD);
    NSString *threads = [NSString stringWithFormat:@"%lu", (unsigned long)MAX(2, MIN(6, NSProcessInfo.processInfo.activeProcessorCount-1))];
    const char *argv[] = {"llama-server", "--model", path.fileSystemRepresentation, "--host", "127.0.0.1", "--port", "18222", "--threads", threads.UTF8String, "--ctx-size", "6144", "--parallel", "1", "--n-gpu-layers", "0", "--jinja", "--no-webui", NULL};
    pid_t pid = 0;
    int result = posix_spawn(&pid, server.fileSystemRepresentation, &actions, NULL, (char * const *)argv, environ);
    posix_spawn_file_actions_destroy(&actions); close(logFD);
    if (result != 0) { completion([NSError errorWithDomain:NSPOSIXErrorDomain code:result userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Could not start llama.cpp (error %d).", result]}]); return; }
    self.serverPID = pid; self.loadedModelPath = path;
    [TSActivityLog record:[NSString stringWithFormat:@"Starting local GGUF model: %@", path.lastPathComponent] category:@"model"];
    [self waitForServer:0 completion:completion];
}
- (void)waitForServer:(NSInteger)attempt completion:(void (^)(NSError *))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self endpoint:@"/health"]]; request.timeoutInterval = 3;
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        if (!error && status >= 200 && status < 300) { self.running = YES; [TSActivityLog record:@"Local inference server is ready on loopback." category:@"model"]; dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); }); return; }
        if (attempt >= 120) { self.running = NO; NSError *timeout = [NSError errorWithDomain:@"TweakStudio.Model" code:13 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"The model did not start in time. See Activity → llama-server.log. %@", error.localizedDescription ?: @""]}]; [TSActivityLog record:timeout.localizedDescription category:@"error"]; dispatch_async(dispatch_get_main_queue(), ^{ completion(timeout); }); return; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ [self waitForServer:attempt+1 completion:completion]; });
    }] resume];
}
- (void)stopModel {
    [self stopModelWithCompletion:nil];
}
- (void)stopModelWithCompletion:(void (^)(void))completion {
    pid_t pid=self.serverPID;
    if (pid > 0) { self.serverPID=0; kill(pid,SIGTERM); }
    self.running = NO; self.loadedModelPath = nil;
    if (pid <= 0) { if(completion) dispatch_async(dispatch_get_main_queue(), completion); return; }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
        int status=0; waitpid(pid,&status,0);
        if(completion) dispatch_async(dispatch_get_main_queue(), completion);
    });
}
- (void)sendMessages:(NSArray<NSDictionary *> *)messages maxTokens:(NSInteger)maxTokens completion:(void (^)(NSString *, NSError *))completion {
    if (!self.running) { completion(nil, [NSError errorWithDomain:@"TweakStudio.Model" code:14 userInfo:@{NSLocalizedDescriptionKey:@"Load a local model before chatting."}]); return; }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self endpoint:@"/v1/chat/completions"]]; request.HTTPMethod = @"POST"; request.timeoutInterval = 600;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *payload = @{@"model":@"tweakstudio-local", @"messages":messages, @"temperature":@0.2, @"max_tokens":@(MAX(64, MIN(2048, maxTokens))), @"stream":@NO, @"response_format":@{@"type":@"json_object"}};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError *failure = error;
        NSString *reply = nil;
        if (!failure) {
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
            NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&failure] : nil;
            if (status < 200 || status >= 300) { NSString *bodyText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]; failure = [NSError errorWithDomain:@"TweakStudio.Model" code:status userInfo:@{NSLocalizedDescriptionKey:bodyText ?: @"Local model request failed."}]; }
            else if (!failure) reply = json[@"choices"][@0][@"message"][@"content"];
            if (!reply && !failure) failure = [NSError errorWithDomain:@"TweakStudio.Model" code:15 userInfo:@{NSLocalizedDescriptionKey:@"The local model returned an empty response."}];
        }
        if (failure) [TSActivityLog record:[NSString stringWithFormat:@"Local model request failed: %@", failure.localizedDescription] category:@"error"];
        else [TSActivityLog record:@"Local model completed a response." category:@"model"];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(reply, failure); });
    }] resume];
}
@end
