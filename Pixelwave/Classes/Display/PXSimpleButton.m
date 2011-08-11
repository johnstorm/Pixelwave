/*
 *  _____                       ___                                            
 * /\  _ `\  __                /\_ \                                           
 * \ \ \L\ \/\_\   __  _    ___\//\ \    __  __  __    ___     __  __    ___   
 *  \ \  __/\/\ \ /\ \/ \  / __`\\ \ \  /\ \/\ \/\ \  / __`\  /\ \/\ \  / __`\ 
 *   \ \ \/  \ \ \\/>  </ /\  __/ \_\ \_\ \ \_/ \_/ \/\ \L\ \_\ \ \_/ |/\  __/ 
 *    \ \_\   \ \_\/\_/\_\\ \____\/\____\\ \___^___ /\ \__/|\_\\ \___/ \ \____\
 *     \/_/    \/_/\//\/_/ \/____/\/____/ \/__//__ /  \/__/\/_/ \/__/   \/____/
 *       
 *           www.pixelwave.org + www.spiralstormgames.com
 *                            ~;   
 *                           ,/|\.           
 *                         ,/  |\ \.                 Core Team: Oz Michaeli
 *                       ,/    | |  \                           John Lattin
 *                     ,/      | |   |
 *                   ,/        |/    |
 *                 ./__________|----'  .
 *            ,(   ___.....-,~-''-----/   ,(            ,~            ,(        
 * _.-~-.,.-'`  `_.\,.',.-'`  )_.-~-./.-'`  `_._,.',.-'`  )_.-~-.,.-'`  `_._._,.
 * 
 * Copyright (c) 2011 Spiralstorm Games http://www.spiralstormgames.com
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

#import "PXSimpleButton.h"

#import "PXLinkedList.h"
#import "PXTouchEvent.h"
#import "PXRectangle.h"

#include "PXGLPrivate.h"
#include "PXEngine.h"
#include "PXPrivateUtils.h"
#include "PXDebug.h"

@interface PXSimpleButton(Private)
- (CGRect) currentHitAreaRect;
@end

/**
 *	@ingroup Display
 *
 *	A PXSimpleButton object represents a button with an up, down and hit test
 *	state. If no hit test state is specified then no touch interactions can
 *	occur. A PXRectangle will be automatically specified for you if you use the
 *	default method initWithUpState:downState:; however, if you use the more
 *	complex method and specify no hit area then none will be used and this
 *	button will recieve no interactions.
 *
 *	Note:	It is advised that you listen to PXTouchEvent_Tap to provide the
 *			most accurate information on when the touch is pressed and released
 *			within the correct bounds. This is because tap will not get fired if
 *			you press down inside the button and release outside; where as up
 *			would.
 *
 *	The following code creates a button with an up and down texture for its
 *	states:
 *	@code
 *	PXTexture *upTex = [PXTexture textureWithTextureData:[PXTextureData textureDataWithContentsOfFile:@"upPic.png"]];
 *	PXTexture *downTex = [PXTexture textureWithTextureData:[PXTextureData textureDataWithContentsOfFile:@"downPic.png"]];
 *
 *	PXSimpleButton *button = [[PXSimpleButton alloc] initWithUpState:upTex downState:downTex hitTestState:upState];
 *	@endcode
 *
 *	@see PXRectangle
 */
@implementation PXSimpleButton

@synthesize downState;
@synthesize upState;
@synthesize enabled;
//@synthesize dragAreaPadding;

- (id) init
{
	return [self initWithUpState:nil downState:nil hitTestState:nil];
}

