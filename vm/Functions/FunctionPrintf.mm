#include "FunctionPrintf.hpp"
#import <Foundation/Foundation.h>

#include <cstdarg> // For va_list, va_start, va_end

int custom_printf(char *format,...)
{
    printf("MY PRINTF\n");
    
    va_list args;
    va_start(args, format);

    char str[1024];
    snprintf(str, 1024, format, args);
    
    va_end(args);
    
    NSLog(@"%s", str);
    
    return printf("%s", str);
}
