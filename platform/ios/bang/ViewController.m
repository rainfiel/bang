//
//  ViewController.m
//  example
//
//  Created by rainfiel on 15-2-14.
//  Copyright (c) 2015年 rainfiel. All rights reserved.
//

#import "ViewController.h"
#import "fw.h"
#import "liosutil.h"
#import "Constants.h"

#import <CoreBluetooth/CoreBluetooth.h>
#import <lua.h>
#import <lauxlib.h>

#define TIMER_PAUSE_INTERVAL 3.0
#define TIMER_SCAN_INTERVAL  1.0
#define SENSOR_TAG_NAME @"iTAG  "

static ViewController* _controller = nil;
static NSString *appFolderPath = nil;

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate> {
	int disableGesture;
}
@property (strong, nonatomic) EAGLContext *context;

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *sensorTag;
@property (nonatomic, assign) BOOL keepScanning;

@end

@implementation ViewController
- (id)init {
	_controller = [super init];
	super.preferredFramesPerSecond = 30;
	set_view_controller((__bridge void *)(_controller));
	return _controller;
}

-(void) loadView {
	CGRect bounds = [UIScreen mainScreen].bounds;
	self.view = [[GLKView alloc] initWithFrame:bounds];
}

+(ViewController*)getLastInstance{
	return _controller;
}

- (void)viewDidLoad {
   // Create the CBCentralManager.
   // NOTE: Creating the CBCentralManager with initWithDelegate will immediately call centralManagerDidUpdateState.
	self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];

	[super viewDidLoad];
	[self setGesture ];
	
	self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	
	if (!self.context) {
		NSLog(@"Failed to create ES context");
	}
	
	GLKView *view = (GLKView *)self.view;
	view.context = self.context;
	
	[EAGLContext setCurrentContext:self.context];
	
	CGFloat screenScale = [[UIScreen mainScreen] scale];
	CGRect bounds = [[UIScreen mainScreen] bounds];
	
	printf("screenScale: %f\n", screenScale);
	printf("bounds: x:%f y:%f w:%f h:%f\n",
     bounds.origin.x, bounds.origin.y,
     bounds.size.width, bounds.size.height);
	
	appFolderPath = [[NSBundle mainBundle] resourcePath];
	const char* folder = [appFolderPath UTF8String];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
	if([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0){
		screenScale = [[UIScreen mainScreen] nativeScale];
	}
#endif
	
	struct STARTUP_INFO* startup = (struct STARTUP_INFO*)malloc(sizeof(struct STARTUP_INFO));
	startup->folder = (char*)folder;
	startup->lua_root = NULL;
	startup->script = NULL;
	startup->orix = bounds.origin.x;
	startup->oriy = bounds.origin.y;
	startup->width = bounds.size.width;
	startup->height = bounds.size.height;
	startup->scale = screenScale;
	startup->reload_count = 0;
	startup->serialized = NULL;
	startup->user_data = NULL;
	ejoy2d_fw_init(startup);
}

-(void)viewDidUnload
{
	[super viewDidUnload];
	
	NSLog(@"viewDidUnload");
	
	//  lejoy_unload();
	
	if ([self isViewLoaded] && ([[self view] window] == nil)) {
		self.view = nil;
		
		if ([EAGLContext currentContext] == self.context) {
			[EAGLContext setCurrentContext:nil];
		}
		self.context = nil;
	}
}

-(BOOL)prefersStatusBarHidden
{
	return YES;
}

- (void)update
{
	ejoy2d_fw_update(self.timeSinceLastUpdate);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	ejoy2d_fw_frame();
}

