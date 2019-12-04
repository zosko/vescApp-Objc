//
//  ViewController.m
//  Pedaless
//
//  Created by Bosko Petreski on 4/19/18.
//  Copyright © 2018 Bosko Petreski. All rights reserved.
//

#import "ViewController.h"
#import "CLLocationManager+blocks.h"
#import "DataCell.h"
#import "Helpers.h"

@interface ViewController (){
    CLLocationManager *manager;
    NSMutableArray *arrLogger;
    NSInteger secondStarted;
    NSTimer *timerValues;
}

@end

@implementation ViewController

#pragma mark - CentralManager
-(void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSString *message = @"Bluetooth";
    switch (central.state) {
        case CBManagerStateUnknown: message = @"Bluetooth Unknown."; break;
        case CBManagerStateResetting: message = @"The update is being started. Please wait until Bluetooth is ready."; break;
        case CBManagerStateUnsupported: message = @"This device does not support Bluetooth low energy."; break;
        case CBManagerStateUnauthorized: message = @"This app is not authorized to use Bluetooth low energy."; break;
        case CBManagerStatePoweredOff: message = @"You must turn on Bluetooth in Settings in order to use the reader."; break;
        default: break;
    }
    NSLog(@"Bluetooth: %@",message);
}
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    if (![peripherals containsObject:peripheral]) {
        [peripherals addObject:peripheral];
    }
}
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    connectedPeripheral = peripheral;
    txCharacteristic = nil;
    
    [connectedPeripheral setDelegate:self];
    [connectedPeripheral discoverServices:nil];
}
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (error != nil) {
        NSLog(@"Error connect: %@",error.description);
    }
}
-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (error != nil) {
        NSLog(@"Error disconnect: %@",error.description);
    }
    else {
        [vescController resetPacket];
    }
}
-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{
    if (error) {
        NSLog(@"Error receiving didWriteValueForCharacteristic %@: %@", characteristic, error);
        return;
    }
}
-(void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral{
    NSLog(@"peripheralIsReadyToSendWriteWithoutResponse");
}
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error receiving notification for characteristic %@: %@", characteristic, error);
        return;
    }
    if ([vescController process_incoming_bytes:characteristic.value] > 0) {
        [self presentData:vescController.readPacket];
    }
}
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:@"FFE1"]] forService:service];
    }
}
-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{
    if (error) {
        NSLog(@"Error receiving didUpdateNotificationStateForCharacteristic %@: %@", characteristic, error);
        return;
    }
}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    
    // http://www.hangar42.nl/hm10
    // BAUD HM-10    115200   //Flashed here http://www.hangar42.nl/ccloader
    // The HM10 has one service, 0xFFE0, which has one characteristic, 0xFFE1 (these UUIDs can be changed with AT commands by the way)
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"FFE1"]]) {
            
            txCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            
            writeType = characteristic.properties == CBCharacteristicPropertyWrite ? CBCharacteristicWriteWithResponse : CBCharacteristicWriteWithoutResponse;
            [self performSelector:@selector(doGetValues) withObject:nil afterDelay:0.3];
        }
    }
}

#pragma mark - IBActions
-(IBAction)onBtnConnect:(UIButton *)sender{
    if (connectedPeripheral != nil) {
        
        [Helpers showPopup:self title:@"Are you sure ?" buttonName:@"Dissconnect" cancelName:@"No" ok:^{
           [self->arrLogger writeToFile:Helpers.documentPath atomically:YES];
            
            [self->timerValues invalidate]; self->timerValues = nil;
            [self->centralManager cancelPeripheralConnection:self->connectedPeripheral];
            self->connectedPeripheral = nil;
            [self->peripherals removeAllObjects];
            [sender setTitle:@"Connect" forState:UIControlStateNormal];
            
            [Helpers showPopup:self title:@"Do you want to share data?" buttonName:@"Yes" cancelName:@"No" ok:^{
                [Helpers shareData:self logData:self->arrLogger shared:^{
                   self->arrLogger = NSMutableArray.new;
                    self->secondStarted = 0;
                    [self->arrLogger writeToFile:Helpers.documentPath atomically:YES];
                }];
            } cancel:nil];
        } cancel:nil];
    }
    else{
        [sender setTitle:@"Disconnect" forState:UIControlStateNormal];
        [peripherals removeAllObjects];
        [centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"FFE0"]] options:nil];
        [self performSelector:@selector(stopSearchReader) withObject:nil afterDelay:2];
    }
}

