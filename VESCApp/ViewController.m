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
-(IBAction)onBtnRead:(UIButton *)sender{
    if (connectedPeripheral != nil) {
        [centralManager cancelPeripheralConnection:connectedPeripheral];
        connectedPeripheral = nil;
        [peripherals removeAllObjects];
        [sender setTitle:@"READ PEDALESS" forState:UIControlStateNormal];
    }
    else{
        [sender setTitle:@"DISCONNECT" forState:UIControlStateNormal];
        [peripherals removeAllObjects];
        [centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"FFE0"]] options:nil];
        [self performSelector:@selector(stopSearchReader) withObject:nil afterDelay:2];
    }
}

#pragma mark - CustomFunctions
-(void)presentData:(mc_values)dataVesc {
    lblTemperature.text = [NSString stringWithFormat:@"Temp Mosfet: %.2f degC\nTemp Motor: %.2f degC\nAMP Hours: %.4f Ah\nAMP Hours Regen: %.4f Ah",
                           dataVesc.temp_mos,
                           dataVesc.temp_motor,
                           dataVesc.amp_hours,
                           dataVesc.amp_hours_charged];
    lblCurrent.text = [NSString stringWithFormat:@"Current Input: %.2f A\nCurrent AVG: %.2f A", dataVesc.current_motor,dataVesc.current_in];
    lblWatts.text = [NSString stringWithFormat:@"Watt : %.4f Wh\nWatt Regen: %.4f Wh" ,dataVesc.watt_hours,dataVesc.watt_hours_charged];
    lblVoltage.text = [NSString stringWithFormat:@"Voltage: %.2f V",dataVesc.v_in];
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
    
    centralManager = [CBCentralManager.alloc initWithDelegate:self queue:nil];
    peripherals = NSMutableArray.new;
    vescController = VESC.new;
    
    manager = [CLLocationManager updateManagerWithAccuracy:50.0 locationAge:15.0 authorizationDesciption:CLLocationUpdateAuthorizationDescriptionAlways];
    [manager startUpdatingLocationWithUpdateBlock:^(CLLocationManager *manager, CLLocation *location, NSError *error, BOOL *stopUpdating) {
        
        double speedKMH = location.speed * 3.6;
        self->lblSpeed.text = [NSString stringWithFormat:@"%.f km/h",speedKMH > 0 ?: 0.0];
    }];
}
-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
