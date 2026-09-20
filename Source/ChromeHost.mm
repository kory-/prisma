#import <Cocoa/Cocoa.h>
#include <unistd.h>
#include <signal.h>
#include "ChromeExtensionID.h"
static NSString*const stateName=@"local.prisma.chrome.state";
static NSString*const commandName=@"local.prisma.chrome.command";
static void send(NSDictionary*message){
 NSData*data=[NSJSONSerialization dataWithJSONObject:message options:0 error:nil];if(!data||data.length>1024*1024)return;
 uint32_t size=CFSwapInt32HostToLittle((uint32_t)data.length);
 if(fwrite(&size,1,4,stdout)!=4||fwrite(data.bytes,1,data.length,stdout)!=data.length||fflush(stdout)!=0)exit(0);
}
static BOOL readBytes(void*buffer,size_t count){size_t done=0;while(done<count){size_t n=fread((char*)buffer+done,1,count-done,stdin);if(!n)return NO;done+=n;}return YES;}
int main(int argc,char**argv){@autoreleasepool{
 NSString*origin=argc>1?[NSString stringWithUTF8String:argv[1]]:@"";
 if(![origin isEqual:[NSString stringWithFormat:@"chrome-extension://%@/",PRISMA_CHROME_ID]])return 1;
 signal(SIGPIPE,SIG_IGN);setvbuf(stdout,nullptr,_IONBF,0);
 NSString*connection=NSUUID.UUID.UUIDString;__block NSString*session=@"";__block NSDate*lastApp=NSDate.distantPast;__block BOOL lastActive=NO;
 NSDistributedNotificationCenter*center=NSDistributedNotificationCenter.defaultCenter;
 id appObserver=[center addObserverForName:@"local.appmixer.state" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*n){
  BOOL active=[n.userInfo[@"active"]boolValue];if([NSDate.date timeIntervalSinceDate:lastApp]<.8&&lastActive==active)return;lastActive=active;lastApp=NSDate.date;send(@{@"type":@"app",@"active":@(active)});
 }];
 id commandObserver=[center addObserverForName:commandName object:connection queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*n){
  NSDictionary*m=n.userInfo;if(![m[@"session"]isEqual:session])return;
  NSString*op=m[@"op"];if(![@[@"up",@"down",@"set",@"mute",@"focus",@"release"]containsObject:op])return;
  NSMutableDictionary*out=[m mutableCopy];out[@"type"]=@"command";send(out);
 }];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  while(true){@autoreleasepool{
   uint32_t header=0;if(!readBytes(&header,4))break;uint32_t size=CFSwapInt32LittleToHost(header);if(size==0||size>256*1024)break;
   NSMutableData*data=[NSMutableData dataWithLength:size];if(!readBytes(data.mutableBytes,size))break;
   id parsed=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if(![parsed isKindOfClass:NSDictionary.class])break;
   NSDictionary*m=parsed;
   dispatch_sync(dispatch_get_main_queue(),^{
    if([m[@"type"]isEqual:@"hello"]){send(@{@"type":@"ready"});return;}
    if([m[@"type"]isEqual:@"activate"]){[center postNotificationName:stateName object:connection userInfo:@{@"connection":connection,@"activate":@YES} deliverImmediately:YES];return;}
    if(![m[@"type"]isEqual:@"state"]||![m[@"session"]isKindOfClass:NSString.class]||![[NSUUID alloc]initWithUUIDString:m[@"session"]]||![m[@"tabs"]isKindOfClass:NSArray.class]||[m[@"tabs"]count]>16)return;
    session=m[@"session"];
    [center postNotificationName:stateName object:connection userInfo:@{@"connection":connection,@"session":session,@"tabs":m[@"tabs"]} deliverImmediately:YES];
   });
  }}
  dispatch_async(dispatch_get_main_queue(),^{[center postNotificationName:stateName object:connection userInfo:@{@"connection":connection,@"closed":@YES} deliverImmediately:YES];exit(0);});
 });
 (void)appObserver;(void)commandObserver;[NSRunLoop.mainRunLoop run];
}return 0;}