/**
 *	Creates a button with specified up and down state. A hit test state is
 *	automatically created as a PXRectangle the size of the up state if one is
 *	stated, or the size of the down state if no up state is provided. The states
 *	retain count also gets increased by 1, so that the button has a strong
 *	reference to it. Because the hit test state will be a rectangle, it will be
 *	automatically expanded by autoExpandSize as a padding.
 *
 *	@param upState
 *		A PXDisplayObject that specifies the visual up state for the button.
 *	@param downState
 *		A PXDisplayObject that specifies the visual down state for the button.
 *
 *	@b Example:
 *	@code
 *	PXShape *upState = [PXShape new];
 *	PXShape *downState = [PXShape new];
 *
 *	[upState.graphics beginFill:0xFF0000 alpha:1.0f];
 *	[upState.graphics drawRectWithX:100 y:100 width:20 height:15];
 *	[upState.graphics endFill];
 *	// draws a red rectangle at (100, 100) with a size of (20, 15)
 *
 *	[downState.graphics beginFill:0x0000FF alpha:1.0f];
 *	[downState.graphics drawRectWithX:105 y:105 width:15 height:10];
 *	[downState.graphics endFill];
 *	// draws a blue rectangle at (105, 105) with a size of (15, 10)
 *
 *	PXSimpleButton *button = [[PXSimpleButton alloc] initWithUpState:upState downState:downState];
 *	// Creates a button that is red with a hit-area at (100, 100) with size
 *	// (20, 15) when not pressed (up state), when it is pressed (down state) it
 *	// is blue with a hit area at (105, 105) with size (15, 10).
 *
 *	[button addEventListenerOfType:PXTouchEvent_Tap listener:PXListener(onTap:)];
 *	// Adding events to the button will allow you to listen in on interaction.
 *	@endcode
 *
 *	@see PXRectangle;
 *	@see PXShape
 *	@see PXGraphics
 *	@see PXTouchEvent
 */
- (id) initWithUpState:(PXDisplayObject *)_upState downState:(PXDisplayObject *)_downState
		hitAreaPadding:(float)padding
{	
	// Create a rectangle of the size of the 'upState' or the 'downState' if the
	// 'upState' is not provided.

	hitAreaIsRect = YES;
	
	PXRectangle *bounds = nil;
	PXDisplayObject *checkState = (_upState == nil) ? _downState : _upState;

	if (checkState)
	{
		bounds = [checkState boundsWithCoordinateSpace:checkState];
		[bounds inflateWithX:padding y:padding];
	}

	return [self initWithUpState:_upState downState:_downState hitTestState:bounds];
}

/**
 *	Creates a button with specified up, down and hit test states. The states
 *	retain count also gets increased by 1, so that the button has a strong
 *	reference to it.
 *
 *	@param upState
 *		A PXDisplayObject that specifies the visual up state for the button.
 *	@param downState
 *		A PXDisplayObject that specifies the visual down state for the button.
 *	@param hitTestState
 *		A PXDisplayObject or PXRectangle that specifies the hit area for the
 *		button. If <code>nil</code> is specified then no interaction can exist
 *		on this button. If neither a PXDisplayObject nor PXRectangle are
 *		specified, a debug message will be printed and it will be treated as
 *		though <code>nil</code> were passed instead.
 *
 *	@b Example:
 *	@code
 *	PXShape *upState = [PXShape new];
 *	PXShape *downState = [PXShape new];
 *
 *	[upState.graphics beginFill:0xFF0000 alpha:1.0f];
 *	[upState.graphics drawRectWithX:100 y:100 width:20 height:15];
 *	[upState.graphics endFill];
 *	// draws a red rectangle at (100, 100) with a size of (20, 15)
 *
 *	[downState.graphics beginFill:0x0000FF alpha:1.0f];
 *	[downState.graphics drawRectWithX:105 y:105 width:15 height:10];
 *	[downState.graphics endFill];
 *	// draws a blue rectangle at (105, 105) with a size of (15, 10)
 *
 *	PXSimpleButton *button = [[PXSimpleButton alloc] initWithUpState:upState downState:downState hitTestState:upState];
 *	// Creates a button that is red with a hit-area at (100, 100) with size
 *	// (20, 15) when not pressed (up state), when it is pressed (down state) it
 *	// is blue with a hit area at (105, 105) with size (15, 10).
 *
 *	[button addEventListenerOfType:PXTouchEvent_Tap listener:PXListener(onTap:)];
 *	// Adding events to the button will allow you to listen in on interaction.
 *	@endcode
 *
 *	@see PXShape
 *	@see PXGraphics
 *	@see PXTouchEvent
 */
- (id) initWithUpState:(PXDisplayObject *)_upState downState:(PXDisplayObject *)_downState hitTestState:(id<NSObject>)_hitTestState
{
	self = [super init];

	if (self)
	{
		PX_ENABLE_BIT(self->_flags, _PXDisplayObjectFlags_useCustomHitArea);

		dragAreaPadding = 60.0f;

		downState = nil;
		upState = nil;
		hitTestState = nil;

		enabled = YES;

		visibleState = _PXSimpleButtonVisibleState_Up;

		listOfTouches = [[PXLinkedList alloc] init];
		
		// Don't set any states until after the listeners are made.
		self.downState = _downState;
		self.upState = _upState;
		self.hitTestState = _hitTestState;
	}

	return self;
}

