#import "XCBRenderingEngine.h"
#import "XCBTitleBar.h"
#import "XCBFrame.h"
#import "XCBThemeService.h"
#import "services/TitleBarSettingsService.h"
#import <cairo/cairo-xcb.h>
#import <xcb/xcb_aux.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846264338327950288
#endif

@implementation XCBRenderingEngine

static XCBRenderingEngine *sharedInstance = nil;

#pragma mark - Singleton

+ (instancetype)sharedEngine {
    if (sharedInstance == nil) {
        sharedInstance = [[XCBRenderingEngine alloc] init];
    }
    return sharedInstance;
}

#pragma mark - Public Methods

+ (void)renderTitleBar:(XCBTitleBar *)titleBar {
    [[self sharedEngine] renderTitleBarInternal:titleBar];
}

+ (void)renderButton:(XCBWindow *)button active:(BOOL)active {
    [[self sharedEngine] renderButtonInternal:button active:active];
}

+ (void)renderFrame:(XCBFrame *)frame {
    [[self sharedEngine] renderFrameInternal:frame];
}

#pragma mark - Title Bar Rendering

- (void)renderTitleBarInternal:(XCBTitleBar *)titleBar {
    if (!titleBar || !titleBar.connection) {
        NSLog(@"[XCBRenderingEngine] Invalid titleBar for rendering");
        return;
    }
    
    if (!titleBar.pixmap || titleBar.pixmap == 0 || !titleBar.dPixmap || titleBar.dPixmap == 0) {
        NSLog(@"[XCBRenderingEngine] Pixmaps not initialized for titleBar");
        return;
    }
    
    XCBWindow *rootWindow = [titleBar.parentWindow parentWindow];
    XCBScreen *screen = [rootWindow screen];
    XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:[screen screen]->root_visual];
    [visual setVisualTypeForScreen:screen];
    
    XCBThemeService *theme = [XCBThemeService sharedInstance];
    XCBColor activeColor = [theme titleBarActiveColor];
    XCBColor inactiveColor = [theme titleBarInactiveColor];
    
    [self renderTitleBarToPixmap:titleBar.pixmap 
                       titleBar:titleBar 
                         visual:visual 
                         active:YES 
                          color:activeColor];
    
    [self renderTitleBarToPixmap:titleBar.dPixmap 
                       titleBar:titleBar 
                         visual:visual 
                         active:NO 
                          color:inactiveColor];
    
    titleBar.isRendered = YES;
}

- (void)renderTitleBarToPixmap:(xcb_pixmap_t)pixmap 
                      titleBar:(XCBTitleBar *)titleBar
                        visual:(XCBVisual *)visual
                        active:(BOOL)active
                         color:(XCBColor)color {
    
    CGFloat width = titleBar.windowRect.size.width;
    CGFloat height = titleBar.windowRect.size.height;
    
    cairo_surface_t *surface = cairo_xcb_surface_create(
        [titleBar.connection connection],
        pixmap,
        [visual visualType],
        width,
        height - 1
    );
    
    cairo_t *cr = cairo_create(surface);
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST);
    
    [self drawTitleBarGradient:cr width:width height:height color:color];
    
    NSString *title = [titleBar windowTitle];
    if (title && [title length] > 0) {
        [self drawTitleText:title context:cr width:width height:height];
    }
    
    cairo_surface_flush(surface);
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
}

- (void)drawTitleBarGradient:(cairo_t *)cr 
                       width:(CGFloat)width 
                      height:(CGFloat)height 
                       color:(XCBColor)color {
    
    cairo_pattern_t *pat = cairo_pattern_create_linear(0, height, 0, 0);
    
    cairo_pattern_add_color_stop_rgb(pat, 0.2, 
        color.redComponent,
        color.greenComponent,
        color.blueComponent);
    
    cairo_pattern_add_color_stop_rgb(pat, 0.99,
        color.redComponent * 0.93,
        color.greenComponent * 0.93,
        color.blueComponent * 0.93);
    
    cairo_set_source(cr, pat);
    cairo_rectangle(cr, 0, 0, width, height - 1);
    cairo_fill(cr);
    
    cairo_pattern_destroy(pat);
}

- (void)drawTitleText:(NSString *)text 
              context:(cairo_t *)cr
                width:(CGFloat)width
               height:(CGFloat)height {
    
    if (!text || [text length] == 0) return;
    
    cairo_set_source_rgb(cr, 0, 0, 0);
    
    cairo_select_font_face(cr, "Serif", 
                          CAIRO_FONT_SLANT_NORMAL, 
                          CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, 11);
    
    cairo_text_extents_t extents;
    const char *utfString = [text UTF8String];
    cairo_text_extents(cr, utfString, &extents);
    
    CGFloat textX = (width - extents.width) / 2.0;
    CGFloat textY = (height / 2.0) + 2;
    
    cairo_move_to(cr, textX, textY);
    cairo_show_text(cr, utfString);
}

#pragma mark - Button Rendering

