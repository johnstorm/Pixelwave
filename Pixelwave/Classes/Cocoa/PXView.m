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

#import <QuartzCore/QuartzCore.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>

#import "PXEngine.h"
#import "PXTouchEngine.h"
#import "PXStage.h"
#import "PXDisplayObject.h"

#import "PXView.h"

#import "PXSettings.h"
#import "PXExceptionUtils.h"
#import "PXCGUtils.h"
#import "PXStageOrientationEvent.h"

#include "PXDebug.h"
#include "PXGLPrivate.h"
#include "PXMathUtils.h"

@interface PXView(Private)
- (void) updateOrientation;
- (void) setupMSAA;
- (BOOL) setupWithScaleFactor:(float)contentScaleFactor colorQuality:(PXViewColorQuality)colorQuality;

- (void) touchHandeler:(NSSet *)touches function:(void(*)(UITouch *touch, CGPoint *pos))function;
@end

/*
 * This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView
 * subclass. The view content is basically an EAGL surface you render your
 * OpenGL scene into. Note that setting the view non-opaque will only work if
 * the EAGL surface has an alpha channel.
 * 
 */

/**
 * A UIView subclass that provides a mechanism to create a Pixelwave rendering
 * surface which acts as the root of the entire engine.
 *
 * Although the view's render area may be set to any value, it is highly
 * recommended to set the view's `frame` to be the same size as the screen.
 *
 * Once instantiated, a #PXView starts up all of the engine's subsytems and
 * initializes the display list, providing a default #stage and #root display
 * object. To change the application's root object use the #root property.
 *
 * @warning Only one #PXView should exist for the duration of your app.
 */
@implementation PXView

@synthesize colorQuality;
@synthesize contentScaleFactorSupported;

@synthesize enableAntiAliasing;
@synthesize antiAliasingSampleCount;

/**
 * @param frame The size of the newly created view.
 */
- (id) initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame
			contentScaleFactor:PXEngineGetMainScreenScale()];
}

/**
 * @param frame The size of the newly created view.
 * @param colorQuality The quality to use for the underlying OpenGL rendering
 * surface. This value must be one of the possible values defined in
 * PXViewColorQuality. The default value is PXViewColorQuality_Medium.
 */
- (id) initWithFrame:(CGRect)frame colorQuality:(PXViewColorQuality)_colorQuality
{
	return [self initWithFrame:frame
			contentScaleFactor:PXEngineGetMainScreenScale()
				  colorQuality:_colorQuality];
}

/**
 * @param frame The size of the newly created view.
 * @param contentScaleFactor The multiplier value by which the contents of the
 * view should be scaled. This value usually corresponds to the
 * contentScaleFactor of the device. Pass 0.0 to use the default value.
 */
- (id) initWithFrame:(CGRect)frame contentScaleFactor:(float)_contentScaleFactor
{
	return [self initWithFrame:frame
			contentScaleFactor:_contentScaleFactor
				  colorQuality:PX_VIEW_DEFAULT_COLOR_QUALITY];
}

/**
 * @param frame The size of the newly created view.
 * @param contentScaleFactor The multiplier value by which the contents of the
 * view should be scaled. This value usually corresponds to the
 * contentScaleFactor of the device. Pass 0.0 to use the default value.
 * @param colorQuality The quality to use for the underlying OpenGL rendering
 * surface. This value must be one of the possible values defined in
 * PXViewColorQuality. The default value is PXViewColorQuality_Medium.
 *
 * @see PXViewColorQuality
 */
- (id) initWithFrame:(CGRect)frame
  contentScaleFactor:(float)_contentScaleFactor
		colorQuality:(PXViewColorQuality)_colorQuality
{
	self = [super initWithFrame:frame];

	if (self)
	{
		if (_contentScaleFactor <= 0.0f)
			_contentScaleFactor = PXEngineGetMainScreenScale();

		autoresize = YES;
		firstOrientationChange = NO;

		if (![self setupWithScaleFactor:_contentScaleFactor
						   colorQuality:_colorQuality])
		{
			[self release];
			return nil;
		}
	}

	return self;
}

