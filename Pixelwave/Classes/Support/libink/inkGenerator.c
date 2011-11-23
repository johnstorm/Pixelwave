//
//  inkGenerator.c
//  ink
//
//  Created by John Lattin on 11/16/11.
//  Copyright (c) 2011 Spiralstorm Games. All rights reserved.
//

#import "inkGenerator.h"

#include "inkFill.h"

inkGenerator* inkGeneratorCreate(inkTessellator* tessellator, void* fill)
{
	inkGenerator* generator = malloc(sizeof(inkGenerator));

	if (generator != NULL)
	{
		generator->me = generator;

		generator->tessellator = tessellator;

		generator->vertexGroupList = inkArrayCreate(sizeof(inkArray *));

		if (generator->vertexGroupList == NULL)
		{
			inkGeneratorDestroy(generator);
			return NULL;
		}

		generator->currentVertices = NULL;
		generator->fill = fill;
	}
	
	return generator;
}

void inkGeneratorDestroy(inkGenerator* generator)
{
	if (generator != NULL)
	{
		if (generator->vertexGroupList != NULL)
		{
			inkArray* array;

			inkArrayPtrForEach(generator->vertexGroupList, array)
			{
				inkArrayDestroy(array);
			}

			inkArrayDestroy(generator->vertexGroupList);
		}

		free(generator);
	}
}

void inkGeneratorMoveTo(inkGenerator* generator, inkPoint position, inkGeneratorEndFunction endFunction, void *userData)
{
	if (generator == NULL || generator->vertexGroupList == NULL)
		return;

	if (endFunction != NULL)
		endFunction(userData);
	else
		inkGeneratorEnd(generator);

	inkArray* vertices = inkArrayCreate(sizeof(INKvertex));

	if (vertices == NULL)
		return;

	inkArray** verticesPtr = inkArrayPush(generator->vertexGroupList);

	if (verticesPtr == NULL)
	{
		inkArrayDestroy(vertices);
		return;
	}

	*verticesPtr = vertices;
	generator->currentVertices = vertices;

	generator->previous = position;

	inkGeneratorAddVertex(generator, generator->previous);
}

void inkGeneratorLineTo(inkGenerator* generator, inkPoint position)
{
	if (generator == NULL)
		return;

	inkGeneratorAddVertex(generator, position);
	generator->previous = position;
}

void inkGeneratorCurveTo(inkGenerator* generator, inkPoint control, inkPoint anchor)
{
	if (generator == NULL)
		return;

	// TODO: Implement properly instead of just making lots of LineTos
	const unsigned int percision = 100;

	inkPoint nextPoint;
	inkPoint previousPoint = generator->previous;

	float tIncrement = 1.0f / (float)(percision - 1);
	float t;
	float oneMinusT;

	float pWeight;
	float cWeight;
	float aWeight;

	unsigned int index;

	for (index = 0, t = 0.0f, oneMinusT = 1.0f; index < percision; ++index, t += tIncrement, oneMinusT -= tIncrement)
	{
		pWeight = oneMinusT * oneMinusT;
		cWeight = 2 * t * oneMinusT;
		aWeight = t * t;

		nextPoint = inkPointMake((previousPoint.x * pWeight) + (control.x * cWeight) + (anchor.x * aWeight),
								 (previousPoint.y * pWeight) + (control.y * cWeight) + (anchor.y * aWeight));

		inkGeneratorAddVertex(generator, nextPoint);
	}
}

void inkGeneratorEnd(inkGenerator* generator)
{
	if (generator == NULL || generator->tessellator == NULL || generator->currentVertices == NULL)
		return;

	inkTessellatorBeginContour(generator->tessellator);

	INKvertex *vertex;

	inkArrayForEach(generator->currentVertices, vertex)
	{
		inkTessellatorAddPoint(generator->tessellator, vertex);
	}

	inkTessellatorEndContour(generator->tessellator);

	generator->currentVertices = NULL;
}

void inkGeneratorInitVertex(INKvertex* vertex, inkPoint position, void* fill)
{
	if (vertex == NULL)
		return;

	vertex->x = (position.x);
	vertex->y = (position.y);

	if (fill == NULL)
		return;

	inkFillType fillType = ((inkFill *)fill)->fillType;

	switch(fillType)
	{
		case inkFillType_Solid:
		{
			inkSolidFill* solidFill = (inkSolidFill *)fill;
			
			// TODO: Use a real color checker instead
			vertex->r = 0xFF & (solidFill->color >> 16);
			vertex->g = 0xFF & (solidFill->color >> 8);
			vertex->b = 0xFF & (solidFill->color);
			vertex->a = 0xFF * solidFill->alpha;
		}
			break;
		case inkFillType_Bitmap:
		{
			inkBitmapFill* bitmapFill = (inkBitmapFill *)fill;
			
			inkPoint convertedPosition = inkMatrixTransformPoint(bitmapFill->matrix, position);
			
			vertex->s = convertedPosition.x * bitmapFill->bitmapInfo.one_textureWidth;
			vertex->t = convertedPosition.y * bitmapFill->bitmapInfo.one_textureHeight;
		}
			break;
		case inkFillType_Gradient:
			// TODO: Implement
			break;
		default:
			break;
	}
}

void inkGeneratorAddVertex(inkGenerator* generator, inkPoint position)
{
	if (generator == NULL || generator->currentVertices == NULL)
		return;

	INKvertex* vertex = (INKvertex*)inkArrayPush(generator->currentVertices);

	inkGeneratorInitVertex(vertex, position, generator->fill);
}