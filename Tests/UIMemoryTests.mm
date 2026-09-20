// Run with the macOS WindowServer available. No real audio engines or settings are changed.
#define main PrismaApplicationMain
#ifndef PRISMA_MIXER_SOURCE
#define PRISMA_MIXER_SOURCE "../Source/Mixer.mm"
#endif
#include PRISMA_MIXER_SOURCE
#undef main
#include <mach/mach.h>
#include <cassert>
static uint64_t footprint(){task_vm_info_data_t info={};mach_msg_type_number_t count=TASK_VM_INFO_COUNT;assert(task_info(mach_task_self(),TASK_VM_INFO,(task_info_t)&info,&count)==KERN_SUCCESS);return info.phys_footprint;}
@interface TestTable:NSTableView
@property NSUInteger reloads;
@end
@implementation TestTable
-(void)reloadData{self.reloads++;[super reloadData];}
@end
int main(int argc,char**argv){@autoreleasepool{
 NSApplication*app=NSApplication.sharedApplication;[app setActivationPolicy:NSApplicationActivationPolicyProhibited];
 Mixer*m=[Mixer new];m.channels=[NSMutableArray array];m.browserTabs=[PrismaBrowserTabs new];m.slots=@[@"",@"",@"",@""];m.active=YES;m.status=[NSTextField labelWithString:@""];m.countLabel=[NSTextField labelWithString:@""];m.emptyState=[NSTextField labelWithString:@""];m.toggle=[NSButton checkboxWithTitle:@"" target:nil action:nil];
 NSUserDefaults*defaults=[[NSUserDefaults alloc]initWithSuiteName:@"local.prisma.memory-test"];m.preferences=[[PrismaPreferences alloc]initWithDefaults:defaults];
 m.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(-10000,-10000,720,480) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];m.window.releasedWhenClosed=NO;
 m.scroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(0,0,720,480)];m.table=[[TestTable alloc]initWithFrame:m.scroll.bounds];m.table.headerView=nil;m.table.rowHeight=60;m.table.dataSource=m;m.table.delegate=m;
 NSTableColumn*col=[[NSTableColumn alloc]initWithIdentifier:@"channel"];col.width=700;[m.table addTableColumn:col];m.scroll.documentView=m.table;[m.window.contentView addSubview:m.scroll];[m.window orderFront:nil];
 for(int i=0;i<8;i++){Channel*c=[Channel new];c.key=[NSString stringWithFormat:@"memory.test.%d",i];c.name=[NSString stringWithFormat:@"Audio %d",i];c.volume=1;[m.channels addObject:c];}
 uint64_t base=0,peak=0;NSUInteger count=argc>1?atoi(argv[1]):20000;
 for(NSUInteger i=0;i<count;i++){@autoreleasepool{
  Channel*c=m.channels[0];c.volume=(i%100)/100.0f;c.muted=(i%1000)>500;
  [m updateUI];[m.table layoutSubtreeIfNeeded];[m.window displayIfNeeded];
  // Drain both autoreleased objects and AppKit's deferred disposal work between updates.
  [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.0001]];
  if(i==999)base=footprint();if(i>=999)peak=std::max(peak,footprint());
  if((i+1)%1000==0){printf("updates=%lu footprint_mib=%.2f reloads=%lu\n",(unsigned long)i+1,footprint()/1048576.0,(unsigned long)((TestTable*)m.table).reloads);fflush(stdout);}
 }}
#ifndef PRISMA_BASELINE
 assert(((TestTable*)m.table).reloads==1);PrismaChannelRow*row=[m.table viewAtColumn:0 row:0 makeIfNecessary:YES];
 assert([row.levelSlider.identifier isEqual:m.channels[0].key]);assert(fabs(row.levelSlider.doubleValue-m.channels[0].volume*100)<.01);
 assert(row.levelSlider.target==m && row.muteButton.target==m);
 assert(([row.valueLabel.stringValue isEqual:[NSString stringWithFormat:@"%.0f%%",m.channels[0].volume*100]]));
 // Structural changes must reload; ordinary values must not. Reused controls target the new row.
 [m.channels removeObjectAtIndex:0];[m updateUI];assert(((TestTable*)m.table).reloads==2);[m.table layoutSubtreeIfNeeded];
 row=[m.table viewAtColumn:0 row:0 makeIfNecessary:YES];assert([row.levelSlider.identifier isEqual:m.channels[0].key]);
 [m.window orderOut:nil];NSUInteger previous=((TestTable*)m.table).reloads;[m.channels removeLastObject];[m updateUI];assert(((TestTable*)m.table).reloads==previous);
 [m.window orderFront:nil];[m updateUI];assert(((TestTable*)m.table).reloads==previous+1);
 assert(peak-base < 16*1024*1024); // Permit AppKit caches to warm; reject sustained accumulation.
 printf("PASS: reusable rows, current values/targets, structural changes, hidden window; growth %.2f MiB\n",(peak-base)/1048576.0);
#endif
 [m.window orderOut:nil];m.table.delegate=nil;m.table.dataSource=nil;
}return 0;}
