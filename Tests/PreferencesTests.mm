#include "../Source/Preferences.h"
#include <cassert>

@interface FakeLoginService:NSObject<PrismaLoginService>
@property(nonatomic) SMAppServiceStatus status;
@property(nonatomic) NSUInteger registrations;
@property(nonatomic) NSUInteger removals;
@property(nonatomic) BOOL fail;
@property(nonatomic) BOOL requireApproval;
@end
@implementation FakeLoginService
-(BOOL)registerAndReturnError:(NSError**)error {
 self.registrations++;
 if(self.fail){if(error)*error=[NSError errorWithDomain:@"Test" code:42 userInfo:@{NSLocalizedDescriptionKey:@"Registration failed"}];return NO;}
 self.status=self.requireApproval?SMAppServiceStatusRequiresApproval:SMAppServiceStatusEnabled;return YES;
}
-(BOOL)unregisterAndReturnError:(NSError**)error {
 self.removals++;
 if(self.fail){if(error)*error=[NSError errorWithDomain:@"Test" code:43 userInfo:@{NSLocalizedDescriptionKey:@"Removal failed"}];return NO;}
 self.status=SMAppServiceStatusNotRegistered;return YES;
}
@end
int main(){@autoreleasepool{
 NSString*suite=[@"local.prisma.test." stringByAppendingString:NSUUID.UUID.UUIDString];
 NSUserDefaults*defaults=[[NSUserDefaults alloc]initWithSuiteName:suite];
 PrismaPreferences*p=[[PrismaPreferences alloc]initWithDefaults:defaults];
 assert(!p.audioAtLaunch);assert(!p.playingOnlyAtLaunch);assert([p flag:@"showWindowAtLaunch"]);assert([p flag:@"showDockIcon"]);
 [p recordAudioActive:YES];assert(p.audioAtLaunch);
 [p setValue:@2 forPreference:@"startupAudioMode"];assert(!p.audioAtLaunch);
 [p recordAudioActive:NO];[p setValue:@1 forPreference:@"startupAudioMode"];assert(p.audioAtLaunch);
 [p setValue:@99 forPreference:@"startupAudioMode"];assert(!p.audioAtLaunch);
 [p setValue:@0 forPreference:@"startupAudioMode"];[p recordAudioActive:YES];
 [p setValue:@YES forPreference:@"lastOnlyPlaying"];assert(p.playingOnlyAtLaunch);
 [p setValue:@1 forPreference:@"startupFilter"];assert(!p.playingOnlyAtLaunch);
 [p setValue:@NO forPreference:@"lastOnlyPlaying"];[p setValue:@2 forPreference:@"startupFilter"];assert(p.playingOnlyAtLaunch);
 [p setValue:@(-1) forPreference:@"startupFilter"];assert(!p.playingOnlyAtLaunch);
 [p setValue:@12 forPreference:@"menuLimit"];assert([p integer:@"menuLimit"]==12);
 [p setValue:@100 forPreference:@"menuLimit"];assert([p integer:@"menuLimit"]==8);
 [p setValue:@(-1) forPreference:@"menuIconStyle"];assert([p integer:@"menuIconStyle"]==0);
 [p setValue:@NO forPreference:@"showWindowAtLaunch"];[p setValue:@NO forPreference:@"showDockIcon"];
 [p setValue:@1 forPreference:@"closeBehavior"];[p setValue:@1 forPreference:@"menuIconStyle"];
 [p setValue:@2 forPreference:@"appearanceMode"];[p setValue:@YES forPreference:@"showPlayingCount"];
 PrismaPreferences*reopened=[[PrismaPreferences alloc]initWithDefaults:[[NSUserDefaults alloc]initWithSuiteName:suite]];
 assert(reopened.audioAtLaunch);assert(![reopened flag:@"showWindowAtLaunch"]);assert(![reopened flag:@"showDockIcon"]);
 assert([reopened integer:@"closeBehavior"]==1);assert([reopened integer:@"menuIconStyle"]==1);assert([reopened integer:@"appearanceMode"]==2);assert([reopened flag:@"showPlayingCount"]);
 [reopened recordAudioActive:NO];assert(!reopened.audioAtLaunch);
 [defaults removePersistentDomainForName:suite];
 FakeLoginService*service=[FakeLoginService new];PrismaLoginController*login=[PrismaLoginController new];login.service=service;
 service.status=SMAppServiceStatusNotFound;assert(!login.isRegistered);assert([login setEnabled:NO]);assert(service.removals==0);
 assert([login setEnabled:YES]);assert(login.isRegistered);assert(service.registrations==1);
 assert([login setEnabled:YES]);assert(service.registrations==1);
 service.fail=YES;assert(![login setEnabled:NO]);assert(login.isRegistered);assert(login.error.code==43);
 service.fail=NO;assert([login setEnabled:NO]);assert(!login.isRegistered);assert(login.error==nil);
 service.fail=YES;assert(![login setEnabled:YES]);assert(!login.isRegistered);assert(login.error.code==42);
 service.fail=NO;service.requireApproval=YES;assert([login setEnabled:YES]);assert(login.isRegistered);assert(service.status==SMAppServiceStatusRequiresApproval);
 NSUInteger count=service.registrations;assert([login setEnabled:YES]);assert(service.registrations==count);assert(!login.error);
 assert([login setEnabled:NO]);assert(!login.isRegistered);
 puts("PASS: launch restore/overrides, persistence, bounds, login enable/disable, approval, failures, idempotence");
}return 0;}
