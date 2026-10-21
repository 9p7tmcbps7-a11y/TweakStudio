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
@property (nonatomic) BOOL stopping;
@property (nonatomic) NSUInteger modelGeneration;
@property (nonatomic, copy) NSString *pendingModelPath;
@property (nonatomic, copy) void (^pendingModelCompletion)(NSError *);
@property (nonatomic, strong) NSMutableArray *stopCompletions;
- (void)waitForServer:(NSInteger)attempt generation:(NSUInteger)generation completion:(void (^)(NSError *))completion;
@end

@implementation TSLocalModelManager
+ (instancetype)shared { static TSLocalModelManager *manager; static dispatch_once_t once; dispatch_once(&once, ^{ manager = [TSLocalModelManager new]; }); return manager; }
- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.timeoutIntervalForRequest = 180; config.timeoutIntervalForResource = 180;
        _session = [NSURLSession sessionWithConfiguration:config];
        _serverPID = 0; _stopCompletions=[NSMutableArray array];
    }
    return self;
}
- (NSURL *)endpoint:(NSString *)path { return [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:18222%@", path]]; }
- (void)startModelAtPath:(NSString *)path completion:(void (^)(NSError *))completion {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self startModelAtPath:path completion:completion];});return;}
    [TSStudioPaths prepareDirectories];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) { completion([NSError errorWithDomain:@"TweakStudio.Model" code:10 userInfo:@{NSLocalizedDescriptionKey:@"Choose an imported GGUF model first."}]); return; }
    if(self.stopping){self.pendingModelPath=path;self.pendingModelCompletion=[completion copy];return;}
    if(self.serverPID>0&&[self.loadedModelPath isEqualToString:path]){int status=0;if(waitpid(self.serverPID,&status,WNOHANG)==0){if(self.running)completion(nil);else[self waitForServer:0 generation:self.modelGeneration completion:completion];return;}self.serverPID=0;self.running=NO;self.loadedModelPath=nil;}
    if(self.serverPID>0){self.pendingModelPath=path;self.pendingModelCompletion=[completion copy];[self stopModelWithCompletion:nil];return;}
    NSString *server=@"/var/jb/usr/libexec/tweakstudio/llama-server";
    if(![NSFileManager.defaultManager isExecutableFileAtPath:server]){completion([NSError errorWithDomain:@"TweakStudio.Model" code:11 userInfo:@{NSLocalizedDescriptionKey:@"The local llama.cpp runner is not installed. Reinstall the TweakStudio AI package."}]);return;}
    NSString *logPath=[[TSStudioPaths.workspacePath stringByAppendingPathComponent:@"Logs"] stringByAppendingPathComponent:@"llama-server.log"];
    int logFD=open(logPath.fileSystemRepresentation,O_CREAT|O_WRONLY|O_APPEND,0600);
    if(logFD<0){completion([NSError errorWithDomain:@"TweakStudio.Model" code:12 userInfo:@{NSLocalizedDescriptionKey:@"Could not open the local model log."}]);return;}
    posix_spawn_file_actions_t actions;posix_spawn_file_actions_init(&actions);posix_spawn_file_actions_adddup2(&actions,logFD,STDOUT_FILENO);posix_spawn_file_actions_adddup2(&actions,logFD,STDERR_FILENO);posix_spawn_file_actions_addclose(&actions,logFD);
    NSString *threads=@"2";const char *argv[]={"llama-server","--model",path.fileSystemRepresentation,"--host","127.0.0.1","--port","18222","--threads",threads.UTF8String,"--ctx-size","2048","--parallel","1","--n-gpu-layers","0","--jinja","--no-webui",NULL};
    pid_t pid=0;int result=posix_spawn(&pid,server.fileSystemRepresentation,&actions,NULL,(char * const *)argv,environ);posix_spawn_file_actions_destroy(&actions);close(logFD);
    if(result!=0){completion([NSError errorWithDomain:NSPOSIXErrorDomain code:result userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Could not start llama.cpp (error %d).",result]}]);return;}
    self.serverPID=pid;self.loadedModelPath=path;self.running=NO;NSUInteger generation=++self.modelGeneration;
    [TSActivityLog record:[NSString stringWithFormat:@"Starting local GGUF model %@ (2 CPU threads, 2048 context).",path.lastPathComponent] category:@"model"];
    [self waitForServer:0 generation:generation completion:completion];
}
- (void)waitForServer:(NSInteger)attempt generation:(NSUInteger)generation completion:(void (^)(NSError *))completion {
    if(generation!=self.modelGeneration)return;
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[self endpoint:@"/health"]];request.timeoutInterval=3;
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        if(generation!=self.modelGeneration)return;NSInteger status=[(NSHTTPURLResponse *)response statusCode];
        if(!error&&status>=200&&status<300){self.running=YES;[TSActivityLog record:@"Local inference server is ready on loopback." category:@"model"];dispatch_async(dispatch_get_main_queue(),^{completion(nil);});return;}
        if(attempt>=120){self.running=NO;NSError *timeout=[NSError errorWithDomain:@"TweakStudio.Model" code:13 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"The model did not start in time. See Activity → llama-server.log. %@",error.localizedDescription?:@""]}];[TSActivityLog record:timeout.localizedDescription category:@"error"];[self stopModel];dispatch_async(dispatch_get_main_queue(),^{completion(timeout);});return;}
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{[self waitForServer:attempt+1 generation:generation completion:completion];});
    }]resume];
}
- (void)stopModel { [self stopModelWithCompletion:nil]; }
- (void)stopModelWithCompletion:(void (^)(void))completion {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self stopModelWithCompletion:completion];});return;}
    if(completion)[self.stopCompletions addObject:[completion copy]];
    if(self.stopping)return;
    pid_t pid=self.serverPID;self.serverPID=0;self.running=NO;self.loadedModelPath=nil;self.modelGeneration++;
    if(pid<=0){NSArray *callbacks=[self.stopCompletions copy];[self.stopCompletions removeAllObjects];for(void(^callback)(void) in callbacks)callback();[self startPendingModelIfNeeded];return;}
    self.stopping=YES;kill(pid,SIGTERM);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{int status=0;BOOL exited=NO;for(int i=0;i<30;i++){pid_t result=waitpid(pid,&status,WNOHANG);if(result==pid||result<0){exited=YES;break;}usleep(100000);}if(!exited){kill(pid,SIGKILL);waitpid(pid,&status,0);[TSActivityLog record:@"llama-server required SIGKILL after its graceful shutdown timed out." category:@"error"];}dispatch_async(dispatch_get_main_queue(),^{self.stopping=NO;NSArray *callbacks=[self.stopCompletions copy];[self.stopCompletions removeAllObjects];for(void(^callback)(void) in callbacks)callback();[self startPendingModelIfNeeded];});});
}
- (void)startPendingModelIfNeeded { NSString *path=self.pendingModelPath;void(^completion)(NSError *)=self.pendingModelCompletion;if(!path)return;self.pendingModelPath=nil;self.pendingModelCompletion=nil;[self startModelAtPath:path completion:completion]; }

