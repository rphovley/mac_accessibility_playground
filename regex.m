#import <Foundation/Foundation.h>

BOOL checkDomain(NSString *str) {
    NSString *pattern = @"^(?:https?:\\/\\/)?(?:www\\.)?[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*\\.[a-zA-Z]{2,}(?:\\/[^\\s]*)?(?:\\?[^\\s]*)?$";
    
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                         options:0
                                                                           error:&error];
    if (error) {
        return NO;
    }
    
    NSRange range = NSMakeRange(0, [str length]);
    NSArray *matches = [regex matchesInString:str options:0 range:range];
    
    return matches.count > 0;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Should match
        printf("Should match:\n");
        printf("google.com: %d\n", checkDomain(@"google.com"));
        printf("google.com/search?q=skadfjljkleo: %d\n", checkDomain(@"google.com/search?q=skadfjljkleo"));
        printf("https://google.com/search?q=: %d\n", checkDomain(@"https://google.com/search?q="));
        printf("https://google.com: %d\n", checkDomain(@"https://google.com"));
        printf("https://www.google.com?q: %d\n", checkDomain(@"https://www.google.com?q"));
        printf("https://www.google.com: %d\n", checkDomain(@"https://www.google.com"));
        printf("www.google.com: %d\n", checkDomain(@"www.google.com"));
        printf("www.photos.google.com: %d\n", checkDomain(@"www.photos.google.com"));
        printf("https://www.photos.google.com?q=wowow: %d\n", checkDomain(@"https://www.photos.google.com?q=wowow"));
        printf("google.com/search?q=app.developer&oq=app.&gs_lcrp=EgZjaHJvbWUqDggAEEUYJxg7GIAEGIoFMg4IABBFGCcYOxiABBiKBTIGCAEQRRg5MgcIAhAAGIAEMgcIAxAAGIAEMg0IBBAAGIMBGLEDGIAEMgcIBRAAGIAEMgcIBhAAGIAEMg0IBxAAGIMBGLEDGIAEMgcICBAAGIAEMgcICRAAGIAE0gEHOTg2ajBqMagCCLACAQ&sourceid=chrome&ie=UTF-8: %d\n", checkDomain(@"google.com/search?q=app.developer&oq=app.&gs_lcrp=EgZjaHJvbWUqDggAEEUYJxg7GIAEGIoFMg4IABBFGCcYOxiABBiKBTIGCAEQRRg5MgcIAhAAGIAEMgcIAxAAGIAEMg0IBBAAGIMBGLEDGIAEMgcIBRAAGIAEMgcIBhAAGIAEMg0IBxAAGIMBGLEDGIAEMgcICBAAGIAEMgcICRAAGIAE0gEHOTg2ajBqMagCCLACAQ&sourceid=chrome&ie=UTF-8"));
        
        // Should not match
        printf("\nShould not match:\n");
        printf("Button Text: %d\n", checkDomain(@"Button Text"));
        printf("Google is awesome: %d\n", checkDomain(@"Google is awesome"));
        printf("Google: %d\n", checkDomain(@"Google"));
        printf(".google: %d\n", checkDomain(@".google"));
        printf("Google is awesome.: %d\n", checkDomain(@"Google is awesome."));
        printf("You should visit google.com: %d\n", checkDomain(@"You should visit google.com"));
        printf("visit https://google.com: %d\n", checkDomain(@"visit https://google.com"));
    }
    return 0;
}

