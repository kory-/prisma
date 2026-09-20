// Exercise real AppKit views without starting audio capture or changing user settings.
#define main PrismaApplicationMain
#include "../Source/Mixer.mm"
#undef main
#include <cassert>

@interface LanguageTestMixer:Mixer @end
@implementation LanguageTestMixer
-(void)refresh{[self updateUI];}
-(void)applyPreferences{[self updateUI];}
@end
static void saveView(NSView *view,NSString *path){
 [view layoutSubtreeIfNeeded];
 NSBitmapImageRep *rep=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
 [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
 assert([[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES]);
}
int main(int argc,char **argv){@autoreleasepool{
 setbuf(stdout,nullptr);puts("Localization: preferences");
 assert(argc==3);NSString *resources=[NSString stringWithUTF8String:argv[1]],*images=[NSString stringWithUTF8String:argv[2]];
 assert([PrismaLanguageFor(0,@[@"ja-JP"])isEqual:@"ja"]);
 assert([PrismaLanguageFor(0,@[@"en_GB"])isEqual:@"en"]);
 assert([PrismaLanguageFor(0,@[@"fr-FR",@"ja"])isEqual:@"ja"]);
 assert([PrismaLanguageFor(0,@[@"fr-FR"])isEqual:@"en"]);
 assert([PrismaLanguageFor(1,@[@"en"])isEqual:@"ja"]);
 assert([PrismaLanguageFor(2,@[@"ja"])isEqual:@"en"]);
 assert([PrismaLanguageFor(99,@[])isEqual:@"en"]);
 NSString *suite=[@"local.prisma.language-test." stringByAppendingString:NSUUID.UUID.UUIDString];
 NSUserDefaults *defaults=[[NSUserDefaults alloc]initWithSuiteName:suite];
 PrismaPreferences *preferences=[[PrismaPreferences alloc]initWithDefaults:defaults];
 PrismaSetLanguagePreference(defaults,1);assert([[defaults stringArrayForKey:@"AppleLanguages"]isEqual:@[@"ja"]]);
 PrismaSetLanguagePreference(defaults,2);assert([[defaults stringArrayForKey:@"AppleLanguages"]isEqual:@[@"en"]]);
 PrismaPreferences *reopened=[[PrismaPreferences alloc]initWithDefaults:[[NSUserDefaults alloc]initWithSuiteName:suite]];assert([reopened integer:@"languageMode"]==2);
 PrismaSetLanguagePreference(defaults,0);assert(![defaults persistentDomainForName:suite][@"AppleLanguages"]);
 [defaults setInteger:99 forKey:@"languageMode"];assert([preferences integer:@"languageMode"]==0);
 [defaults removePersistentDomainForName:suite];
 puts("Localization: views");
 NSApplication *app=NSApplication.sharedApplication;[app setActivationPolicy:NSApplicationActivationPolicyProhibited];app.appearance=[NSAppearance appearanceNamed:NSAppearanceNameAqua];
 LanguageTestMixer *m=[LanguageTestMixer new];m.preferences=preferences;m.channels=[NSMutableArray array];m.browserTabs=[PrismaBrowserTabs new];m.slots=@[@"example.app",@"",@"",@""];m.active=YES;m.onlyPlaying=NO;
 Channel *channel=[Channel new];channel.key=@"example.app";channel.name=@"Example Player";channel.volume=.42;channel.muted=YES;channel.enabled=YES;channel->engine.gain.store(.42);[m.channels addObject:channel];
 PrismaLoadLanguage(@"ja",resources);[m buildInterface];[m.window setFrameOrigin:NSMakePoint(-10000,-10000)];[m buildSettings];[m.settingsWindow setFrameOrigin:NSMakePoint(-10000,-10000)];
 assert([m.window.subtitle isEqual:@"アプリごとの音量"]);
 NSWindow *mainWindow=m.window,*preferencesWindow=m.settingsWindow;
 NSStatusItem *statusItem=m.item;Engine *engine=&channel->engine;
 puts("Localization: switching");
 for(NSString *language in @[@"en",@"ja",@"en"]){
  printf("Language: %s\n",language.UTF8String);PrismaLoadLanguage(language,resources);[m relocalizeInterface];if(!m.settingsWindow)[m buildSettings];[m.settingsWindow setFrameOrigin:NSMakePoint(-10000,-10000)];[m.settingsWindow orderFront:nil];
  assert(m.window==mainWindow&&m.settingsWindow==preferencesWindow);
  assert(m.item==statusItem&&m.channels[0]==channel&&&channel->engine==engine);
  assert(m.active&&channel.muted&&channel.enabled&&fabs(channel.volume-.42)<.0001&&fabs(channel->engine.gain.load()-.42)<.0001);
  assert([m.window.subtitle isEqual:PL(@"Per-app Volume")]);
  assert([NSApp.mainMenu.itemArray[0].submenu.itemArray[0].title isEqual:PL(@"About Prisma")]);
  [m menuNeedsUpdate:m.item.menu];assert([m.item.menu.itemArray.lastObject.title isEqual:PL(@"Quit")]);
  NSPopUpButton *picker=(NSPopUpButton*)m.preferenceControls[@"languageMode"];
  assert(picker.numberOfItems==3);assert([picker.itemArray[1].title isEqual:@"日本語"]);assert([picker.itemArray[2].title isEqual:@"English"]);
  NSTabViewController *tabs=(NSTabViewController*)m.settingsWindow.contentViewController;
  assert(tabs.tabViewItems.count==4);
  for(NSUInteger index=0;index<tabs.tabViewItems.count;index++){
   tabs.selectedTabViewItemIndex=index;
   NSView *view=tabs.tabViewItems[index].viewController.view;
   saveView(view,[images stringByAppendingPathComponent:[NSString stringWithFormat:@"settings-%@-%lu.png",language,(unsigned long)index]]);
   // Measure wrapped notes using the same font and available width.
   for(NSView *child in view.subviews)if([child isKindOfClass:NSTextField.class]){
    NSTextField *label=(NSTextField*)child;
    if(label.maximumNumberOfLines==0){NSRect size=[label.stringValue boundingRectWithSize:NSMakeSize(label.frame.size.width,1000) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:label.font}];assert(size.size.height<=label.frame.size.height+2);}
   }
  }
  PrismaChannelRow *row=[[PrismaChannelRow alloc]initWithFrame:NSMakeRect(0,0,700,60)];[row configure:channel icon:nil chromeHasTabs:NO target:m];
  assert([row.detailLabel.stringValue isEqual:PL(@"Muted")]);assert(([row.levelSlider.accessibilityLabel isEqual:[NSString stringWithFormat:PL(@"Volume for %@"),channel.name]]));
 }
 // Allow AppKit's deferred disposal to run between events, as in the real app.
 NSUInteger settledWindows=0,finalWindows=0;
 for(int i=0;i<12;i++){@autoreleasepool{
  PrismaLoadLanguage(i%2?@"ja":@"en",resources);[m relocalizeInterface];
  [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.02]];
 }
  finalWindows=0;for(NSWindow *window in NSApp.windows)if([window.title hasPrefix:@"Prisma"])finalWindows++;
  if(i==3)settledWindows=finalWindows;
  printf("switch=%d windows=%lu\n",i+1,(unsigned long)finalWindows);
 }
 assert(finalWindows<=settledWindows);
 puts("PASS: repeated language changes reuse the same Prisma windows");
 PrismaLoadLanguage(@"ja",resources);assert([PL(@"Settings")isEqual:@"設定"]);assert([PrismaLocalizedError(@"Unable to create the audio capture (Core Audio: -1)")isEqual:@"音声の取り込みを作成できません (Core Audio: -1)"]);
 PrismaLoadLanguage(@"en",resources);assert([PrismaLocalizedError(@"音声経路を作成できません")isEqual:@"Unable to create the audio route"]);
 [m.window orderOut:nil];[m.settingsWindow orderOut:nil];[NSStatusBar.systemStatusBar removeStatusItem:m.item];
 [defaults removePersistentDomainForName:suite];
 puts("PASS: language negotiation, persistence, permission preference, native menus/rows/settings, layout, and audio state preserved across language changes");
}return 0;}
