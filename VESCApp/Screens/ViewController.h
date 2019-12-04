//
//  ViewController.h
//  Pedaless
//
//  Created by Bosko Petreski on 4/19/18.
//  Copyright © 2018 Bosko Petreski. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VESC.h"

#define LOG_DATA 0

@import CoreBluetooth;

@interface ViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate,UICollectionViewDelegate,UICollectionViewDataSource>{
    VESC *vescController;
    
    CBCentralManager *centralManager;
    CBPeripheral *connectedPeripheral;
    NSMutableArray *peripherals;
    CBCharacteristic *txCharacteristic;
    CBCharacteristicWriteType writeType;
    
    NSArray *arrPedalessData;
    IBOutlet UICollectionView *colPedalessData;
    IBOutlet UIButton *btnConnect;
}


@end

