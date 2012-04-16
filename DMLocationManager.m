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

#import "DMLocationManager.h"

@interface DMLocationManager (private)
- (void)initLocationManager;
- (void)initListener;
- (void)update;

- (void)startQueryingTimer;
- (void)stopQueryingTimer;

- (void)startLoopTimer;
- (void)stopLoopTimer;

- (void)willUpdateLocationHandler;

- (void)informDidChangeLocationServiceEnabledState:(BOOL)locationServiceEnabled;
- (void)informWillUpdateLocation;
- (void)informDidStopUpdateLocation;
- (void)informDidUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation;
- (void)informDidFailWithError:(NSError*)error;
@end

static DMLocationManager* sharedLocationManager = nil;

@implementation DMLocationManager

@synthesize location									= _location;
@dynamic	desiredAccuracy;

@dynamic	isQuerying;
@synthesize queryingInterval							= _queryingInterval;

@synthesize useCache									= _useCache;
@synthesize cacheAge                                    = _cacheAge;
@synthesize	isLocationServiceEnabled					= _isLocationServiceEnabled;

@synthesize updateLocationOnApplicationDidBecomeActive	= _updateLocationOnApplicationDidBecomeActive;

@synthesize loopTimeInterval							= _loopTimeInterval;
@synthesize loop										= _loop;

+ (DMLocationManager*) sharedLocationManager
{
	if (nil == sharedLocationManager)
	{
		sharedLocationManager = [[DMLocationManager alloc] init];
	}
	
	return sharedLocationManager;
}


#pragma mark -
#pragma mark Initialization

- (id) init
{
	self = [super init];
	if (self != nil)
	{
		[self initLocationManager];
		[self initListener];
	}
	
	return self;
}

- (void)dealloc
{
	_locationManager.delegate = nil;
	[_locationManager release];
	
	[_delegates release];
	
	[_queryingTimer release];
	
	[super dealloc];
}

- (void)initLocationManager
{
	_locationManager	= [CLLocationManager new];
	
	_delegates			= [NSMutableArray new];
	
	_useCache			= YES;
	_cacheAge           = 10.0;
	_queryingInterval	= 10.0;
	
	_isLocationServiceEnabled	= [CLLocationManager locationServicesEnabled];
	
	_updateLocationOnApplicationDidBecomeActive	= NO;
	
	_loop				= NO;
	_loopTimeInterval	= 10.0;
}

- (void)initListener
{
	// Listen for 'did become active' of application
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(update:)
												 name: UIApplicationDidBecomeActiveNotification
											   object: nil];
	
	// Listen for application enters background
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(update:)
												 name: UIApplicationDidEnterBackgroundNotification
											   object: nil];
}


#pragma mark -
#pragma mark Update

- (void)update:(NSNotification*)notification
{
	// Update location manager after restart of app
	if ([UIApplicationDidBecomeActiveNotification isEqualToString: [notification name]])
	{
		// Did location service changed enabled state?
		BOOL locationServicesEnabled = [CLLocationManager locationServicesEnabled];
		if (_isLocationServiceEnabled != locationServicesEnabled)
		{			
			_isLocationServiceEnabled = locationServicesEnabled;
			[self informDidChangeLocationServiceEnabledState: _isLocationServiceEnabled];
		}
		
		// Whether to update the location on becoming active again
		if (YES == _updateLocationOnApplicationDidBecomeActive)
		{
			[self startUpdatingLocation];
		}
	}
	
	// Stop all processes on app entering background
	else if ([UIApplicationDidEnterBackgroundNotification isEqualToString: [notification name]])
	{
		[self stopUpdatingLocation];
	}
}


#pragma mark -
#pragma mark Delegates

- (void)addDelegate:(id<DMLocationManagerDelegate>) delegate
{	
	if (nil == delegate)
		return;
	
	if ([_delegates containsObject: delegate])
		return;
	
	[_delegates addObject: delegate];
}

- (void)removeDelegate:(id<DMLocationManagerDelegate>) delegate
{
	if ([_delegates containsObject: delegate])
		[_delegates removeObject: delegate];
}


