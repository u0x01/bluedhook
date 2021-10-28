//  weibo:   https://weibo.com/u/2738662791
//  twitter: https://twitter.com/u0x01
//
//  bluedhook.mm
//  bluedhook.Dylib
//
//  Created by u0x01 on 2021/10/20.
//  Copyright (c) 2021 u0x01. All rights reserved.
//
// 本项目支持 Blued、Blued 极速版

// 1: 普通文本消息
// 2: 图片消息
// 3: 语音消息
// 5: 视频
// 6: 大表情
// 24: 闪照
// 25: 闪频

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import "substrate.h"
#import <UIKit/UIkit.h>
#import <Foundation/Foundation.h>
#import "CaptainHook/CaptainHook.h"

#import "PushPackage.h"
#import "GJIMMessageModel.h"
#import "GJIMSessionService.h"
#import "GJIMMessageService.h"
#import "BDEncrypt.h"
#import "BDChatBasicCell.h"

#import "GJIMDBService.h"
#import "GJIMSessionToken.h"
#import <UserNotifications/UserNotifications.h>

#import "FJDeepSleepPreventerPlus.h"

CHDeclareClass(GJIMSessionService);
CHOptimizedMethod1(self, id, GJIMSessionService, p_handlePushPackage, PushPackage*, pkg) {
    NSString *pushContent = pkg.contents;
    switch (pkg.messageType) {
        case 55: // 撤回
        {
            NSLog(@"[BLUEDHOOK] %@ 撤回消息已被拦截。", pkg.name);
            pushContent = @"对方尝试撤回一条消息，已被阻止。";

            // 获取原始消息，打 tag
            GJIMSessionToken *sessionToken = [objc_getClass("GJIMSessionToken") gji_sessionTokenWithId: pkg.sessionId type:2];
            [objc_getClass("GJIMDBService") gji_getMessagesWithToken:sessionToken complete:^(id data) {
                GJIMMessageModel *targetMsg;
                for (GJIMMessageModel *msg in data) {
                    if (msg.msgId == pkg.messageId) {
                        targetMsg = msg;
                        break;
                    }
                }
                
                if (targetMsg == nil) {
                    NSLog(@"[BLUEDHOOK] Warning: cannot find msgid %llu from %d in message service, canceled tagging.", pkg.messageId, pkg.from);
                    for (GJIMMessageModel *msg in data) {
                        if (msg.fromId == pkg.from) {
                            targetMsg = msg;
                            break;
                        }
                    }
                    targetMsg.type = 1;
                    targetMsg.msgId = pkg.messageId;
                    targetMsg.sendTime = pkg.timestamp;
                    targetMsg.msgExtra = @{@"BLUED_HOOK_IS_RECALLED": @1};
                    targetMsg.content = @"对方撤回了一条消息，但已错过接收原始消息无法复原。";
                    [self addMessage:targetMsg];
                    return;
                }
                
                targetMsg.msgExtra = @{@"BLUED_HOOK_IS_RECALLED": @1};
                [self updateMessage:targetMsg];
                
                NSString *notifyStr = @"对方尝试撤回一条消息，已被阻止。";
                switch (targetMsg.type) {
                    case 1:
                        notifyStr = [NSString stringWithFormat:@"对方尝试撤回\"%@\"，已被阻止。", targetMsg.content];
                        break;
                    case 2:
                        notifyStr = [NSString stringWithFormat:@"对方尝试撤回\"%@\"，已被阻止。", @"[图片]"];
                        if ([targetMsg.content containsString:@"burn-chatfiles"]) {
                            notifyStr = [NSString stringWithFormat:@"对方尝试撤回\"%@\"，已被阻止。", @"[闪照]"];
                        }
                        break;
                    case 3:
                        notifyStr = [NSString stringWithFormat:@"对方尝试撤回\"%@\"，已被阻止。", @"[语音]"];
                        break;
                    case 5:
                        notifyStr = [NSString stringWithFormat:@"对方尝试撤回\"%@\"，已被阻止。", @"[视频]"];
                        if ([targetMsg.content containsString:@"burn-chatfiles"]) {
                            notifyStr = [NSString stringWithFormat:@"对方尝试撤回\"%@\"，已被阻止。", @"[闪照视频]"];
                        }
                        break;
                }

                UNMutableNotificationContent *content = [UNMutableNotificationContent new];
                content.title = pkg.name;
                content.body = notifyStr;
                UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[NSString stringWithFormat:@"2+%d+%llu+%llu",pkg.from, pkg.messageType, pkg.messageId] content:content trigger:nil];
                [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
            }];
        }
            break;
        case 24:
            pushContent = @"[闪照]";
            pkg.messageType = 2;
            pkg.contents = [objc_getClass("BDEncrypt") decryptVideoUrl:pkg.contents];
            pkg.msgExtra = @{@"BLUEDHOOK_IS_SNAPIMG": @1};
            break;
        case 25:
            pushContent = @"[闪照视频]";
            pkg.messageType = 5;
            pkg.contents = [objc_getClass("BDEncrypt") decryptVideoUrl:pkg.contents];
            pkg.msgExtra = @{@"BLUEDHOOK_IS_SNAPIMG": @1};
            break;
        case 2:
            pushContent = @"[图片]";
            break;
        case 3:
            pushContent = @"[语音]";
            break;
        case 5:
            pushContent = @"[视频]";
            break;
        case 6:
            pushContent = @"给你发了一个表情";
            break;
        default:
            break;
    }
    
    
    if (pkg.messageType == 55) {
        return nil;
    }
    
    // 判断是否在前台决定是否推送
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    } else {
        [UIApplication sharedApplication].applicationIconBadgeNumber += 1;
        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        content.title = pkg.name;
        content.body = pushContent;
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[NSString stringWithFormat:@"2+%d+%llu+%llu",pkg.from, pkg.messageType, pkg.messageId] content:content trigger:nil];
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
    }
    
    return CHSuper1(GJIMSessionService, p_handlePushPackage, pkg);
}

