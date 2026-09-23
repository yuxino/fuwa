#import "FuwaQAVirtualDisplay.h"
@interface QA : NSObject<NSApplicationDelegate>
@property CGVirtualDisplay *display;
@property NSWindow *window;
@property NSTextField *label;
@property NSInteger tick;
@end
@implementation QA
- (void)applicationDidFinishLaunching:(NSNotification *)n {
 CGVirtualDisplayDescriptor *d = [CGVirtualDisplayDescriptor new];
 d.queue=dispatch_get_main_queue(); d.name=@"Fuwa QA 1080p"; d.maxPixelsWide=1920; d.maxPixelsHigh=1080; d.sizeInMillimeters=CGSizeMake(480,270); d.vendorID=0x3456; d.productID=0xF016; d.serialNum=92317;
 self.display=[[CGVirtualDisplay alloc] initWithDescriptor:d];
 CGVirtualDisplaySettings *s=[CGVirtualDisplaySettings new]; s.hiDPI=0; s.modes=@[[[CGVirtualDisplayMode alloc] initWithWidth:1920 height:1080 refreshRate:60]];
 [self.display applySettings:s];
 NSMenu *menu=[NSMenu new]; NSMenuItem *item=[NSMenuItem new]; NSMenu *sub=[NSMenu new];
 [sub addItemWithTitle:@"Quit FuwaDisplayQA" action:@selector(terminate:) keyEquivalent:@"q"]; item.submenu=sub; [menu addItem:item]; NSApp.mainMenu=menu;
 [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(show) userInfo:nil repeats:NO];
 [NSTimer scheduledTimerWithTimeInterval:600 repeats:NO block:^(NSTimer *t){[NSApp terminate:nil];}];
}
- (void)show {
 self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(1640,180,600,400) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
 self.window.title=@"Fuwa QA — virtual second display"; self.window.releasedWhenClosed=NO;
 self.label=[NSTextField labelWithString:@"Virtual display counter"]; self.label.font=[NSFont monospacedSystemFontOfSize:28 weight:NSFontWeightMedium]; self.label.frame=NSMakeRect(30,260,550,70); [self.window.contentView addSubview:self.label];
 NSArray *titles=@[@"Move to built-in display",@"Move to virtual display",@"Disconnect virtual display"];
 SEL actions[]={@selector(moveMain),@selector(moveVirtual),@selector(disconnect)};
 for(int i=0;i<3;i++){NSButton *b=[NSButton buttonWithTitle:titles[i] target:self action:actions[i]]; b.frame=NSMakeRect(30,200-i*55,320,40);[self.window.contentView addSubview:b];}
 [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
 [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(update) userInfo:nil repeats:YES];
 for(NSScreen *screen in NSScreen.screens) NSLog(@"SCREEN %@ %@ scale=%g",screen.localizedName,NSStringFromRect(screen.frame),screen.backingScaleFactor);
}
- (void)update { self.tick++; self.label.stringValue=[NSString stringWithFormat:@"Virtual display counter: %ld",(long)self.tick]; }
- (void)moveMain {[self.window setFrameOrigin:NSMakePoint(180,180)];}
- (void)moveVirtual {[self.window setFrameOrigin:NSMakePoint(1640,180)];}
- (void)disconnect {self.display=nil;}
@end
int main(){@autoreleasepool{[NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular]; QA *qa=[QA new]; NSApp.delegate=qa;[NSApp run];}}