- (void)dealloc
{
	//lejoy_exit();
	_controller = nil;
	if ([EAGLContext currentContext] == self.context) {
		[EAGLContext setCurrentContext:nil];
	}
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate {
	return YES;
}

- (void)viewDidLayoutSubviews {
	CGRect bounds = [[UIScreen mainScreen] bounds];
	
	
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
	float version = [[[UIDevice currentDevice] systemVersion] floatValue];
	if (version >= 8.0) {
		ejoy2d_fw_view_layout(1, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
		return;
	}
#endif
	
	UIDeviceOrientation ori = [[UIDevice currentDevice] orientation];
	if (ori == UIDeviceOrientationLandscapeLeft || ori == UIDeviceOrientationLandscapeRight) {
		ejoy2d_fw_view_layout(1, bounds.origin.x, bounds.origin.y, bounds.size.height, bounds.size.width);
	} else {
		ejoy2d_fw_view_layout(1, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
	}
}

//gesture
- (BOOL) gestureRecognizerShouldBegin:(UIGestureRecognizer *)gr {
	return (disableGesture == 0 ? YES : NO);
}

- (BOOL) gestureRecognizer:(UIGestureRecognizer *) gr shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *) ogr {
    return ejoy2d_fw_simul_gesture();
}

- (void) setGesture
{
	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
																 initWithTarget:self action:@selector(handlePan:)];
	pan.delegate = self;
	[[self view] addGestureRecognizer:pan];
	
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
																 initWithTarget:self action:@selector(handleTap:)];
	tap.delegate = self;
	[[self view] addGestureRecognizer:tap];
	
	UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc]
																		 initWithTarget:self action:@selector(handlePinch:)];
	pinch.delegate = self;
	[[self view] addGestureRecognizer:pinch];
	
	UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc]
																				 initWithTarget:self action:@selector(handleLongPress:)];
	press.delegate = self;
	[[self view] addGestureRecognizer:press];
}

static int
getStateCode(UIGestureRecognizerState state) {
	switch(state) {
		case UIGestureRecognizerStatePossible: return STATE_POSSIBLE;
		case UIGestureRecognizerStateBegan: return STATE_BEGAN;
		case UIGestureRecognizerStateChanged: return STATE_CHANGED;
		case UIGestureRecognizerStateEnded: return STATE_ENDED;
		case UIGestureRecognizerStateCancelled: return STATE_CANCELLED;
		case UIGestureRecognizerStateFailed: return STATE_FAILED;
			
			// recognized == ended
			// case UIGestureRecognizerStateRecognized: return STATE_RECOGNIZED;
			
		default: return STATE_POSSIBLE;
	}
}

- (void) handlePan:(UIPanGestureRecognizer *) gr {
	int state = getStateCode(gr.state);
	CGPoint trans = [gr translationInView:self.view];
	// CGPoint p = [gr locationInView:self.view];
	CGPoint v = [gr velocityInView:self.view];
	[gr setTranslation:CGPointMake(0,0) inView:self.view];
	ejoy2d_fw_gesture(1, trans.x, trans.y, v.x, v.y, state);
}

- (void) handleTap:(UITapGestureRecognizer *) gr {
	int state = getStateCode(gr.state);
	CGPoint p = [gr locationInView:self.view];
	ejoy2d_fw_gesture(2, p.x, p.y, 0, 0, state);
}

- (void) handlePinch:(UIPinchGestureRecognizer *) gr {
	int state = getStateCode(gr.state);
	CGPoint p = [gr locationInView:self.view];
	ejoy2d_fw_gesture(3, p.x, p.y, (gr.scale * 1024.0), 0.0, state);
	gr.scale = 1;
}

- (void) handleLongPress:(UILongPressGestureRecognizer *) gr {
	int state = getStateCode(gr.state);
	CGPoint p = [gr locationInView:self.view];
	ejoy2d_fw_gesture(4, p.x, p.y, 0, 0, state);
}


//touch
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	// UITouch *touch = [touches anyObject];
	for(UITouch *touch in touches) {
		CGPoint p = [touch locationInView:touch.view];
		disableGesture = ejoy2d_fw_touch(p.x, p.y, TOUCH_BEGIN,0);
	}
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	// UITouch *touch = [touches anyObject];
	for(UITouch *touch in touches) {
		CGPoint p = [touch locationInView:touch.view];
		ejoy2d_fw_touch(p.x, p.y, TOUCH_MOVE,0);
	}
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	// UITouch *touch = [touches anyObject];
	for(UITouch *touch in touches) {
		CGPoint p = [touch locationInView:touch.view];
		ejoy2d_fw_touch(p.x, p.y, TOUCH_END,0);
	}
}



#pragma mark - CBCentralManagerDelegate methods

- (void)pauseScan {
    // Scanning uses up battery on phone, so pause the scan process for the designated interval.
    NSLog(@"*** PAUSING SCAN...");
    [NSTimer scheduledTimerWithTimeInterval:TIMER_PAUSE_INTERVAL target:self selector:@selector(resumeScan) userInfo:nil repeats:NO];
    [self.centralManager stopScan];
}