#pragma mark -
#pragma mark Inform delegates

- (void)informDidChangeLocationServiceEnabledState:(BOOL)locationServiceEnabled
{
	for (id<DMLocationManagerDelegate> delegate in _delegates)
	{
		if ([delegate respondsToSelector: @selector(locationManager:didChangeLocationServiceEnabledState:)])
			[delegate locationManager: self didChangeLocationServiceEnabledState: locationServiceEnabled];
	}
}

- (void)informDidStopUpdateLocation
{
	for (id<DMLocationManagerDelegate> delegate in _delegates)
	{
		if ([delegate respondsToSelector: @selector(locationManagerDidStopUpdateLocation:)])
			[delegate locationManagerDidStopUpdateLocation: self];
	}
}

- (void)informWillUpdateLocation
{
	for (id<DMLocationManagerDelegate> delegate in _delegates)
	{
		if ([delegate respondsToSelector: @selector(locationManagerWillUpdateLocation:)])
			[delegate locationManagerWillUpdateLocation: self];
	}
}

- (void)informDidUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation
{
	for (id<DMLocationManagerDelegate> delegate in _delegates)
	{
		if ([delegate respondsToSelector: @selector(locationManager:didUpdateToLocation:fromLocation:)])
			[delegate locationManager: _locationManager didUpdateToLocation: newLocation fromLocation: oldLocation];
	}
}

- (void)informDidFailWithError:(NSError*)error
{
	for (id<DMLocationManagerDelegate> delegate in _delegates)
	{
		if ([delegate respondsToSelector: @selector(locationManager:didFailWithError:)])
			[delegate locationManager: _locationManager didFailWithError: error];
	}
}


#pragma mark -
#pragma mark Location

/**
 * Start updating the location
 *
 */
- (void)startUpdatingLocation
{
	[self willUpdateLocationHandler];
	
	_locationManager.delegate = self;
	[_locationManager startUpdatingLocation];
}

/**
 * Stop updating the location
 *
 */
- (void)stopUpdatingLocation
{
	[_locationManager stopUpdatingLocation];
	_locationManager.delegate = nil;
	
	[self stopQueryingTimer];
	[self stopLoopTimer];
	
	[self informDidStopUpdateLocation];
}


#pragma mark -
#pragma mark Querying timer

- (void)startQueryingTimer
{
	[self stopQueryingTimer];
	
	_queryingTimer = [[NSTimer scheduledTimerWithTimeInterval: _queryingInterval target: self selector: @selector(queryingTimerPassed:) userInfo: nil repeats: YES] retain];
}

- (void)stopQueryingTimer
{
	if (_queryingTimer)
	{
		if ([_queryingTimer isValid])
		{
			[_queryingTimer invalidate];
		}
		[_queryingTimer release];
		_queryingTimer = nil;
	}
}

- (void)queryingTimerPassed:(NSTimer*)queryingTimer
{
	[self stopUpdatingLocation];
	[self stopQueryingTimer];
	
	if (_location)
	{
		[self informDidUpdateToLocation: _location fromLocation: nil];
	}
	else
	{
		[self informDidFailWithError: nil];
	}
}


#pragma mark -
#pragma mark Loop timer

- (void)startLoopTimer
{
	[self stopLoopTimer];
	
	_loopTimer = [[NSTimer scheduledTimerWithTimeInterval: _loopTimeInterval target: self selector: @selector(loopTimerPassed:) userInfo: nil repeats: YES] retain];
}

- (void)stopLoopTimer
{
	if (_loopTimer)
	{
		if ([_loopTimer isValid])
		{
			[_loopTimer invalidate];
		}
		[_loopTimer release];
		_loopTimer = nil;
	}
}

- (void)loopTimerPassed:(NSTimer*)loopTimer
{	
	[self stopLoopTimer];
	[self startUpdatingLocation];
}


#pragma mark -
#pragma mark Desired accuracy

