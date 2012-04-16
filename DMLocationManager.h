//
// Copyright devmob (Martin Stolz) | devmob.de
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

/**
 * The DMLocationManager is a convinience wrapper for the CLLocationManager.
 * It accepts multiple delegate instances at one time.
 *
 *		DMLocationManager* locationManager = [DMLocationManager sharedLocationManager];
 *		[locationManager addDelegate:self];
 *		[locationManager removeDelegate:self];
 *
 * To avoid bad accuracy of location the property 'queryingInterval' defines how long to search for a location with the desired accuracy.
 *
 *		DMLocationManager* locationManager = [DMLocationManager sharedLocationManager];
 *		locationManager.desiredAccuracy	   = kCLLocationAccuracyNearestTenMeters
 *		locationManager.queryingInterval   = 10.0;
 *
 * To avoid getting cached location coordinates deactivate it by setting NO to 'useCache' property.
 *
 *		DMLocationManager* locationManager = [DMLocationManager sharedLocationManager];
 *		locationManager.useCache		   = NO;
 *
 * The 'cacheAge' defines how old a location is allowed to be.
 *
 *		DMLocationManager* locationManager = [DMLocationManager sharedLocationManager];
 *		locationManager.cacheAge	   = 10.0;
 *
 * If nessecary the property 'updateLocationOnApplicationDidBecomeActive' can be used to allow the update of the location on application (re-)start.
 *
 *		DMLocationManager* locationManager							= [DMLocationManager sharedLocationManager];
 *		locationManager.updateLocationOnApplicationDidBecomeActive	= YES;
 *
 * To keep the location permanent up to date the property 'loop' defines whether to repeadeatly determine new location coordinates.
 * The property 'loopTimeInterval' defines how long to sleep between determining the location successfully and beginning the next determination.
 *
 *		DMLocationManager* locationManager = [DMLocationManager sharedLocationManager];
 *		locationManager.loop			   = YES;
 *		locationManager.loopTimeInterval   = 10.0;
 *
 *
 *
 * How it works:
 *
 * Use location manager singleton instance:
 *
 *		DMLocationManager* locationManager = [DMLocationManager sharedLocationManager];
 *
 * Listen for changes by setting delegate instance:
 *
 *		[locationManager addDelegate:self];
 *
 * Make listening instance optionally conform to DMLocationManagerDelegate:
 *
 *		- (void)locationManager:(DMLocationManager*)manager didChangeLocationServiceEnabledState:(BOOL)isLocationServiceEnabled {
 *		}
 *
 *		- (void)locationManagerWillUpdateLocation:(DMLocationManager*)manager {
 *		}
 *
 *		- (void)locationManagerDidStopUpdateLocation:(DMLocationManager*)manager {
 *		}
 *      
 *      - (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
 *      }
 *
 * Start determine location:
 *
 *		[locationManager startUpdatingLocation];
 *
 * Stop determine location on leaving a view e.g.:
 *
 *		[locationManager stopUpdatingLocation];
 *
 * Stop listening for location changes:
 *
 *		[locationManager removeDelegate:self];
 *
 * Activate logging by setting the log level define e.g.:
 *
 *		#define DM_LOCATION_MANAGER_LOG_LEVEL	DM_LOCATION_MANAGER_LOG_LEVEL_INFO
 */

@protocol DMLocationManagerDelegate;


#pragma mark -
#pragma mark DMLocationManager

#define	DM_LOCATION_MANAGER_LOG_LEVEL_NONE		0
#define	DM_LOCATION_MANAGER_LOG_LEVEL_INFO		1
#define	DM_LOCATION_MANAGER_LOG_LEVEL_WARNING	2
#define	DM_LOCATION_MANAGER_LOG_LEVEL_ERROR		3
#define	DM_LOCATION_MANAGER_LOG_LEVEL_DEBUG		4

#define DM_LOCATION_MANAGER_LOG_LEVEL			DM_LOCATION_MANAGER_LOG_LEVEL_INFO

