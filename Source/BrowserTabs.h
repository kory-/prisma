#include "Localization.h"
#pragma once
#import <Cocoa/Cocoa.h>
#include <cmath>
#include <algorithm>
static NSString*PrismaTabKey(NSString*session,NSNumber*identifier){return [NSString stringWithFormat:@"chrome-tab:%@:%@",session,identifier];}
static BOOL PrismaIsTabKey(NSString*key){return [key hasPrefix:@"chrome-tab:"];}
@interface PrismaBrowserTabs:NSObject
@property NSMutableDictionary<NSString*,NSDictionary*>*sources;
@property NSMutableDictionary<NSString*,NSDictionary*>*pending;
- (void)receive:(NSDictionary*)message now:(NSTimeInterval)now;
- (NSArray<NSDictionary*>*)tabsAt:(NSTimeInterval)now;
- (NSDictionary*)commandForKey:(NSString*)key op:(NSString*)op value:(float)value step:(float)step now:(NSTimeInterval)now;
@end
@implementation PrismaBrowserTabs
-(instancetype)init{if((self=[super init])){_sources=[NSMutableDictionary dictionary];_pending=[NSMutableDictionary dictionary];}return self;}
-(void)receive:(NSDictionary*)message now:(NSTimeInterval)now {
 NSString*connection=message[@"connection"],*session=message[@"session"];
 if(![connection isKindOfClass:NSString.class]||![[NSUUID alloc]initWithUUIDString:connection])return;
 if([message[@"closed"]boolValue]){[self.sources removeObjectForKey:connection];return;}
 if(![session isKindOfClass:NSString.class]||![[NSUUID alloc]initWithUUIDString:session]||![message[@"tabs"]isKindOfClass:NSArray.class]||[message[@"tabs"]count]>16)return;
 NSMutableArray*tabs=[NSMutableArray array];NSMutableSet*seen=[NSMutableSet set];
 for(id item in message[@"tabs"]){
  if(![item isKindOfClass:NSDictionary.class])continue;NSDictionary*t=item;NSNumber*identifier=t[@"id"],*volume=t[@"volume"];
  if(![identifier isKindOfClass:NSNumber.class]||identifier.doubleValue<0||identifier.doubleValue>2147483647||floor(identifier.doubleValue)!=identifier.doubleValue||[seen containsObject:identifier])continue;
  if(![volume isKindOfClass:NSNumber.class]||!std::isfinite(volume.doubleValue)||![t[@"name"]isKindOfClass:NSString.class])continue;
  [seen addObject:identifier];NSString*key=PrismaTabKey(session,identifier),*name=t[@"name"],*icon=t[@"icon"],*ack=t[@"lastCommand"],*error=t[@"error"];
  if(![icon isKindOfClass:NSString.class]||![icon hasPrefix:@"data:image/png;base64,"]||icon.length>8192)icon=@"";
  if(![error isKindOfClass:NSString.class]||error.length>180)error=@"";
  if([t[@"errorCode"]isEqual:@"reload_page"])error=PL(@"Reload this page to control its volume.");
  if(![ack isKindOfClass:NSString.class]||ack.length>64)ack=@"";
  NSDictionary*pending=self.pending[key];if([pending[@"requestId"]isEqual:ack]||[pending[@"until"]doubleValue]<now){[self.pending removeObjectForKey:key];pending=nil;}
  [tabs addObject:@{@"key":key,@"connection":connection,@"session":session,@"id":identifier,@"name":[name substringToIndex:MIN(name.length,180)],@"icon":icon,@"error":error,
   @"volume":pending?pending[@"volume"]:@(std::clamp(volume.floatValue,0.0f,1.0f)),@"muted":pending?pending[@"muted"]:@([t[@"muted"]respondsToSelector:@selector(boolValue)]&&[t[@"muted"]boolValue]),
   @"playing":@([t[@"playing"]respondsToSelector:@selector(boolValue)]&&[t[@"playing"]boolValue])}];
 }
 for(NSString*old in self.sources.allKeys)if(![old isEqual:connection]&&[self.sources[old][@"session"]isEqual:session])[self.sources removeObjectForKey:old];
 self.sources[connection]=@{@"time":@(now),@"session":session,@"tabs":tabs};
}
-(NSArray<NSDictionary*>*)tabsAt:(NSTimeInterval)now {
 NSMutableArray*tabs=[NSMutableArray array];NSMutableSet*live=[NSMutableSet set];
 for(NSString*connection in self.sources.allKeys){NSDictionary*source=self.sources[connection];if(now-[source[@"time"]doubleValue]>4){[self.sources removeObjectForKey:connection];continue;}for(NSDictionary*t in source[@"tabs"]){NSMutableDictionary*shown=[t mutableCopy];NSDictionary*p=self.pending[t[@"key"]];if([p[@"until"]doubleValue]>=now){shown[@"volume"]=p[@"volume"];shown[@"muted"]=p[@"muted"];}[tabs addObject:shown];[live addObject:t[@"key"]];}}
 for(NSString*key in self.pending.allKeys)if(![live containsObject:key]||[self.pending[key][@"until"]doubleValue]<now)[self.pending removeObjectForKey:key];
 return tabs;
}
-(NSDictionary*)commandForKey:(NSString*)key op:(NSString*)op value:(float)value step:(float)step now:(NSTimeInterval)now {
 if(![@[@"set",@"up",@"down",@"mute",@"focus",@"release"]containsObject:op]||!std::isfinite(value)||!std::isfinite(step))return nil;
 NSDictionary*tab=nil;for(NSDictionary*t in [self tabsAt:now])if([t[@"key"]isEqual:key]){tab=t;break;}if(!tab)return nil;
 NSDictionary*current=self.pending[key]?:tab;float level=[current[@"volume"]floatValue];BOOL muted=[current[@"muted"]boolValue];step=std::clamp(step,1.0f,100.0f);
 if([op isEqual:@"set"])level=std::clamp(value,0.0f,1.0f);if([op isEqual:@"up"])level=MIN(1,level+step/100);if([op isEqual:@"down"])level=MAX(0,level-step/100);if([op isEqual:@"mute"])muted=!muted;
 NSString*request=NSUUID.UUID.UUIDString;
 if(![@[@"focus",@"release"]containsObject:op])self.pending[key]=@{@"requestId":request,@"until":@(now+3),@"volume":@(level),@"muted":@(muted)};
 return @{@"connection":tab[@"connection"],@"session":tab[@"session"],@"id":tab[@"id"],@"op":op,@"value":@(value),@"step":@(step),@"requestId":request};
}
@end
