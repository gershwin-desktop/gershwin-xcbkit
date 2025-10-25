//
//  CairoDrawer.h
//  XCBKit
//
//  Created by Alessandro Sangiuliano on 02/01/20.
//  Copyright (c) 2020 alex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <cairo/cairo-xcb.h>
#import <cairo/cairo.h>
#import <XCBConnection.h>
#import "../XCBWindow.h"
#import "../XCBVisual.h"
#import "XCBShape.h"

@interface CairoDrawer : NSObject

@property (nonatomic) cairo_surface_t *cairoSurface;
@property (nonatomic) cairo_t *cr;
@property (strong, nonatomic) XCBConnection *connection;
@property (strong, nonatomic) XCBWindow *window;
@property (strong, nonatomic) XCBVisual *visual;
@property (nonatomic) CGFloat height;
@property (nonatomic) CGFloat width;
@property (nonatomic) BOOL alreadyScaled;

- (id) initWithConnection:(XCBConnection*) aConnection;
- (id) initWithConnection:(XCBConnection *)aConnection window:(XCBWindow*) aWindow visual:(XCBVisual*) aVisual;
- (id) initWithConnection:(XCBConnection *)aConnection window:(XCBWindow*) aWindow;

// Preview/miniaturize functionality
- (void) makePreviewImage;
- (void) setPreviewImage;

// Icon processing
- (cairo_surface_t*) drawContentFromData:(uint32_t *)data withWidht:(int)aWidth andHeight:(int)aHeight;
- (void) drawIconFromSurface:(cairo_surface_t*)aSurface;

// Image loading (for custom button images if needed)
- (void) putImage:(NSString*)aPath forDPixmap:(BOOL)aValue;

// Debug/development helpers
- (void) drawContent;

// Context management
- (void) saveContext;
- (void) restoreContext;

@end
