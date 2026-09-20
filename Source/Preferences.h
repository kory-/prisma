#pragma once
#import <Cocoa/Cocoa.h>
#include "Localization.h"
#import <ServiceManagement/ServiceManagement.h>

@interface PrismaPreferences : NSObject
@property(nonatomic,strong) NSUserDefaults *defaults;
- (instancetype)initWithDefaults:(NSUserDefaults*)defaults;
- (NSInteger)integer:(NSString*)key;
- (BOOL)flag:(NSString*)key;
- (void)setValue:(id)value forPreference:(NSString*)key;
- (BOOL)audioAtLaunch;
- (BOOL)playingOnlyAtLaunch;
- (void)recordAudioActive:(BOOL)active;
@end
@implementation PrismaPreferences
- (instancetype)initWithDefaults:(NSUserDefaults*)defaults {
 if((self=[super init])){_defaults=defaults;[defaults registerDefaults:@{
  @"languageMode":@0, @"startupAudioMode":@0, @"lastAudioActive":@NO, @"showWindowAtLaunch":@YES,
  @"closeBehavior":@0, @"showDockIcon":@YES, @"appearanceMode":@0,
  @"startupFilter":@0, @"lastOnlyPlaying":@NO, @"menuIconStyle":@0,
  @"menuFilter":@0, @"menuLimit":@8, @"showPlayingCount":@NO
 }];}return self;
}
- (NSInteger)integer:(NSString*)key {
 NSInteger value=[self.defaults integerForKey:key];
 if([key isEqual:@"menuLimit"])return [@[@4,@6,@8,@12] containsObject:@(value)]?value:8;
 NSInteger maximum=[@[@"startupAudioMode",@"appearanceMode",@"startupFilter",@"languageMode"] containsObject:key]?2:1;
 return value>=0&&value<=maximum?value:0;
}
- (BOOL)flag:(NSString*)key{return [self.defaults boolForKey:key];}
- (void)setValue:(id)value forPreference:(NSString*)key{[self.defaults setObject:value forKey:key];}
- (BOOL)audioAtLaunch {
 switch([self integer:@"startupAudioMode"]){case 1:return YES;case 2:return NO;default:return [self flag:@"lastAudioActive"];}
}
- (BOOL)playingOnlyAtLaunch {
 switch([self integer:@"startupFilter"]){case 1:return NO;case 2:return YES;default:return [self flag:@"lastOnlyPlaying"];}
}
- (void)recordAudioActive:(BOOL)active{[self.defaults setBool:active forKey:@"lastAudioActive"];}
@end

// The service is injected so failure and approval states can be tested without
// changing the user's real login items.
@protocol PrismaLoginService <NSObject>
@property(nonatomic,readonly) SMAppServiceStatus status;
- (BOOL)registerAndReturnError:(NSError**)error;
- (BOOL)unregisterAndReturnError:(NSError**)error;
@end
@interface PrismaLoginController:NSObject
@property(nonatomic,strong) id<PrismaLoginService> service;
@property(nonatomic,strong) NSError *error;
- (BOOL)isRegistered;
- (BOOL)setEnabled:(BOOL)enabled;
@end
@implementation PrismaLoginController
- (BOOL)isRegistered{return self.service.status==SMAppServiceStatusEnabled||self.service.status==SMAppServiceStatusRequiresApproval;}
- (BOOL)setEnabled:(BOOL)enabled {
 self.error=nil;
 if(enabled==self.isRegistered)return YES;
 NSError*error=nil;BOOL ok=enabled?[self.service registerAndReturnError:&error]:[self.service unregisterAndReturnError:&error];
 if(!ok)self.error=error?:[NSError errorWithDomain:@"PrismaLogin" code:1 userInfo:@{NSLocalizedDescriptionKey:PL(@"Unable to change the login item.")}];
 return ok;
}
@end