- (void)sendMessages:(NSArray<NSDictionary *> *)messages maxTokens:(NSInteger)maxTokens completion:(void (^)(NSString *, NSError *))completion {
    if (!self.running) { completion(nil, [NSError errorWithDomain:@"TweakStudio.Model" code:14 userInfo:@{NSLocalizedDescriptionKey:@"Load a local model before chatting."}]); return; }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self endpoint:@"/v1/chat/completions"]]; request.HTTPMethod = @"POST"; request.timeoutInterval = 180;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *payload = @{@"model":@"tweakstudio-local", @"messages":messages, @"temperature":@0.2, @"max_tokens":@(MAX(64, MIN(768, maxTokens))), @"stream":@NO};
    NSError *serializationError=nil; request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&serializationError];
    if (!request.HTTPBody) { completion(nil, serializationError ?: [NSError errorWithDomain:@"TweakStudio.Model" code:16 userInfo:@{NSLocalizedDescriptionKey:@"Could not encode the local chat request."}]); return; }
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError *failure = error; NSString *reply = nil;
        if (!failure) {
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
            if (status < 200 || status >= 300) {
                NSString *bodyText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
                if (bodyText.length > 700) bodyText=[bodyText substringToIndex:700];
                failure = [NSError errorWithDomain:@"TweakStudio.Model" code:status userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Local model returned HTTP %ld: %@",(long)status,bodyText.length?bodyText:@"no response body"]}];
            } else {
                NSError *parseError=nil; id decoded=data?[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&parseError]:nil;
                id choices=[decoded isKindOfClass:NSDictionary.class]?decoded[@"choices"]:nil;
                id first=[choices isKindOfClass:NSArray.class]&&[choices count]?choices[0]:nil;
                id message=[first isKindOfClass:NSDictionary.class]?first[@"message"]:nil;
                id content=[message isKindOfClass:NSDictionary.class]?message[@"content"]:nil;
                if ([content isKindOfClass:NSString.class] && [content length]) reply=content;
                else failure=[NSError errorWithDomain:@"TweakStudio.Model" code:15 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"The local model response was not in the expected chat format (HTTP %ld, %lu bytes). Check Activity → Runner for model/template errors.",(long)status,(unsigned long)data.length]}];
            }
        }
        if (failure) [TSActivityLog record:[NSString stringWithFormat:@"Local model request failed: %@", failure.localizedDescription] category:@"error"];
        else [TSActivityLog record:@"Local model completed a response." category:@"model"];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(reply, failure); });
    }] resume];
}
@end

