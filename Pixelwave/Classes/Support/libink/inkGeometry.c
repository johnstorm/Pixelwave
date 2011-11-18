//
//  inkGeometry.c
//  ink
//
//  Created by John Lattin on 11/9/11.
//  Copyright (c) 2011 Spiralstorm Games. All rights reserved.
//

#import "inkGeometry.h"

#pragma mark -
#pragma mark Constants
#pragma mark -

const inkPoint inkPointZero = _inkPointZero;
const inkSize inkSizeZero = _inkSizeZero;
const inkRect inkRectZero = _inkRectZero;
const inkMatrix inkMatrixIdentity = _inkMatrixIdentity;

#pragma mark -
#pragma mark Point
#pragma mark -

#pragma mark -
#pragma mark Size
#pragma mark -

#pragma mark -
#pragma mark Rect
#pragma mark -

#pragma mark -
#pragma mark Matrix
#pragma mark -

inkPoint inkMatrixTransformPoint(inkMatrix matrix, inkPoint point)
{
	return inkPointMake((point.x * matrix.a) + (point.y * matrix.c) + matrix.tx,
						(point.x * matrix.b) + (point.y * matrix.d) + matrix.ty);
}

inkPoint inkMatrixDeltaTransformPoint(inkMatrix matrix, inkPoint point)
{
	return inkPointMake((point.x * matrix.a) + (point.y * matrix.c),
						(point.x * matrix.b) + (point.y * matrix.d));
}
