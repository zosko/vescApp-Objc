//
//  ViewController.m
//  Pedaless
//
//  Created by Bosko Petreski on 4/19/18.
//  Copyright © 2018 Bosko Petreski. All rights reserved.
//

#import "ViewController.h"
#import "CLLocationManager+blocks.h"

@interface ViewController (){
    CLLocationManager *manager;
    NSMutableArray *arrLogger;
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
    //NSLog(@"peripheralIsReadyToSendWriteWithoutResponse");
}
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error receiving notification for characteristic %@: %@", characteristic, error);
        return;
    }
    if ([vescController process_incoming_bytes:characteristic.value] > 0) {
        [self presentData:[vescController readPacket]];
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
-(IBAction)onBtnShare:(UIButton *)sender{
    NSData *dataJSON = [NSJSONSerialization dataWithJSONObject:arrLogger options:0 error:nil];
    
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingString:@"JSON.txt"]];
    NSString *strLog = [NSString.alloc initWithData:dataJSON encoding:NSUTF8StringEncoding];
    [strLog writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[@"JSON",url] applicationActivities:nil];
    [self presentViewController:activityViewController animated:YES completion:nil];
    [activityViewController setCompletionWithItemsHandler:^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
       
        self->arrLogger = NSMutableArray.new;
        [self->arrLogger writeToFile:self.documentPath atomically:YES];
    }];
}
-(IBAction)onBtnRead:(UIButton *)sender{
    if (connectedPeripheral != nil) {
        [centralManager cancelPeripheralConnection:connectedPeripheral];
        connectedPeripheral = nil;
        [peripherals removeAllObjects];
        [sender setTitle:@"READ PEDALESS" forState:UIControlStateNormal];
    }
    else{
        [arrLogger writeToFile:self.documentPath atomically:YES];
        
        [sender setTitle:@"DISCONNECT" forState:UIControlStateNormal];
        [peripherals removeAllObjects];
        [centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"FFE0"]] options:nil];
        [self performSelector:@selector(stopSearchReader) withObject:nil afterDelay:2];
    }
}

#pragma mark - CustomFunctions
-(NSString *)documentPath{
    NSString *directory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *plistPath = [directory stringByAppendingPathComponent:@"DataLog.plist"];
    return plistPath;
}
-(void)presentData:(mc_values)dataVesc {
    lblTemperature.text = [NSString stringWithFormat:@"Temp Mosfet: %.2f degC\nAMP Hours: %.4f Ah",
                           dataVesc.temp_mos,dataVesc.amp_hours];
    lblCurrent.text = [NSString stringWithFormat:@"Current Motor: %.2f A\nCurrent In: %.2f A", dataVesc.current_motor,dataVesc.current_in];
    lblWatts.text = [NSString stringWithFormat:@"Watt : %.4f Wh" ,dataVesc.watt_hours];
    lblVoltage.text = [NSString stringWithFormat:@"Voltage: %.2f V",dataVesc.v_in];
    lblFaultyCode.text = @[@"NONE",@"OVER VOLTAGE",@"UNDER VOLTAGE",@"DRV",@"ABS OVER CURRENT",@"OVER TEMP FET",@"OVER TEMP MOTOR"][dataVesc.fault_code];
    
    [arrLogger addObject:@{@"timestamp":@(NSDate.date.timeIntervalSince1970),
                           @"v_in":@(dataVesc.v_in),
                           @"temp_mos":@(dataVesc.temp_mos),
                           @"current_motor":@(dataVesc.current_motor),
                           @"current_in":@(dataVesc.current_in),
                           @"rpm":@(dataVesc.rpm),
                           @"amp_hours":@(dataVesc.amp_hours),
                           @"watt_hours":@(dataVesc.watt_hours),
                           @"tachometer":@(dataVesc.tachometer),
                           @"tachometer_abs":@(dataVesc.tachometer_abs),
                           @"mc_fault_code":@(dataVesc.fault_code),
                           @"latitude":@(manager.location.coordinate.latitude),
                           @"longitude":@(manager.location.coordinate.longitude),
                           @"speed":@(manager.location.speed * 3.6)
                           }];
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
    }];
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
}
-(void)doGetValues {
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSData *dataToSend = self->vescController.dataForGetValues;
        [self->connectedPeripheral writeValue:dataToSend forCharacteristic:self->txCharacteristic type:self->writeType];
    }];
}

#pragma mark - UIViewDelegates
-(void)viewDidLoad {
    [super viewDidLoad];
    
    NSArray *dataLogs = [NSArray arrayWithContentsOfFile:self.documentPath];
    arrLogger = dataLogs ? [NSMutableArray arrayWithArray:dataLogs] : NSMutableArray.new;
    
    centralManager = [CBCentralManager.alloc initWithDelegate:self queue:nil];
    peripherals = NSMutableArray.new;
    vescController = VESC.new;
    
    manager = [CLLocationManager updateManagerWithAccuracy:50.0 locationAge:15.0 authorizationDesciption:CLLocationUpdateAuthorizationDescriptionAlways];
    __block CLLocation *oldLocation = nil;
    __block double distance = 0;
    [manager startUpdatingLocationWithUpdateBlock:^(CLLocationManager *manager, CLLocation *location, NSError *error, BOOL *stopUpdating) {
        
        if(oldLocation != nil){
            distance += [location distanceFromLocation:oldLocation] / 1000;
            self->lblDistance.text = [NSString stringWithFormat:@"Distance: %.1f km", distance];
        }
        oldLocation = location;
        double speedKMH = location.speed * 3.6;
        self->lblSpeed.text = [NSString stringWithFormat:@"%.1f km/h",speedKMH];
    }];
}
-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