- (void) dealloc
{
	[listOfTouches release];

	self.downState = nil;
	self.upState = nil;
	self.hitTestState = nil;
	
	[super dealloc];
}

- (void) setHitTestState:(id<NSObject>)newState
{	
	[newState retain];
	[hitTestState release];
	hitTestState = nil;
	
	hitAreaIsRect = NO;
	
	if([newState isKindOfClass:[PXDisplayObject class]])
	{
		hitTestState = [(PXDisplayObject *)newState retain];
	}
	else if([newState isKindOfClass:[PXRectangle class]])
	{
		hitAreaIsRect = YES;
		hitAreaRect = PXRectangleToCGRect((PXRectangle *)newState);
	}else if(newState != nil)
	{
		PXDebugLog(@"PXSimpleButton ERROR: hitTestState MUST be either a PXRectangle or PXDisplayObject\n");
	}
	
	[newState release];
}

- (id<NSObject>) hitTestState
{
	if(hitAreaIsRect)
	{
		return PXRectangleFromCGRect(hitAreaRect);
	}
	else
	{
		return hitTestState;
	}
}

- (BOOL) dispatchEvent:(PXEvent *)event
{
	[self retain];
	BOOL dispatched = [super dispatchEvent:event];
	
	if(!dispatched) return NO;
	
	// It's important to do this logic afterwards so that we're not changing
	// this hit area BEFORE a touch up event, which will cause tap to
	// not fire if the touch was in the buffer zone.
	if ([event isKindOfClass:[PXTouchEvent class]])
	{
		PXTouchEvent *touchEvent = (PXTouchEvent *)event;
		NSString *eventType = touchEvent.type;
		
		if([eventType isEqualToString:PXTouchEvent_TouchDown])
		{
			[listOfTouches addObject:touchEvent.nativeTouch];
			
			visibleState = _PXSimpleButtonVisibleState_Down;
			
			isPressed = YES;
		}
		else if ([eventType isEqualToString:PXTouchEvent_TouchMove])
		{
			// Checking the auto expand rect is automatically done
			if (touchEvent.insideTarget == YES)
			{
				visibleState = _PXSimpleButtonVisibleState_Down;
			}
			else
			{
				visibleState = _PXSimpleButtonVisibleState_Up;
			}
		}
		else if ([eventType isEqualToString:PXTouchEvent_TouchUp]
				 || [eventType isEqualToString:PXTouchEvent_TouchCancel])
		{
			[listOfTouches removeObject:touchEvent.nativeTouch];
			
			if ([listOfTouches count] == 0)
			{
				visibleState = _PXSimpleButtonVisibleState_Up;
			}
			
			isPressed = NO;
		}
	}
	[self release];
	
	return dispatched;
}

- (void) _measureLocalBounds:(CGRect *)retBounds
{
	*retBounds = CGRectZero;

	if(hitAreaIsRect){
		*retBounds = [self currentHitAreaRect];
	}else if(hitTestState){
		// Ask the hit test for the GLOBAL bounds, because it needs to take
		// any children it may have into affect.
		[hitTestState _measureGlobalBounds:retBounds];
	}	
}

- (BOOL) _containsPointWithLocalX:(float)x localY:(float)y shapeFlag:(BOOL)shapeFlag
{
	if(hitAreaIsRect)
	{
		return CGRectContainsPoint([self currentHitAreaRect], CGPointMake(x, y));
	}
	else if(hitTestState)
	{
		return [hitTestState _hitTestPointWithParentX:x parentY:y shapeFlag:shapeFlag];
	}
	
	return NO;
}

- (CGRect) currentHitAreaRect
{
	if(isPressed)
	{
		float amount = -dragAreaPadding;
		return CGRectInset(hitAreaRect, amount, amount);
	}
	else
	{
		return hitAreaRect;
	}
}

- (void) _renderGL
{
	PXDisplayObject *visibleStateDisp = nil;

	switch (visibleState)
	{
		case _PXSimpleButtonVisibleState_Up:
			visibleStateDisp = upState;
			break;
		case _PXSimpleButtonVisibleState_Down:
			visibleStateDisp = downState;
			break;
		default:
			visibleStateDisp = nil;
			break;
	}

	if (visibleStateDisp)
	{
		PXEngineRenderDisplayObject(visibleStateDisp, YES, NO);
	}
}

