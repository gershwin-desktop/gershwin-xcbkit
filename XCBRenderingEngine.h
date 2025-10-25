#import <Foundation/Foundation.h>
#import "utils/XCBShape.h"

@class XCBTitleBar;
@class XCBFrame;
@class XCBWindow;

@interface XCBRenderingEngine : NSObject

// Singleton
+ (instancetype)sharedEngine;

// Main rendering methods
+ (void)renderTitleBar:(XCBTitleBar *)titleBar;
+ (void)renderButton:(XCBWindow *)button active:(BOOL)active;
+ (void)renderFrame:(XCBFrame *)frame;

// Utility methods
+ (void)updateTitleForTitleBar:(XCBTitleBar *)titleBar;
+ (void)refreshTitleBar:(XCBTitleBar *)titleBar;

@end
