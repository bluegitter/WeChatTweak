//
//  TweakEntry.swift
//
//  Injected entry for DYLD_INSERT_LIBRARIES
//

import Foundation
import Dispatch
import WeChatTweakObjC

// 你外部也可以手动 dlsym 调用这个符号
@_cdecl("WechatTweakEntry")
public func WechatTweakEntry() {
    // 避免重复初始化（某些场景可能被调用多次）
    struct Once { static var didInit = false }
    if Once.didInit { return }
    Once.didInit = true

    NSLog("[WeChatTweak] WechatTweakEntry invoked")

    // 注入场景：尽量不要阻塞当前线程；推到 main thread 做 UI/RunLoop 相关操作
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        NSLog("[WeChatTweak] Calling AlfredManager.startListener()")
        AlfredManager.sharedInstance().startListener()
    }
}

/// 可选：如果你希望 dylib 被加载时“自动执行”，可以额外加一个 constructor 风格入口。
/// 注意：这不是标准 C constructor，但在很多场景下足够用于触发一次初始化。
@_cdecl("_wechattweak_autorun")
public func _wechattweak_autorun() {
    WechatTweakEntry()
}
