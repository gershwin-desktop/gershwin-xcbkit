//
//  CairoDrawer.m
//  XCBKit
//
//  Created by Alessandro Sangiuliano on 02/01/20.
//  Copyright (c) 2020 alex. All rights reserved.
//

#import "CairoDrawer.h"
#import "../XCBTitleBar.h"
#import "../services/TitleBarSettingsService.h"
#import <xcb/xcb_aux.h>
#import "../functions/Comparators.h"

static cairo_user_data_key_t data_key;

static inline void free_callback(void *data)
{
    free(data);
}

@implementation CairoDrawer

@synthesize cairoSurface;
@synthesize cr;
@synthesize connection;
@synthesize window;
@synthesize visual;
@synthesize height;
@synthesize width;
@synthesize alreadyScaled;

- (id) initWithConnection:(XCBConnection *)aConnection
{
    return [self initWithConnection:aConnection window:nil visual:nil];
}

- (id) initWithConnection:(XCBConnection *)aConnection window:(XCBWindow *)aWindow visual:(XCBVisual *)aVisual
{
    self = [super init];
    
    if (self == nil)
    {
        NSLog(@"Unable to init");
        return nil;
    }
    
    connection = aConnection;
    [self setWindow:aWindow];
    visual = aVisual;
    
    height = (CGFloat)[aWindow windowRect].size.height;
    width = (CGFloat)[aWindow windowRect].size.width;
    
    XCBScreen *screen = [window onScreen];
    
    if (visual != nil)
        [visual setVisualTypeForScreen:screen];
    else if (window != nil)
    {
        xcb_visualid_t visualid = [[window attributes] visualId];
        visual = [[XCBVisual alloc] initWithVisualId:visualid withVisualType:xcb_aux_find_visual_by_id([screen screen], visualid)];
    }
    
    screen = nil;
    alreadyScaled = NO;
    
    return self;
}

- (id) initWithConnection:(XCBConnection *)aConnection window:(XCBWindow*) aWindow
{
    self = [super init];

    if (self == nil)
    {
        NSLog(@"Unable to init");
        return nil;
    }

    connection = aConnection;
    [self setWindow:aWindow];

    visual = [window visual];

    height = (CGFloat)[aWindow windowRect].size.height;
    width = (CGFloat)[aWindow windowRect].size.width;
    alreadyScaled = NO;

    return self;
}

- (void) makePreviewImage
{
    cairoSurface = cairo_xcb_surface_create([connection connection], [window window], [visual visualType], width, height);
    cr = cairo_create(cairoSurface);
    cairo_set_source_surface(cr, cairoSurface, 0,0);
    cairo_paint(cr);

    cairo_surface_write_to_png(cairoSurface, "/tmp/Preview.png");

    cairo_surface_destroy(cairoSurface);
    cairo_destroy(cr);
}

- (void) setPreviewImage
{
    XCBSize size = [window windowRect].size;
    cairoSurface = cairo_xcb_surface_create([connection connection], [window window], [visual visualType], size.width, size.height);
    cr = cairo_create(cairoSurface);
    
    cairo_surface_t* imageSurface = cairo_image_surface_create_from_png("/tmp/Preview.png");
    cairo_surface_t* similar = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, size.width, size.height);
    cairo_t* aux = cairo_create(similar);
    
    double scalingFactorW = 50.0 /(double) cairo_image_surface_get_width(imageSurface);
    double scalingFactorH = 50.0 /(double) cairo_image_surface_get_height(imageSurface);
    
    cairo_scale(aux, scalingFactorW, scalingFactorH);
    cairo_set_source_surface(aux, imageSurface, 0, 0);
    cairo_set_operator(aux, CAIRO_OPERATOR_SOURCE);
    cairo_paint(aux);
    
    cairo_set_source_surface(cr, similar, 0, 0);
    cairo_paint(cr);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError* error;
    [fileManager removeItemAtPath:@"/tmp/Preview.png" error:&error];
    
    cairo_paint(cr);
    
    cairo_surface_destroy(cairoSurface);
    cairo_surface_destroy(imageSurface);
    cairo_surface_destroy(similar);
    cairo_destroy(cr);
    cairo_destroy(aux);
    
    error = nil;
    fileManager = nil;
}