/**
 *	Creates a button with specified up and down state. A hit test state is
 *	automatically created as a PXRectangle the size of the up state if one is
 *	stated, or the size of the down state if no up state is provided. The states
 *	retain count also gets increased by 1, so that the button has a strong
 *	reference to it. Because the hit test state will be a rectangle, it will be
 *	automatically expanded by autoExpandSize as a padding.
 *
 *	@param upState
 *		A PXDisplayObject that specifies the visual up state for the button.
 *	@param downState
 *		A PXDisplayObject that specifies the visual down state for the button.
 *
 *	@b Example:
 *	@code
 *	PXShape *upState = [PXShape new];
 *	PXShape *downState = [PXShape new];
 *
 *	[upState.graphics beginFill:0xFF0000 alpha:1.0f];
 *	[upState.graphics drawRectWithX:100 y:100 width:20 height:15];
 *	[upState.graphics endFill];
 *	// draws a red rectangle at (100, 100) with a size of (20, 15)
 *
 *	[downState.graphics beginFill:0x0000FF alpha:1.0f];
 *	[downState.graphics drawRectWithX:105 y:105 width:15 height:10];
 *	[downState.graphics endFill];
 *	// draws a blue rectangle at (105, 105) with a size of (15, 10)
 *
 *	PXSimpleButton *button = [PXSimpleButton simpleButtonWithUpState:upState downState:downState];
 *	// Creates a button that is red with a hit-area at (100, 100) with size
 *	// (20, 15) when not pressed (up state), when it is pressed (down state) it
 *	// is blue with a hit area at (105, 105) with size (15, 10).
 *
 *	[button addEventListenerOfType:PXTouchEvent_Tap listener:PXListener(onTap:)];
 *	// Adding events to the button will allow you to listen in on interaction.
 *	@endcode
 *
 *	@see PXRectangle;
 *	@see PXShape
 *	@see PXGraphics
 *	@see PXTouchEvent
 */
+ (PXSimpleButton *)simpleButtonWithUpState:(PXDisplayObject *)upState
								  downState:(PXDisplayObject *)downState
							 hitAreaPadding:(float)hitAreaPadding
{
	return [[[PXSimpleButton alloc] initWithUpState:upState
										  downState:downState
									 hitAreaPadding:hitAreaPadding] autorelease];
}

/**
 *	Creates a button with specified up, down and hit test states. The button
 *	holds a strong refernece to the states, so you can release them after
 *	setting them.
 *
 *	@param upState
 *		A PXDisplayObject that specifies the visual up state for the button.
 *	@param downState
 *		A PXDisplayObject that specifies the visual down state for the button.
 *	@param hitTestState
 *		A PXDisplayObject or PXRectangle that specifies the hit area for the
 *		button. If <code>nil</code> is specified then no interaction can exist
 *		on this button. If neither a PXDisplayObject nor PXRectangle are
 *		specified, a debug message will be printed and it will be treated as
 *		though <code>nil</code> were passed instead.
 *
 *	@b Example:
 *	@code
 *	PXShape *upState = [PXShape new];
 *	PXShape *downState = [PXShape new];
 *
 *	[upState.graphics beginFill:0xFF0000 alpha:1.0f];
 *	[upState.graphics drawRectWithX:100 y:100 width:20 height:15];
 *	[upState.graphics endFill];
 *	// draws a red rectangle at (100, 100) with a size of (20, 15)
 *
 *	[downState.graphics beginFill:0x0000FF alpha:1.0f];
 *	[downState.graphics drawRectWithX:105 y:105 width:15 height:10];
 *	[downState.graphics endFill];
 *	// draws a blue rectangle at (105, 105) with a size of (15, 10)
 *
 *	PXSimpleButton *button = [PXSimpleButton simpleButtonWithUpState:upState downState:downState hitTestState:upState];
 *	// Creates a button that is red with a hit-area at (100, 100) with size
 *	// (20, 15) when not pressed (up state), when it is pressed (down state) it
 *	// is blue with a hit area at (105, 105) with size (15, 10).
 *
 *	[button addEventListenerOfType:PXTouchEvent_Tap listener:PXListener(onTap:)];
 *	// Adding events to the button will allow you to listen in on interaction.
 *	@endcode
 */
+ (PXSimpleButton *)simpleButtonWithUpState:(PXDisplayObject *)upState
								  downState:(PXDisplayObject *)downState
							   hitTestState:(id<NSObject>)hitTestState
{
	return [[[PXSimpleButton alloc] initWithUpState:upState
										  downState:downState
									   hitTestState:hitTestState] autorelease];
}

@end
