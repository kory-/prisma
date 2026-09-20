#import <Cocoa/Cocoa.h>
#include <initializer_list>

// Export the artwork through the app's rounded tile mask. The output has real
// transparency outside the tile and one pixel-aligned representation per size.
int main(int argc,char**argv){@autoreleasepool{
 if(argc!=3){fprintf(stderr,"Usage: make-icons OUTPUT_DIRECTORY ARTWORK.png\n");return 1;}
 NSString*folder=[NSString stringWithUTF8String:argv[1]];
 NSImage*art=[[NSImage alloc]initWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]];
 if(!art){fprintf(stderr,"Cannot load Prisma icon artwork\n");return 1;}
 [[NSFileManager defaultManager]createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
 for(int size:{16,32,64,128,256,512,1024}){
  NSBitmapImageRep*bitmap=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:size pixelsHigh:size bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
  if(!bitmap)return 1;
  [NSGraphicsContext saveGraphicsState];
  NSGraphicsContext*context=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
  NSGraphicsContext.currentContext=context;context.imageInterpolation=NSImageInterpolationHigh;
  NSRect bounds=NSMakeRect(0,0,size,size);[NSColor.clearColor setFill];NSRectFillUsingOperation(bounds,NSCompositingOperationCopy);
  CGFloat scale=size/100.0;
  NSBezierPath*tile=[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(5.6*scale,5.6*scale,88.8*scale,88.8*scale) xRadius:21.5*scale yRadius:21.5*scale];
  [tile addClip];[art drawInRect:bounds fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
  [NSGraphicsContext restoreGraphicsState];
  NSData*png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
  NSString*path=[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"prism-%d.png",size]];
  if(![png writeToFile:path atomically:YES])return 1;
 }
}return 0;}
