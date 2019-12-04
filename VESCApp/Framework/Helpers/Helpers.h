//
//  Helpers.h
//  Pedaless
//
//  Created by Bosko Petreski on 12/4/19.
//  Copyright © 2019 Bosko Petreski. All rights reserved.
//

#import <Foundation/Foundation.h>
@import UIKit;

typedef void(^VoidCallback)(void);

NS_ASSUME_NONNULL_BEGIN

@interface Helpers : NSObject

+(NSString *)documentPath;
+(void)showPopup:(UIViewController *)controller title:(NSString *)title buttonName:(NSString *)buttonName cancelName:(NSString *)cancelName ok:(VoidCallback)ok cancel:(nullable VoidCallback)cancel;
+(void)shareData:(UIViewController *)controller logData:(NSArray *)arrData shared:(VoidCallback)shared;
@end

NS_ASSUME_NONNULL_END
