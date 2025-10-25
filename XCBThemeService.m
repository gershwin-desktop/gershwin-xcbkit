#import "XCBThemeService.h"

// Suppress the typedef redefinition warning from GNUstep headers
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtypedef-redefinition"
#import <AppKit/AppKit.h>
#pragma clang diagnostic pop

@implementation XCBThemeService

+ (instancetype)sharedInstance {
    static XCBThemeService *instance = nil;
    if (!instance) {
        instance = [[XCBThemeService alloc] init];
    }
    return instance;
}

- (XCBColor)titleBarActiveColor {
    @try {
        // Try to get theme colors from GNUstep
        NSColor *color = [[NSColor controlColor] highlightWithLevel:0.1];
        return [self xcbColorFromNSColor:color];
    }
    @catch (NSException *exception) {
        // Fallback to original color if GSTheme fails
        return XCBMakeColor(0.720, 0.720, 0.720, 1);
    }
}

- (XCBColor)titleBarInactiveColor {
    @try {
        NSColor *color = [NSColor controlBackgroundColor];
        return [self xcbColorFromNSColor:color];
    }
    @catch (NSException *exception) {
        return XCBMakeColor(0.898, 0.898, 0.898, 1);
    }
}

- (XCBColor)buttonCloseColor {
    @try {
        // macOS-like red color
        return XCBMakeColor(0.97, 0.26, 0.23, 1.0);
    }
    @catch (NSException *exception) {
        return XCBMakeColor(0.97, 0.26, 0.23, 1.0);
    }
}

- (XCBColor)buttonMinimizeColor {
    @try {
        // macOS-like yellow color
        return XCBMakeColor(0.9, 0.7, 0.3, 1.0);
    }
    @catch (NSException *exception) {
        return XCBMakeColor(0.9, 0.7, 0.3, 1.0);
    }
}

- (XCBColor)buttonMaximizeColor {
    @try {
        // macOS-like green color
        return XCBMakeColor(0.322, 0.778, 0.244, 1.0);
    }
    @catch (NSException *exception) {
        return XCBMakeColor(0.322, 0.778, 0.244, 1.0);
    }
}

- (XCBColor)xcbColorFromNSColor:(NSColor*)nsColor {
    if (!nsColor) {
        return XCBMakeColor(0.5, 0.5, 0.5, 1.0); // Gray fallback
    }
    
    // Convert to RGB color space
    NSColor *rgbColor = [nsColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    if (!rgbColor) {
        return XCBMakeColor(0.5, 0.5, 0.5, 1.0); // Gray fallback
    }
    
    CGFloat r, g, b, a;
    [rgbColor getRed:&r green:&g blue:&b alpha:&a];
    return XCBMakeColor(r, g, b, a);
}

@end
