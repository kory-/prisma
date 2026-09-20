// Compose Marketplace graphics from Prisma artwork and its real dial layout.
// These are sample assignments, not screenshots of a user's app list or hardware.
#import <Cocoa/Cocoa.h>
#include <cassert>
static CGFloat H=960;
static NSColor*C(unsigned n){return [NSColor colorWithSRGBRed:((n>>16)&255)/255.0 green:((n>>8)&255)/255.0 blue:(n&255)/255.0 alpha:1];}
static NSRect R(CGFloat x,CGFloat y,CGFloat w,CGFloat h){return NSMakeRect(x,H-y-h,w,h);}
static void rect(CGFloat x,CGFloat y,CGFloat w,CGFloat h,CGFloat radius,unsigned fill,unsigned stroke=0){NSBezierPath*p=[NSBezierPath bezierPathWithRoundedRect:R(x,y,w,h) xRadius:radius yRadius:radius];[C(fill)setFill];[p fill];if(stroke){[C(stroke)setStroke];p.lineWidth=1.5;[p stroke];}}
static void text(NSString*s,CGFloat x,CGFloat y,CGFloat w,CGFloat size,NSFontWeight weight,unsigned color){NSDictionary*a=@{NSFontAttributeName:[NSFont systemFontOfSize:size weight:weight],NSForegroundColorAttributeName:C(color)};[s drawInRect:R(x,y,w,size*1.6) withAttributes:a];}
static void picture(NSImage*i,CGFloat x,CGFloat y,CGFloat w,CGFloat h){[i drawInRect:R(x,y,w,h) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];}
static void sampleIcon(NSString*letter,CGFloat x,CGFloat y,CGFloat size,unsigned color){rect(x,y,size,size,size*.22,color);NSMutableParagraphStyle*p=[NSMutableParagraphStyle new];p.alignment=NSTextAlignmentCenter;NSDictionary*a=@{NSFontAttributeName:[NSFont systemFontOfSize:size*.45 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NSColor.whiteColor,NSParagraphStyleAttributeName:p};[letter drawInRect:R(x,y+size*.22,size,size*.64) withAttributes:a];}
static void actionIcon(int kind,CGFloat x,CGFloat y,CGFloat k){
 NSBezierPath*p=[NSBezierPath bezierPath];p.lineWidth=1.7*k;p.lineCapStyle=NSLineCapStyleRound;p.lineJoinStyle=NSLineJoinStyleRound;
 auto point=[&](CGFloat a,CGFloat b){return NSMakePoint(x+a*k,H-y-b*k);};
 [p moveToPoint:point(4,9)];[p lineToPoint:point(7,9)];[p lineToPoint:point(12,5)];[p lineToPoint:point(12,19)];[p lineToPoint:point(7,15)];[p lineToPoint:point(4,15)];[p closePath];
 if(kind<2){[p moveToPoint:point(16,12)];[p lineToPoint:point(22,12)];if(kind==1){[p moveToPoint:point(19,9)];[p lineToPoint:point(19,15)];}}
 else{[p moveToPoint:point(17,9)];[p lineToPoint:point(22,15)];[p moveToPoint:point(22,9)];[p lineToPoint:point(17,15)];}
 [C(0xf5f5f7)setStroke];[p stroke];
}
static NSArray*layout;
static void dial(NSString*name,NSString*letter,CGFloat volume,BOOL muted,CGFloat x,CGFloat y,CGFloat scale,unsigned color){
 rect(x,y,200*scale,100*scale,0,0x09090b);
 for(NSDictionary*item in layout){NSArray*r=item[@"rect"];CGFloat ix=x+[r[0]doubleValue]*scale,iy=y+[r[1]doubleValue]*scale,w=[r[2]doubleValue]*scale,h=[r[3]doubleValue]*scale;
 NSString*key=item[@"key"];
 if([key isEqual:@"icon"])sampleIcon(letter,ix,iy,w,color);
 if([key isEqual:@"title"])text(name,ix,iy,w,[item[@"font"][@"size"]doubleValue]*scale,NSFontWeightSemibold,0xf5f5f7);
 if([key isEqual:@"value"])text(muted?@"Muted":[NSString stringWithFormat:@"%.0f%%",volume],ix,iy,w,[item[@"font"][@"size"]doubleValue]*scale,NSFontWeightMedium,0xd1d1d6);
 if([key isEqual:@"indicator"]){rect(ix,iy,w,h,0,0x333336);rect(ix,iy,w*volume/100,h,0,0xe5e5ea);}
 }
}
static void footer(NSString*s){text(@"Prisma",112,862,300,27,NSFontWeightSemibold,0xe8e8ed);text(s,700,866,1120,22,NSFontWeightRegular,0x8d8e98);}
static void heading(NSString*a,NSString*b){text(a,112,84,1696,78,NSFontWeightSemibold,0xf5f5f7);text(b,116,208,1660,32,NSFontWeightRegular,0xaaaab3);}
static void exportPNG(NSString*file,int width,int height,void(^draw)(void)){
 H=height;NSBitmapImageRep*bitmap=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:nil pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
 [NSGraphicsContext saveGraphicsState];NSGraphicsContext*context=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];NSGraphicsContext.currentContext=context;context.imageInterpolation=NSImageInterpolationHigh;[NSColor.clearColor setFill];NSRectFillUsingOperation(NSMakeRect(0,0,width,height),NSCompositingOperationCopy);draw();[NSGraphicsContext restoreGraphicsState];assert([[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}]writeToFile:file atomically:YES]);
}
int main(int argc,char**argv){@autoreleasepool{
 assert(argc==2);NSString*out=[NSString stringWithUTF8String:argv[1]];[[NSFileManager defaultManager]createDirectoryAtPath:out withIntermediateDirectories:YES attributes:nil error:nil];
 NSImage*art=[[NSImage alloc]initWithContentsOfFile:@"io.github.kory-.prisma.sdPlugin/images/plugin@2x.png"];assert(art);
 NSData*data=[NSData dataWithContentsOfFile:@"io.github.kory-.prisma.sdPlugin/dial-layout.json"];layout=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil][@"items"];assert(layout.count==4);
 exportPNG([out stringByAppendingPathComponent:@"icon-288.png"],288,288,^{picture(art,0,0,288,288);});
 exportPNG([out stringByAppendingPathComponent:@"thumbnail.png"],1920,960,^{
  rect(0,0,1920,960,0,0x101113);picture(art,122,190,590,590);text(@"Prisma",822,228,950,114,NSFontWeightSemibold,0xf5f5f7);text(@"Per-app volume for macOS",828,398,990,43,NSFontWeightRegular,0xb8b8c2);rect(830,498,800,1,0,0x34353a);text(@"Stream Deck keys & dials",828,542,960,33,NSFontWeightMedium,0xe2e2e7);text(@"Apple Silicon  ·  macOS 14.4 or later",832,824,990,24,NSFontWeightRegular,0x81828b);
 });
 exportPNG([out stringByAppendingPathComponent:@"gallery-playing.png"],1920,960,^{
  rect(0,0,1920,960,0,0x101113);heading(@"Playing apps",@"Automatic assignment on Stream Deck +.");rect(108,390,1704,220,18,0x09090b,0x33343a);
  dial(@"Music",@"M",42,NO,130,400,2.05,0xb83b64);dial(@"Browser",@"B",85,NO,550,400,2.05,0x3b78b8);dial(@"Calls",@"C",65,YES,970,400,2.05,0x5965bc);dial(@"Player",@"P",100,NO,1390,400,2.05,0x3b8a80);
  text(@"Turn to adjust. Press or tap to mute.",116,680,1670,34,NSFontWeightRegular,0xe2e2e7);footer(@"Sample assignments · Requires Prisma for macOS");
 });
 exportPNG([out stringByAppendingPathComponent:@"gallery-controls.png"],1920,960,^{
  rect(0,0,1920,960,0,0x101113);heading(@"Keys and dials",@"Choose a fixed app and set your volume step.");
  NSArray*labels=@[@"Volume Down",@"Volume Up",@"Mute"];
  for(int i=0;i<3;i++){CGFloat x=116+i*254;rect(x,382,214,214,26,0x202126,0x45464c);actionIcon(i,x+47,429,5);text(labels[i],x,633,240,25,NSFontWeightMedium,0xc4c4ce);}
  rect(1038,380,750,242,16,0x09090b,0x34353a);dial(@"Music",@"M",65,NO,1188,391,2.2,0xb83b64);
  text(@"5% per tick",1220,654,490,29,NSFontWeightMedium,0xc4c4ce);footer(@"Example controls · Volume, mute and fixed targets");
 });
 exportPNG([out stringByAppendingPathComponent:@"gallery-tabs.png"],1920,960,^{
  rect(0,0,1920,960,0,0x101113);heading(@"Chrome tabs",@"Separate volume, in the same browser.");
  rect(148,382,1624,260,18,0x09090b,0x33343a);dial(@"Video",@"V",35,NO,180,396,2.35,0x8861bb);dial(@"Radio",@"R",70,NO,725,396,2.35,0xb8703b);dial(@"Meeting",@"M",100,YES,1270,396,2.35,0x3b8e78);
  text(@"Tabs appear automatically when they play.",116,710,1680,32,NSFontWeightRegular,0xe2e2e7);footer(@"Sample tabs · Requires the Prisma Tabs Chrome extension");
 });puts("Marketplace media exported: icon, thumbnail and 3 gallery images.");
}return 0;}
