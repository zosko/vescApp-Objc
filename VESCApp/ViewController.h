//
//  ViewController.h
//  VESCApp
//
//  Created by Bosko Petreski on 4/19/18.
//  Copyright © 2018 Bosko Petreski. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VescController.h"

@import CoreBluetooth;

@interface ViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate>{
    VescController *aVescController;
    
    CBCentralManager *_centralManager;
    CBPeripheral *_peripheral;
    NSMutableArray *_peripherals;
    CBCharacteristic *txCharacteristic;
    CBCharacteristic *rxCharacteristic;
    
    IBOutlet UILabel *lblVoltage;
    IBOutlet UILabel *lblCurrent;
    IBOutlet UILabel *lblTemperature;
}


@end