// When the GL view is stored in the nib file and gets unarchived, it's sent
// -initWithCoder:
- (id) initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];

	if (self)
	{
		if ([self setupWithScaleFactor:PXEngineGetMainScreenScale() colorQuality:PX_VIEW_DEFAULT_COLOR_QUALITY] == NO)
		{
			[self release];
			return nil;
		}
	}

	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];

	EAGLContext *oldContext = [EAGLContext currentContext];

	if (oldContext != eaglContext)
		[EAGLContext setCurrentContext:eaglContext];

	PXEngineDealloc();

	glBindFramebufferOES(GL_FRAMEBUFFER_OES, 0);
	glBindRenderbufferOES(GL_RENDERBUFFER_BINDING_OES, 0);

	glDeleteRenderbuffersOES(1, &renderbuffer);
	renderbuffer = 0;

	glDeleteFramebuffersOES(1, &framebuffer);
	framebuffer = 0;

	// To kill the msaa frame buffer if it exists
	self.enableAntiAliasing = NO;

	if (oldContext != eaglContext)
		[EAGLContext setCurrentContext:oldContext];
	else
		[EAGLContext setCurrentContext:nil];

	[eaglContext release];
	eaglContext = nil;

	[super dealloc];
}

// This is the real initializer, since there are many init... functions
- (BOOL) setupWithScaleFactor:(float)_contentScaleFactor colorQuality:(PXViewColorQuality)_colorQuality
{
	if (PXEngineIsInitialized())
	{
		PXThrow(PXException, @"Only one PXView should exist at a time");
		return NO;
	}

	antiAliasingSampleCount = 2;
	colorQuality = _colorQuality;

	/////////////////
	// Set up EAGL //
	/////////////////

	CAEAGLLayer *eaglLayer = (CAEAGLLayer *)[self layer];
	eaglLayer.opaque = YES;

	// Set the drawable properties

	NSNumber *surfaceRetainedBacking = [NSNumber numberWithBool:NO];
	NSString *surfaceColorFormat;
	BOOL surfaceDither;

	switch (_colorQuality)
	{
		case PXViewColorQuality_Low:
			surfaceColorFormat = kEAGLColorFormatRGB565;
			surfaceDither = NO;
			break;
		case PXViewColorQuality_Medium:
			surfaceColorFormat = kEAGLColorFormatRGB565;
			surfaceDither = YES;
			break;
		case PXViewColorQuality_High:
		default:
			surfaceColorFormat = kEAGLColorFormatRGBA8;
			surfaceDither = NO;
			break;
	}

	// Since the simulator doesn't seem to support dithering... If dithering is
	// on always use RGBA8 to simulate the effect
	if (surfaceDither == YES && surfaceColorFormat == kEAGLColorFormatRGB565 && [[[UIDevice currentDevice] model] isEqualToString:@"iPhone Simulator"])
	{
		colorQuality = PXViewColorQuality_High;
		surfaceColorFormat = kEAGLColorFormatRGBA8;
	}

	NSDictionary *drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
										surfaceRetainedBacking,	kEAGLDrawablePropertyRetainedBacking,
										surfaceColorFormat,		kEAGLDrawablePropertyColorFormat,
										nil];

	[eaglLayer setDrawableProperties:drawableProperties];

	contentScaleFactorSupported = NO;

#ifdef __IPHONE_4_0
	NSString *reqSysVer = @"4.0";
	NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
	if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending)
	{
		contentScaleFactorSupported = YES;
		super.contentScaleFactor = _contentScaleFactor;

		[self setNeedsLayout];
	}
#endif

	// Create the EAGL Context, using ES 1.1
	[eaglContext release];
	eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
	if (eaglContext == nil)
		return NO;

	if ([EAGLContext setCurrentContext:eaglContext] == NO)
		return NO;

	///////////////////////////
	// Initialize the engine //
	///////////////////////////

	glGenFramebuffersOES(1, &framebuffer);
	glGenRenderbuffersOES(1, &renderbuffer);

	glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, renderbuffer);
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, renderbuffer);

	glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebuffer);
	boundFramebuffer = framebuffer;

/*#ifdef __IPHONE_4_0
	if (contentScaleFactorSupported == YES)
	{
		GLenum attachment = GL_DEPTH_ATTACHMENT_OES;
		glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 1, &attachment);
	}
#endif*/

	PXEngineInit(self);

	[eaglContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:eaglLayer];

	// Now the OpenGL is set up, we can change the dithering if needed
	if (surfaceDither == NO)
	{
		glDisable(GL_DITHER);
	}

	PXStage *stage = PXEngineGetStage();

	UIInterfaceOrientation io = [UIApplication sharedApplication].statusBarOrientation;
	if (io == UIInterfaceOrientationPortrait)
		stage.orientation = PXStageOrientation_Portrait;
	else if (io == UIInterfaceOrientationPortraitUpsideDown)
		stage.orientation = PXStageOrientation_PortraitUpsideDown;
	else if (io == UIInterfaceOrientationLandscapeLeft)
		stage.orientation = PXStageOrientation_LandscapeLeft;
	else if (io == UIInterfaceOrientationLandscapeRight)
		stage.orientation = PXStageOrientation_LandscapeRight;

	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateOrientation)
												 name:UIDeviceOrientationDidChangeNotification
											   object:nil];

	return YES;
}