CHDeclareClass(UITableViewCell);
CHOptimizedMethod0(self, id, UITableViewCell, contentView){
    NSString *cellClassName = [NSString stringWithFormat:@"%@", ((UIView*)self).class];
    if (![cellClassName containsString:@"PrivateOther"]) {
        return CHSuper0(UITableViewCell, contentView);
    }
    
    UIView *contentView = CHSuper0(UITableViewCell, contentView);
    GJIMMessageModel *msg = [[(BDChatBasicCell*)self message] copy];
    if (msg == nil) {
        return contentView;
    }
    NSLog(@"handing msg type:%llu, msgID: %llu, msgContent: %@\nBLUEDHOOK_IS_SNAPIMG: %@, BLUED_HOOK_IS_RECALLED: %@", msg.type, msg.msgId, msg.content, [msg.msgExtra objectForKey:@"BLUEDHOOK_IS_SNAPIMG"], [msg.msgExtra objectForKey:@"BLUED_HOOK_IS_RECALLED"]);

    // 渲染时如果检测到未处理闪照，则处理
    if (msg.type == 24) {
        msg.type = 2;
        msg.content = [objc_getClass("BDEncrypt") decryptVideoUrl:msg.content];
        msg.msgExtra = @{@"BLUEDHOOK_IS_SNAPIMG": @1};
        GJIMSessionService * sessionService = [objc_getClass("GJIMSessionService") sharedInstance];
        [sessionService updateMessage:msg];
        return contentView;
    } else if (msg.type == 25) {
        msg.type = 5;
        msg.content = [objc_getClass("BDEncrypt") decryptVideoUrl:msg.content];
        msg.msgExtra = @{@"BLUEDHOOK_IS_SNAPIMG": @1};
        GJIMSessionService * sessionService = [objc_getClass("GJIMSessionService") sharedInstance];
        [sessionService updateMessage:msg];
        return contentView;
    }
    
    
    // 被处理消息添加提示，样式处理
    NSInteger labelTag = 1069;
    CGFloat labelPosTop = contentView.frame.size.height-12;
    CGFloat labelPosLeft = [contentView subviews][2].frame.origin.x;
    
    switch (msg.type) {
        case 1:
            labelPosTop -= 8;
            labelPosLeft += 12;
            break;
        case 3:
            labelPosLeft += 12;
            break;
        default:
            break;
    }
    
    CGRect labelFrame = CGRectMake(labelPosLeft, labelPosTop, contentView.frame.size.width, 12);
    UILabel *label;
    UILabel *oldLabel = [self viewWithTag:labelTag];
    if (oldLabel == nil) {
        label = [[UILabel alloc] init];
    } else {
        label = oldLabel;
    }
    
    [label setFrame:labelFrame];
    
    NSArray *keys = [msg.msgExtra allKeys];
    if (msg.msgId == 0 || [keys count] == 0) {
        return contentView;
    }

    NSString *labelText = @"";
    if ([keys containsObject:@"BLUEDHOOK_IS_SNAPIMG"]) {
        if (msg.type == 5) {
            labelText = @"该视频由闪照转换而成";
        } else {
            labelText = @"该照片由闪照转换而成";
        }
    } else if ([keys containsObject:@"BLUED_HOOK_IS_RECALLED"]) {
        labelText = @"对方尝试撤回此消息，已被阻止";
        if ([msg.content containsString:@"burn-chatfiles"]) {
            labelText = @"对方尝试撤回该闪照，已被阻止";
            if (msg.type == 5) {
                labelText = @"对方尝试撤回该闪照视频，已被阻止";
            }
        }
        
//    } else if ([keys containsObject:@"BLUED_HOOK_RECALLED_MISSED"]){
//        labelText = @"已错过接收原始消息。";
    }
    else {
//        return contentView;
//        labelText = [NSString stringWithFormat:@"%llu: %@", msg.msgId, msg.content];
    }


    [label setFont:[UIFont systemFontOfSize:9]];
    label.textColor = [UIColor grayColor];
    label.tag = labelTag;
    label.text = labelText;
    label.numberOfLines = 1;
    [self addSubview:label];

    return contentView;
}