- (void)renderButtonInternal:(XCBWindow *)button active:(BOOL)active {
    if (!button || !button.connection) {
        NSLog(@"[XCBRenderingEngine] Invalid button for rendering");
        return;
    }
    
    if (!button.pixmap || button.pixmap == 0 || !button.dPixmap || button.dPixmap == 0) {
        NSLog(@"[XCBRenderingEngine] Pixmaps not initialized for button");
        return;
    }
    
    XCBTitleBar *titleBar = (XCBTitleBar *)[button parentWindow];
    XCBWindow *rootWindow = [titleBar.parentWindow parentWindow];
    XCBScreen *screen = [rootWindow screen];
    XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:[screen screen]->root_visual];
    [visual setVisualTypeForScreen:screen];
    
    XCBThemeService *theme = [XCBThemeService sharedInstance];
    XCBColor buttonColor;
    
    if ([button isCloseButton]) {
        buttonColor = [theme buttonCloseColor];
    } else if ([button isMinimizeButton]) {
        buttonColor = [theme buttonMinimizeColor];
    } else if ([button isMaximizeButton]) {
        buttonColor = [theme buttonMaximizeColor];
    } else {
        buttonColor = XCBMakeColor(0.5, 0.5, 0.5, 1.0);
    }
    
    [self renderButtonToPixmap:button.pixmap 
                        button:button 
                        visual:visual 
                        active:YES 
                         color:buttonColor
                    titleColor:titleBar.titleBarUpColor];
    
    [self renderButtonToPixmap:button.dPixmap 
                        button:button 
                        visual:visual 
                        active:NO 
                         color:buttonColor
                    titleColor:titleBar.titleBarDownColor];
}

- (void)renderButtonToPixmap:(xcb_pixmap_t)pixmap
                       button:(XCBWindow *)button
                       visual:(XCBVisual *)visual
                       active:(BOOL)active
                        color:(XCBColor)buttonColor
                   titleColor:(XCBColor)titleBarColor {
    
    CGFloat width = button.windowRect.size.width;
    CGFloat height = button.windowRect.size.height;
    
    cairo_surface_t *surface = cairo_xcb_surface_create(
        [button.connection connection],
        pixmap,
        [visual visualType],
        width,
        height
    );
    
    cairo_t *cr = cairo_create(surface);
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST);
    
    cairo_set_source_rgb(cr, 
        titleBarColor.redComponent,
        titleBarColor.greenComponent,
        titleBarColor.blueComponent);
    cairo_paint(cr);
    
    if (active) {
        [self drawButtonCircle:cr 
                         width:width 
                        height:height 
                         color:buttonColor];
    } else {
        XCBColor dimmedColor = XCBMakeColor(
            buttonColor.redComponent * 0.6,
            buttonColor.greenComponent * 0.6,
            buttonColor.blueComponent * 0.6,
            buttonColor.alphaComponent
        );
        [self drawButtonCircle:cr 
                         width:width 
                        height:height 
                         color:dimmedColor];
    }
    
    cairo_surface_flush(surface);
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
}

- (void)drawButtonCircle:(cairo_t *)cr 
                   width:(CGFloat)width
                  height:(CGFloat)height
                   color:(XCBColor)color {
    
    CGFloat centerX = width / 2.0;
    CGFloat centerY = height / 2.0;
    CGFloat radius = 6.0;
    
    cairo_pattern_t *pat = cairo_pattern_create_radial(
        centerX - radius/4, centerY - radius/4, radius/8,
        centerX, centerY, radius
    );
    
    cairo_pattern_add_color_stop_rgb(pat, 0.0,
        fmin(color.redComponent * 1.3, 1.0),
        fmin(color.greenComponent * 1.3, 1.0),
        fmin(color.blueComponent * 1.3, 1.0));
    
    cairo_pattern_add_color_stop_rgb(pat, 0.5,
        color.redComponent,
        color.greenComponent,
        color.blueComponent);
    
    cairo_pattern_add_color_stop_rgb(pat, 1.0,
        color.redComponent * 0.85,
        color.greenComponent * 0.85,
        color.blueComponent * 0.85);
    
    cairo_set_source(cr, pat);
    cairo_arc(cr, centerX, centerY, radius, 0, 2 * M_PI);
    cairo_fill_preserve(cr);
    
    cairo_set_line_width(cr, 0.75);
    cairo_set_source_rgba(cr, 0, 0, 0, 0.2);
    cairo_stroke(cr);
    
    cairo_pattern_destroy(pat);
}

#pragma mark - Frame Rendering

- (void)renderFrameInternal:(XCBFrame *)frame {
    if (!frame || !frame.connection) {
        NSLog(@"[XCBRenderingEngine] Invalid frame for rendering");
        return;
    }
    
    XCBScreen *screen = [frame onScreen];
    XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:[screen screen]->root_visual];
    [visual setVisualTypeForScreen:screen];
}

#pragma mark - Utility Methods

+ (void)updateTitleForTitleBar:(XCBTitleBar *)titleBar {
    XCBRenderingEngine *engine = [self sharedEngine];
    
    NSString *title = [titleBar windowTitle];
    if (title && [title length] > 0) {
        [engine renderTitleBarInternal:titleBar];
    }
}

+ (void)refreshTitleBar:(XCBTitleBar *)titleBar {
    titleBar.isRendered = NO;
    [[self sharedEngine] renderTitleBarInternal:titleBar];
}

@end