- (void) putImage:(NSString*)aPath forDPixmap:(BOOL)aValue
{
    TitleBarSettingsService *settingsService = [TitleBarSettingsService sharedInstance];
    XCBSize size = [window windowRect].size;
    XCBPoint position;

    if (!aValue)
        cairoSurface = cairo_xcb_surface_create([connection connection], [window pixmap], [visual visualType], size.width, size.height);
    else
        cairoSurface = cairo_xcb_surface_create([connection connection], [window dPixmap], [visual visualType], size.width, size.height);

    cr = cairo_create(cairoSurface);

    cairo_surface_t* imageSurface = cairo_image_surface_create_from_png([aPath cString]);
    cairo_surface_t* similar = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, size.width, size.height);
    cairo_t* similarCtx = cairo_create(similar);

    cairo_set_source_surface(similarCtx, imageSurface, 0, 0);
    cairo_set_operator(similarCtx, CAIRO_OPERATOR_SOURCE);
    cairo_paint(similarCtx);

    if ([window isCloseButton])
        position = [settingsService closePosition];
    else if ([window isMaximizeButton])
        position = [settingsService maximizePosition];
    else if ([window isMinimizeButton])
        position = [settingsService minimizePosition];

    cairo_set_source_surface(cr, similar, position.x, position.y);
    cairo_paint(cr);

    cairo_surface_destroy(cairoSurface);
    cairo_surface_destroy(imageSurface);
    cairo_surface_destroy(similar);
    cairo_destroy(cr);
    cairo_destroy(similarCtx);
    settingsService = nil;

    return;
}

- (void) drawContent
{
    cairoSurface = cairo_xcb_surface_create([connection connection], [window pixmap], [visual visualType], width, height);
    cr = cairo_create(cairoSurface);

    cairo_surface_write_to_png(cairoSurface, "/tmp/Pixmap.png");
    
    cairo_surface_flush(cairoSurface);
    cairo_surface_destroy(cairoSurface);
    cairo_destroy(cr);

    cairoSurface = cairo_xcb_surface_create([connection connection], [window dPixmap], [visual visualType], width, height);
    cr = cairo_create(cairoSurface);

    cairo_surface_write_to_png(cairoSurface, "/tmp/dPixmap.png");

    cairo_surface_flush(cairoSurface);
    cairo_surface_destroy(cairoSurface);
    cairo_destroy(cr);
}

- (void) drawIconFromSurface:(cairo_surface_t*)aSurface
{
    cairoSurface = cairo_xcb_surface_create([connection connection], [window window], [visual visualType], width, height);
    cr = cairo_create(cairoSurface);
    cairo_surface_write_to_png(aSurface, "/tmp/Pova.png");
    cairo_paint(cr);
    cairo_surface_destroy(cairoSurface);
    cairo_destroy(cr);
}

- (cairo_surface_t*)drawContentFromData:(uint32_t*)data withWidht:(int)aWidth andHeight:(int)aHeight
{
    width = aWidth;
    height = aHeight;
    unsigned long int len = aWidth * aHeight;
    unsigned long int i;
    uint32_t *buffer = (uint32_t*) malloc(sizeof(uint32_t) * len);

    for(i = 0; i < len; i++)
    {
        uint8_t a = (data[i] >> 24) & 0xff;
        double alpha = a / 255.0;
        uint8_t r = ((data[i] >> 16) & 0xff) * alpha;
        uint8_t g = ((data[i] >>  8) & 0xff) * alpha;
        uint8_t b = ((data[i] >>  0) & 0xff) * alpha;
        buffer[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }

    cairoSurface = cairo_image_surface_create_for_data((unsigned char *) buffer,
                                                CAIRO_FORMAT_ARGB32,
                                                aWidth,
                                                aHeight,
                                                aWidth*4);

    cairo_surface_set_user_data(cairoSurface, &data_key, buffer, &free_callback);

    return cairoSurface;
}

- (void) saveContext
{
    cairo_save(cr);
}

- (void) restoreContext
{
    cairo_restore(cr);
}

- (void) dealloc
{
    cairoSurface = NULL;
    cr = NULL;
    connection = nil;
    window = nil;
    visual = nil;
    height =  0.0;
    width = 0.0;
}

@end
