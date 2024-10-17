#import <Foundation/Foundation.h>
#import "vmh.h"

@implementation VM

- (int) jmp:(NSInteger)address
{
    NSLog(@"VM Jumping to: 0x%02lx", (long)address);
    int (*jump_function)(void) = (int (*)(void))address;
    int result = jump_function();
    NSLog(@"result: %d", result);
    return result;
}

@end

