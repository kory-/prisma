#import <Cocoa/Cocoa.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/CATapDescription.h>
#import <CoreAudio/AudioHardwareTapping.h>
#include <atomic>
#include <vector>
#include <algorithm>
#include <cmath>
#include <libproc.h>
#include "Brand.h"
#include "Preferences.h"
#include "BrowserTabs.h"
#include "ChromeExtensionID.h"

static AudioObjectPropertyAddress addr(AudioObjectPropertySelector s, AudioObjectPropertyScope scope=kAudioObjectPropertyScopeGlobal) { return {s,scope,kAudioObjectPropertyElementMain}; }
template<class T> static T readValue(AudioObjectID o, AudioObjectPropertySelector s, AudioObjectPropertyScope scope=kAudioObjectPropertyScopeGlobal) { T v{}; UInt32 n=sizeof(v); auto a=addr(s,scope); AudioObjectGetPropertyData(o,&a,0,nullptr,&n,&v); return v; }
static NSArray<NSNumber*>* ids(AudioObjectID o, AudioObjectPropertySelector s, AudioObjectPropertyScope scope=kAudioObjectPropertyScopeGlobal) { auto a=addr(s,scope); UInt32 n=0; if(AudioObjectGetPropertyDataSize(o,&a,0,nullptr,&n)) return @[]; std::vector<AudioObjectID> v(n/4); if(n && AudioObjectGetPropertyData(o,&a,0,nullptr,&n,v.data())) return @[]; NSMutableArray *r=[NSMutableArray array]; for(auto x:v) [r addObject:@(x)]; return r; }
static NSString* str(AudioObjectID o,AudioObjectPropertySelector s) { CFStringRef v=readValue<CFStringRef>(o,s); return v ? CFBridgingRelease(v) : @""; }
static void check(OSStatus s,NSString* step) { if(s) @throw [NSException exceptionWithName:@"Audio" reason:[NSString stringWithFormat:@"%@ (Core Audio: %d)",step,(int)s] userInfo:nil]; }
static BOOL floatPCM(AudioStreamBasicDescription f) { return f.mFormatID==kAudioFormatLinearPCM && (f.mFormatFlags & kAudioFormatFlagIsFloat) && !(f.mFormatFlags & kAudioFormatFlagIsBigEndian) && f.mBitsPerChannel==32; }

struct Engine {
 AudioObjectID tap=0, device=0; AudioDeviceIOProcID io=nullptr;
 std::atomic<float> gain{1}, peak{0}; std::atomic<unsigned> callbacks{0};
 bool monitoring=false; float smooth=1; double rate=48000;
 static OSStatus render(AudioObjectID,const AudioTimeStamp*,const AudioBufferList* in,const AudioTimeStamp*,AudioBufferList* out,const AudioTimeStamp*,void* ctx) {
  Engine* e=(Engine*)ctx; e->callbacks.fetch_add(1,std::memory_order_relaxed);
  for(UInt32 b=0;b<out->mNumberBuffers;b++) if(out->mBuffers[b].mData) memset(out->mBuffers[b].mData,0,out->mBuffers[b].mDataByteSize);
  // The tap is appended after the physical device's input streams. Never route microphone channels.
  unsigned total=0; for(UInt32 b=0;b<in->mNumberBuffers;b++) total+=in->mBuffers[b].mNumberChannels;
  if(total<2) return noErr;
  const AudioBuffer* src[2]={}; unsigned off[2]={}; unsigned pos=0;
  for(UInt32 b=0;b<in->mNumberBuffers;b++) { auto &x=in->mBuffers[b]; for(unsigned c=0;c<2;c++) if(total-2+c>=pos && total-2+c<pos+x.mNumberChannels) {src[c]=&x;off[c]=total-2+c-pos;} pos+=x.mNumberChannels; }
  if(e->monitoring){float p=0;for(int c=0;c<2;c++){if(!src[c]||!src[c]->mData)continue;unsigned n=src[c]->mDataByteSize/(4*src[c]->mNumberChannels);for(unsigned f=0;f<n;f++){float v=((float*)src[c]->mData)[f*src[c]->mNumberChannels+off[c]];if(std::isfinite(v))p=std::max(p,std::abs(v));}}float previous=e->peak.load();while(previous<p&&!e->peak.compare_exchange_weak(previous,p)){}return noErr;}
  AudioBuffer* dst[2]={}; unsigned dOff[2]={};pos=0;
  for(UInt32 b=0;b<out->mNumberBuffers;b++) {auto &x=out->mBuffers[b];for(unsigned c=0;c<2;c++) if(c>=pos && c<pos+x.mNumberChannels){dst[c]=&x;dOff[c]=c-pos;}pos+=x.mNumberChannels;}
  unsigned frames=UINT_MAX;
  for(int c=0;c<2;c++){if(!src[c]||!dst[c]||!src[c]->mData||!dst[c]->mData)return noErr;frames=std::min(frames,src[c]->mDataByteSize/(4*src[c]->mNumberChannels));frames=std::min(frames,dst[c]->mDataByteSize/(4*dst[c]->mNumberChannels));}
  float target=e->gain.load(std::memory_order_relaxed), p=0; float step=1.0f/(float)(e->rate*0.005);
  for(unsigned f=0;f<frames;f++){e->smooth+=std::clamp(target-e->smooth,-step,step);for(int c=0;c<2;c++){float v=((float*)src[c]->mData)[f*src[c]->mNumberChannels+off[c]]; if(!std::isfinite(v))v=0; p=std::max(p,std::abs(v)); ((float*)dst[c]->mData)[f*dst[c]->mNumberChannels+dOff[c]]=std::clamp(v*e->smooth,-1.0f,1.0f);}}
  float previous=e->peak.load();while(previous<p&&!e->peak.compare_exchange_weak(previous,p)){}return noErr;
 }
 void stop(){if(device&&io){AudioDeviceStop(device,io);AudioDeviceDestroyIOProcID(device,io);}io=nullptr;if(device)AudioHardwareDestroyAggregateDevice(device);device=0;if(tap)AudioHardwareDestroyProcessTap(tap);tap=0;}
 ~Engine(){stop();}
 void start(NSArray<NSNumber*>* processes,AudioObjectID output,float volume,bool monitor=false){
  stop();monitoring=monitor; @try {
   NSArray *streams=ids(output,kAudioDevicePropertyStreams,kAudioObjectPropertyScopeOutput);
   if(streams.count!=1) @throw [NSException exceptionWithName:@"Format" reason:PL(@"Please select a stereo output device, such as the built-in speakers.") userInfo:nil];
   auto fmt=readValue<AudioStreamBasicDescription>([streams[0] unsignedIntValue],kAudioStreamPropertyVirtualFormat);
   if(!floatPCM(fmt)||fmt.mChannelsPerFrame!=2) @throw [NSException exceptionWithName:@"Format" reason:PL(@"This output device does not support 32-bit float stereo audio.") userInfo:nil];
   rate=fmt.mSampleRate;NSString *uid=str(output,kAudioDevicePropertyDeviceUID);
   CATapDescription *desc=[[CATapDescription alloc] initWithProcesses:processes andDeviceUID:uid withStream:0];desc.name=@"Prisma";[desc setPrivate:YES];desc.muteBehavior=monitor?CATapUnmuted:CATapMutedWhenTapped;
   check(AudioHardwareCreateProcessTap(desc,&tap),PL(@"Unable to create the audio capture"));
   auto tf=readValue<AudioStreamBasicDescription>(tap,kAudioTapPropertyFormat);
   if(!floatPCM(tf)||tf.mChannelsPerFrame!=2||tf.mSampleRate!=rate) @throw [NSException exceptionWithName:@"Format" reason:PL(@"The captured audio format does not match the output.") userInfo:nil];
   NSMutableDictionary *spec=[@{@kAudioAggregateDeviceNameKey:@"Prisma",@kAudioAggregateDeviceUIDKey:NSUUID.UUID.UUIDString,@kAudioAggregateDeviceIsPrivateKey:@YES,@kAudioAggregateDeviceMainSubDeviceKey:uid,@kAudioAggregateDeviceSubDeviceListKey:@[@{@kAudioSubDeviceUIDKey:uid}],@kAudioAggregateDeviceTapListKey:@[@{@kAudioSubTapUIDKey:desc.UUID.UUIDString,@kAudioSubTapDriftCompensationKey:@YES}],@kAudioAggregateDeviceTapAutoStartKey:@NO} mutableCopy];
   if(monitor){[spec removeObjectForKey:@kAudioAggregateDeviceMainSubDeviceKey];[spec removeObjectForKey:@kAudioAggregateDeviceSubDeviceListKey];}
   check(AudioHardwareCreateAggregateDevice((__bridge CFDictionaryRef)spec,&device),PL(@"Unable to create the audio route"));
   gain.store(volume);smooth=volume;callbacks.store(0);peak.store(0);
   check(AudioDeviceCreateIOProcID(device,render,this,&io),PL(@"Unable to register audio processing"));check(AudioDeviceStart(device,io),PL(@"Unable to start audio processing. Check system audio recording permission"));
  } @catch(NSException *ex){stop();@throw ex;}
 }
};