@implementation TSAgentSearchService
+ (void)searchGitHubRepositories:(NSString *)query completion:(void (^)(NSArray<NSDictionary *> *, NSError *))completion {
    NSString *trimmed=[(query ?: @"") stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; NSString *clean=[trimmed substringToIndex:MIN(trimmed.length,160)];
    if(!clean.length){dispatch_async(dispatch_get_main_queue(),^{completion(@[],[NSError errorWithDomain:@"TweakStudio.Search" code:1 userInfo:@{NSLocalizedDescriptionKey:@"The agent returned an empty search query."}]);});return;}
    NSURLComponents *components=[NSURLComponents componentsWithString:@"https://api.github.com/search/repositories"];
    components.queryItems=@[[NSURLQueryItem queryItemWithName:@"q" value:clean],[NSURLQueryItem queryItemWithName:@"per_page" value:@"4"],[NSURLQueryItem queryItemWithName:@"sort" value:@"stars"]];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:components.URL];request.HTTPMethod=@"GET";request.timeoutInterval=20;
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];[request setValue:@"TweakStudio/0.4.3" forHTTPHeaderField:@"User-Agent"];[request setValue:@"2022-11-28" forHTTPHeaderField:@"X-GitHub-Api-Version"];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){NSError *failure=error;NSMutableArray *results=[NSMutableArray array];NSInteger status=[(NSHTTPURLResponse *)response statusCode];if(!failure&&(status<200||status>=300)){NSString *body=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]?:@"";if(body.length>350)body=[body substringToIndex:350];failure=[NSError errorWithDomain:@"TweakStudio.Search" code:status userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"GitHub search returned HTTP %ld: %@",(long)status,body]}];}if(!failure){id decoded=data?[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil]:nil;id items=[decoded isKindOfClass:NSDictionary.class]?decoded[@"items"]:nil;if([items isKindOfClass:NSArray.class])for(id item in items){if(![item isKindOfClass:NSDictionary.class])continue;NSString *name=[item[@"full_name"] isKindOfClass:NSString.class]?item[@"full_name"]:@"";NSString *url=[item[@"html_url"] isKindOfClass:NSString.class]?item[@"html_url"]:@"";NSString *description=[item[@"description"] isKindOfClass:NSString.class]?item[@"description"]:@"No description provided.";NSString *language=[item[@"language"] isKindOfClass:NSString.class]?item[@"language"]:@"";NSNumber *stars=[item[@"stargazers_count"] isKindOfClass:NSNumber.class]?item[@"stargazers_count"]:@0;if(name.length&&[url hasPrefix:@"https://github.com/"]){[results addObject:@{@"name":name,@"url":url,@"description":description.length>450?[description substringToIndex:450]:description,@"language":language,@"stars":stars}];if(results.count>=4)break;}}if(![items isKindOfClass:NSArray.class]&&!failure)failure=[NSError errorWithDomain:@"TweakStudio.Search" code:2 userInfo:@{NSLocalizedDescriptionKey:@"GitHub returned an unexpected search response."}];}[TSActivityLog record:[NSString stringWithFormat:@"Public GitHub repository search completed (%lu results). Query: %@",(unsigned long)results.count,clean] category:@"search"];dispatch_async(dispatch_get_main_queue(),^{completion(results,failure);});}]resume];
}
@end
