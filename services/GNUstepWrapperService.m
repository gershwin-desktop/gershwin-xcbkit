//
//  GNUstepWrapperService.m
//  XCBKit
//

#import "GNUstepWrapperService.h"
#import "EWMHService.h"
#import <sys/types.h>
#import <sys/sysctl.h>
#import <sys/user.h>
#import <signal.h>
#import <AppKit/AppKit.h>

@protocol ModernApplicationWrapperProtocol <NSObject>
- (void)activateIgnoringOtherApps:(BOOL)flag;
- (void)hide:(id)sender;
- (BOOL)isHidden;
- (void)terminate:(id)sender;
- (BOOL)isRunning;
- (NSNumber *)processIdentifier;
- (NSString *)applicationName;
- (id)applicationMenu;
- (void)showMenuAtPoint:(NSPoint)point;
@end

static GNUstepWrapperService *sharedInstance = nil;

@implementation GNUstepWrapperService

+ (instancetype)sharedInstanceWithConnection:(XCBConnection *)connection {
    if (sharedInstance == nil) {
        sharedInstance = [[self alloc] initWithConnection:connection];
    }
    return sharedInstance;
}

- (instancetype)initWithConnection:(XCBConnection *)connection {
    self = [super init];
    if (self) {
        self.connection = connection;
        self.wrapperRegistry = [NSMutableDictionary dictionary];
        self.pidToServiceMap = [NSMutableDictionary dictionary];

        // Start periodic cleanup of stale wrappers
        [NSTimer scheduledTimerWithTimeInterval:30.0
                                         target:self
                                       selector:@selector(cleanupStaleWrappers)
                                       userInfo:nil
                                        repeats:YES];
    }
    return self;
}

#pragma mark - Wrapper Detection

- (BOOL)isGNUstepWrapper:(XCBWindow *)window {
    // Get the PID of the window
    EWMHService *ewmhService = [EWMHService sharedInstanceWithConnection:self.connection];
    uint32_t pid = [ewmhService netWMPidForWindow:window];

    if (pid == 0) {
        return NO;
    }

    // Check if we have a registered wrapper for this PID
    NSString *serviceName = [self getWrapperServiceNameForPID:pid];
    if (serviceName) {
        return YES;
    }

    // Try to detect by process name pattern
    return [self detectWrapperByProcessName:pid];
}

- (BOOL)detectWrapperByProcessName:(pid_t)pid {
    // Get process name using sysctl
    int mib[4];
    size_t size;
    struct kinfo_proc proc;

    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = pid;

    size = sizeof(proc);
    if (sysctl(mib, 4, &proc, &size, NULL, 0) != 0) {
        return NO;
    }

    NSString *processName = [NSString stringWithUTF8String:proc.ki_comm];

    // Check if process name suggests it's a wrapper
    // Look for pattern like "AppWrapper-ApplicationName" or similar
    if ([processName containsString:@"Wrapper"] ||
        [processName hasSuffix:@"-wrapper"] ||
        [processName hasPrefix:@"GNUstep-"]) {

        // Try to connect using predictable service name
        NSString *serviceName = [NSString stringWithFormat:@"ApplicationWrapper-%@", processName];
        id<ModernApplicationWrapperProtocol> wrapper = [self connectToWrapper:serviceName];

        if (wrapper) {
            [self registerWrapper:serviceName forPID:pid];
            return YES;
        }

        // Try alternative naming patterns
        serviceName = [NSString stringWithFormat:@"AppWrapper.%@", processName];
        wrapper = [self connectToWrapper:serviceName];

        if (wrapper) {
            [self registerWrapper:serviceName forPID:pid];
            return YES;
        }
    }

    return NO;
}

- (NSString *)getWrapperServiceNameForWindow:(XCBWindow *)window {
    EWMHService *ewmhService = [EWMHService sharedInstanceWithConnection:self.connection];
    uint32_t pid = [ewmhService netWMPidForWindow:window];

    if (pid == 0) {
        return nil;
    }

    return [self getWrapperServiceNameForPID:pid];
}

- (NSString *)getWrapperServiceNameForPID:(pid_t)pid {
    return self.pidToServiceMap[@(pid)];
}

#pragma mark - Wrapper Communication

