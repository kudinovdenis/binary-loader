#import "FunctionsHandler.h"
#include <cstdint>  // For uintptr_t

#import "vmh.h"
#import "FunctionPrintf.hpp"

@implementation FunctionsHandler

int custom_error2()
{
    return 0;
}

int* custom_error()
{
    return (int*)custom_error2;
}

- (NSDictionary<NSString*, NSNumber*>*) functionsTable
{
    return @{
        @"_printf" : @((uintptr_t)(int*)custom_printf),
        @"___error" : @((uintptr_t)(void*)custom_error)
    };
}

@end
