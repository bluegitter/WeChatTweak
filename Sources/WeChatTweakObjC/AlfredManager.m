// Sources/WeChatTweak/AlfredManager.m
#import "AlfredManager.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "GCDWebServer.h"
#import "GCDWebServerDataResponse.h"

@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)service;
@end

@interface ContactStorage : NSObject
- (NSArray *)GetAllFriendContacts;
- (id)GetContact:(id)identifier;
@end

@interface GroupStorage : NSObject
- (NSArray *)GetAllGroups;
- (id)GetGroupContact:(id)identifier;
@end

@interface WCContactData : NSObject
@property (nonatomic, assign) NSUInteger m_uiBrandSubscriptionSettings;
@property (nonatomic, copy) NSString *m_nsNickName;
@property (nonatomic, copy) NSString *m_nsUsrName;
@property (nonatomic, copy) NSString *m_nsAliasName;
@property (nonatomic, copy) NSString *m_nsRemark;
@property (nonatomic, copy) NSString *m_nsFullPY;
@property (nonatomic, copy) NSString *m_nsRemarkPYFull;
@property (nonatomic, copy) NSString *m_nsRemarkPYShort;
@end

@interface WeChat : NSObject
+ (instancetype)sharedInstance;
- (void)startANewChatWithContact:(id)contact;
- (void)showMainWindow;
@end

@interface AlfredManager ()

@property (nonatomic, strong, nullable) GCDWebServer *server;

@end

@implementation AlfredManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static AlfredManager *shared = nil;
    dispatch_once(&onceToken, ^{
        shared = [[AlfredManager alloc] init];
    });
    return shared;
}

