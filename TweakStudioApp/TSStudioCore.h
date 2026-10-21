#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSStudioPaths : NSObject
+ (NSString *)workspacePath;
+ (NSString *)projectsPath;
+ (NSString *)modelsPath;
+ (NSString *)skillsPath;
+ (NSString *)logsPath;
+ (NSString *)currentProject;
+ (void)setCurrentProject:(NSString *)path;
+ (void)prepareDirectories;
@end

@interface TSActivityLog : NSObject
+ (void)record:(NSString *)event category:(NSString *)category;
+ (NSArray<NSDictionary *> *)latest:(NSUInteger)limit;
+ (NSString *)plainText;
@end

@interface TSLocalModelManager : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) BOOL running;
@property (nonatomic, copy, readonly, nullable) NSString *loadedModelPath;
- (void)startModelAtPath:(NSString *)path completion:(void (^)(NSError * _Nullable error))completion;
- (void)stopModel;
- (void)sendMessages:(NSArray<NSDictionary *> *)messages
          maxTokens:(NSInteger)maxTokens
         completion:(void (^)(NSString * _Nullable reply, NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
