#import <Foundation/Foundation.h>

// 你 Swift 里导出的入口符号
extern void WechatTweakEntry(void);

__attribute__((constructor))
static void WeChatTweakConstructor(void) {
    NSLog(@"[WeChatTweak] constructor fired");
    @try {
        WechatTweakEntry();
        NSLog(@"[WeChatTweak] WechatTweakEntry() returned");
    } @catch (NSException *e) {
        NSLog(@"[WeChatTweak] exception: %@ %@", e.name, e.reason);
    }
}
