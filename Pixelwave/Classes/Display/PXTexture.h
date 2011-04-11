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

#import "PXDisplayObject.h"

@class PXTextureData;
@class PXClipRect;
@protocol PXTextureModifier;

@interface PXTexture : PXDisplayObject
{
	/// @cond DX_IGNORE
@private
	PXTextureData *textureData;
	
	// Info from the clip rect
	ushort contentWidth;
	ushort contentHeight;
	float contentRotation;
	ushort contentPadding[4];
	
	// Anchors, saved in percent values
	float anchorX;
	float anchorY;
	
	// Invalidation
	BOOL anchorsInvalidated;
	BOOL resetClipFlag;
	
	// This is positioned here for padding purposes, should be under
	// contentPadding[4] above
	BOOL contentPaddingEnabled;
	
	// GL data
	unsigned char numVerts;
	PXGLTextureVertex *verts;
	
	// Either GL_LINEAR or GL_NEAREST
	unsigned short smoothingType;
	// Either GL_REPEAT or GL_CLAMP_TO_EDGE
	unsigned short wrapType;
	/// @endcond
}

/**
 *	The texture data that this texture represents.
 */
@property (nonatomic, assign) PXTextureData *textureData;
/**
 *	The clip area of the texture data that this texture is representing. To
 *	show the entire image, set this property to nil.
 *
 *	Since the clip rectangle is closely tied to the textureData, if the
 *	textureData property is nil, this property will remain nil.
 *	Also, setting the textureData property wipes out the current clipRect, so
 *	make sure to set the clipRect AFTER setting the textureData property.
 *	
 *	Thus if the texture is 256x256 pixels, and you only want a 32x64 segment,
 *	the	clip rect is what would be set to achieve this.
 */
@property (nonatomic, copy) PXClipRect *clipRect;

/**
 *	The horizontal anchor position in percent.  If the texture was 32x64 and you
 *	set the anchor to 0.5f, the horizontal position in pixel coordinates would
 *	be 16.  The anchor position is what the texture will rotate, scale, and
 *	position around.
 */
@property (nonatomic, assign) float anchorX;
/**
 *	The vertical anchor position in percent.  If the texture was 32x64 and you
 *	set the anchor to 0.5f, the vertical position in pixel coordinates would
 *	be 32.  The anchor position is what the texture will rotate, scale, and
 *	position around.
 */
@property (nonatomic, assign) float anchorY;

@property (nonatomic, readonly) ushort paddingTop;
@property (nonatomic, readonly) ushort paddingRight;
@property (nonatomic, readonly) ushort paddingBottom;
@property (nonatomic, readonly) ushort paddingLeft;

/**
 *	Determines whether pixel smoothing will be turned on when the texture is
 *	scaled or rotated.
 *	Note that while smoothing looks better it is also more taxing on the gpu.
 */
@property (nonatomic, assign) BOOL smoothing;
/**
 *	Determines how pixels outside of the texture's boundaries should be handled.
 *	If the clipRect of the texture is outside of the bounds of the texture,
 *	setting repeat to <code>YES</code> will simply repeat the texture's pixels
 *	to fill the gap. If set to <code>NO</code>, the 1-pixel boundary around the
 *	edge of will be stretched to fill the gap.
 */
@property (nonatomic, assign) BOOL repeat;

/**
 *	The width of the clipping area, or of the <code>textureData</code> property
 *	if no clipping area is set.
 */
@property (nonatomic, readonly) ushort contentWidth;
/**
 *	The height of the clipping area, or of the <code>textureData</code> property
 *	if no clipping area is set.
 */
@property (nonatomic, readonly) ushort contentHeight;

/**
 *	The rotation offset of the content, as defined by the texture's
 *	clip rectangle. The default value is 0.
 */
@property (nonatomic, readonly) float contentRotation;

//-- ScriptName: Texture
- (id) initWithTextureData:(PXTextureData *)textureData;

////////////
// Anchor //
////////////

//-- ScriptName: setAnchor
- (void) setAnchorWithX:(float)x andY:(float)y;
//-- ScriptName: setAnchorWithPoints
- (void) setAnchorWithPointX:(float)x andPointY:(float)y;

/////////////
// Padding //
/////////////

/*
- (void) setPadding(ushort *)padding;
- (void) setPaddingWithTop:(ushort)top
andRight:(ushort)right
*/

// TODO: Should we keep these, deprecate them, or get rid of them?

//-- ScriptIgnore
- (void) setClipRectWithX:(int)x
					 andY:(int)y
				 andWidth:(ushort)width
				andHeight:(ushort)height;

//-- ScriptName: setClipRect
//-- ScriptArg[0]: required
//-- ScriptArg[1]: required
//-- ScriptArg[2]: required
//-- ScriptArg[3]: required
//-- ScriptArg[4]: 0.0f
//-- ScriptArg[5]: 0.0f
- (void) setClipRectWithX:(int)x
					 andY:(int)y
				 andWidth:(ushort)width
				andHeight:(ushort)height
			 usingAnchorX:(float)anchorX
			   andAnchorY:(float)anchorY;

////

+ (PXTexture *)texture;
//-- ScriptName: make
+ (PXTexture *)textureWithTextureData:(PXTextureData *)textureData;
//-- ScriptIgnore
+ (PXTexture *)textureWithContentsOfFile:(NSString *)path;
//-- ScriptName: makeWithContentsOfFile
//-- ScriptArg[0]: required
//-- ScriptArg[1]: nil
+ (PXTexture *)textureWithContentsOfFile:(NSString *)path modifier:(id<PXTextureModifier>)modifier;
//-- ScriptIgnore
+ (PXTexture *)textureWithContentsOfURL:(NSURL *)url;
//-- ScriptName: makeWithContentsOfURL
//-- ScriptArg[0]: required
//-- ScriptArg[1]: nil
+ (PXTexture *)textureWithContentsOfURL:(NSURL *)url modifier:(id<PXTextureModifier>)modifier;
//-- ScriptIgnore
+ (PXTexture *)textureWithData:(NSData *)data;
//-- ScriptName: makeWithData
//-- ScriptArg[0]: required
//-- ScriptArg[1]: nil
+ (PXTexture *)textureWithData:(NSData *)data modifier:(id<PXTextureModifier>)modifier;

@end
