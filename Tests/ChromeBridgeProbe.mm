#import <Cocoa/Cocoa.h>
int main(int argc,char**argv){@autoreleasepool{
 if(argc!=2)return 1;NSString*session=[NSString stringWithUTF8String:argv[1]];
 __block BOOL received=NO;NSDistributedNotificationCenter*c=NSDistributedNotificationCenter.defaultCenter;
 id observer=[c addObserverForName:@"local.prisma.chrome.state" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*n){
  NSDictionary*m=n.userInfo;if(![m[@"session"]isEqual:session])return;NSArray*tabs=m[@"tabs"];if(tabs.count!=2)return;
  [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.prisma.chrome.command" object:m[@"connection"] userInfo:@{@"session":session,@"id":@701,@"op":@"set",@"value":@0.35,@"step":@5,@"requestId":@"probe"} deliverImmediately:YES];
  received=YES;
 }];
 puts("READY");fflush(stdout);NSDate*deadline=[NSDate dateWithTimeIntervalSinceNow:5];while(!received&&deadline.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
 [c removeObserver:observer];return received?0:2;
}}
