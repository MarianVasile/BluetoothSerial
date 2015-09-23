//
//  BluetoothSerial.m
//  EADemo
//
//  Created by Matěj Kříž on 27.01.15.
//
// Edited by Guy Umbright, Krzysztof Pintscher on 07.07.2015
// Edited by Guy Umbright on 23.09.2015 - Guy is THE guy!
//

#import "BluetoothSerial.h"
#import <Cordova/CDV.h>

@interface EAAccessoryBluetooth : EAAccessory
@property(readonly, nonatomic) NSString *macAddress;
@end

@implementation BluetoothSerial

//This structure was set up for the Socket Mobile 7x(?) scanner, but it is being reused for
//the Model 6 as well.  They appear to have significantly differnt outputs.
//As mentioned above, the 7 outputs the following structure, the 6 outputs:
//
// One byte of total length
// 0xF30000nn - consistently with our scanner where nn = 0x03 or 0x0F (as we have seen) based on the bar code scanned
// ASCII data of length = header length - 5
//
// See fetchAvailableData: below for more
typedef struct
{
    uint8_t f1;
    uint8_t seq;
    uint8_t f2;
    uint8_t f3;

    uint8_t f4;
    uint8_t f4a;
    uint16_t f5;

    uint32_t f6;

    uint16_t lth;
    uint16_t f7;
    uint8_t f8;
    uint8_t data;
} RawScanData;

- (void)connect:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    NSString *deviceID = [command.arguments objectAtIndex:0];

    if (!_eaSessionController){
        _eaSessionController = [EADSessionController sharedController];
    }

    NSArray *accessories = [[EAAccessoryManager sharedAccessoryManager]
                            connectedAccessories];

    EAAccessoryBluetooth *accessory = nil;
    for (EAAccessoryBluetooth *obj in accessories) {
        if ([obj connectionID] == [deviceID integerValue]){
            accessory = obj;
            break;
        }
    }

    bool result = [_eaSessionController openSession:accessory];

    NSMutableDictionary *deviceDictionary = [[NSMutableDictionary alloc] init];

    [deviceDictionary setObject:accessory.name forKey:@"name"];
    [deviceDictionary setObject:accessory.macAddress forKey:@"macAddress"];
    [deviceDictionary setObject:[NSString stringWithFormat:@"%@",  @(accessory.connectionID)] forKey:@"id"];


    if(result){
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:deviceDictionary];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Device could not connect!"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)connectMac:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    NSString *deviceMac = [command.arguments objectAtIndex:0];

    if (!_eaSessionController){
        _eaSessionController = [EADSessionController sharedController];
    }

    NSArray *accessories = [[EAAccessoryManager sharedAccessoryManager]
                            connectedAccessories];

    EAAccessoryBluetooth *accessory = nil;
    for (EAAccessoryBluetooth *obj in accessories) {
        if ([[obj macAddress] isEqualToString:deviceMac]){
            accessory = obj;
            break;
        }
    }

    if (accessory == nil) {

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Device could not connect!"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    } else {

        bool result = [_eaSessionController openSession:accessory];

        NSMutableDictionary *deviceDictionary = [[NSMutableDictionary alloc] init];

        [deviceDictionary setObject:accessory.name forKey:@"name"];
        [deviceDictionary setObject:accessory.macAddress forKey:@"macAddress"];
        [deviceDictionary setObject:[NSString stringWithFormat:@"%@",  @(accessory.connectionID)] forKey:@"id"];


        if(result){
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:deviceDictionary];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Device could not connect!"];
        }

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void)disconnect:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    [self removeSubscription];
    [_eaSessionController closeSession];

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Device disconnected!"];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(NSMutableArray*)getList
{
    if (!_eaSessionController){
        _eaSessionController = [EADSessionController sharedController];
    }

    _accessoryList = [[NSMutableArray alloc] initWithArray:[[EAAccessoryManager sharedAccessoryManager] connectedAccessories]];
    NSLog(@"_accessoryList %@", _accessoryList);

    NSMutableArray *accessoryDictionary = [[NSMutableArray alloc] init];
    for (EAAccessoryBluetooth *device in _accessoryList) {
        if ([[device protocolStrings] containsObject:@"com.socketmobile.chs"]) {
            NSMutableDictionary *tmpDic=[[NSMutableDictionary alloc] init];
            [tmpDic setObject:device.name forKey:@"name"];
            [tmpDic setObject:device.macAddress forKey:@"macAddress"];
            [tmpDic setObject:[NSString stringWithFormat:@"%@",  @(device.connectionID)] forKey:@"id"];

            [accessoryDictionary addObject:tmpDic];
        }
    }
    return accessoryDictionary;
}

- (void)list:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:[self getList]];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)connectIOS:(CDVInvokedUrlCommand*)command
{
    if (!_eaSessionController){
        _eaSessionController = [EADSessionController sharedController];
    }

    [[EAAccessoryManager sharedAccessoryManager] showBluetoothAccessoryPickerWithNameFilter:nil completion:^(NSError *error) {
        [self.commandDelegate runInBackground:^{
            CDVPluginResult* pluginResult = nil;
            if (error) {
                NSLog(@"error :%@", error);
            }
            if(error != nil && [error code] == EABluetoothAccessoryPickerResultCancelled) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:@[]];
            } else {
                // connectedAccessories need some time to load protocolStrings properly
                usleep(3500000);
                NSMutableArray *accessoryDictionary  = [self getList];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:accessoryDictionary];

            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    }];
}