- (id<ModernApplicationWrapperProtocol>)connectToWrapper:(NSString *)serviceName {
    @try {
        NSConnection *connection = [NSConnection connectionWithRegisteredName:serviceName host:nil];
        if (connection) {
            id<ModernApplicationWrapperProtocol> wrapper = (id<ModernApplicationWrapperProtocol>)[connection rootProxy];
            if (wrapper) {
                // Test the connection
                BOOL isRunning = [wrapper isRunning];
                (void)isRunning;
                return wrapper;
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Failed to connect to wrapper service %@: %@", serviceName, exception.reason);
    }

    return nil;
}

- (void)showWrapperMenuForWindow:(XCBWindow *)window atPoint:(NSPoint)point {
    NSString *serviceName = [self getWrapperServiceNameForWindow:window];
    if (!serviceName) {
        return;
    }

    id<ModernApplicationWrapperProtocol> wrapper = [self connectToWrapper:serviceName];
    if (wrapper) {
        @try {
            [wrapper showMenuAtPoint:point];
        }
        @catch (NSException *exception) {
            NSLog(@"Failed to show wrapper menu: %@", exception.reason);
        }
    }
}

#pragma mark - Registry Management

- (void)registerWrapper:(NSString *)serviceName forPID:(pid_t)pid {
    self.pidToServiceMap[@(pid)] = serviceName;
    self.wrapperRegistry[serviceName] = @(pid);

    NSLog(@"Registered wrapper service %@ for PID %d", serviceName, pid);
}

- (void)unregisterWrapperForPID:(pid_t)pid {
    NSString *serviceName = self.pidToServiceMap[@(pid)];
    if (serviceName) {
        [self.pidToServiceMap removeObjectForKey:@(pid)];
        [self.wrapperRegistry removeObjectForKey:serviceName];

        NSLog(@"Unregistered wrapper service %@ for PID %d", serviceName, pid);
    }
}

- (void)cleanupStaleWrappers {
    NSMutableArray *stalePIDs = [NSMutableArray array];

    for (NSNumber *pidNumber in [self.pidToServiceMap allKeys]) {
        pid_t pid = [pidNumber intValue];

        // Check if process is still running
        if (kill(pid, 0) == -1) {
            [stalePIDs addObject:pidNumber];
        }
    }

    // Remove stale entries
    for (NSNumber *pidNumber in stalePIDs) {
        [self unregisterWrapperForPID:[pidNumber intValue]];
    }

    if ([stalePIDs count] > 0) {
        NSLog(@"Cleaned up %lu stale wrapper registrations", (unsigned long)[stalePIDs count]);
    }
}

#pragma mark - Window Event Handling

- (void)handleWindowClick:(XCBWindow *)window withEvent:(xcb_button_press_event_t *)event {
    // Check if this is a left click
    if (event->detail != 1) { // 1 = left mouse button
        return;
    }

    // Check if this is a GNUstep wrapper window
    if (![self isGNUstepWrapper:window]) {
        return;
    }

    // Convert event coordinates to NSPoint
    NSPoint clickPoint = NSMakePoint(event->root_x, event->root_y);

    // Show the wrapper menu
    [self showWrapperMenuForWindow:window atPoint:clickPoint];
}

- (void)handleWindowActivation:(XCBWindow *)window {
    BOOL isWrapperWindow = [self isGNUstepWrapper:window];

    if (!isWrapperWindow) {
        // Switching away from wrapper to regular window - reset tracking
        self.isWrapperCurrentlyActive = NO;
        self.currentActiveWrapper = nil;
        NSLog(@"Switched to non-wrapper window - cleared wrapper tracking");
        return;
    }

    NSString *serviceName = [self getWrapperServiceNameForWindow:window];
    if (!serviceName) {
        return;
    }

    // Gently activate wrapper when switching to it, but not when clicking same window repeatedly
    BOOL shouldActivate = !self.isWrapperCurrentlyActive ||
                         !self.currentActiveWrapper ||
                         ![self.currentActiveWrapper isEqualToString:serviceName];

    if (shouldActivate) {
        id<ModernApplicationWrapperProtocol> wrapper = [self connectToWrapper:serviceName];
        if (wrapper) {
            @try {
                // Use gentle activation that doesn't disrupt menus
                [wrapper activateIgnoringOtherApps:NO];
                self.currentActiveWrapper = serviceName;
                self.isWrapperCurrentlyActive = YES;
                NSLog(@"Gently activated wrapper: %@", serviceName);
            }
            @catch (NSException *exception) {
                NSLog(@"Failed to activate wrapper: %@", exception.reason);
            }
        }
    } else {
        NSLog(@"Same wrapper %@ already active - no reactivation needed", serviceName);
    }
}

@end