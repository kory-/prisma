#include "../Source/BrowserTabs.h"
#include <cassert>
int main(){@autoreleasepool{
 PrismaBrowserTabs*store=[PrismaBrowserTabs new];NSString*connection=NSUUID.UUID.UUIDString,*session=NSUUID.UUID.UUIDString;
 auto row=^(int identifier,float volume,NSString*ack){return @{@"id":@(identifier),@"name":@"Example tab",@"volume":@(volume),@"muted":@NO,@"playing":@YES,@"lastCommand":ack};};
 auto receive=^(NSString*c,NSString*s,NSArray*t,double now){[store receive:@{@"connection":c,@"session":s,@"tabs":t} now:now];};
 receive(connection,session,@[row(7,.6,@""),row(8,.9,@"")],100);
 assert([store tabsAt:100].count==2);NSString*key=PrismaTabKey(session,@7);
 NSDictionary*command=[store commandForKey:key op:@"down" value:0 step:10 now:100.1];assert([command[@"id"]intValue]==7);assert([command[@"connection"]isEqual:connection]);
 auto level=^float(NSString*k,double now){for(NSDictionary*t in [store tabsAt:now])if([t[@"key"]isEqual:k])return [t[@"volume"]floatValue];return -1;};
 assert(fabs(level(key,100.1)-.5)<.001);assert(fabs(level(PrismaTabKey(session,@8),100.1)-.9)<.001);
 receive(connection,session,@[row(7,.6,@""),row(8,.9,@"")],100.2);assert(fabs(level(key,100.2)-.5)<.001);
 receive(connection,session,@[row(7,.5,command[@"requestId"]),row(8,.9,@"")],100.3);assert(!store.pending[key]);
 assert(![store commandForKey:PrismaTabKey(session,@99) op:@"mute" value:0 step:5 now:100.3]);
 [store commandForKey:key op:@"up" value:0 step:5 now:100.4];[store commandForKey:key op:@"up" value:0 step:5 now:100.4];assert(fabs(level(key,100.4)-.6)<.001);
 NSString*reconnected=NSUUID.UUID.UUIDString;receive(reconnected,session,@[row(7,.6,@"")],101);assert(store.sources.count==1);
 assert([[[store commandForKey:key op:@"mute" value:0 step:5 now:101]objectForKey:@"connection"]isEqual:reconnected]);
 NSString*otherSession=NSUUID.UUID.UUIDString;receive(connection,otherSession,@[row(7,.8,@"")],101);assert([store tabsAt:101].count==2);assert(![PrismaTabKey(otherSession,@7)isEqual:key]);
 [store receive:@{@"connection":reconnected,@"closed":@YES} now:101];assert([store tabsAt:101].count==1);
 assert([store tabsAt:106].count==0);assert(store.pending.count==0);
 receive(connection,session,@[row(7,.4,@""),row(7,.8,@""),@{@"id":@8,@"name":@"bad",@"volume":@"oops"}],110);assert([store tabsAt:110].count==1);
 assert(![store commandForKey:key op:@"set" value:NAN step:5 now:110]);
 puts("PASS: tab isolation, pending commands, acknowledgements, reconnect, multiple sessions, disconnect/expiry, validation");
}return 0;}