// MARK: -

- (void) updateOrientation
{
	PXStage *_stage = self.stage;

	if (_stage.autoOrients == NO)
	{
		return;
	}

	// Although this is a device orientation, we test against interface
	// orientation due to the conversion of right and left. Compare the enums
	// for more information.
	UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];

	PXStageOrientation afterOrientation;
	switch (interfaceOrientation)
	{
		case UIInterfaceOrientationPortrait:
			afterOrientation = PXStageOrientation_Portrait;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			afterOrientation = PXStageOrientation_PortraitUpsideDown;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			afterOrientation = PXStageOrientation_LandscapeLeft;
			break;
		case UIInterfaceOrientationLandscapeRight:
			afterOrientation = PXStageOrientation_LandscapeRight;
			break;
		default:
			return;
	}

	PXStageOrientation beforeOrientation = _stage.orientation;
	PXStageOrientationEvent *event;

	event = [[PXStageOrientationEvent alloc] initWithType:PXStageOrientationEvent_OrientationChanging
												  bubbles:YES
											   cancelable:YES
										beforeOrientation:beforeOrientation
										 afterOrientation:afterOrientation];

	if (event != nil)
	{
		event->_target = _stage;
	}

	BOOL success = [_stage dispatchEvent:event];

	[event release];

	if (success == YES)
	{
		_stage.orientation = afterOrientation;

		event = [[PXStageOrientationEvent alloc] initWithType:PXStageOrientationEvent_OrientationChange
													  bubbles:YES
												   cancelable:NO
											beforeOrientation:beforeOrientation
											 afterOrientation:afterOrientation];

		if (event != nil)
		{
			event->_target = _stage;
		}

		[_stage dispatchEvent:event];

		[event release];
	}
}

// - (void) memoryWarning
// {
// 	PXEvent *event = [[PXEvent alloc] initWithType:PXEvent_MemoryWarning
// 										bubbles:YES
// 									  cancelable:NO];
// 
// 	[self.stage dispatchEvent:event];
// 	[event release];
// }

- (void) setupMSAA
{
#ifdef __IPHONE_4_0
	if (contentScaleFactorSupported == YES)
	{
		[self _bindFrameBufferDefault];

		GLint backingWidth;
		GLint backingHeight;
		GLenum colorFormat;
		GLenum depthFormat;

		glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
		glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);

		[self _bindFrameBufferWithTarget:GL_FRAMEBUFFER_OES frameBuffer:msaaFramebuffer];
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, msaaRenderbuffer);

		switch (colorQuality)
		{
			case PXViewColorQuality_High:
				colorFormat = GL_RGBA8_OES;
				depthFormat = GL_DEPTH_COMPONENT24_OES;
				break;
			case PXViewColorQuality_Low:
			case PXViewColorQuality_Medium:
			default:
				colorFormat = GL_RGB5_A1_OES;
				depthFormat = GL_DEPTH_COMPONENT16;
				break;
		}

		// 4 will be the number of pixels that the MSAA buffer will use in order
		// to make one pixel on the render buffer.
		glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER_OES, antiAliasingSampleCount, colorFormat, backingWidth, backingHeight);
		glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, msaaRenderbuffer);

		// Bind the msaa depth buffer.
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, msaaDepthbuffer);
		glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER_OES, antiAliasingSampleCount, depthFormat, backingWidth, backingHeight);
		glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, msaaDepthbuffer);

		glBindRenderbufferOES(GL_RENDERBUFFER_OES, renderbuffer);
	}
#endif
}

// MARK: -
// MARK: Properties
// MARK: -

- (void) setEnableAntiAliasing:(BOOL)use
{
#ifdef __IPHONE_4_0
	if (contentScaleFactorSupported)
	{
		if (use == enableAntiAliasing)
			return;

		enableAntiAliasing = use;

		PXGLFlush();

		// TODO: Enable this
		if (use == YES)
		{
			glGenFramebuffersOES(1, &msaaFramebuffer);
			glGenRenderbuffersOES(1, &msaaRenderbuffer);
			glGenRenderbuffersOES(1, &msaaDepthbuffer);

			[self setupMSAA];
		}
		else
		{
			glDeleteRenderbuffersOES(1, &msaaDepthbuffer);
			msaaDepthbuffer = 0;
			glDeleteRenderbuffersOES(1, &msaaRenderbuffer);
			msaaRenderbuffer = 0;
			glDeleteFramebuffersOES(1, &msaaFramebuffer);
			msaaFramebuffer = 0;

			[self _bindFrameBufferDefault];

		//	glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebuffer);
		//	glBindRenderbufferOES(GL_RENDERBUFFER_OES, renderbuffer);
		}
	}
	else
		PXDebugLog(@"anti-aliasing not supported on this device.");
#else
	PXDebugLog(@"anti-aliasing not supported on this device.");
#endif
}