- (void)isEnabled:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    if (!_eaSessionController){
        _eaSessionController = [EADSessionController sharedController];
    }

    bool isEnabled = _eaSessionController?true:false;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:isEnabled];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)isConnected:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    if (!_eaSessionController){
        _eaSessionController = [EADSessionController sharedController];
    }

    bool connected = [_eaSessionController.session.accessory isConnected];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:connected];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)available:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    NSString* available = [NSString stringWithFormat: @"%lu", (unsigned long)[_eaSessionController readBytesAvailable]];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:available];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString*) fetchAvailableData
{
    NSData *data = [[NSData alloc] init];
    unsigned long bytesAvailable = 0;
    while ((bytesAvailable = [_eaSessionController readBytesAvailable]) > 0) {
        data = [_eaSessionController readData:bytesAvailable];
    }

    unsigned char *buffer;
    buffer = (unsigned char*)[data bytes];
    [data getBytes:buffer length:[data length]];

    if ([data length] > 0)
    {
        RawScanData* scanData = (RawScanData*) buffer;

        //As mentioned above, the two scanners produce different outputs.  We are differentiating the 6 & 7 by looking at
        //the contents of byte offset 1-4.  If it contains 0xF3000003 or 0xF300000F we assume it is output from a model 6 scanner
        //added: as the last byte of the header appears to be a bar code type indicator, lets not even bother with it as we need to go through the process again if another bar code type gets thrown in.
        NSString* currentData;
        if (scanData->seq == 0xF3 && scanData->f2 == 0x00 && scanData->f3 == 0x00)
        {
            int lth = scanData->f1 - 5;
            currentData = [[NSString alloc] initWithBytes:&scanData->f4a length:lth encoding:NSASCIIStringEncoding];
        }
        else
        {
            currentData = [[NSString alloc] initWithBytes:&scanData->data length:scanData->lth encoding:NSASCIIStringEncoding];
        }
        return currentData;
    } else {
        return nil;
    }
}

- (void)read:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

//     NSData *data = [[NSData alloc] init];
//     unsigned long bytesAvailable = 0;
//     while ((bytesAvailable = [_eaSessionController readBytesAvailable]) > 0) {
//         data = [_eaSessionController readData:bytesAvailable];
//     }
//
//     unsigned char *buffer;
//     buffer = (unsigned char*)[data bytes];
//     [data getBytes:buffer length:[data length]];
//
//     RawScanData* scanData = (RawScanData*) buffer;
//
//     NSString* message = [[NSString alloc] initWithBytes:&scanData->data length:scanData->lth encoding:NSASCIIStringEncoding];
	NSString* message = [self fetchAvailableData];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)readUntil:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"ReadUntil not implemented yet!"];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)write:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Write not implemented yet!"];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)listenToDevice:(CDVInvokedUrlCommand*)command
{
    _listenerCallbackId = [command.callbackId copy];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    [center addObserver:self
               selector:@selector(_accessoryDisconnected:)
                   name:EAAccessoryDidDisconnectNotification
               object:nil];

    [center addObserver:self
               selector:@selector(_accessoryConnected:)
                   name:EAAccessoryDidConnectNotification
                 object:nil];

    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
}

- (void) _accessoryDisconnected:(NSNotification*)notification {
    CDVPluginResult *pluginResult = nil;

    NSMutableDictionary *statusDictionary = [[NSMutableDictionary alloc] init];

    [self removeSubscription];
    [_eaSessionController closeSession];

    [statusDictionary setObject:[NSNumber numberWithBool:YES] forKey:@"disconnected"];

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:statusDictionary];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_listenerCallbackId];
}

- (void) _accessoryConnected:(NSNotification*)notification {
    CDVPluginResult *pluginResult = nil;

    NSMutableDictionary *statusDictionary = [[NSMutableDictionary alloc] init];

    [statusDictionary setObject:[NSNumber numberWithBool:YES] forKey:@"connected"];

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:statusDictionary];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_listenerCallbackId];
}


- (void)subscribe:(CDVInvokedUrlCommand*)command
{
    _subscribeCallbackId = [command.callbackId copy];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    _dataReceivedObserver = [center addObserverForName:@"EADSessionDataReceivedNotification" object:nil
                                                     queue:mainQueue usingBlock:^(NSNotification *note) {
                                                         [self sendDataToSubscriber];
                                                     }];
}


- (NSString*)readUntilDelimiter: (NSString*) delimiter {

    NSData *data = [[NSData alloc] init];
    unsigned long bytesAvailable = 0;
    if ((bytesAvailable = [_eaSessionController readBytesAvailable]) > 0) {
        data = [_eaSessionController readData:bytesAvailable];
    }

    unsigned char *buffer;
    buffer = (unsigned char*)[data bytes];
    [data getBytes:buffer length:[data length]];
    NSString* _buffer = [NSString stringWithFormat: @"%s", (char *)buffer];

    NSRange range = [_buffer rangeOfString: delimiter];
    NSString *message = @"";

    if (range.location != NSNotFound) {

        int end = range.location + range.length;
        message = [_buffer substringToIndex:end];
    }
    return message;
}

- (void) sendDataToSubscriber {

//    NSString *message = [self readUntilDelimiter:_delimiter];
	NSString* message = [self fetchAvailableData];

    if ([message length] > 0) {
        CDVPluginResult *pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: message];
        [pluginResult setKeepCallbackAsBool:TRUE];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_subscribeCallbackId];

        [self sendDataToSubscriber];
    }

}

- (void) removeSubscription {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:_dataReceivedObserver];
}

- (void)unsubscribe:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    [self removeSubscription];

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Unsubscribed!"];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)clear:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    [_eaSessionController clearData];

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Data cleared!"];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