- (void)setDesiredAccuracy:(CLLocationAccuracy)accuracy
{
	_locationManager.desiredAccuracy = accuracy;
}

- (CLLocationAccuracy) desiredAccuracy
{
	return _locationManager.desiredAccuracy;
}


#pragma mark -
#pragma mark Public getter

/**
 * Returns whether the location manager currently searches for new locations.
 *
 */
- (BOOL)isQuerying
{
	return [_queryingTimer isValid];
}


#pragma mark -
#pragma mark Event handling

/**
 * Handling the start of querying for a new location.
 *
 */
- (void)willUpdateLocationHandler
{
	[self startQueryingTimer];
	
	[self informWillUpdateLocation];
}

/**
 * Handling the new location.
 *
 */
- (void)didUpdateLocationHandler
{	
	[self stopUpdatingLocation];
	
	[self informDidUpdateToLocation: _location fromLocation: nil];
	
	// If YES start immedeatly searching new locations after one was found
	if (YES == _loop)
	{
		[self startLoopTimer];
	}
}

/**
 * Handling the some error.
 *
 */
- (void)didFailWithErrorHandler:(NSError*)error
{
	[self stopUpdatingLocation];
	
	[self informDidFailWithError: error];
}

#pragma mark -
#pragma mark CLLocationManagerDelegate

/**
 * Invoked when a new location is available. oldLocation may be nil if there is no previous location
 *
 */
- (void)locationManager:(CLLocationManager*)manager
	 didUpdateToLocation:(CLLocation*)newLocation
		    fromLocation:(CLLocation*)oldLocation
{
#if	DM_LOCATION_MANAGER_LOG_LEVEL >= DM_LOCATION_MANAGER_LOG_LEVEL_DEBUG
	NSLog(@"locationManager didUpdateToLocation: %@\nfrom: %@", newLocation, oldLocation);
#endif
	
	// If cache is deactivated do only use fresh locations within 'cache time interval'
	if (NO == _useCache)
	{        
		NSDate* eventDate			= newLocation.timestamp;
		NSTimeInterval howRecent	= [eventDate timeIntervalSinceNow];
		
		if(abs(howRecent) > _cacheAge)
		{
#if	DM_LOCATION_MANAGER_LOG_LEVEL >= DM_LOCATION_MANAGER_LOG_LEVEL_DEBUG
			NSLog(@"locationManager didUpdateToLocation with timestamp %@ which is to old to use", newLocation.timestamp);
#endif
			return;
		}
	}
	
	// If cache is activated or location is fresh enough determine the accuracy of the location in comparison to old locations
	// If the desired accuracy is reached stop here with success, else let the location manager query again
    
    // We have a measurement that meets our requirements, so we can stop updating the location
    if (newLocation.horizontalAccuracy <= manager.desiredAccuracy)
	{
        [_location release];
		_location = [newLocation retain];
		
		[self didUpdateLocationHandler];
	}
    // New location is better than the old one but does not reach the desired accuracy
	else if (_location == nil || _location.horizontalAccuracy > newLocation.horizontalAccuracy)
	{
		[_location release];
		_location = [newLocation retain];
	}
}

/**
 * Invoked when an error occurred. Check error domain and code for reason.
 *
 */
- (void)locationManager:(CLLocationManager*)manager
	    didFailWithError:(NSError*)error
{
#if	DM_LOCATION_MANAGER_LOG_LEVEL >= DM_LOCATION_MANAGER_LOG_LEVEL_ERROR
	NSLog(@"locationManager didFailWithError: %@", [error domain]);
#endif
	
	if ([error domain] == kCLErrorDomain)
	{
		switch ([error code])
		{
			case kCLErrorDenied:
			{
				if (_isLocationServiceEnabled != NO)
				{			
					_isLocationServiceEnabled = NO;
					[self informDidChangeLocationServiceEnabledState: _isLocationServiceEnabled];
				}
				
				break;
			}
			default:
			{
				break;
			}
		}
	}
	
	[self didFailWithErrorHandler: error];
}

@end