- (void)startListener {
    NSLog(@"[WeChatTweak] AlfredManager startListener invoked");
    if (self.server != nil) {
        NSLog(@"[WeChatTweak] GCDWebServer already running, skip start");
        return;
    }

    self.server = [[GCDWebServer alloc] init];
    NSLog(@"[WeChatTweak] GCDWebServer instance created");

    __weak typeof(self) weakSelf = self;

    // 1) 搜索联系人
    [self.server addHandlerForMethod:@"GET"
                                path:@"/wechat/search"
                        requestClass:[GCDWebServerRequest class]
                        processBlock:^GCDWebServerResponse * _Nullable(GCDWebServerRequest *request) {

        NSString *keyword = [request.query[@"keyword"] lowercaseString] ?: @"";

        NSLog(@"[WeChatTweak][Alfred] search request keyword=%@", keyword);

        // 从微信内部取联系人列表（文章里的那段代码）
        NSArray<WCContactData *> *contacts = ({
            MMServiceCenter *serviceCenter = [objc_getClass("MMServiceCenter") defaultCenter];
            ContactStorage *contactStorage = [serviceCenter getService:objc_getClass("ContactStorage")];
            GroupStorage *groupStorage = [serviceCenter getService:objc_getClass("GroupStorage")];
            NSArray<WCContactData *> *friends = [contactStorage GetAllFriendContacts];
            NSArray<WCContactData *> *groups = [groupStorage GetAllGroups];
            NSMutableArray<WCContactData *> *array = [NSMutableArray array];
            [array addObjectsFromArray:friends ?: @[]];
            [array addObjectsFromArray:groups ?: @[]];
            NSLog(@"[WeChatTweak][Alfred] fetched contacts friends=%lu groups=%lu total=%lu",
                  (unsigned long)friends.count, (unsigned long)groups.count, (unsigned long)array.count);
            array;
        });

        NSMutableArray *results = [NSMutableArray array];

        for (WCContactData *contact in contacts) {
            BOOL isFriend = contact.m_uiBrandSubscriptionSettings == 0;
            BOOL containsNickName = [contact.m_nsNickName.lowercaseString containsString:keyword];
            BOOL containsUsername = [contact.m_nsUsrName.lowercaseString containsString:keyword];
            BOOL containsAliasName = [contact.m_nsAliasName.lowercaseString containsString:keyword];
            BOOL containsRemark = [contact.m_nsRemark.lowercaseString containsString:keyword];
            BOOL containsNickNamePinyin = [contact.m_nsFullPY.lowercaseString containsString:keyword];
            BOOL containsRemarkPinyin = [contact.m_nsRemarkPYFull.lowercaseString containsString:keyword];
            BOOL matchRemarkShortPinyin = [contact.m_nsRemarkPYShort.lowercaseString isEqualToString:keyword];

            if (isFriend &&
                (containsNickName || containsUsername || containsAliasName ||
                 containsRemark || containsNickNamePinyin || containsRemarkPinyin ||
                 matchRemarkShortPinyin)) {
                NSLog(@"[WeChatTweak][Alfred] match nick=%@ remark=%@ username=%@", contact.m_nsNickName, contact.m_nsRemark, contact.m_nsUsrName);
                [results addObject:@{
                    @"m_nsNickName": contact.m_nsNickName ?: @"",
                    @"m_nsRemark": contact.m_nsRemark ?: @"",
                    @"m_nsUsrName": contact.m_nsUsrName ?: @""
                }];
            }
        }

        NSLog(@"[WeChatTweak][Alfred] search result count=%lu", (unsigned long)results.count);
        return [GCDWebServerDataResponse responseWithJSONObject:results];
    }];

    // 2) 打开聊天窗口
    [self.server addHandlerForMethod:@"GET"
                                path:@"/wechat/start"
                        requestClass:[GCDWebServerRequest class]
                        processBlock:^GCDWebServerResponse * _Nullable(GCDWebServerRequest *request) {

        NSString *session = request.query[@"session"];
        if (session.length == 0) {
            return [GCDWebServerDataResponse responseWithStatusCode:400];
        }

        __block WCContactData *contact = nil;
        MMServiceCenter *serviceCenter = [objc_getClass("MMServiceCenter") defaultCenter];

        if ([session rangeOfString:@"@chatroom"].location == NSNotFound) {
            ContactStorage *contactStorage = [serviceCenter getService:objc_getClass("ContactStorage")];
            contact = [contactStorage GetContact:session];
        } else {
            GroupStorage *groupStorage = [serviceCenter getService:objc_getClass("GroupStorage")];
            contact = [groupStorage GetGroupContact:session];
        }

        if (contact == nil) {
            return [GCDWebServerDataResponse responseWithStatusCode:404];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[objc_getClass("WeChat") sharedInstance] startANewChatWithContact:contact];
            [[objc_getClass("WeChat") sharedInstance] showMainWindow];
            [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        });

        return [GCDWebServerDataResponse responseWithJSONObject:@{@"status": @"ok"}];
    }];

    // 3) 发送文本消息（示意，具体方法名需要你自己 class-dump 确认）
    [self.server addHandlerForMethod:@"POST"
                                path:@"/wechat/send"
                        requestClass:[GCDWebServerDataRequest class]
                        processBlock:^GCDWebServerResponse * _Nullable(GCDWebServerRequest *request) {

        GCDWebServerDataRequest *dataReq = (GCDWebServerDataRequest *)request;
        NSDictionary *body = dataReq.jsonObject;
        NSString *session = body[@"session"];
        NSString *content = body[@"content"];

        if (session.length == 0 || content.length == 0) {
            return [GCDWebServerDataResponse responseWithStatusCode:400];
        }

        // 这里需要你根据当前微信版本找到真正的“发消息”方法
        // 伪代码示意：
        /*
        MMServiceCenter *serviceCenter = [objc_getClass("MMServiceCenter") defaultCenter];
        MessageService *msgService = [serviceCenter getService:objc_getClass("MessageService")];
        [msgService SendTextMessage:content toUser:session];
        */

        return [GCDWebServerDataResponse responseWithJSONObject:@{@"status": @"queued"}];
    }];

    // 启动 HTTP Server
    [self.server startWithOptions:@{
        GCDWebServerOption_Port: @(48065),
        GCDWebServerOption_BindToLocalhost: @(YES)
    } error:nil];
    NSLog(@"[WeChatTweak] GCDWebServer started on 48065 (localhost only)");
}

- (void)stopListener {
    if (self.server == nil) {
        return;
    }
    [self.server stop];
    [self.server removeAllHandlers];
    self.server = nil;
}

@end