@interface DMLocationManager : NSObject <CLLocationManagerDelegate>
{
@private
	NSMutableArray*		_delegates;			// Delegate instances which must be served
	
	CLLocationManager*	_locationManager;	// Shared location manager instance
	CLLocation*			_location;
	BOOL				_useCache;
	NSTimeInterval		_cacheAge;
	BOOL				_isLocationServiceEnabled;
	
	BOOL				_updateLocationOnApplicationDidBecomeActive;
	
	BOOL				_loop;
	NSTimeInterval		_loopTimeInterval;
	NSTimer*			_loopTimer;			// Restart searching of new locations after one was found
	
	NSTimeInterval		_queryingInterval;
	NSTimer*			_queryingTimer;		// On timeout the updating of location will be stopped
}

/**
 * Last determined location by location manager. If nil the location was or could not be updated.
 */
@property (nonatomic, retain, readonly) CLLocation*						location;

/**
 * The accuracy which should be aimed. If the accuracy is the desired one, the updating process will be stopped before the query time is reached.
 * Default is -1.
 */
@property (nonatomic, assign)			CLLocationAccuracy				desiredAccuracy;

/**
 * Determines how long the location manager must search for new locations with desired accuracy.
 * Default is 10 seconds.
 */
@property (nonatomic, assign)			NSTimeInterval					queryingInterval;

/**
 * Returns whether the location manager currently searches for new locations.
 */
@property (nonatomic, assign, readonly) BOOL							isQuerying;

/**
 * If YES the last cached location of location manager will be used, which could be some days ago.
 * Default is NO.
 */
@property (nonatomic, assign)			BOOL							useCache;

/**
 * The threshold until the location manager uses the cached location of core location manager.
 * Default is 10 seconds.
 */
@property (nonatomic, assign)			NSTimeInterval					cacheAge;

/**
 * Returns whether the location service of the device is activated. If the application is not allowed this value will be updated by the first search of new location.
 */
@property (nonatomic, assign, readonly) BOOL							isLocationServiceEnabled;

/**
 * If YES the delegates will be informed of location service state changes and a new location will be searched on (re-) activation of the app.
 * Default is NO.
 */
@property (nonatomic, assign)			BOOL							updateLocationOnApplicationDidBecomeActive;

/**
 * Repeat searching for new locations after a location was determined.
 * Default is NO.
 */
@property (nonatomic, assign)			BOOL							loop;

/**
 * After which amount of time after finding a location the search should be restarted
 * Default is 10 seconds.
 */
@property (nonatomic, assign)			NSTimeInterval					loopTimeInterval;

/**
 * Returns the shared instance.
 */
+ (DMLocationManager*) sharedLocationManager;

/**
 * Add a delegate of kind DMLocationManagerDelegate which must be served.
 *
 * @see DMLocationManagerDelegate
 */
- (void)addDelegate:(id<DMLocationManagerDelegate>) delegate;

/**
 * Remove a delegate of kind DMLocationManagerDelegate which must not be served.
 *
 * @see DMLocationManagerDelegate
 */
- (void)removeDelegate:(id<DMLocationManagerDelegate>) delegate;

/**
 * Start updating the location
 */
- (void)startUpdatingLocation;

/**
 * Stop updating the location
 */
- (void)stopUpdatingLocation;

@end


#pragma mark -
#pragma mark DMLocationManagerDelegate

@protocol DMLocationManagerDelegate <CLLocationManagerDelegate>
@optional

/**
 * Informs about changes of location service state.
 *
 * @see DMLocationManager
 */
- (void)locationManager:(DMLocationManager*)manager didChangeLocationServiceEnabledState:(BOOL)isLocationServiceEnabled;

/**
 * Informs when new locations will be started to search for.
 *
 * @see DMLocationManager
 */
- (void)locationManagerWillUpdateLocation:(DMLocationManager*)manager;

/**
 * Informs about stop searching new locations.
 *
 * @see DMLocationManager
 */
- (void)locationManagerDidStopUpdateLocation:(DMLocationManager*)manager;

@end