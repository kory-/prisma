#import <Cocoa/Cocoa.h>
static NSColor *PrismColor(unsigned rgb,CGFloat a=1){return [NSColor colorWithRed:((rgb>>16)&255)/255.0 green:((rgb>>8)&255)/255.0 blue:(rgb&255)/255.0 alpha:a];}
static NSBezierPath* PrismFace(CGFloat s,NSArray<NSValue*>*points){NSBezierPath*p=[NSBezierPath bezierPath];BOOL first=YES;for(NSValue*v in points){NSPoint a=v.pointValue;a.x*=s;a.y*=s;if(first){[p moveToPoint:a];first=NO;}else[p lineToPoint:a];}[p closePath];p.lineJoinStyle=NSLineJoinStyleRound;return p;}
#define PP(x,y) [NSValue valueWithPoint:NSMakePoint(x,y)]
static NSImage* PrismMark(CGFloat size,BOOL monochrome=NO,BOOL tile=YES){
 if(!monochrome && tile){NSImage*art=[NSImage imageNamed:@"PrismaIcon"];if(art){NSImage*scaled=[art copy];scaled.size=NSMakeSize(size,size);return scaled;}}
 NSImage*image=[[NSImage alloc]initWithSize:NSMakeSize(size,size)];[image lockFocus];CGFloat s=size/100;
 if(monochrome){NSBezierPath*triangle=PrismFace(s,@[PP(48,84),PP(15,18),PP(81,18)]);triangle.lineWidth=6*s;[NSColor.blackColor setStroke];[triangle stroke];NSBezierPath*edge=[NSBezierPath bezierPath];[edge moveToPoint:NSMakePoint(48*s,84*s)];[edge lineToPoint:NSMakePoint(54*s,87*s)];[edge lineToPoint:NSMakePoint(88*s,24*s)];[edge lineToPoint:NSMakePoint(81*s,18*s)];edge.lineWidth=6*s;edge.lineJoinStyle=NSLineJoinStyleRound;[edge stroke];[image unlockFocus];[image setTemplate:YES];return image;}
 if(tile){NSBezierPath*base=[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(5*s,5*s,90*s,90*s) xRadius:21*s yRadius:21*s];NSGradient*metal=[[NSGradient alloc]initWithColors:@[PrismColor(0x242a30),PrismColor(0x101419),PrismColor(0x06080b)]];[metal drawInBezierPath:base angle:-90];base.lineWidth=.6*s;[PrismColor(0xffffff,.14)setStroke];[base stroke];}
 [NSGraphicsContext saveGraphicsState];NSShadow*shadow=[NSShadow new];shadow.shadowColor=PrismColor(0x000000,.65);shadow.shadowOffset=NSMakeSize(0,-3*s);shadow.shadowBlurRadius=5*s;[shadow set];NSBezierPath*silhouette=PrismFace(s,@[PP(20,25),PP(45,78),PP(62,85),PP(85,35),PP(69,25)]);[PrismColor(0x66767e)setFill];[silhouette fill];[NSGraphicsContext restoreGraphicsState];
 NSBezierPath*side=PrismFace(s,@[PP(45,78),PP(62,85),PP(85,35),PP(69,25)]);NSGradient*sideGradient=[[NSGradient alloc]initWithColors:@[PrismColor(0x273a48),PrismColor(0x698e9d),PrismColor(0xc9dfdf)]];[sideGradient drawInBezierPath:side angle:145];
 NSBezierPath*front=PrismFace(s,@[PP(45,78),PP(20,25),PP(69,25)]);NSGradient*glass=[[NSGradient alloc]initWithColors:@[PrismColor(0xf0ffff),PrismColor(0xaacbd4),PrismColor(0xdbe7ee),PrismColor(0x90aab9)]];[glass drawInBezierPath:front angle:-36];front.lineWidth=.8*s;[PrismColor(0xffffff,.8)setStroke];[front stroke];
 [NSGraphicsContext saveGraphicsState];[front addClip];NSBezierPath*reflection=PrismFace(s,@[PP(34,68),PP(42,72),PP(68,24),PP(61,24)]);[PrismColor(0xffffff,.28)setFill];[reflection fill];[NSGraphicsContext restoreGraphicsState];
 NSBezierPath*ridge=[NSBezierPath bezierPath];[ridge moveToPoint:NSMakePoint(45*s,78*s)];[ridge lineToPoint:NSMakePoint(62*s,85*s)];[ridge lineToPoint:NSMakePoint(85*s,35*s)];ridge.lineWidth=.65*s;[PrismColor(0xf2faff,.85)setStroke];[ridge stroke];
 NSBezierPath*refraction=[NSBezierPath bezierPath];[refraction moveToPoint:NSMakePoint(25*s,26*s)];[refraction lineToPoint:NSMakePoint(68*s,26*s)];refraction.lineWidth=1.0*s;[PrismColor(0xc9b7b1,.8)setStroke];[refraction stroke];
 [image unlockFocus];return image;
}
#undef PP
static NSImage *PrismAppIcon(NSString*key){
 static NSCache<NSString*,NSImage*>*cache;static dispatch_once_t once;dispatch_once(&once,^{cache=[NSCache new];cache.countLimit=64;});
 NSImage*cached=[cache objectForKey:key];if(cached)return cached;
 NSURL*url=[NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:key];
 NSImage*source=url?[NSWorkspace.sharedWorkspace iconForFile:url.path]:[NSImage imageWithSystemSymbolName:@"waveform" accessibilityDescription:nil];
 // Keep just the representation used by the mixer/menu instead of full-size app artwork.
 NSImage*icon=[[NSImage alloc]initWithSize:NSMakeSize(32,32)];[icon lockFocus];[source drawInRect:NSMakeRect(0,0,32,32) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];[icon unlockFocus];
 [cache setObject:icon forKey:key];return icon;
}
