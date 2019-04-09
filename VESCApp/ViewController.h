//
//  ViewController.h
//  Pedaless
//
//  Created by Bosko Petreski on 4/19/18.
//  Copyright © 2018 Bosko Petreski. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VESC.h"

@import CoreBluetooth;

@interface ViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate>{
    VESC *vescController;
    
    CBCentralManager *centralManager;
    CBPeripheral *connectedPeripheral;
    NSMutableArray *peripherals;
    CBCharacteristic *txCharacteristic;
    CBCharacteristic *rxCharacteristic;
    
    IBOutlet UILabel *lblVoltage;
    IBOutlet UILabel *lblCurrent;
    IBOutlet UILabel *lblWatts;
    IBOutlet UILabel *lblTemperature;
}


@end

