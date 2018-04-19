//
//  ViewController.m
//  VESCApp
//
//  Created by Bosko Petreski on 4/19/18.
//  Copyright © 2018 Bosko Petreski. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

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
    if (![_peripherals containsObject:peripheral]) {
        [_peripherals addObject:peripheral];
    }
}
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected");
    _peripheral = peripheral;
    txCharacteristic = nil;
    rxCharacteristic = nil;
    
    [_peripheral setDelegate:self];
    [_peripheral discoverServices:nil];
}
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (error != nil) {
        NSLog(@"Error connect: %@",error.description);
    }
}
-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (error != nil) {
        NSLog(@"Error disconnect: %@",error.description);
    } else {
        [aVescController resetPacket];
        NSLog(@"Information: The reader is disconnected successfully.");
    }
}
-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{
    if (error) {
        NSLog(@"Error receiving didWriteValueForCharacteristic %@: %@", characteristic, error);
        return;
    }
    NSLog(@"didWriteValueForCharacteristic");
}
-(void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral{
    NSLog(@"peripheralIsReadyToSendWriteWithoutResponse");
}
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error receiving notification for characteristic %@: %@", characteristic, error);
        return;
    }
    NSLog(@"didUpdateValueForCharacteristic");
    if ([aVescController process_incoming_bytes:characteristic.value] > 0) {
        struct bldcMeasure values = [aVescController ProcessReadPacket];
        
        NSData *myData = [NSData dataWithBytes:&values length:sizeof(values)];
        [self logData: myData];
        if (values.fault_code == FAULT_CODE_NO_DATA) {
            NSLog(@"Error");
        } else {
            NSLog(@"RPM: %ld", values.rpm);
        }
    }
}
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service: %@", service.UUID);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}
-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error{
    if (error) {
        NSLog(@"Error receiving didUpdateNotificationStateForCharacteristic %@: %@", characteristic, error);
        return;
    }
    NSLog(@"didUpdateNotificationStateForCharacteristic");
}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    
    NSLog(@"Discovered UART service characteristics");
    
    for (CBCharacteristic *aChar in service.characteristics) {
        NSLog(@"Char %@", aChar);
        
        // BAUD BleMini   57600
        //TX BleMini:    713D0003-503E-4C75-BA94-3148F18D941E
        //RX BleMini:    713D0002-503E-4C75-BA94-3148F18D941E
        
        if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"713D0003-503E-4C75-BA94-3148F18D941E"]]) {
            NSLog(@"Found TX service: %@",aChar);
            txCharacteristic = aChar;
            if (rxCharacteristic != nil){
                [self performSelector:@selector(doGetValues) withObject:nil afterDelay:0.3];
            }
        }
        if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"713D0002-503E-4C75-BA94-3148F18D941E"]]) {
            NSLog(@"Found RX service: %@",aChar);
            rxCharacteristic = aChar;
            [_peripheral setNotifyValue:YES forCharacteristic:rxCharacteristic];

            if (txCharacteristic != nil){
                [self performSelector:@selector(doGetValues) withObject:nil afterDelay:0.3];
            }
        }
    }
    
//    NSLog(@"Discovered Device Info");
//    for (CBCharacteristic *aChar in service.characteristics){
//        NSLog(@"Found device service: %@", aChar.UUID);
//        [_peripheral readValueForCharacteristic:aChar];
//    }
}

#pragma mark - IBActions
-(IBAction)onBtnRead:(UIButton *)sender{
    if (_peripheral != nil) {
        [_centralManager cancelPeripheralConnection:_peripheral];
        _peripheral = nil;
    }
    [_peripherals removeAllObjects];
    [_centralManager scanForPeripheralsWithServices:nil options:nil];
    
    [self performSelector:@selector(stopSearchReader) withObject:nil afterDelay:2];
}

#pragma mark - CustomFunctions
-(void)logData:(NSData *)theData {
    struct bldcMeasure thisData;
    
    [theData getBytes:&thisData length:sizeof(thisData)];
    
    lblTemperature.text = [NSString stringWithFormat:@"Temp Mosfet 1: %1.fC\nTemp Mosfet 2: %1.fC\nTemp Mosfet 3: %1.fC\nTemp Mosfet 4: %1.fC\nTemp Mosfet 5: %1.fC\nTemp Mosfet 6: %1.fC\nTemp PCB: %1.fC",
                           thisData.temp_mos1,
                           thisData.temp_mos2,
                           thisData.temp_mos3,
                           thisData.temp_mos4,
                           thisData.temp_mos5,
                           thisData.temp_mos6,
                           thisData.temp_pcb];
    lblCurrent.text = [NSString stringWithFormat:@"Current Input: %1.fA\nCurrent AVG: %1.fA",thisData.avgInputCurrent,thisData.avgMotorCurrent];
    lblVoltage.text = [NSString stringWithFormat:@"Voltage: %.1fv",thisData.inpVoltage];
}

-(void)stopSearchReader{
    [_centralManager stopScan];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Readers" message:@"Choose reader" preferredStyle:UIAlertControllerStyleAlert];
    for(CBPeripheral *periperal in _peripherals){
        UIAlertAction *action = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@",periperal.name] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self->_centralManager connectPeripheral:periperal options:nil];
        }];
        [alert addAction:action];
    }
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    }];
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
}
-(void)doGetValues {
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSLog(@"Get Values");
        self->lblTemperature.text = self->lblCurrent.text = self->lblVoltage.text = @"";
        NSData *dataToSend = [self->aVescController dataForGetValues:COMM_GET_VALUES val:0];
        [self->_peripheral writeValue:dataToSend forCharacteristic:self->txCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }];
}

#pragma mark - UIViewDelegates
-(void)viewDidLoad {
    [super viewDidLoad];
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _peripherals = [NSMutableArray array];
    aVescController = [[VescController alloc] init];
    [aVescController dataForGetValues:0 val:0];
}
-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
