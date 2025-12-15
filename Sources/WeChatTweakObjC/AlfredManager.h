// Sources/WeChatTweak/AlfredManager.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AlfredManager : NSObject

+ (instancetype)sharedInstance;

- (void)startListener;
- (void)stopListener;

@end

NS_ASSUME_NONNULL_END
