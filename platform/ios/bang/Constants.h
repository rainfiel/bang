//
//  Constants.h
//  BLETemperatureReader
//
//  Created by Evan Stone on 8/7/15.
//  Copyright (c) 2015 Cloud City. All rights reserved.
//

#ifndef BLETemperatureReader_Constants_h
#define BLETemperatureReader_Constants_h

//------------------------------------------------------------------------
// Information about Texas Instruments SensorTag UUIDs can be found at:
// http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#Sensors
//------------------------------------------------------------------------
// Per the TI documentation:
//  The TI Base 128-bit UUID is: F0000000-0451-4000-B000-000000000000.
//
//  All sensor services use 128-bit UUIDs, but for practical reasons only
//  the 16-bit part is listed in this document.
//
//  It is embedded in the 128-bit UUID as shown by example below.
//
//          Base 128-bit UUID:  F0000000-0451-4000-B000-000000000000
//          "0xAA01" maps as:   F000AA01-0451-4000-B000-000000000000
//                                  ^--^
//------------------------------------------------------------------------

#define IMMEDIATE_ALERT_SERVICE @"00001802-0000-1000-8000-00805f9b34fb"
#define FIND_ME_SERVICE @"0000ffe0-0000-1000-8000-00805f9b34fb"
#define LINK_LOSS_SERVICE @"00001803-0000-1000-8000-00805f9b34fb"
#define BATTERY_SERVICE @"0000180f-0000-1000-8000-00805f9b34fb"

#define CLIENT_CHARACTERISTIC_CONFIG @"00002902-0000-1000-8000-00805f9b34fb"
#define ALERT_LEVEL_CHARACTERISTIC @"00002a06-0000-1000-8000-00805f9b34fb"
#define FIND_ME_CHARACTERISTIC @"0000ffe1-0000-1000-8000-00805f9b34fb"

#endif
