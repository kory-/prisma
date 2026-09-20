#define main PrismaMain
#include "../Source/Mixer.mm"
#undef main
#include <cassert>
int main(){@autoreleasepool{
 Mixer*m=[Mixer new];m.channels=[NSMutableArray array];m.slots=@[@"",@"",@"",@""];
 auto make=^(NSString*key,double delta){Channel*c=[Channel new];c.key=key;c.name=key;c.lastHeard=NSDate.timeIntervalSinceReferenceDate-delta;[m.channels addObject:c];return c;};
 Channel*a=make(@"a",.2),*b=make(@"b",.4),*silent=make(@"silent",100);
 [m assignSlots];assert([m.slots[0]isEqual:@"a"]&&[m.slots[1]isEqual:@"b"]&&[m.slots[2]isEqual:@""]);
 b.lastHeard=NSDate.timeIntervalSinceReferenceDate;[m assignSlots];assert([m.slots[0]isEqual:@"a"]&&[m.slots[1]isEqual:@"b"]);
 a.lastHeard=NSDate.timeIntervalSinceReferenceDate-10;a.muted=YES;a.processPlaying=YES;[m assignSlots];assert([m.slots[0]isEqual:@"a"]);
 a.muted=NO;m.freezeUntil=NSDate.timeIntervalSinceReferenceDate+2;[m assignSlots];assert([m.slots[0]isEqual:@"a"]);
 m.freezeUntil=0;[m assignSlots];assert([m.slots[0]isEqual:@""]&&[m.slots[1]isEqual:@"b"]);
 silent.lastHeard=NSDate.timeIntervalSinceReferenceDate;[m assignSlots];assert([m.slots[0]isEqual:@"silent"]);
 m.channels=[NSMutableArray array];m.slots=@[@"com.google.Chrome",@"",@"",@""];
 Channel*chrome=make(@"com.google.Chrome",.1);Channel*tab=make(@"chrome-tab:test:7",.2);tab.browserTab=YES;
 [m assignSlots];assert([m.slots[0]isEqual:tab.key]);assert(![m.slots containsObject:chrome.key]);
 tab.lastHeard=NSDate.timeIntervalSinceReferenceDate-10;[m assignSlots];assert([m.slots containsObject:chrome.key]);
 puts("PASS: active-only selection, stable slots, muted retention, interaction lock, silence expiry, gap fill");
}return 0;}
