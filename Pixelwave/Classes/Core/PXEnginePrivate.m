//
//  PXEnginePrivate.m
//  Pixelwave
//
//  Created by John Lattin on 8/2/11.
//  Copyright 2011 Spiralstorm Games. All rights reserved.
//

#include "PXEnginePrivate.h"

PXStage *pxEngineStage = nil;							//Strongly referenced
PXDisplayObject *pxEngineRoot = nil;					//Weakly referenced
PXView *pxEngineView = nil;								//Weakly referenced

_PXEngineDisplayObjectBuffer pxEngineDOBuffer;
PXDisplayObject **pxEngineDOBufferCurrentObject = NULL;

unsigned pxEngineDOBufferMaxSize = 0;
unsigned pxEngineDOBufferOldMaxSize = 0;

PXGLAABB PXEngineAABBStageToGL(PXGLAABB aabb, PXStage *stage)
{
	aabb = PXEngineAABBGLToStage(aabb, stage);
	aabb = PXEngineAABBGLToStage(aabb, stage);
	return PXEngineAABBGLToStage(aabb, stage);
}

PXGLAABB PXEngineAABBGLToStage(PXGLAABB aabb, PXStage *stage)
{
	switch (stage.orientation)
	{
		case PXStageOrientation_PortraitUpsideDown:
		{
			int stageWidth  = stage.stageWidth;
			int stageHeight = stage.stageHeight;
			return PXGLAABBMake(stageWidth - aabb.xMax, stageHeight - aabb.yMax, stageWidth - aabb.xMin, stageHeight - aabb.yMin);
		}
		case PXStageOrientation_LandscapeLeft:
		{
			int stageWidth  = stage.stageWidth;
			return PXGLAABBMake(stageWidth - aabb.yMax, aabb.xMin, stageWidth - aabb.yMin, aabb.xMax);
		}
		case PXStageOrientation_LandscapeRight:
		{
			int stageHeight = stage.stageHeight;
			return PXGLAABBMake(aabb.yMin, stageHeight - aabb.xMax, aabb.yMax, stageHeight - aabb.xMin);
		}
		case PXStageOrientation_Portrait:
		default:
			break;
	}

	return aabb;
}

PXGLAABBf PXEngineAABBfStageToGL(PXGLAABBf aabb, PXStage *stage)
{
	aabb = PXEngineAABBfGLToStage(aabb, stage);
	aabb = PXEngineAABBfGLToStage(aabb, stage);
	return PXEngineAABBfGLToStage(aabb, stage);
}

PXGLAABBf PXEngineAABBfGLToStage(PXGLAABBf aabb, PXStage *stage)
{
	switch (stage.orientation)
	{
		case PXStageOrientation_PortraitUpsideDown:
		{
			float stageWidth  = stage.stageWidth;
			float stageHeight = stage.stageHeight;
			return PXGLAABBfMake(stageWidth - aabb.xMax, stageHeight - aabb.yMax, stageWidth - aabb.xMin, stageHeight - aabb.yMin);
		}
		case PXStageOrientation_LandscapeLeft:
		{
			float stageWidth  = stage.stageWidth;
			return PXGLAABBfMake(stageWidth - aabb.yMax, aabb.xMin, stageWidth - aabb.yMin, aabb.xMax);
		}
		case PXStageOrientation_LandscapeRight:
		{
			float stageHeight = stage.stageHeight;
			return PXGLAABBfMake(aabb.yMin, stageHeight - aabb.xMax, aabb.yMax, stageHeight - aabb.xMin);
		}
		case PXStageOrientation_Portrait:
		default:
			break;
	}

	return aabb;
}

CGPoint PXEnginePointStageToGL(CGPoint point, PXStage *stage)
{
	point = PXEnginePointGLToStage(point, stage);
	point = PXEnginePointGLToStage(point, stage);
	return PXEnginePointGLToStage(point, stage);
}

CGPoint PXEnginePointGLToStage(CGPoint point, PXStage *stage)
{
	switch (stage.orientation)
	{
		case PXStageOrientation_PortraitUpsideDown:
			return CGPointMake(stage.stageWidth - point.x, stage.stageHeight - point.y);
		case PXStageOrientation_LandscapeLeft:
			return CGPointMake(stage.stageWidth - point.y, point.x);
		case PXStageOrientation_LandscapeRight:
			return CGPointMake(point.y, stage.stageHeight - point.x);
		case PXStageOrientation_Portrait:
		default:
			break;
	}

	return point;
}
