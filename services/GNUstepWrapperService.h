//
//  GNUstepWrapperService.h
//  XCBKit
//
//  Service for detecting and communicating with GNUstep application wrappers
//

#import <Foundation/Foundation.h>
#import "../XCBConnection.h"
#import "../XCBWindow.h"

@protocol ModernApplicationWrapperProtocol;

@interface GNUstepWrapperService : NSObject

@property (nonatomic, strong) XCBConnection *connection;
@property (nonatomic, strong) NSMutableDictionary *wrapperRegistry;
@property (nonatomic, strong) NSMutableDictionary *pidToServiceMap;
@property (nonatomic, strong) NSString *currentActiveWrapper;
@property (nonatomic, assign) BOOL isWrapperCurrentlyActive;

+ (instancetype)sharedInstanceWithConnection:(XCBConnection *)connection;

- (instancetype)initWithConnection:(XCBConnection *)connection;

// Wrapper Detection
- (BOOL)isGNUstepWrapper:(XCBWindow *)window;
- (NSString *)getWrapperServiceNameForWindow:(XCBWindow *)window;
- (NSString *)getWrapperServiceNameForPID:(pid_t)pid;

// Wrapper Communication
- (id<ModernApplicationWrapperProtocol>)connectToWrapper:(NSString *)serviceName;
- (void)showWrapperMenuForWindow:(XCBWindow *)window atPoint:(NSPoint)point;

// Registry Management
- (void)registerWrapper:(NSString *)serviceName forPID:(pid_t)pid;
- (void)unregisterWrapperForPID:(pid_t)pid;
- (void)cleanupStaleWrappers;

// Window Event Handling
- (void)handleWindowClick:(XCBWindow *)window withEvent:(xcb_button_press_event_t *)event;
- (void)handleWindowActivation:(XCBWindow *)window;

@end