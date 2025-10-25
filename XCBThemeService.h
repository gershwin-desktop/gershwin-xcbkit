#import <Foundation/Foundation.h>
#import "utils/XCBShape.h"

@interface XCBThemeService : NSObject

+ (instancetype)sharedInstance;
- (XCBColor)titleBarActiveColor;
- (XCBColor)titleBarInactiveColor;
- (XCBColor)buttonCloseColor;
- (XCBColor)buttonMinimizeColor;
- (XCBColor)buttonMaximizeColor;

@end