- (void) antiAliasingSampleCount:(unsigned int)count
{
#ifdef __IPHONE_4_0
	if (contentScaleFactorSupported)
	{
		count = PXMathClamp(count, 1, 4);

		if (count == antiAliasingSampleCount)
			return;

		antiAliasingSampleCount = count;

		if (self.enableAntiAliasing)
		{
			self.enableAntiAliasing = false;
			self.enableAntiAliasing = true;
			//[self setupMSAA];
		}
	}
	else
		PXDebugLog(@"anti-aliasing not supported on this device.");
#else
	PXDebugLog(@"anti-aliasing not supported on this device.");
#endif
}

- (void) setContentScaleFactor:(float)_contentScaleFactor
{
#ifdef __IPHONE_4_0
	if (contentScaleFactorSupported)
	{
		super.contentScaleFactor = _contentScaleFactor;
		PXEngineSetContentScaleFactor(_contentScaleFactor);
	}
#endif
}

- (float) contentScaleFactor
{
#ifdef __IPHONE_4_0
	if (contentScaleFactorSupported)
		return super.contentScaleFactor;
#endif

	return 1.0f;
}

- (void) setOpaque:(BOOL)value
{
	[super setOpaque:value];

	PXColor4f clearColor = PXEngineGetClearColor();

	if (self.opaque == YES)
	{
		clearColor.a = 1.0f;
	}
	else
	{
		// This is needed in order for a non-opaque view to work correctly
		clearColor.r = 0.0f;
		clearColor.g = 0.0f;
		clearColor.b = 0.0f;
		clearColor.a = 0.0f;

		if (colorQuality != PXViewColorQuality_High)
		{
			PXDebugLog (@"Pixelwave Warning: Setting PXView.opaque = NO when the colorQuality of the view isn't 'high' will have no effect.");
		}
	}

	PXEngineSetClearColor(clearColor);
}

- (PXStage *)stage
{
	return PXEngineGetStage();
}

- (void) setRoot:(PXDisplayObject *)root
{
	if (root == nil)
	{
		PXThrowNilParam(root);
		return;
	}

	PXEngineSetRoot(root);
}

- (PXDisplayObject *)root
{
	return PXEngineGetRoot();
}

// MARK: -
// MARK: EAGL
// MARK: -

- (void) _bindFrameBufferWithTarget:(GLenum)target frameBuffer:(GLuint)_frameBuffer
{
	if (target != GL_FRAMEBUFFER_OES || boundFramebuffer == _frameBuffer)
		return;

	PXGLFlush();

	boundFramebuffer = _frameBuffer;
	glBindFramebufferOES(target, boundFramebuffer);
}

- (GLuint) _boundFrameBuffer
{
	return boundFramebuffer;
}

- (void) _bindFrameBufferDefault
{
#ifdef __IPHONE_4_0
	if (contentScaleFactorSupported && enableAntiAliasing)
	{
		[self _bindFrameBufferWithTarget:GL_FRAMEBUFFER_OES frameBuffer:msaaFramebuffer];
		return;
	}
#endif

	[self _bindFrameBufferWithTarget:GL_FRAMEBUFFER_OES frameBuffer:framebuffer];
}

+ (Class) layerClass
{
	return [CAEAGLLayer class];
}

- (void) _swapBuffers
{
#ifdef __IPHONE_4_0
	if (contentScaleFactorSupported && enableAntiAliasing)
	{
		[self _bindFrameBufferDefault];
		//[self _setCurrentContext];

	//	GLenum attachments[] = {GL_DEPTH_ATTACHMENT_OES};
	//	glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 1, attachments);

		glBindFramebufferOES(GL_READ_FRAMEBUFFER_APPLE, msaaFramebuffer);
		glBindFramebufferOES(GL_DRAW_FRAMEBUFFER_APPLE, framebuffer);
		// Call a resolve to combine both buffers
		glResolveMultisampleFramebufferAPPLE();
		// Present final image to screen
		glBindFramebufferOES(GL_FRAMEBUFFER_OES, msaaFramebuffer);
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, renderbuffer);
	}
