#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface TSProjectService : NSObject
+ (NSString * _Nullable)createProjectNamed:(NSString *)name type:(NSString *)type error:(NSError **)error;
+ (NSArray<NSString *> *)projectNames;
+ (NSString * _Nullable)newestDebForProject:(NSString *)path;
+ (BOOL)isSafeRelativeProjectFile:(NSString *)relativePath;
@end
@interface TSBuildService : NSObject
+ (void)buildProject:(NSString *)path completion:(void (^)(BOOL success, NSString *output))completion;
+ (void)setupToolchain:(void (^)(BOOL success, NSString *output))completion;
@end
NS_ASSUME_NONNULL_END