- (void)resumeScan {
    if (self.keepScanning) {
        // Start scanning again...
        NSLog(@"*** RESUMING SCAN!");
        [NSTimer scheduledTimerWithTimeInterval:TIMER_SCAN_INTERVAL target:self selector:@selector(pauseScan) userInfo:nil repeats:NO];
        [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerRestoredStateScanOptionsKey:@(YES)}];    }
}

- (void)cleanup {
    [_centralManager cancelPeripheralConnection:self.sensorTag];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    BOOL showAlert = YES;
    NSString *state = @"";
    switch ([central state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"This device does not support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"This app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth on this device is currently powered off.";
            break;
        case CBCentralManagerStateResetting:
            state = @"The BLE Manager is resetting; a state update is pending.";
            break;
        case CBCentralManagerStatePoweredOn:
            showAlert = NO;
            state = @"Bluetooth LE is turned on and ready for communication.";
            NSLog(@"%@", state);
            self.keepScanning = YES;
            [NSTimer scheduledTimerWithTimeInterval:TIMER_SCAN_INTERVAL target:self selector:@selector(pauseScan) userInfo:nil repeats:NO];
            [self.centralManager scanForPeripheralsWithServices:nil options:nil];
            break;
        case CBCentralManagerStateUnknown:
            state = @"The state of the BLE Manager is unknown.";
            break;
        default:
            state = @"The state of the BLE Manager is unknown.";
    }
    
    if (showAlert) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Central Manager State" message:state preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
        [ac addAction:okAction];
        [self presentViewController:ac animated:YES completion:nil];
    }
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    // Retrieve the peripheral name from the advertisement data using the "kCBAdvDataLocalName" key
    NSString *peripheralName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    NSLog(@"NEXT PERIPHERAL: %@ %@ (%@) %@", peripheralName, peripheral.name, peripheral.identifier.UUIDString, RSSI);
    //NSLog(@"NEXT PERIPHERAL: %@ (%@)", peripheral.name, peripheral.identifier.UUIDString);
    if (peripheralName) {
        if ([peripheralName isEqualToString:SENSOR_TAG_NAME]) {
          NSLog(@".........................connect");
            self.keepScanning = NO;
            
            // save a reference to the sensor tag
            self.sensorTag = peripheral;
            self.sensorTag.delegate = self;
            
            // Request a connection to the peripheral
            [self.centralManager connectPeripheral:self.sensorTag options:nil];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"**** SUCCESSFULLY CONNECTED TO SENSOR TAG!!!");
    // Now that we've successfully connected to the SensorTag, let's discover the services.
    // - NOTE:  we pass nil here to request ALL services be discovered.
    //          If there was a subset of services we were interested in, we could pass the UUIDs here.
    //          Doing so saves batter life and saves time.
    ejoy2d_fw_message(-2, "connect", nil, 0);
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"**** CONNECTION FAILED!!!");
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"**** DISCONNECTED FROM SENSOR TAG!!!");
}


#pragma mark - CBPeripheralDelegate methods

// When the specified services are discovered, the peripheral calls the peripheral:didDiscoverServices: method of its delegate object.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    // Core Bluetooth creates an array of CBService objects —- one for each service that is discovered on the peripheral.
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service: %@ %@", service, service.UUID);
        if (([service.UUID isEqual:[CBUUID UUIDWithString:FIND_ME_SERVICE]])) {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics) {
        uint8_t enableValue = 1;
        NSData *enableBytes = [NSData dataWithBytes:&enableValue length:sizeof(uint8_t)];
      
      	NSLog(@"char UUID:%@", characteristic.UUID);

        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FIND_ME_CHARACTERISTIC]]) {
            [self.sensorTag setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error changing notification state: %@", [error localizedDescription]);
    } else {
      
      if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FIND_ME_CHARACTERISTIC]]) {
      	NSLog(@"bang:%@", characteristic.UUID);
        char* uuid = [characteristic.UUID.UUIDString UTF8String];
     	 	ejoy2d_fw_message(-2, "click", uuid, 0);
      }

      
        // extract the data from the characteristic's value property and display the value based on the characteristic type
        //NSData *dataBytes = characteristic.value;
        // if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:UUID_TEMPERATURE_DATA]]) {
        //     [self displayTemperature:dataBytes];
        // } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:UUID_HUMIDITY_DATA]]) {
        //     [self displayHumidity:dataBytes];
        // }
    }
}
@end