#endif

	if ([eaglContext presentRenderbuffer:GL_RENDERBUFFER_OES] == NO)
	{
		PXDebugLog(@"PXView unable to swap buffers.");
	}
}

- (void) _setCurrentContext
{
	if ([EAGLContext setCurrentContext:eaglContext] == NO)
	{
		PXDebugLog(@"Failed to set current context %p in %s\n", eaglContext, __FUNCTION__);
	}
}

- (BOOL) _isCurrentContext
{
	return ([EAGLContext currentContext] == eaglContext ? YES : NO);
}

- (void) _clearCurrentContext
{
	if ([EAGLContext setCurrentContext:nil] == NO)
	{
		PXDebugLog(@"Failed to clear current context in %s\n", __FUNCTION__);
	}
}

// MARK: -
// MARK: UIView
// MARK: -

- (BOOL) resizeFromLayer:(CAEAGLLayer *)layer
{
	if ([eaglContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:layer] == NO)
	{
		PXDebugLog(@"PXView failed to attach a render buffer to the eagl layer.");
		return NO;
	}

	if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
	{
		PXDebugLog(@"PXView failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return NO;
	}

	return YES;
}

- (void) layoutSubviews
{
	if (autoresize == YES)
	{
		[self resizeFromLayer:(CAEAGLLayer*)self.layer];
	}
}

- (void) setAutoresizesEAGLSurface:(BOOL)autoresizesEAGLSurface;
{
	autoresize = autoresizesEAGLSurface;
	if (autoresize)
		[self layoutSubviews];
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
}

// MARK: -
// MARK: Touch Handling
// MARK: -

- (void) touchHandeler:(NSSet *)touches function:(void(*)(UITouch *touch, CGPoint *pos))function
{
	if (function == NULL)
		return;

	CGPoint touchLocation;

	for (UITouch *touch in touches)
	{
		touchLocation = [touch locationInView:self];

		function(touch, &touchLocation);
	}
}

// These methods get called automatically on every UIView

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)e
{
	[self touchHandeler:touches function:PXTouchEngineInvokeTouchDown];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)e
{
	[self touchHandeler:touches function:PXTouchEngineInvokeTouchMove];
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e
{
	[self touchHandeler:touches function:PXTouchEngineInvokeTouchUp];
}

- (void) touchesCanceled:(NSSet *)touches
{
	[self touchHandeler:touches function:PXTouchEngineInvokeTouchCancel];
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self touchesCanceled:touches];
}

// MARK: -
// MARK: Misc
// MARK: -

// Invoked by super when the view is about to be added/removed. We use it to
// immediately render the display list.
-(void) willMoveToSuperview:(UIView *)newSuperview
{
	// Do a quick render when being added to a window/superview. If it is nil,
	// it means that we are being removed... thus, we can check to see if it
	// exists prior to the render call.
	if (newSuperview)
	{
		PXEngineRender();
		[self _swapBuffers];
	}
}

// MARK: -
// MARK: Utility
// MARK: -

/**
 * A screen grab of the current state of the main display list, as a UIImage.
 *
 * **Please note** that this is a fairly expensive method to execute, and
 * shouldn't be used for real-time effects to avoid a performance hit.
 *
 * This method is generally intended for debugging purposes, but can be safely
 * used in production.
 */

// This is an expensive method
- (UIImage *)screenshot
{
	// Render the current state of the display list
	PXEngineRender();

	CGImageRef cgImage = PXCGUtilsCreateCGImageFromScreenBuffer();

	// Figure out the orientation of the stage and use it to set the
	// orientation of the UIImage.
	PXStageOrientation stageOrientation = PXEngineGetStage().orientation;

	UIImageOrientation imageOrientation = UIImageOrientationUp;

	switch (stageOrientation)
	{
		case PXStageOrientation_Portrait:
			imageOrientation = UIImageOrientationUp;
			break;
		case PXStageOrientation_PortraitUpsideDown:
			imageOrientation = UIImageOrientationDown;
			break;
		case PXStageOrientation_LandscapeRight:
			imageOrientation = UIImageOrientationLeft;
			break;
		case PXStageOrientation_LandscapeLeft:
			imageOrientation = UIImageOrientationRight;
			break;
	}

	UIImage *image = [[UIImage alloc] initWithCGImage:cgImage
												scale:PXEngineGetContentScaleFactor()
										  orientation:imageOrientation];

	CGImageRelease(cgImage);

	return [image autorelease];
}

@end
