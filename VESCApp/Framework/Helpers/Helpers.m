//
//  Helpers.m
//  Pedaless
//
//  Created by Bosko Petreski on 12/4/19.
//  Copyright © 2019 Bosko Petreski. All rights reserved.
//

#import "Helpers.h"

@implementation Helpers

+(NSString *)documentPath{
    NSString *directory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *plistPath = [directory stringByAppendingPathComponent:@"DataLog.plist"];
    return plistPath;
}
+(void)showPopup:(UIViewController *)controller title:(NSString *)title buttonName:(NSString *)buttonName cancelName:(NSString *)cancelName ok:(VoidCallback)ok cancel:(nullable VoidCallback)cancel{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:@"" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:buttonName style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        ok();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:cancelName style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if(cancel)cancel();
    }]];
    [controller presentViewController:alert animated:YES completion:nil];
}
+(void)shareData:(UIViewController *)controller logData:(NSArray *)arrData shared:(VoidCallback)shared{
    NSData *dataJSON = [NSJSONSerialization dataWithJSONObject:arrData options:0 error:nil];
    
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingString:@"JSON.txt"]];
    NSString *strLog = [NSString.alloc initWithData:dataJSON encoding:NSUTF8StringEncoding];
    [strLog writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[@"JSON",url] applicationActivities:nil];
    [controller presentViewController:activityViewController animated:YES completion:nil];
    [activityViewController setCompletionWithItemsHandler:^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        shared();
    }];
}
@end