@interface Channel:NSObject { @public Engine engine; }
@property BOOL browserTab; @property NSString *iconData; @property NSImage *tabIcon;
@property NSString *key; @property NSString *name; @property NSArray<NSNumber*> *processes;
@property NSDate *started; @property NSTimeInterval lastHeard; @property BOOL processPlaying;
@property float volume; @property float meter; @property BOOL muted; @property BOOL enabled; @property NSString *error;
@end
@implementation Channel @end

static NSTextField* Label(NSString*text,CGFloat size,NSFontWeight weight,NSColor*color,NSRect frame){NSTextField*l=[NSTextField labelWithString:text];l.font=[NSFont systemFontOfSize:size weight:weight];l.textColor=color;l.frame=frame;l.lineBreakMode=NSLineBreakByTruncatingTail;return l;}
static void SetLabel(NSTextField*label,NSString*value){if(![label.stringValue isEqual:value])label.stringValue=value;}
static NSImageView* Icon(NSImage*im,NSRect frame){NSImageView*v=[[NSImageView alloc]initWithFrame:frame];v.image=im;return v;}
static NSSlider* Slider(float value,id target,SEL action,NSString*key,NSRect frame){NSSlider*s=[NSSlider sliderWithValue:value*100 minValue:0 maxValue:100 target:target action:action];s.frame=frame;s.continuous=YES;s.identifier=key;s.controlSize=NSControlSizeRegular;return s;}
static NSBox* Rule(NSRect frame){NSBox*box=[[NSBox alloc]initWithFrame:frame];box.boxType=NSBoxSeparator;return box;}
// One reusable native row per visible channel; polling only changes its values.
@interface PrismaChannelRow:NSView
@property NSImageView*iconView;
@property NSTextField*nameLabel; @property NSTextField*detailLabel; @property NSTextField*valueLabel;
@property NSSlider*levelSlider; @property NSButton*muteButton; @property NSString*muteSymbol;
-(void)configure:(Channel*)channel icon:(NSImage*)icon chromeHasTabs:(BOOL)chromeHasTabs target:(id)target;
@end
@implementation PrismaChannelRow
-(instancetype)initWithFrame:(NSRect)frame {
 if((self=[super initWithFrame:frame])){
  self.identifier=@"channel-row";CGFloat w=frame.size.width;
  self.iconView=Icon(nil,NSMakeRect(20,15,30,30));[self addSubview:self.iconView];
  self.nameLabel=Label(@"",13,NSFontWeightMedium,NSColor.labelColor,NSMakeRect(64,31,MAX(150,w-433),19));self.nameLabel.autoresizingMask=NSViewWidthSizable;[self addSubview:self.nameLabel];
  self.detailLabel=Label(@"",11,NSFontWeightRegular,NSColor.secondaryLabelColor,NSMakeRect(65,13,MAX(150,w-433),17));self.detailLabel.autoresizingMask=NSViewWidthSizable;[self addSubview:self.detailLabel];
  self.levelSlider=Slider(1,nil,@selector(level:),@"",NSMakeRect(w-324,21,198,22));self.levelSlider.autoresizingMask=NSViewMinXMargin;[self addSubview:self.levelSlider];
  self.valueLabel=Label(@"",12,NSFontWeightRegular,NSColor.secondaryLabelColor,NSMakeRect(w-113,22,44,19));self.valueLabel.font=[NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];self.valueLabel.identifier=@"value";self.valueLabel.alignment=NSTextAlignmentRight;self.valueLabel.autoresizingMask=NSViewMinXMargin;[self addSubview:self.valueLabel];
  self.muteSymbol=@"speaker.wave.2";self.muteButton=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"speaker.wave.2" accessibilityDescription:PL(@"Toggle Mute")] target:nil action:@selector(mute:)];self.muteButton.bordered=NO;self.muteButton.frame=NSMakeRect(w-54,18,30,26);self.muteButton.autoresizingMask=NSViewMinXMargin;[self addSubview:self.muteButton];
  NSBox*line=Rule(NSMakeRect(64,0,w-86,1));line.autoresizingMask=NSViewWidthSizable;[self addSubview:line];
 }return self;
}
-(void)configure:(Channel*)c icon:(NSImage*)icon chromeHasTabs:(BOOL)chromeHasTabs target:(id)target {
 BOOL playing=NSDate.timeIntervalSinceReferenceDate-c.lastHeard<2;
 NSString*status=c.error?(c.browserTab?PL(@"Reload the page"):PL(@"Check audio access")):c.muted?PL(@"Muted"):playing?PL(@"Playing"):PL(@"Idle");
 if(c.browserTab)status=[PL(@"Chrome tab · ") stringByAppendingString:status];else if([c.key isEqual:@"com.google.Chrome"]&&chromeHasTabs)status=[PL(@"All of Chrome · ") stringByAppendingString:status];
 if(self.iconView.image!=icon)self.iconView.image=icon;
 if(![self.nameLabel.stringValue isEqual:c.name])self.nameLabel.stringValue=c.name;
 if(![self.detailLabel.stringValue isEqual:status])self.detailLabel.stringValue=status;
 NSString*tip=PrismaLocalizedError(c.error)?:c.browserTab?c.name:c.key;if(![self.detailLabel.toolTip isEqual:tip])self.detailLabel.toolTip=tip;
 if(![self.levelSlider.identifier isEqual:c.key]){self.levelSlider.identifier=c.key;self.levelSlider.accessibilityLabel=[NSString stringWithFormat:PL(@"Volume for %@"),c.name];self.muteButton.identifier=c.key;}
 else if(![self.levelSlider.accessibilityLabel isEqual:[NSString stringWithFormat:PL(@"Volume for %@"),c.name]])self.levelSlider.accessibilityLabel=[NSString stringWithFormat:PL(@"Volume for %@"),c.name];
 self.levelSlider.target=target;self.muteButton.target=target;
 if(fabs(self.levelSlider.doubleValue-c.volume*100)>0.0001)self.levelSlider.doubleValue=c.volume*100;
 NSString*value=[NSString stringWithFormat:@"%.0f%%",c.volume*100];if(![self.valueLabel.stringValue isEqual:value])self.valueLabel.stringValue=value;
 NSString*symbol=c.muted?@"speaker.slash.fill":@"speaker.wave.2";
 if(![self.muteSymbol isEqual:symbol]){self.muteSymbol=symbol;self.muteButton.image=[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:PL(@"Toggle Mute")];}
 NSColor*color=c.muted?NSColor.systemOrangeColor:NSColor.secondaryLabelColor;if(![self.muteButton.contentTintColor isEqual:color])self.muteButton.contentTintColor=color;
 NSString*muteTip=[NSString stringWithFormat:PL(@"Toggle mute for %@"),c.name];if(![self.muteButton.toolTip isEqual:muteTip])self.muteButton.toolTip=muteTip;
}
@end
@interface Mixer:NSObject<NSApplicationDelegate,NSTableViewDataSource,NSTableViewDelegate,NSMenuDelegate,NSToolbarDelegate,NSWindowDelegate>
@property PrismaBrowserTabs *browserTabs;
@property PrismaPreferences *preferences; @property PrismaLoginController *loginController;
@property NSWindow *settingsWindow; @property NSMutableDictionary<NSString*,NSControl*> *preferenceControls;
@property NSSwitch *loginSwitch; @property NSTextField *loginStatus; @property NSButton *loginSettingsButton;
@property NSWindow *window; @property NSTableView *table; @property NSTextField *status; @property NSTextField *countLabel;
@property NSButton *toggle; @property NSSegmentedControl *scope; @property NSScrollView *scroll; @property NSTextField *emptyState;
@property NSMutableArray<Channel*> *channels; @property NSArray<Channel*> *displayed; @property NSMutableDictionary *prefs;
@property BOOL rowsNeedReload;
@property BOOL active; @property BOOL onlyPlaying; @property BOOL menuOpen; @property BOOL refreshing;
@property NSArray<NSString*> *slots; @property NSTimeInterval freezeUntil;
@property NSPopUpButton *outputs; @property AudioObjectID output;
@property NSString *outputSignature; @property NSArray *deviceIDs; @property NSTimer *timer; @property NSStatusItem *item;
@end
@implementation Mixer
-(Channel*)channel:(NSString*)key{for(Channel*c in self.channels)if([c.key isEqual:key])return c;return nil;}
-(void)applicationDidFinishLaunching:(NSNotification*)n {
 self.browserTabs=[PrismaBrowserTabs new];[NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(receiveBrowser:) name:@"local.prisma.chrome.state" object:nil];
 self.preferences=[[PrismaPreferences alloc]initWithDefaults:NSUserDefaults.standardUserDefaults];PrismaRefreshLanguage(self.preferences.defaults);self.active=self.preferences.audioAtLaunch;self.onlyPlaying=self.preferences.playingOnlyAtLaunch;
 self.loginController=[PrismaLoginController new];self.loginController.service=(id<PrismaLoginService>)SMAppService.mainAppService;
 NSApp.applicationIconImage=PrismMark(256);self.channels=[NSMutableArray array];self.prefs=[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"levels"] mutableCopy]?:[NSMutableDictionary dictionary];self.slots=@[@"",@"",@"",@""];
 [self buildInterface];
 [self applyPreferences];[self refresh];self.timer=[NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(refresh) userInfo:nil repeats:YES];[[NSRunLoop mainRunLoop]addTimer:self.timer forMode:NSRunLoopCommonModes];
 if([self.preferences flag:@"showWindowAtLaunch"])[self show:nil];
}
// Rebuild only views when the language changes; channels and audio engines stay alive.
-(void)buildInterface {
 BOOL newWindow=self.window==nil;
 for(NSView *view in self.window.contentView.subviews.copy)[view removeFromSuperview];
 if(newWindow)self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,720,390) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];self.window.delegate=self;self.window.releasedWhenClosed=NO;self.window.title=@"Prisma";self.window.subtitle=PL(@"Per-app Volume");self.window.toolbarStyle=NSWindowToolbarStyleUnified;self.window.minSize=NSMakeSize(720,310);self.window.backgroundColor=NSColor.windowBackgroundColor;if(newWindow){[self.window center];[self.window setFrameAutosaveName:@"PrismaMixerWindow"];}
 NSToolbar*toolbar=[[NSToolbar alloc]initWithIdentifier:@"PrismaNativeToolbar"];toolbar.delegate=self;toolbar.displayMode=NSToolbarDisplayModeIconOnly;toolbar.allowsUserCustomization=NO;self.window.toolbar=toolbar;
 NSView*v=self.window.contentView;CGFloat width=v.bounds.size.width,height=v.bounds.size.height;
 NSVisualEffectView*background=[[NSVisualEffectView alloc]initWithFrame:v.bounds];background.material=NSVisualEffectMaterialWindowBackground;background.blendingMode=NSVisualEffectBlendingModeBehindWindow;background.state=NSVisualEffectStateFollowsWindowActiveState;background.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;[v addSubview:background];
 self.scroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(0,36,width,height-36)];self.scroll.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;self.scroll.hasVerticalScroller=YES;self.scroll.drawsBackground=NO;self.scroll.automaticallyAdjustsContentInsets=NO;
 self.table=[[NSTableView alloc]initWithFrame:self.scroll.bounds];NSTableColumn*col=[[NSTableColumn alloc]initWithIdentifier:@"channel"];col.width=MAX(1,width-16);[self.table addTableColumn:col];self.table.style=NSTableViewStyleFullWidth;self.table.headerView=nil;self.table.backgroundColor=NSColor.clearColor;self.table.columnAutoresizingStyle=NSTableViewLastColumnOnlyAutoresizingStyle;self.table.intercellSpacing=NSMakeSize(0,0);self.table.rowHeight=60;self.table.delegate=self;self.table.dataSource=self;self.table.selectionHighlightStyle=NSTableViewSelectionHighlightStyleNone;self.scroll.documentView=self.table;[v addSubview:self.scroll];
 self.emptyState=Label(PL(@"No apps are playing audio"),13,NSFontWeightRegular,NSColor.secondaryLabelColor,NSMakeRect(50,36+(height-36)/2-12,width-100,24));self.emptyState.alignment=NSTextAlignmentCenter;self.emptyState.autoresizingMask=NSViewWidthSizable|NSViewMinYMargin|NSViewMaxYMargin;[v addSubview:self.emptyState];
 NSVisualEffectView*footer=[[NSVisualEffectView alloc]initWithFrame:NSMakeRect(0,0,width,36)];footer.material=NSVisualEffectMaterialHeaderView;footer.blendingMode=NSVisualEffectBlendingModeWithinWindow;footer.autoresizingMask=NSViewWidthSizable;[v addSubview:footer];NSBox*line=Rule(NSMakeRect(0,35,width,1));line.autoresizingMask=NSViewWidthSizable;[footer addSubview:line];self.status=Label(@"",11,NSFontWeightRegular,NSColor.secondaryLabelColor,NSMakeRect(20,10,width-240,17));self.status.autoresizingMask=NSViewWidthSizable;[footer addSubview:self.status];self.countLabel=Label(@"",11,NSFontWeightRegular,NSColor.secondaryLabelColor,NSMakeRect(width-200,10,180,17));self.countLabel.alignment=NSTextAlignmentRight;self.countLabel.autoresizingMask=NSViewMinXMargin;[footer addSubview:self.countLabel];
 NSImage*mark=PrismMark(20);if(!self.item)self.item=[[NSStatusBar systemStatusBar]statusItemWithLength:NSVariableStatusItemLength];self.item.button.image=mark;self.item.button.toolTip=PL(@"Prisma — Per-app Volume");NSMenu*menu=[NSMenu new];menu.delegate=self;self.item.menu=menu;
 NSMenu*main=[NSMenu new];NSMenuItem*root=[NSMenuItem new];[main addItem:root];NSMenu*application=[NSMenu new];
 [application addItemWithTitle:PL(@"About Prisma") action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
 [application addItem:NSMenuItem.separatorItem];NSMenuItem*settings=[application addItemWithTitle:PL(@"Settings…") action:@selector(showSettings:) keyEquivalent:@","];settings.target=self;
 NSMenuItem*chrome=[application addItemWithTitle:PL(@"Set Up Chrome Extension…") action:@selector(configureChrome:) keyEquivalent:@""];chrome.target=self;
 NSMenuItem*access=[application addItemWithTitle:PL(@"Audio Access Settings…") action:@selector(permissions:) keyEquivalent:@""];access.target=self;
 [application addItem:NSMenuItem.separatorItem];[application addItemWithTitle:PL(@"Hide Prisma") action:@selector(hide:) keyEquivalent:@"h"];
 [application addItemWithTitle:PL(@"Quit Prisma") action:@selector(terminate:) keyEquivalent:@"q"];root.submenu=application;
 NSMenuItem*quick=[NSMenuItem new];quick.title=PL(@"Mixer");NSMenu*qm=[NSMenu new];qm.delegate=self;quick.submenu=qm;[main addItem:quick];NSApp.mainMenu=main;
 self.rowsNeedReload=YES;self.deviceIDs=nil;
}
-(void)relocalizeInterface {
 for(Channel *channel in self.channels)channel.error=PrismaLocalizedError(channel.error);
 BOOL settingsVisible=self.settingsWindow.visible;
 NSRect frame=self.window.frame,settingsFrame=self.settingsWindow.frame;
 NSInteger selected=self.settingsWindow?((NSTabViewController*)self.settingsWindow.contentViewController).selectedTabViewItemIndex:0;
 [self buildInterface];[self.window setFrame:frame display:NO];[self applyPreferences];
 if(self.settingsWindow){[self buildSettings];((NSTabViewController*)self.settingsWindow.contentViewController).selectedTabViewItemIndex=selected;[self.settingsWindow setFrameOrigin:settingsFrame.origin];if(settingsVisible)[self showSettings:nil];}
 [self refresh];
}
-(NSArray<NSToolbarItemIdentifier>*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar{return @[@"scope",NSToolbarFlexibleSpaceItemIdentifier,@"output",@"power",@"preferences"];}
-(NSArray<NSToolbarItemIdentifier>*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar{return [self toolbarAllowedItemIdentifiers:toolbar];}
-(NSToolbarItem*)toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)identifier willBeInsertedIntoToolbar:(BOOL)flag{
 NSToolbarItem*item=[[NSToolbarItem alloc]initWithItemIdentifier:identifier];
 if([identifier isEqual:@"scope"]){self.scope=[NSSegmentedControl segmentedControlWithLabels:@[PL(@"All"),PL(@"Playing")] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(filter:)];self.scope.segmentStyle=NSSegmentStyleAutomatic;self.scope.selectedSegment=self.onlyPlaying?1:0;item.view=self.scope;item.label=PL(@"View");item.toolTip=PL(@"Apps to display");}
 if([identifier isEqual:@"output"]){self.outputs=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(0,0,174,28) pullsDown:NO];self.outputs.target=self;self.outputs.action=@selector(selectOutput:);self.outputs.toolTip=PL(@"Audio output device");item.view=self.outputs;item.label=PL(@"Output");}
 if([identifier isEqual:@"power"]){self.toggle=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"power" accessibilityDescription:PL(@"Volume Control")] target:self action:@selector(toggleAudio:)];[self.toggle setButtonType:NSButtonTypePushOnPushOff];self.toggle.bezelStyle=NSBezelStyleTexturedRounded;self.toggle.frame=NSMakeRect(0,0,34,28);item.view=self.toggle;item.label=PL(@"Volume Control");item.visibilityPriority=NSToolbarItemVisibilityPriorityHigh;}
 if([identifier isEqual:@"preferences"]){NSButton*button=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:PL(@"Settings")] target:self action:@selector(showSettings:)];button.bezelStyle=NSBezelStyleTexturedRounded;button.frame=NSMakeRect(0,0,34,28);item.view=button;item.label=PL(@"Settings");item.toolTip=PL(@"Prisma Settings (⌘,)");}
 return item;
}
-(void)applyPreferences {
 NSInteger appearance=[self.preferences integer:@"appearanceMode"];
 NSApp.appearance=appearance==0?nil:[NSAppearance appearanceNamed:appearance==1?NSAppearanceNameAqua:NSAppearanceNameDarkAqua];
 [NSApp setActivationPolicy:[self.preferences flag:@"showDockIcon"]?NSApplicationActivationPolicyRegular:NSApplicationActivationPolicyAccessory];
 self.item.button.image=PrismMark(20,[self.preferences integer:@"menuIconStyle"]==1);
 self.item.button.imagePosition=NSImageLeft;
 [self updateUI];
}
-(void)addPreferenceTitle:(NSString*)title to:(NSView*)view y:(CGFloat)y {
 [view addSubview:Label(title,13,NSFontWeightSemibold,NSColor.labelColor,NSMakeRect(28,y,464,20))];
}
-(void)addPreferenceNote:(NSString*)text to:(NSView*)view y:(CGFloat)y height:(CGFloat)height {
 NSTextField*note=Label(text,11,NSFontWeightRegular,NSColor.secondaryLabelColor,NSMakeRect(28,y,464,height));
 note.lineBreakMode=NSLineBreakByWordWrapping;note.maximumNumberOfLines=0;[view addSubview:note];
}
-(void)addPreferenceSwitch:(NSString*)key label:(NSString*)label to:(NSView*)view y:(CGFloat)y {
 [view addSubview:Label(label,13,NSFontWeightRegular,NSColor.labelColor,NSMakeRect(28,y+3,390,20))];
 NSSwitch*control=[[NSSwitch alloc]initWithFrame:NSMakeRect(454,y,38,26)];control.identifier=key;control.accessibilityLabel=label;control.target=self;control.action=@selector(preferenceChanged:);[view addSubview:control];self.preferenceControls[key]=control;
}
-(void)addPreferencePopup:(NSString*)key label:(NSString*)label choices:(NSArray<NSString*>*)choices values:(NSArray<NSNumber*>*)values to:(NSView*)view y:(CGFloat)y {
 [view addSubview:Label(label,13,NSFontWeightRegular,NSColor.labelColor,NSMakeRect(28,y+3,226,20))];
 NSPopUpButton*control=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(266,y,230,26) pullsDown:NO];control.identifier=key;control.accessibilityLabel=label;control.target=self;control.action=@selector(preferenceChanged:);
 for(NSUInteger i=0;i<choices.count;i++){[control addItemWithTitle:choices[i]];control.lastItem.representedObject=values?values[i]:@(i);}
 [view addSubview:control];self.preferenceControls[key]=control;
}
-(void)buildSettings {
 self.preferenceControls=[NSMutableDictionary dictionary];
 NSTabViewController*tabs=[NSTabViewController new];tabs.tabStyle=NSTabViewControllerTabStyleToolbar;tabs.canPropagateSelectedChildViewControllerTitle=NO;tabs.title=PL(@"Prisma Settings");tabs.transitionOptions=0;
 NSArray*names=@[PL(@"General"),PL(@"Appearance"),PL(@"Menu"),PL(@"Language")],*symbols=@[@"gearshape",@"circle.lefthalf.filled",@"menubar.rectangle",@"globe"];
 NSMutableArray<NSView*>*pages=[NSMutableArray array];
 for(NSUInteger i=0;i<names.count;i++){NSViewController*page=[NSViewController new];page.view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,520,380)];page.preferredContentSize=NSMakeSize(520,380);page.title=names[i];NSTabViewItem*item=[NSTabViewItem tabViewItemWithViewController:page];item.identifier=names[i];item.label=names[i];item.image=[NSImage imageWithSystemSymbolName:symbols[i] accessibilityDescription:names[i]];[tabs addTabViewItem:item];[pages addObject:page.view];}
 NSView*general=pages[0];[self addPreferenceTitle:PL(@"Startup") to:general y:345];
 [general addSubview:Label(PL(@"Open Prisma at login"),13,NSFontWeightRegular,NSColor.labelColor,NSMakeRect(28,307,390,20))];
 self.loginSwitch=[[NSSwitch alloc]initWithFrame:NSMakeRect(454,304,38,26)];self.loginSwitch.target=self;self.loginSwitch.action=@selector(toggleLogin:);self.loginSwitch.accessibilityLabel=PL(@"Open Prisma at login");[general addSubview:self.loginSwitch];
 self.loginStatus=Label(@"",11,NSFontWeightRegular,NSColor.secondaryLabelColor,NSMakeRect(28,263,310,34));self.loginStatus.lineBreakMode=NSLineBreakByWordWrapping;self.loginStatus.maximumNumberOfLines=2;[general addSubview:self.loginStatus];
 self.loginSettingsButton=[NSButton buttonWithTitle:PL(@"Login Items…") target:self action:@selector(openLoginSettings:)];self.loginSettingsButton.bezelStyle=NSBezelStyleRounded;self.loginSettingsButton.controlSize=NSControlSizeSmall;self.loginSettingsButton.font=[NSFont systemFontOfSize:11];self.loginSettingsButton.frame=NSMakeRect(365,270,131,24);[general addSubview:self.loginSettingsButton];
 [self addPreferencePopup:@"startupAudioMode" label:PL(@"Volume control at launch") choices:@[PL(@"Restore previous state"),PL(@"Always on"),PL(@"Always off")] values:nil to:general y:228];
 [self addPreferenceSwitch:@"showWindowAtLaunch" label:PL(@"Open window at launch") to:general y:188];
 [general addSubview:Rule(NSMakeRect(28,167,464,1))];[self addPreferenceTitle:PL(@"Background") to:general y:139];
 [self addPreferencePopup:@"closeBehavior" label:PL(@"When closing the window") choices:@[PL(@"Keep running in menu bar"),PL(@"Quit Prisma")] values:nil to:general y:98];
 [self addPreferenceNote:PL(@"Volume and mute settings are saved automatically.\nThey are applied when volume control is enabled.") to:general y:40 height:37];
 NSView*appearance=pages[1];[self addPreferenceTitle:PL(@"View") to:appearance y:345];
 [self addPreferencePopup:@"appearanceMode" label:PL(@"Appearance") choices:@[PL(@"Follow System"),PL(@"Light"),PL(@"Dark")] values:nil to:appearance y:300];
 [self addPreferenceSwitch:@"showDockIcon" label:PL(@"Show Prisma in the Dock") to:appearance y:250];
 [self addPreferenceNote:PL(@"You can always open Prisma from the menu bar.") to:appearance y:216 height:19];
 [appearance addSubview:Rule(NSMakeRect(28,196,464,1))];[self addPreferenceTitle:PL(@"App List") to:appearance y:166];
 [self addPreferencePopup:@"startupFilter" label:PL(@"View at launch") choices:@[PL(@"Restore previous view"),PL(@"All"),PL(@"Playing")] values:nil to:appearance y:123];
 [self addPreferenceNote:PL(@"Applies at the next launch. You can also switch views in the toolbar.") to:appearance y:81 height:32];
 NSView*menu=pages[2];[self addPreferenceTitle:PL(@"Menu Bar") to:menu y:345];
 [self addPreferencePopup:@"menuIconStyle" label:PL(@"Icon") choices:@[PL(@"Color (app icon)"),PL(@"Monochrome")] values:nil to:menu y:300];
 [self addPreferenceSwitch:@"showPlayingCount" label:PL(@"Show number of playing apps") to:menu y:250];
 [menu addSubview:Rule(NSMakeRect(28,218,464,1))];[self addPreferenceTitle:PL(@"Quick Controls") to:menu y:187];
 [self addPreferencePopup:@"menuFilter" label:PL(@"Apps to display") choices:@[PL(@"Playing or muted"),PL(@"All")] values:nil to:menu y:145];
 [self addPreferencePopup:@"menuLimit" label:PL(@"Maximum apps") choices:@[PL(@"4 apps"),PL(@"6 apps"),PL(@"8 apps"),PL(@"12 apps")] values:@[@4,@6,@8,@12] to:menu y:100];
 [self addPreferenceNote:PL(@"Playing apps appear first.\nAdjust volume and mute from the menu.") to:menu y:43 height:37];
 NSView*language=pages[3];[self addPreferenceTitle:PL(@"Language") to:language y:345];
 [self addPreferencePopup:@"languageMode" label:PL(@"Language") choices:@[PL(@"System Default"),@"日本語",@"English"] values:nil to:language y:300];
 [self addPreferenceNote:PL(@"Prisma updates immediately. System permission dialogs use this language after Prisma restarts.") to:language y:231 height:48];
 [language addSubview:Rule(NSMakeRect(28,208,464,1))];
 [self addPreferenceNote:PL(@"Stream Deck follows its own language setting. Chrome follows the browser language.") to:language y:143 height:48];
 BOOL newSettings=self.settingsWindow==nil;if(newSettings)self.settingsWindow=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,520,380) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];self.settingsWindow.releasedWhenClosed=NO;self.settingsWindow.title=PL(@"Prisma Settings");self.settingsWindow.toolbarStyle=NSWindowToolbarStylePreference;self.settingsWindow.contentViewController=tabs;self.settingsWindow.toolbar.displayMode=NSToolbarDisplayModeIconAndLabel;self.settingsWindow.toolbar.allowsUserCustomization=NO;if(newSettings)[self.settingsWindow center];
}
-(void)refreshLoginState {
 if(!self.loginSwitch)return;
 SMAppServiceStatus status=self.loginController.service.status;self.loginSwitch.state=self.loginController.isRegistered?NSControlStateValueOn:NSControlStateValueOff;
 NSString*message=PL(@"Prisma can open automatically when you log in.");
 if(status==SMAppServiceStatusEnabled)message=PL(@"Prisma will open automatically at login.");
 if(status==SMAppServiceStatusRequiresApproval)message=PL(@"Allow Prisma in System Settings → Login Items.");
 // A never-registered main-app service can return NotFound; only show a
 // registration error after an attempted change, not as a missing app.
 if(self.loginController.error)message=self.loginController.error.localizedDescription;
 self.loginStatus.stringValue=message;self.loginStatus.toolTip=message;
 self.loginStatus.textColor=(self.loginController.error||status==SMAppServiceStatusRequiresApproval)?NSColor.systemOrangeColor:NSColor.secondaryLabelColor;
}
-(void)showSettings:(id)sender {
 if(!self.settingsWindow)[self buildSettings];
 for(NSString*key in self.preferenceControls){NSControl*control=self.preferenceControls[key];if([control isKindOfClass:NSSwitch.class])((NSSwitch*)control).state=[self.preferences flag:key]?NSControlStateValueOn:NSControlStateValueOff;else{NSPopUpButton*popup=(NSPopUpButton*)control;for(NSMenuItem*item in popup.itemArray)if([item.representedObject integerValue]==[self.preferences integer:key]){[popup selectItem:item];break;}}}
 [self refreshLoginState];[self.settingsWindow makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
}
-(void)preferenceChanged:(NSControl*)sender {
 NSNumber*value=[sender isKindOfClass:NSSwitch.class]?@(((NSSwitch*)sender).state==NSControlStateValueOn):((NSPopUpButton*)sender).selectedItem.representedObject;
 if([sender.identifier isEqual:@"languageMode"]){PrismaSetLanguagePreference(self.preferences.defaults,value.integerValue);dispatch_async(dispatch_get_main_queue(),^{[self relocalizeInterface];});return;}
 [self.preferences setValue:value forPreference:sender.identifier];[self applyPreferences];
}
-(void)toggleLogin:(NSSwitch*)sender {
 sender.enabled=NO;[self.loginController setEnabled:sender.state==NSControlStateValueOn];sender.enabled=YES;[self refreshLoginState];
}
-(void)openLoginSettings:(id)sender{[SMAppService openSystemSettingsLoginItems];}
-(void)applicationDidBecomeActive:(NSNotification*)notification{if(self.preferences&&PrismaRefreshLanguage(self.preferences.defaults))[self relocalizeInterface];if(self.settingsWindow.visible)[self refreshLoginState];}
-(BOOL)windowShouldClose:(NSWindow*)sender {
 if(sender==self.window&&[self.preferences integer:@"closeBehavior"]==1){[NSApp terminate:nil];return NO;}return YES;
}

-(void)receiveBrowser:(NSNotification*)notification {
 NSDictionary*m=notification.userInfo;
 if([m[@"activate"]boolValue]&&self.browserTabs.sources[m[@"connection"]]){self.active=YES;[self.preferences recordAudioActive:YES];}
 else [self.browserTabs receive:m now:NSDate.timeIntervalSinceReferenceDate];
 [self refresh];
}
-(NSImage*)iconForChannel:(Channel*)channel{return channel.browserTab?(channel.tabIcon?:PrismAppIcon(@"com.google.Chrome")):PrismAppIcon(channel.key);}
-(BOOL)controlTabKey:(NSString*)key op:(NSString*)op value:(float)value step:(float)step {
 NSDictionary*command=[self.browserTabs commandForKey:key op:op value:value step:step now:NSDate.timeIntervalSinceReferenceDate];if(!command)return NO;
 self.active=YES;[self.preferences recordAudioActive:YES];self.freezeUntil=NSDate.timeIntervalSinceReferenceDate+2;
 [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.prisma.chrome.command" object:command[@"connection"] userInfo:command deliverImmediately:YES];[self refresh];return YES;
}
-(void)configureChrome:(id)sender {
 NSError*error=nil;NSFileManager*fm=NSFileManager.defaultManager;
 NSURL*support=[fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL*hostDirectory=[support URLByAppendingPathComponent:@"Google/Chrome/NativeMessagingHosts" isDirectory:YES];
 NSURL*extensionDirectory=[support URLByAppendingPathComponent:@"Prisma/ChromeExtension" isDirectory:YES];
 [fm createDirectoryAtURL:hostDirectory withIntermediateDirectories:YES attributes:nil error:&error];
 if(!error)[fm createDirectoryAtURL:extensionDirectory withIntermediateDirectories:YES attributes:nil error:&error];
 NSURL*source=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"ChromeExtension" isDirectory:YES];
 if(!error){NSDirectoryEnumerator*files=[fm enumeratorAtURL:source includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:0 errorHandler:nil];for(NSURL*file in files){NSNumber*directory=nil;[file getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];NSString*relative=[file.path substringFromIndex:source.path.length+1];NSURL*destination=[extensionDirectory URLByAppendingPathComponent:relative];if(directory.boolValue)[fm createDirectoryAtURL:destination withIntermediateDirectories:YES attributes:nil error:&error];else{NSData*data=[NSData dataWithContentsOfURL:file options:0 error:&error];if(data)[data writeToURL:destination options:NSDataWritingAtomic error:&error];}if(error)break;}}
 if(!error){NSDictionary*manifest=@{@"name":@"local.prisma.chrome",@"description":@"Prisma Tabs",@"path":[NSBundle.mainBundle.executableURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"PrismaChromeHost"].path,@"type":@"stdio",@"allowed_origins":@[[NSString stringWithFormat:@"chrome-extension://%@/",PRISMA_CHROME_ID]]};NSData*data=[NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingPrettyPrinted error:&error];if(data)[data writeToURL:[hostDirectory URLByAppendingPathComponent:@"local.prisma.chrome.json"] options:NSDataWritingAtomic error:&error];}
 NSAlert*alert=[NSAlert new];
 if(error){alert.messageText=PL(@"Unable to prepare the Chrome extension");alert.informativeText=error.localizedDescription;[alert addButtonWithTitle:PL(@"Close")];}
 else{alert.messageText=PL(@"Add Prisma Tabs to Chrome");alert.informativeText=[NSString stringWithFormat:PL(@"Open chrome://extensions in Chrome and turn on Developer mode.\n\nChoose “Load unpacked” and select this folder:\n\n%@\n\nTabs are detected automatically when audio plays. If the extension is already installed, click its Reload button."),extensionDirectory.path];[alert addButtonWithTitle:PL(@"Open Folder")];[alert addButtonWithTitle:PL(@"Close")];}
 [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response){if(!error&&response==NSAlertFirstButtonReturn)[NSWorkspace.sharedWorkspace openURL:extensionDirectory];}];
}

-(void)show:(id)sender{[self.window makeKeyAndOrderFront:nil];[self updateUI];[NSApp activateIgnoringOtherApps:YES];}
-(void)windowDidDeminiaturize:(NSNotification*)notification{[self updateUI];}
-(void)quit:(id)sender{[NSApp terminate:nil];}
-(void)permissions:(id)sender{[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"]];}
-(void)selectOutput:(id)sender{AudioObjectID d=[self.outputs.selectedItem.representedObject unsignedIntValue];auto a=addr(kAudioHardwarePropertyDefaultOutputDevice);OSStatus err=AudioObjectSetPropertyData(kAudioObjectSystemObject,&a,0,nullptr,sizeof(d),&d);if(err){NSAlert*alert=[NSAlert new];alert.messageText=PL(@"Unable to change the output");alert.informativeText=PL(@"Choose an output device in macOS Sound settings.");[alert beginSheetModalForWindow:self.window completionHandler:nil];}else [self refresh];}
-(void)save{[NSUserDefaults.standardUserDefaults setObject:self.prefs forKey:@"levels"];}
-(void)persist:(Channel*)c{if(c.browserTab)return;self.prefs[c.key]=@{@"volume":@(c.volume),@"muted":@(c.muted)};[self save];}
-(void)stopAll{for(Channel*c in self.channels){c->engine.stop();c.enabled=NO;c.meter=0;}}
-(void)toggleAudio:(id)sender{self.active=!self.active;[self.preferences recordAudioActive:self.active];if(!self.active)[self stopAll];for(Channel*c in self.channels)c.error=nil;[self refresh];}
-(void)filter:(NSSegmentedControl*)sender{self.onlyPlaying=sender.selectedSegment==1;[self.preferences setValue:@(self.onlyPlaying) forPreference:@"lastOnlyPlaying"];[self updateUI];if(self.displayed.count)[self.table scrollRowToVisible:0];}
-(void)assignSlots {
 if(NSDate.timeIntervalSinceReferenceDate<self.freezeUntil)return;
 NSMutableArray*slots=[self.slots mutableCopy];NSTimeInterval now=NSDate.timeIntervalSinceReferenceDate;BOOL tabPlaying=NO;for(Channel*c in self.channels)if(c.browserTab&&now-c.lastHeard<2)tabPlaying=YES;
 for(int i=0;i<4;i++){Channel*c=[self channel:slots[i]];BOOL keep=c && !(tabPlaying&&[c.key isEqual:@"com.google.Chrome"]) && (now-c.lastHeard<5 || (c.muted&&c.processPlaying));if(!keep)slots[i]=@"";}
 NSArray*candidates=[self.channels sortedArrayUsingComparator:^NSComparisonResult(Channel*a,Channel*b){if(a.lastHeard!=b.lastHeard)return a.lastHeard>b.lastHeard?NSOrderedAscending:NSOrderedDescending;return [a.key compare:b.key];}];
 for(Channel*c in candidates){if(now-c.lastHeard>=2||[slots containsObject:c.key]||(tabPlaying&&[c.key isEqual:@"com.google.Chrome"]))continue;NSUInteger empty=[slots indexOfObject:@""];if(empty==NSNotFound)break;slots[empty]=c.key;}self.slots=slots;
}
-(void)refresh {
 if(self.refreshing)return;self.refreshing=YES;@autoreleasepool{
 NSArray*devices=ids(kAudioObjectSystemObject,kAudioHardwarePropertyDevices);if(![devices isEqual:self.deviceIDs]){self.deviceIDs=devices;[self.outputs removeAllItems];for(NSNumber*d in devices)if(ids(d.unsignedIntValue,kAudioDevicePropertyStreams,kAudioObjectPropertyScopeOutput).count){[self.outputs addItemWithTitle:str(d.unsignedIntValue,kAudioObjectPropertyName)];self.outputs.lastItem.representedObject=d;}}
 AudioObjectID output=readValue<AudioObjectID>(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultOutputDevice);for(NSMenuItem*i in self.outputs.itemArray)if([i.representedObject unsignedIntValue]==output&&self.outputs.selectedItem!=i)[self.outputs selectItem:i];
 auto rate=readValue<Float64>(output,kAudioDevicePropertyNominalSampleRate);NSString*signature=[NSString stringWithFormat:@"%u-%f",output,rate];if(![self.outputSignature isEqual:signature]){[self stopAll];self.output=output;self.outputSignature=signature;for(Channel*c in self.channels)c.error=nil;}
 NSMutableDictionary<NSString*,NSMutableArray*>*groups=[NSMutableDictionary dictionary];NSMutableDictionary*names=[NSMutableDictionary dictionary];NSMutableDictionary*playing=[NSMutableDictionary dictionary];NSArray*running=NSWorkspace.sharedWorkspace.runningApplications;
 for(NSNumber*obj in ids(kAudioObjectSystemObject,kAudioHardwarePropertyProcessObjectList)){
  pid_t pid=readValue<pid_t>(obj.unsignedIntValue,kAudioProcessPropertyPID);if(pid==getpid())continue;NSString*bid=str(obj.unsignedIntValue,kAudioProcessPropertyBundleID);NSRunningApplication*ra=[NSRunningApplication runningApplicationWithProcessIdentifier:pid];NSString*key=ra.bundleIdentifier?:bid;NSString*name=ra.localizedName;
  char path[PROC_PIDPATHINFO_MAXSIZE]={};proc_pidpath(pid,path,sizeof(path));NSString*p=[NSString stringWithUTF8String:path];NSRange end=[p rangeOfString:@".app/"];if(end.location!=NSNotFound){NSBundle*b=[NSBundle bundleWithPath:[p substringToIndex:end.location+4]];if(b.bundleIdentifier){key=b.bundleIdentifier;name=[b objectForInfoDictionaryKey:@"CFBundleDisplayName"]?:[b objectForInfoDictionaryKey:@"CFBundleName"];}}
  BOOL visible=NO;for(NSRunningApplication*a in running)if([a.bundleIdentifier isEqual:key]&&a.activationPolicy==NSApplicationActivationPolicyRegular){visible=YES;name=a.localizedName;break;}
  if(!key.length||(!visible&&!self.prefs[key])||[key isEqual:@"com.bearisdriving.BGM.App"])continue;
  if(!groups[key])groups[key]=[NSMutableArray array];[groups[key] addObject:obj];names[key]=name?:key;if(readValue<UInt32>(obj.unsignedIntValue,kAudioProcessPropertyIsRunningOutput))playing[key]=@YES;
 }
 NSMutableArray*next=[NSMutableArray array];NSTimeInterval now=NSDate.timeIntervalSinceReferenceDate;
 for(NSString*key in [[groups allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]){
  Channel*c=[self channel:key];if(!c){c=[Channel new];c.key=key;c.volume=self.prefs[key]?[self.prefs[key][@"volume"] floatValue]:1;c.muted=[self.prefs[key][@"muted"] boolValue];}
  c.name=names[key];c.processPlaying=[playing[key]boolValue];NSArray*procs=[groups[key]sortedArrayUsingSelector:@selector(compare:)];if(![c.processes isEqual:procs]){c->engine.stop();c.enabled=NO;c.error=nil;c.processes=procs;}
  BOOL route=c.muted||c.volume<0.999f;BOOL needed=self.active&&(route||c.processPlaying);
  if(c.enabled&&(!needed||c->engine.monitoring==route)){c->engine.stop();c.enabled=NO;}
  if(needed&&!c.enabled&&!c.error){@try{c->engine.start(c.processes,self.output,c.muted?0:c.volume,!route);c.enabled=YES;c.started=NSDate.date;}@catch(NSException*ex){c.error=ex.reason;}}
  if(c.enabled){c->engine.gain.store(c.muted?0:c.volume);float peak=c->engine.peak.exchange(0);c.meter=std::max(peak,c.meter*0.65f);if(peak>0.0001)c.lastHeard=now;}
  else c.meter=0;
  if(c.enabled&&[NSDate.date timeIntervalSinceDate:c.started]>5&&c->engine.callbacks.load()==0){c->engine.stop();c.enabled=NO;c.error=PL(@"Audio processing is not responding. Allow audio access and try again.");}
  [next addObject:c];
 }
 for(NSDictionary*t in [self.browserTabs tabsAt:now]){
  Channel*c=[self channel:t[@"key"]];if(!c){c=[Channel new];c.key=t[@"key"];c.browserTab=YES;}
  c.error=[t[@"error"]length]?t[@"error"]:nil;c.name=t[@"name"];c.volume=[t[@"volume"]floatValue];c.muted=[t[@"muted"]boolValue];c.processPlaying=[t[@"playing"]boolValue];c.enabled=self.active;
  if(c.processPlaying)c.lastHeard=now;
  if(![c.iconData isEqual:t[@"icon"]]){c.iconData=t[@"icon"];c.tabIcon=nil;if(c.iconData.length>22){NSData*data=[[NSData alloc]initWithBase64EncodedString:[c.iconData substringFromIndex:22] options:0];NSImage*image=[[NSImage alloc]initWithData:data];if(image.size.width<=128&&image.size.height<=128)c.tabIcon=image;}}
  [next addObject:c];
 }
 for(Channel*c in self.channels)if(![next containsObject:c])c->engine.stop();self.channels=next;[self assignSlots];
 NSMutableDictionary*state=[NSMutableDictionary dictionary];for(Channel*c in self.channels)state[c.key]=@{@"volume":@(c.volume),@"muted":@(c.muted),@"running":@YES,@"playing":@(now-c.lastHeard<2),@"name":c.name,@"error":c.error?:@"",@"kind":c.browserTab?@"tab":@"app",@"icon":c.iconData?:@""};
 [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.appmixer.state" object:nil userInfo:@{@"levels":state,@"active":@(self.active),@"slots":self.slots} deliverImmediately:YES];
 if(!NSEvent.pressedMouseButtons&&!self.menuOpen)[self updateUI];}self.refreshing=NO;
}
-(void)updateUI {
 NSTimeInterval now=NSDate.timeIntervalSinceReferenceDate;NSMutableArray*list=[NSMutableArray array];NSUInteger count=0,tabCount=0;NSString*error=nil;for(Channel*c in self.channels){BOOL playing=now-c.lastHeard<2;if(c.browserTab)tabCount++;if(playing)count++;if(c.error&&!error)error=c.error;if(!self.onlyPlaying||playing||c.muted)[list addObject:c];}
 [list sortUsingComparator:^NSComparisonResult(Channel*a,Channel*b){BOOL ap=now-a.lastHeard<2,bp=now-b.lastHeard<2;if(ap!=bp)return ap?NSOrderedAscending:NSOrderedDescending;return [a.name localizedCaseInsensitiveCompare:b.name];}];BOOL firstDisplay=!self.displayed.count && list.count;BOOL structureChanged=![[self.displayed valueForKey:@"key"]isEqual:[list valueForKey:@"key"]];self.displayed=list;
 NSString*menuTitle=[self.preferences flag:@"showPlayingCount"]?[NSString stringWithFormat:@" %lu",(unsigned long)count]:@"";if(![self.item.button.title isEqual:menuTitle])self.item.button.title=menuTitle;
 SetLabel(self.countLabel,tabCount?[NSString stringWithFormat:PL(@"Apps: %lu · Tabs: %lu"),(unsigned long)(self.channels.count-tabCount),(unsigned long)tabCount]:[NSString stringWithFormat:PL(@"Playing: %lu  /  Apps: %lu"),(unsigned long)count,(unsigned long)self.channels.count]);NSControlStateValue power=self.active?NSControlStateValueOn:NSControlStateValueOff;if(self.toggle.state!=power)self.toggle.state=power;NSString*powerTip=self.active?PL(@"Stop volume control"):PL(@"Start volume control");if(![self.toggle.toolTip isEqual:powerTip])self.toggle.toolTip=powerTip;
 self.emptyState.hidden=list.count>0;SetLabel(self.emptyState,self.onlyPlaying?PL(@"No apps are playing"):PL(@"Apps appear here when they use audio"));
 NSString*output=str(self.output,kAudioObjectPropertyName);if(error){SetLabel(self.status,error);self.status.textColor=NSColor.systemOrangeColor;}else if([output containsString:@"Background Music"]){SetLabel(self.status,PL(@"Select speakers or another output device"));self.status.textColor=NSColor.systemOrangeColor;}else{self.status.textColor=NSColor.secondaryLabelColor;SetLabel(self.status,self.active?PL(@"Volume control is on"):PL(@"Start volume control with the power button"));}if(![self.status.toolTip isEqual:self.status.stringValue])self.status.toolTip=self.status.stringValue;
 if(!self.window.visible||self.window.miniaturized){self.rowsNeedReload=YES;return;}
 if(structureChanged||self.rowsNeedReload){[self.table reloadData];self.rowsNeedReload=NO;}
 else for(NSUInteger row=0;row<list.count;row++){PrismaChannelRow*view=[self.table viewAtColumn:0 row:row makeIfNecessary:NO];if(view)[view configure:list[row] icon:[self iconForChannel:list[row]] chromeHasTabs:tabCount>0 target:self];}
 if(firstDisplay)[self.table scrollRowToVisible:0];

}
-(NSInteger)numberOfRowsInTableView:(NSTableView*)table{return self.displayed.count;}
-(NSView*)tableView:(NSTableView*)table viewForTableColumn:(NSTableColumn*)col row:(NSInteger)row{
 Channel*c=self.displayed[row];PrismaChannelRow*view=[table makeViewWithIdentifier:@"channel-row" owner:self];
 if(!view)view=[[PrismaChannelRow alloc]initWithFrame:NSMakeRect(0,0,col.width,60)];
 BOOL hasTabs=NO;for(Channel*channel in self.channels)if(channel.browserTab){hasTabs=YES;break;}
 [view configure:c icon:[self iconForChannel:c] chromeHasTabs:hasTabs target:self];return view;
}
-(void)level:(NSSlider*)s{Channel*c=[self channel:s.identifier];if(!c)return;if(c.browserTab){for(NSView*v in s.superview.subviews)if([v.identifier isEqual:@"value"])((NSTextField*)v).stringValue=[NSString stringWithFormat:@"%.0f%%",s.floatValue];[self controlTabKey:c.key op:@"set" value:s.floatValue/100 step:5];return;}self.active=YES;[self.preferences recordAudioActive:YES];c.volume=s.floatValue/100;c.error=nil;self.freezeUntil=NSDate.timeIntervalSinceReferenceDate+2;[self persist:c];for(NSView*v in s.superview.subviews)if([v.identifier isEqual:@"value"])((NSTextField*)v).stringValue=[NSString stringWithFormat:@"%.0f%%",c.volume*100];[self refresh];}
-(void)mute:(NSButton*)b{Channel*c=[self channel:b.identifier];if(!c)return;if(c.browserTab){[self controlTabKey:c.key op:@"mute" value:0 step:5];return;}self.active=YES;[self.preferences recordAudioActive:YES];c.muted=!c.muted;c.error=nil;self.freezeUntil=NSDate.timeIntervalSinceReferenceDate+2;[self persist:c];[self refresh];}
-(void)menuWillOpen:(NSMenu*)m{self.menuOpen=YES;}
-(void)menuDidClose:(NSMenu*)m{self.menuOpen=NO;}
-(void)menuNeedsUpdate:(NSMenu*)m{
 [m removeAllItems];NSMenuItem*h=[[NSMenuItem alloc]initWithTitle:@"Prisma" action:nil keyEquivalent:@""];h.image=PrismMark(22);h.enabled=NO;[m addItem:h];NSUInteger count=0;
 NSMutableArray*list=[self.channels mutableCopy];[list sortUsingComparator:^NSComparisonResult(Channel*a,Channel*b){if(a.lastHeard!=b.lastHeard)return a.lastHeard>b.lastHeard?NSOrderedAscending:NSOrderedDescending;return [a.name compare:b.name];}];
 for(Channel*c in list){BOOL playing=NSDate.timeIntervalSinceReferenceDate-c.lastHeard<2;BOOL include=[self.preferences integer:@"menuFilter"]==1||playing||c.muted||c.error||(!self.active&&c.processPlaying);if(!include)continue;if(count>=[self.preferences integer:@"menuLimit"])break;count++;NSMenuItem*i=[NSMenuItem new];NSView*v=[[NSView alloc]initWithFrame:NSMakeRect(0,0,326,64)];[v addSubview:Icon([self iconForChannel:c],NSMakeRect(13,26,27,27))];[v addSubview:Label(c.name,12,NSFontWeightSemibold,NSColor.labelColor,NSMakeRect(51,37,192,18))];NSTextField*value=Label([NSString stringWithFormat:@"%.0f%%",c.volume*100],11,NSFontWeightMedium,NSColor.secondaryLabelColor,NSMakeRect(260,38,52,17));value.identifier=@"value";value.alignment=NSTextAlignmentRight;[v addSubview:value];[v addSubview:Slider(c.volume,self,@selector(level:),c.key,NSMakeRect(51,8,198,22))];NSButton*b=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:c.muted?@"speaker.slash.fill":@"speaker.wave.2" accessibilityDescription:PL(@"Toggle Mute")] target:self action:@selector(mute:)];b.identifier=c.key;b.frame=NSMakeRect(263,6,48,26);b.bezelStyle=NSBezelStyleRounded;[v addSubview:b];i.view=v;[m addItem:i];}
 if(!count){NSMenuItem*empty=[m addItemWithTitle:PL(@"No apps are playing") action:nil keyEquivalent:@""];empty.enabled=NO;}
 [m addItem:NSMenuItem.separatorItem];for(NSArray*a in @[@[PL(@"Open Prisma…"),NSStringFromSelector(@selector(show:))],@[self.active?PL(@"Stop and Restore Normal Audio"):PL(@"Start Audio Control"),NSStringFromSelector(@selector(toggleAudio:))],@[PL(@"Settings…"),NSStringFromSelector(@selector(showSettings:))],@[PL(@"Audio Access Settings…"),NSStringFromSelector(@selector(permissions:))],@[PL(@"Quit"),NSStringFromSelector(@selector(quit:))]]){NSMenuItem*i=[[NSMenuItem alloc]initWithTitle:a[0] action:NSSelectorFromString(a[1]) keyEquivalent:@""];i.target=self;[m addItem:i];}
}
-(void)application:(NSApplication*)application openURLs:(NSArray<NSURL*>*)urls{
 for(NSURL*u in urls){if(![@[@"appmixer",@"prism-audio"]containsObject:u.scheme])continue;if([u.host isEqual:@"settings"]){[self showSettings:nil];continue;}if([u.host isEqual:@"show"]){[self show:nil];continue;}if(![u.host isEqual:@"control"])continue;NSMutableDictionary*q=[NSMutableDictionary dictionary];for(NSURLQueryItem*i in [NSURLComponents componentsWithURL:u resolvingAgainstBaseURL:NO].queryItems)if(i.value)q[i.name]=i.value;
 NSString*key=q[@"app"],*op=q[@"op"];if(!key.length||![@[@"up",@"down",@"mute",@"set"]containsObject:op])continue;float step=q[@"step"]?[q[@"step"]floatValue]:5;if(!std::isfinite(step))continue;step=std::clamp(step,1.0f,100.0f);if(PrismaIsTabKey(key)){if([op isEqual:@"set"]&&!q[@"value"])continue;float value=[q[@"value"]floatValue]/100;if(std::isfinite(value))[self controlTabKey:key op:op value:value step:step];continue;}NSDictionary*p=self.prefs[key];float volume=p?[p[@"volume"]floatValue]:1;BOOL muted=[p[@"muted"]boolValue];if([op isEqual:@"mute"])muted=!muted;else if([op isEqual:@"set"]){if(!q[@"value"])continue;volume=[q[@"value"]floatValue]/100;}else volume+=([op isEqual:@"up"]?step:-step)/100;if(!std::isfinite(volume))continue;volume=std::clamp(volume,0.0f,1.0f);self.prefs[key]=@{@"volume":@(volume),@"muted":@(muted)};Channel*c=[self channel:key];if(c){c.volume=volume;c.muted=muted;c.error=nil;}self.freezeUntil=NSDate.timeIntervalSinceReferenceDate+2;[self save];self.active=YES;[self.preferences recordAudioActive:YES];
 }[self refresh];
}
-(void)applicationWillTerminate:(NSNotification*)n{[NSDistributedNotificationCenter.defaultCenter removeObserver:self];[NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.appmixer.state" object:nil userInfo:@{@"active":@NO,@"levels":@{},@"slots":@[@"",@"",@"",@""]} deliverImmediately:YES];[self.preferences recordAudioActive:self.active];[self.timer invalidate];[self stopAll];[self save];}
-(BOOL)applicationShouldHandleReopen:(NSApplication*)a hasVisibleWindows:(BOOL)v{[self show:nil];return YES;}
@end
int main(int argc,char**argv){@autoreleasepool{NSApplication*app=NSApplication.sharedApplication;Mixer*delegate=[Mixer new];app.delegate=delegate;[app setActivationPolicy:NSApplicationActivationPolicyRegular];[app run];}return 0;}