CHConstructor {
    @autoreleasepool {        
        CHLoadLateClass(GJIMSessionService);
        CHClassHook1(GJIMSessionService, p_handlePushPackage);
        
        CHLoadLateClass(UITableViewCell);
        CHHook0(UITableViewCell, contentView);
        
        // 清理推送、保活
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
            [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
            
            // 停止保活
            [[FJDeepSleepPreventerPlus sharedInstance] stop];
        }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            // 开始保活
            [[FJDeepSleepPreventerPlus sharedInstance] start];
        }];
    }

}

// 保推送(屏蔽后台 GRPC 中断)
CHDeclareClass(BDLiveIM);
CHDeclareMethod1(void, BDLiveIM, p_didEnterBackground, id, arg1) {}
CHDeclareClass(GJIMEngine); // 注：GJIMEngine 负责处理撤回动作
CHDeclareMethod1(void, GJIMEngine, p_didEnterBackground, id, arg1) {}
CHDeclareClass(BDgRPCConnector);
CHDeclareMethod1(void, BDgRPCConnector, p_appDidEnterBackground, id, arg1) {}


// ========== BDMineViewController ad block ==========
CHDeclareClass(BDMineViewController);
CHDeclareMethod1(void, BDMineViewController, setItemsModel, id, arg1){
    MSHookIvar<NSArray*>(arg1, "_anchors") = @[];
    MSHookIvar<NSArray*>(arg1, "_health") = @[];
    MSHookIvar<NSArray*>(arg1, "_service") = @[];
    
    NSMutableArray *othersList = MSHookIvar<NSMutableArray*>(arg1, "_others");
    id emojiItem = [othersList lastObject];
    MSHookIvar<NSString*>(emojiItem, "_title") = @"Telegram群组";
    MSHookIvar<NSString*>(emojiItem, "_icon") = @"https://telegram.org/img/t_logo.png";
    MSHookIvar<NSString*>(emojiItem, "_url") = @"https://t.me/Talk4Gay";
    
    MSHookIvar<NSArray*>(arg1, "_others") = othersList;
    CHSuper1(BDMineViewController, setItemsModel, arg1);
}

CHDeclareMethod1(void, BDMineViewController, setHeaderModel, id, arg1){
    MSHookIvar<NSArray*>(MSHookIvar<id>(arg1, "_broadcast"), "_carousels") = @[];
    CHSuper1(BDMineViewController, setHeaderModel, arg1);
}

// 屏蔽杂乱信息
CHDeclareMethod1(void, BDMineViewController, setText_banners, id, arg1) {}
// 屏蔽 banner 广告
CHDeclareMethod1(void, BDMineViewController, setImgBannerModel, id, arg1) {}
// ========== BDMineViewController ad block ==========


// ========== vip mock ==========
CHDeclareClass(LoginData);
CHDeclareMethod0(id, LoginData, getUserInfo) {
    id data = CHSuper0(LoginData, getUserInfo);
    MSHookIvar<long long>(data, "_vip_grade") = 2;
    MSHookIvar<long long>(data, "_vip_exp_lvl") = 7;
    MSHookIvar<long long>(data, "_is_vip_annual") = 1;
    return data;
}
CHDeclareMethod0(long long, LoginData, vip_grade) { return 2; }
CHDeclareMethod0(long long, LoginData, vip_exp_lvl) { return 7; }
CHDeclareMethod0(long long, LoginData, is_vip_annual) { return 1; }
// ========== vip mock ==========


// ========== fuck ads ==========

// 屏蔽直播推荐
CHDeclareClass(BDNearbyTopFixView);
CHDeclareMethod1(void, BDNearbyTopFixView, setRecommendModule, id, arg1){}
CHDeclareClass(BDNearbyMakeFriendsSubPageController);
CHDeclareMethod1(void, BDNearbyMakeFriendsSubPageController, setTopView, id, arg1){}
CHDeclareMethod1(void, BDNearbyMakeFriendsSubPageController, synchronizeTopHeaderWithHeight, double, arg1) {
    CHSuper1(BDNearbyMakeFriendsSubPageController, synchronizeTopHeaderWithHeight, 0.0);
}


// 屏蔽开屏广告
CHDeclareClass(GDTSplashAD);
CHDeclareMethod0(bool, GDTSplashAD, isAdValid){ return false; }

CHDeclareClass(BUSplashPreloader);
CHDeclareMethod1(void, BUSplashPreloader, setTimeout, id, arg1){}

// 屏蔽 feed 页广告
CHDeclareClass(BDNearbyMakeFriendsSubPageManager);
CHDeclareMethod1(void, BDNearbyMakeFriendsSubPageManager, p_insertAdvertisementByArray, id, arg1){}
CHDeclareMethod2(void, BDNearbyMakeFriendsSubPageManager, p_insertAdvertisementByList, id, arg1, grid, id, arg2){}

CHDeclareClass(BDAdvertisementLoadingServer);
CHDeclareMethod1(void, BDAdvertisementLoadingServer, showAdvertisementImmediately, unsigned long long, arg1){}

CHDeclareClass(BDTopOnNativeManager)
CHDeclareMethod0(void, BDTopOnNativeManager, loadBannerAd){}

// ========== fuck ads ==========
