#import "BlockRunner+Specs.h"
#import <objc/runtime.h>

@implementation BlockRunner (Specs)

+ (void)load
{
    Method originalRunBlockMethod = class_getClassMethod(self, @selector(runBlock:onThread:));
    IMP newRunBlockIMP = imp_implementationWithBlock(^(id me, void (^block)(void), dispatch_queue_t thread) {
        block();
    });
    method_setImplementation(originalRunBlockMethod, newRunBlockIMP);
    
    Method originalRunSyncMethod = class_getClassMethod(self, @selector(runBlockSynchronously:onThread:));
    IMP newRunSyncIMP = imp_implementationWithBlock(^(id me, void (^block)(void), dispatch_queue_t thread) {
        block();
    });
    method_setImplementation(originalRunSyncMethod, newRunSyncIMP);
}

@end