#pragma mark - CustomFunctions
-(void)presentData:(mc_values)dataVesc {
    double wheelDiameter = 700; //mm diameter
    double motorDiameter = 63; //mm diameter
    double gearRatio = motorDiameter / wheelDiameter;
    double motorPoles = 14;
    
    double ratioRpmSpeed = (gearRatio * 60 * wheelDiameter * M_PI) / ((motorPoles / 2) * 1000000); // ERPM to Km/h
    double ratioPulseDistance = (gearRatio * wheelDiameter * M_PI) / ((motorPoles * 3) * 1000000); // Pulses to km travelled

    double speed = dataVesc.rpm * ratioRpmSpeed;
    double distance = dataVesc.tachometer_abs * ratioPulseDistance;
    double power = dataVesc.current_in * dataVesc.v_in;

    NSInteger h = secondStarted / 3600;
    NSInteger m = (secondStarted / 60) % 60;
    NSInteger s = secondStarted % 60;
    
    arrPedalessData = @[@{@"title":@"Temp",@"data":[NSString stringWithFormat:@"%.2f degC",dataVesc.temp_mos]},
                        @{@"title":@"Amp hours",@"data":[NSString stringWithFormat:@"%.4f Ah",dataVesc.amp_hours]},
                        @{@"title":@"Current Motor",@"data":[NSString stringWithFormat:@"%.2f A",dataVesc.current_motor]},
                        @{@"title":@"Current Batt",@"data":[NSString stringWithFormat:@"%.2f A",dataVesc.current_in]},
                        @{@"title":@"Watts",@"data":[NSString stringWithFormat:@"%.4f Wh" ,dataVesc.watt_hours]},
                        @{@"title":@"Voltage",@"data":[NSString stringWithFormat:@"%.2f V",dataVesc.v_in]},
                        @{@"title":@"Fault Code",@"data":@[@"NONE",@"OVER VOLTAGE",@"UNDER VOLTAGE",@"DRV",@"ABS OVER CURRENT",@"OVER TEMP FET",@"OVER TEMP MOTOR"][dataVesc.fault_code]},
                        @{@"title":@"Distance",@"data":[NSString stringWithFormat:@"%.2f km", distance]},
                        @{@"title":@"Speed",@"data":[NSString stringWithFormat:@"%.1f km/h",speed]},
                        @{@"title":@"Power",@"data":[NSString stringWithFormat:@"%.f W",power]},
                        @{@"title":@"Drive time",@"data":[NSString stringWithFormat:@"%ld:%02ld:%02ld", h, m, s]}
    ];
    
    [colPedalessData reloadData];
    
    if(dataVesc.current_motor > 0){
       secondStarted++;
    }
    
    if(LOG_DATA){
        [arrLogger addObject:@{@"timestamp":@(NSDate.date.timeIntervalSince1970),
                               @"v_in":@(dataVesc.v_in),
                               @"temp_mos":@(dataVesc.temp_mos),
                               @"current_motor":@(dataVesc.current_motor),
                               @"current_in":@(dataVesc.current_in),
                               @"rpm":@(dataVesc.rpm),
                               @"duty":@(dataVesc.duty_now * 1000),
                               @"amp_hours":@(dataVesc.amp_hours),
                               @"watt_hours":@(dataVesc.watt_hours),
                               @"tachometer":@(dataVesc.tachometer),
                               @"tachometer_abs":@(dataVesc.tachometer_abs),
                               @"mc_fault_code":@(dataVesc.fault_code),
                               @"latitude":@(manager.location.coordinate.latitude),
                               @"longitude":@(manager.location.coordinate.longitude),
                               @"speed":@(speed),
                               @"distance":@(distance),
                               @"drive_time":@(secondStarted)
                               }];
    }
}

-(void)stopSearchReader{
    [centralManager stopScan];
        
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Search device" message:@"Choose Pedaless device" preferredStyle:UIAlertControllerStyleActionSheet];
    for(CBPeripheral *periperal in peripherals){
        UIAlertAction *action = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@",periperal.name] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self->centralManager connectPeripheral:periperal options:nil];
        }];
        [alert addAction:action];
    }
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self->btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
    }];
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
}
-(void)doGetValues {
    timerValues = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSData *dataToGet = self->vescController.dataForGetValues;
        [self->connectedPeripheral writeValue:dataToGet forCharacteristic:self->txCharacteristic type:self->writeType];
    }];
}

#pragma mark - CollectionView
-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return arrPedalessData.count;
}
-(__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *cellIdentifier = @"DataCell";
    DataCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    
    NSDictionary *dictData = arrPedalessData[indexPath.row];
    
    cell.lblData.text = dictData[@"data"];
    cell.lblTitle.text = dictData[@"title"];
    
    cell.layer.borderColor = UIColor.lightGrayColor.CGColor;
    cell.layer.borderWidth = 2;
    
    return cell;
}

#pragma mark - UIViewDelegates
-(void)viewDidLoad {
    [super viewDidLoad];
    
    NSArray *dataLogs = [NSArray arrayWithContentsOfFile:Helpers.documentPath];
    arrLogger = dataLogs ? [NSMutableArray arrayWithArray:dataLogs] : NSMutableArray.new;
    
    centralManager = [CBCentralManager.alloc initWithDelegate:self queue:nil];
    peripherals = NSMutableArray.new;
    vescController = VESC.new;
    
    manager = [CLLocationManager updateManagerWithAccuracy:50.0 locationAge:15.0 authorizationDesciption:CLLocationUpdateAuthorizationDescriptionAlways];
    [manager startUpdatingLocationWithUpdateBlock:^(CLLocationManager *manager, CLLocation *location, NSError *error, BOOL *stopUpdating) {
        
    }];
}
-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
