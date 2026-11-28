#import <Foundation/Foundation.h>
#import "KASecurity.h"
int main(void) {
    @autoreleasepool {
        NSData *data=[NSData dataWithContentsOfFile:@".validation/grants.json"];
        NSDictionary *fixture=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        NSUInteger count=0;
        for(NSDictionary *test in fixture[@"cases"]) {
            NSError *error=nil;
            NSDictionary *result=KAVerifyGrant(test[@"jwt"],fixture[@"token"],fixture[@"installation"],&error);
            BOOL expected=[test[@"ok"] boolValue];
            if ((result!=nil)!=expected || (!expected && !error)) {
                fprintf(stderr,"FAILED: %s\n",[test[@"name"] UTF8String]);return 1;
            }
            count++;
        }
        printf("%lu signed-grant validation checks passed (Apple Security).\n",(unsigned long)count);
    }
}
