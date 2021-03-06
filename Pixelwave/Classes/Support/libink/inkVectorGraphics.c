//
//  inkVectorGraphics.c
//  ink
//
//  Created by John Lattin on 11/7/11.
//  Copyright (c) 2011 Spiralstorm Games. All rights reserved.
//

#include "inkVectorGraphics.h"

#include "inkCommand.h"

#include "inkFillGenerator.h"
#include "inkStrokeGenerator.h"

#include "inkGLU.h"

typedef struct
{
	inkCanvas* canvas;
	inkFillGenerator* fillGenerator;
	inkStrokeGenerator* strokeGenerator;
} inkCurveGenerators;

inkPoint inkUpdatePositionv(inkPoint point, void* canvas);
inkPoint inkUpdatePosition(inkCanvas* canvas, inkPoint point);

void inkInternalLineTo(inkCanvas* canvas, inkPoint point, inkFillGenerator* fillGenerator, inkStrokeGenerator* strokeGenerator, bool isCurve);
void inkCurve(inkCanvas* canvas, inkFillGenerator* fillGenerator, inkStrokeGenerator* strokeGenerator, inkCurveType curveType, inkPoint controlA, inkPoint controlB, inkPoint anchor);

inkInline inkPoint inkPosition(inkCanvas* canvas, inkPoint position, bool relative)
{
	assert(canvas != NULL);

	if (relative == false)
		return position;

	return inkPointAdd(canvas->cursor, position);
}

inkInline void inkSetCursor(inkCanvas* canvas, inkPoint position)
{
	assert(canvas != NULL);

	canvas->cursor = position;
}

unsigned int inkArcLengthSegmentCount(inkCanvas* canvas, float arcLength)
{
	unsigned int count = ceilf(fabsf(arcLength));

	count *= canvas->pixelsPerPoint * canvas->curveMultiplier;

	if (count < 3)
		count = 3;

	return count;
}

void inkClear(inkCanvas* canvas)
{
	assert(canvas != NULL);

	inkRemoveAllCommands(canvas);
	inkRemoveAllRenderGroups(canvas);
	inkFreeCachedMemory(canvas);

	inkRemoveAllCommands(canvas);
	inkRemoveAllRenderGroups(canvas);
	inkFreeCachedMemory(canvas);
}

void inkMoveTov(inkCanvas* canvas, inkPoint position, bool relative)
{
	position = inkPosition(canvas, position, relative);

	inkMoveToCommand command = position;
	inkAddCommand(canvas, inkCommandType_MoveTo, &command);

	inkSetCursor(canvas, position);
}

void inkLineTov(inkCanvas* canvas, inkPoint position, bool relative)
{
	position = inkPosition(canvas, position, relative);

	inkLineToCommand command = position;
	inkAddCommand(canvas, inkCommandType_LineTo, &command);

	inkSetCursor(canvas, position);
}

void inkCurveTov(inkCanvas* canvas, inkPoint control, inkPoint anchor, bool relative, bool reflect)
{
	inkQuadraticCurveTov(canvas, control, anchor, relative, reflect);
}

void inkQuadraticCurveTov(inkCanvas* canvas, inkPoint control, inkPoint anchor, bool relative, bool reflect)
{
	assert(canvas != NULL);

	if (reflect == false)
		control = inkPosition(canvas, control, relative);
	else
	{
		inkPoint cursor = canvas->cursor;
		control = inkPointAdd(inkPointSubtract(cursor, canvas->previousControl), cursor);
	}

	anchor = inkPosition(canvas, anchor, relative);

	inkQuadraticCurveToCommand command;
	command.control = control;
	command.anchor = anchor;

	inkAddCommand(canvas, inkCommandType_QuadraticCurveTo, &command);

	canvas->previousControl = control;

	inkSetCursor(canvas, anchor);
}

void inkCubicCurveTov(inkCanvas* canvas, inkPoint controlA, inkPoint controlB, inkPoint anchor, bool relative, bool reflect)
{
	if (reflect == false)
	{
		controlA = inkPosition(canvas, controlA, relative);
		controlB = inkPosition(canvas, controlB, relative);
	}
	else
	{
		inkPoint cursor = canvas->cursor;
		controlA = inkPointAdd(inkPointSubtract(cursor, canvas->previousControl), cursor);
		controlB = inkPosition(canvas, controlB, relative);
	}

	anchor = inkPosition(canvas, anchor, relative);

	inkCubicCurveToCommand command;
	command.controlA = controlA;
	command.controlB = controlB;
	command.anchor = anchor;

	inkAddCommand(canvas, inkCommandType_CubicCurveTo, &command);

	canvas->previousControl = controlB;
	inkSetCursor(canvas, anchor);
}

void inkBeginFill(inkCanvas* canvas, inkSolidFill solidFill)
{
	inkSolidFillCommand command = solidFill;
	inkAddCommand(canvas, inkCommandType_SolidFill, &command);
}

void inkBeginBitmapFill(inkCanvas* canvas, inkBitmapFill bitmapFill)
{
	inkBitmapFillCommand command = bitmapFill;
	inkAddCommand(canvas, inkCommandType_BitmapFill, &command);
}

void inkBeginGradientFill(inkCanvas* canvas, inkGradientFill gradientFill)
{
	inkGradientFillCommand command = gradientFill;
	inkAddCommand(canvas, inkCommandType_GradientFill, &command);
}

void inkLineStyle(inkCanvas* canvas, inkStroke stroke, inkSolidFill solidFill)
{
	inkLineStyleCommand command;
	command.fill = solidFill;
	command.stroke = stroke;

	inkAddCommand(canvas, inkCommandType_LineStyle, &command);
}

void inkLineBitmapStyle(inkCanvas* canvas, inkBitmapFill bitmapFill)
{
	inkBitmapFillCommand command = bitmapFill;

	inkAddCommand(canvas, inkCommandType_LineBitmap, &command);
}

void inkLineGradientStyle(inkCanvas* canvas, inkGradientFill gradientFill)
{
	inkLineGradientCommand command = gradientFill;

	inkAddCommand(canvas, inkCommandType_LineGradient, &command);
}

void inkWindingStyle(inkCanvas* canvas, inkWindingRule winding)
{
	inkWindingCommand command = winding;

	inkAddCommand(canvas, inkCommandType_Winding, &command);
}

void inkUserData(inkCanvas* canvas, void* userData)
{
	inkUserDataCommand command = userData;

	inkAddCommand(canvas, inkCommandType_UserData, &command);
}

void inkEndFill(inkCanvas* canvas)
{
	inkAddCommand(canvas, inkCommandType_EndFill, NULL);
}

void inkLineStyleNone(inkCanvas* canvas)
{
	inkLineStyle(canvas, inkStrokeDefault, inkSolidFillDefault);
}

void inkEndGenerators(inkFillGenerator** fillGeneratorPtr, inkStrokeGenerator** strokeGeneratorPtr)
{
	if (fillGeneratorPtr)
	{
		// Must be destroyed before we end the stroke generator
		inkFillGeneratorEnd(*fillGeneratorPtr);
		inkFillGeneratorDestroy(*fillGeneratorPtr);
		*fillGeneratorPtr = NULL;
	}

	if (strokeGeneratorPtr)
	{
		// Must be done after we destroy the fill generator.
		inkStrokeGeneratorEnd(*strokeGeneratorPtr);
		inkStrokeGeneratorDestroy(*strokeGeneratorPtr);
		*strokeGeneratorPtr = NULL;
	}
}

inkPoint inkUpdatePositionv(inkPoint point, void* canvas)
{
	return point;
//	return inkUpdatePosition((inkCanvas*)canvas, point);
}

inkPoint inkUpdatePosition(inkCanvas* canvas, inkPoint point)
{
	assert(canvas != NULL);

	return inkMatrixTransformPoint(canvas->matrix, point);
}

void inkInternalLineTo(inkCanvas* canvas, inkPoint point, inkFillGenerator* fillGenerator, inkStrokeGenerator* strokeGenerator, bool isCurve)
{
	assert(canvas != NULL);

	if (canvas->totalLength >= canvas->maxLength || inkIsZerof(canvas->maxLength))
		return;

	float additionalDistance = inkPointDistance(point, canvas->cursor);

	if (canvas->maxLength != FLT_MAX && inkIsZerof(additionalDistance) == false)
	{
		if (canvas->totalLength + additionalDistance >= canvas->maxLength)
		{
			float percent = (canvas->maxLength - canvas->totalLength) / additionalDistance;
			point = inkPointInterpolate(canvas->cursor, point, percent);
		}
	}

	inkFillGeneratorLineTo(fillGenerator, point, isCurve);
	inkStrokeGeneratorLineTo(strokeGenerator, point, isCurve);

	canvas->totalLength += additionalDistance;
	canvas->cursor = point;
}

void inkCurveAdd(inkPoint point, void* userData)
{
	if (userData == NULL)
		return;

	inkInternalLineTo(((inkCurveGenerators*)userData)->canvas, point, ((inkCurveGenerators*)userData)->fillGenerator, ((inkCurveGenerators*)userData)->strokeGenerator, true);
}

void inkCurve(inkCanvas* canvas, inkFillGenerator* fillGenerator, inkStrokeGenerator* strokeGenerator, inkCurveType curveType, inkPoint controlA, inkPoint controlB, inkPoint anchor)
{
	inkPoint start;

	if (fillGenerator != NULL && fillGenerator->generator != NULL)
		start = fillGenerator->generator->previous;
	else if (strokeGenerator != NULL && strokeGenerator->generator != NULL)
		start = strokeGenerator->generator->previous;
	else
		return;

	float arcLength = inkCurveLength(curveType, start, controlA, controlB, anchor);

	if (isnan(arcLength))
		assert(arcLength);

	inkCurveGenerators generators;
	generators.canvas = canvas;
	generators.fillGenerator = fillGenerator;
	generators.strokeGenerator = strokeGenerator;

	inkCurveApproximation(curveType, start, controlA, controlB, anchor, inkArcLengthSegmentCount(canvas, arcLength), inkCurveAdd, (void*)(&generators));
}

void inkFadeStrategyRenderGroups(inkCanvas* canvas, float red, float green, float blue, float alpha)
{
	assert(canvas != NULL);

	if (canvas->incompleteFillStrategy != inkIncompleteDrawStrategy_Fade &&
		canvas->incompleteStrokeStrategy != inkIncompleteDrawStrategy_Fade)
	{
		return;
	}

	inkArray* renderGroups = inkRenderGroups(canvas);

	if (renderGroups == NULL)
		return;

	inkRenderGroup* renderGroup;
	inkArray* vertexArray;
	inkVertex* vertex;

	inkArrayPtrForEach(renderGroups, renderGroup)
	{
		if (renderGroup->isStroke == false && canvas->incompleteFillStrategy != inkIncompleteDrawStrategy_Fade)
			continue;

		if (renderGroup->isStroke == true && canvas->incompleteStrokeStrategy != inkIncompleteDrawStrategy_Fade)
			continue;

		vertexArray = renderGroup->vertices;

		inkArrayForEach(vertexArray, vertex)
		{
			vertex->color.r *= red;
			vertex->color.g *= green;
			vertex->color.b *= blue;
			vertex->color.a *= alpha;
		}
	}
}

void inkHandleIncompleteGenerator(inkCanvas* canvas, inkGenerator* generator, inkIncompleteDrawStrategy strategy, float alphaMult)
{
	assert(generator != NULL);

	switch(strategy)
	{
		case inkIncompleteDrawStrategy_None:
			inkGeneratorRemoveAllVertices(generator);
			break;
		case inkIncompleteDrawStrategy_Fade:
		{
			inkGeneratorMultColor(generator, 1.0f, 1.0f, 1.0f, alphaMult);
		}
			break;
		case inkIncompleteDrawStrategy_Full:
			break;
		default:
			break;
	}
}

void inkHandleIncompleteDraw(inkCanvas* canvas, inkFillGenerator* fillGenerator, inkStrokeGenerator* strokeGenerator)
{
	assert(canvas != NULL);

	float alphaMult = 0.0f;
	if (canvas->overDrawAllowance != 0.0f)
	{
		canvas->overDrawAllowance = (canvas->totalLength - canvas->maxLength) / canvas->overDrawAllowance;
		alphaMult = fmaxf(0.0f, fminf(alphaMult, 1.0f));
	}

	if (fillGenerator != NULL)
	{
		inkHandleIncompleteGenerator(canvas, fillGenerator->generator, canvas->incompleteFillStrategy, alphaMult);
	}

	if (strokeGenerator != NULL)
	{
		inkHandleIncompleteGenerator(canvas, strokeGenerator->generator, canvas->incompleteStrokeStrategy, alphaMult);
	}

	inkFadeStrategyRenderGroups(canvas, 1.0f, 1.0f, 1.0f, alphaMult);
}

// ONLY call this method on the main thread as it uses a non-thread safe shared
// tessellator.
void inkBuild(inkCanvas* canvas)
{
	assert(canvas != NULL);

	inkRemoveAllRenderGroups(canvas);

	inkArray* commandList = canvas->commandList;
	void* commandData;
	inkCommand* command;
	inkCommandType commandType;
	inkFillGenerator* fillGenerator = NULL;
	inkStrokeGenerator* strokeGenerator = NULL;

	inkTessellator* fillTessellator = canvas->fillTessellator;
	inkTessellator* strokeTessellator = canvas->strokeTessellator;

	inkArrayPtrForEach(commandList, command)
	{
		commandType = command->type;
		commandData = command->data;

		switch(commandType)
		{
			case inkCommandType_MoveTo:
			{
				inkMoveToCommand* command = (inkPoint*)(commandData);

				inkPoint point = inkUpdatePosition(canvas, *command);
				inkFillGeneratorMoveTo(fillGenerator, point);
				inkStrokeGeneratorMoveTo(strokeGenerator, point);
				canvas->cursor = point;
			}
				break;
			case inkCommandType_LineTo:
			{
				inkLineToCommand* command = (inkPoint*)(commandData);

				inkPoint point = inkUpdatePosition(canvas, *command);
				inkInternalLineTo(canvas, point, fillGenerator, strokeGenerator, false);
			}
				break;
			case inkCommandType_QuadraticCurveTo:
			{
				inkQuadraticCurveToCommand* command = (inkQuadraticCurveToCommand*)(commandData);

				inkPoint control = inkUpdatePosition(canvas, command->control);
				inkPoint anchor = inkUpdatePosition(canvas, command->anchor);
				inkCurve(canvas, fillGenerator, strokeGenerator, inkCurveType_Quadratic, inkPointZero, control, anchor);
			}
				break;
			case inkCommandType_CubicCurveTo:
			{
				inkCubicCurveToCommand* command = (inkCubicCurveToCommand*)(commandData);

				inkPoint controlA = inkUpdatePosition(canvas, command->controlA);
				inkPoint controlB = inkUpdatePosition(canvas, command->controlB);
				inkPoint anchor = inkUpdatePosition(canvas, command->anchor);
				inkCurve(canvas, fillGenerator, strokeGenerator, inkCurveType_Cubic, controlA, controlB, anchor);
			}
				break;
			case inkCommandType_SolidFill:
			{
				inkEndGenerators(&fillGenerator, NULL);

				inkSolidFillCommand* fill = (inkSolidFillCommand*)(commandData);

				fillGenerator = inkFillGeneratorCreate(fillTessellator, canvas->renderGroups, fill, inkMatrixInvert(canvas->matrix));
			}
				break;
			case inkCommandType_BitmapFill:
			{
				inkEndGenerators(&fillGenerator, NULL);

				inkBitmapFillCommand* fill = (inkBitmapFillCommand*)(commandData);

				fillGenerator = inkFillGeneratorCreate(fillTessellator, canvas->renderGroups, fill, inkMatrixInvert(canvas->matrix));
			}
				break;
			case inkCommandType_GradientFill:
			{
				inkEndGenerators(&fillGenerator, NULL);

				inkGradientFillCommand* fill = (inkGradientFillCommand*)(commandData);

				fillGenerator = inkFillGeneratorCreate(fillTessellator, canvas->renderGroups, fill, inkMatrixInvert(canvas->matrix));
			}
				break;
			case inkCommandType_LineStyle:
			{
				inkEndGenerators(NULL, &strokeGenerator);

				inkLineStyleCommand* command = (inkLineStyleCommand*)(commandData);

				if (!isnan(command->stroke.thickness))
				{
					if (command->stroke.scaleMode == inkLineScaleMode_None)
					{
						command->stroke.thickness = command->stroke.origThickness;
					}
					else
					{
						inkSize scale = inkMatrixSize(canvas->matrix);
						float val = fabsf(command->stroke.origThickness);
						inkPoint thickness = inkPointMake(val, val);
						thickness = inkPointMultiply(thickness, inkPointFromSize(scale));

						thickness.x = fabsf(thickness.x);
						thickness.y = fabsf(thickness.y);

						switch(command->stroke.scaleMode)
						{
							case inkLineScaleMode_None:
								break;
							case inkLineScaleMode_Horizontal:
								command->stroke.thickness = thickness.y;
								break;
							case inkLineScaleMode_Vertical:
								command->stroke.thickness = thickness.x;
								break;
							case inkLineScaleMode_Normal:
								command->stroke.thickness = (thickness.x + thickness.y) * 0.5f;
								break;
							default:
								break;
						}
					}

					if (command->stroke.pixelHinting == true)
					{
						float minThickness = 1.0f / inkGetPixelsPerPoint(canvas);
						command->stroke.thickness = inkRoundToNearestf(command->stroke.thickness, minThickness);
						command->stroke.thickness = fmaxf(minThickness, command->stroke.thickness);
					}

					strokeGenerator = inkStrokeGeneratorCreate(strokeTessellator, canvas, canvas->renderGroups, &(command->stroke), inkMatrixInvert(canvas->matrix));
					inkStrokeGeneratorSetFill(strokeGenerator, &(command->fill), inkMatrixInvert(canvas->matrix));
				}
			}
				break;
			case inkCommandType_LineBitmap:
			{
				inkLineBitmapCommand* command = (inkLineBitmapCommand*)(commandData);

				// Setting the fill will properly concat the vertices on
				inkStrokeGeneratorSetFill(strokeGenerator, command, inkMatrixInvert(canvas->matrix));
			}
				break;
			case inkCommandType_LineGradient:
			{
				inkLineGradientCommand* command = (inkLineGradientCommand*)(commandData);

				// Setting the fill will properly concat the vertices on
				inkStrokeGeneratorSetFill(strokeGenerator, command, inkMatrixInvert(canvas->matrix));
			}
				break;
			case inkCommandType_Winding:
			{
				inkWindingCommand* command = (inkWindingCommand*)(commandData);

				inkTessellatorSetWindingRule(fillTessellator, *command);
				inkTessellatorSetWindingRule(strokeTessellator, *command);
			}
				break;
			case inkCommandType_UserData:
			{
				inkUserDataCommand* command = (inkUserDataCommand*)(commandData);

				inkTessellatorSetUserData(fillTessellator, *command);
				inkTessellatorSetUserData(strokeTessellator, *command);
			}
				break;
			case inkCommandType_EndFill:
				inkEndGenerators(&fillGenerator, NULL);
				if (strokeGenerator)
				{
					inkStrokeGeneratorEnd(strokeGenerator);
					inkGeneratorRemoveAllVertices(strokeGenerator->generator);
				}
				break;
			default:
				break;
		}

		if (canvas->totalLength >= canvas->maxLength)
		{
			inkHandleIncompleteDraw(canvas, fillGenerator, strokeGenerator);
			break;
		}
	}

	inkEndGenerators(&fillGenerator, &strokeGenerator);

	canvas->cursor = inkPointZero;

	inkArray* renderGroups = inkRenderGroups(canvas);

	if (renderGroups == NULL)
	{
		canvas->bounds = inkRectZero;
		return;
	}

	inkRenderGroup* renderGroup;
	inkArray* vertexArray;
	inkVertex* vertex;
	unsigned int vertexCount;

	inkPoint minPoint = inkPointMax;
	inkPoint maxPoint = inkPointMin;
	inkPoint minPointWithStroke = inkPointMax;
	inkPoint maxPointWithStroke = inkPointMin;

//	unsigned int totalVerticesBeforeStrips = 0;
//	unsigned int totalVerticesAsStrips = 0;
//	unsigned int totalVerticesAsElements = 0;

	inkArrayPtrForEach(renderGroups, renderGroup)
	{
		vertexArray = renderGroup->vertices;
		vertexCount = inkArrayCount(vertexArray);
		//totalVerticesBeforeStrips += vertexCount;

		if (vertexCount == 0)
			continue;

		inkArrayForEach(vertexArray, vertex)
		{
			if (renderGroup->isStroke == false)
			{
				minPoint = inkPointMake(fminf(minPoint.x, vertex->pos.x), fminf(minPoint.y, vertex->pos.y));
				maxPoint = inkPointMake(fmaxf(maxPoint.x, vertex->pos.x), fmaxf(maxPoint.y, vertex->pos.y));
			}

			minPointWithStroke = inkPointMake(fminf(minPointWithStroke.x, vertex->pos.x), fminf(minPointWithStroke.y, vertex->pos.y));
			maxPointWithStroke = inkPointMake(fmaxf(maxPointWithStroke.x, vertex->pos.x), fmaxf(maxPointWithStroke.y, vertex->pos.y));
		}

		if (inkGetConvertTrianglesIntoStrips(canvas) == true)
		{
			inkRenderGroupConvertToStrips(renderGroup);
			inkRenderGroupConvertToElements(renderGroup);
		}

//		totalVerticesAsStrips += inkArrayCount(renderGroup->vertices);
		//inkRenderGroupConvertToElements(renderGroup);
	}

	//if (inkGetConvertTrianglesIntoStrips(canvas) == true)
	/*{
		inkArrayPtrForEach(renderGroups, renderGroup)
		{
			assert(renderGroup->glDrawMode == GL_TRIANGLE_STRIP);

			inkRenderGroupConvertToElements(renderGroup);
		//	totalVerticesAsElements += inkArrayCount(renderGroup->vertices);
		}
	}*/

	//printf("orig = %u, strips = %u, elements = %u\n", totalVerticesBeforeStrips, totalVerticesAsStrips, totalVerticesAsElements);

	canvas->bounds = inkRectMake(minPoint, inkSizeFromPoint(inkPointSubtract(maxPoint, minPoint)));
	canvas->boundsWithStroke = inkRectMake(minPointWithStroke, inkSizeFromPoint(inkPointSubtract(maxPointWithStroke, minPointWithStroke)));
}

inkRenderGroup* inkContainsPoint(inkCanvas* canvas, inkPoint point, bool useBoundingBox, bool useStroke)
{
	inkArray* renderGroups = inkRenderGroups(canvas);

	if (renderGroups == NULL)
		return NULL;

	inkRenderGroup* renderGroup;
	inkArray* vertexArray;
	inkVertex* vertex;
	inkTriangle triangle = inkTriangleZero;
	inkPoint firstPoint;

	unsigned int index;
	unsigned int vertexCount;

	inkRect bounds = useStroke ? canvas->boundsWithStroke : canvas->bounds;

	if (inkRectContainsPoint(bounds, point) == false)
		return NULL;
	else if (useBoundingBox == true)
		return inkArrayElementAt(renderGroups, 0);

	inkArrayPtrForEach(renderGroups, renderGroup)
	{
		vertexArray = renderGroup->vertices;
		vertexCount = inkArrayCount(vertexArray);

		if (vertexCount == 0)
			continue;
		if (renderGroup->isStroke == true && useStroke == false)
			continue;

		//index = 0;

		firstPoint = *((inkPoint*)inkArrayElementAt(vertexArray, 0));
		triangle.pointC = *((inkPoint*)inkArrayElementAt(vertexArray, vertexCount - 1));

		inkArrayForEachv(vertexArray, vertex, index = 0, ++index)
		{
			triangle.pointA = triangle.pointB;
			triangle.pointB = triangle.pointC;
			triangle.pointC = inkPointMake(vertex->pos.x, vertex->pos.y);

			switch(renderGroup->glDrawMode)
			{
		// POINTS
				case GL_POINTS:
					if (inkPointIsEqual(triangle.pointC, point))
						return renderGroup;
					break;

		// LINES
				case GL_LINES:
					if (index % 2 == 0)
						break; // must break so index iterates
				case GL_LINE_STRIP:
					if (index == 0)
						break; // must break so index iterates
				case GL_LINE_LOOP:
					// At index  0, point B will be the last point, and pointC
					// will be the first point, thus checking loop.
					if (inkLineContainsPoint(inkLineMake(triangle.pointB, triangle.pointC), point))
						return renderGroup;

					break;

		// TRIANGLES
				case GL_TRIANGLES:
					if (index % 3 != 0)
						break;
				case GL_TRIANGLE_FAN:
					if (renderGroup->glDrawMode == GL_TRIANGLE_FAN)
						triangle.pointA = firstPoint;
				case GL_TRIANGLE_STRIP:
					if (index < 2)
						break; // must break so index iterates

					if (inkTriangleContainsPoint(triangle, point))
					{
						inkTriangleContainsPoint(triangle, point);
						return renderGroup;
					}

					break;
			}
		}
	}

	return NULL;
}

void inkPushMatrix(inkCanvas* canvas)
{
	assert(canvas != NULL);

	inkMatrix* matrixPtr = inkArrayPush(canvas->matrixStack);

	if (matrixPtr != NULL)
	{
		*matrixPtr = canvas->matrix;
	}
}

void inkPopMatrix(inkCanvas* canvas)
{
	assert(canvas != NULL);

	inkArrayPop(canvas->matrixStack);

	unsigned int count = inkArrayCount(canvas->matrixStack);

	if (count == 0)
	{
		canvas->matrix = inkMatrixIdentity;
	}
	else
	{
		inkArrayElementAt(canvas->matrixStack, count - 1);
	}
}

void inkLoadMatrix(inkCanvas* canvas, inkMatrix matrix)
{
	assert(canvas != NULL);

	canvas->matrix = matrix;
}

void inkMultMatrix(inkCanvas* canvas, inkMatrix matrix)
{
	assert(canvas != NULL);

	canvas->matrix = inkMatrixMultiply(canvas->matrix, matrix);
}

void inkRotate(inkCanvas* canvas, float radians)
{
	assert(canvas != NULL);

	canvas->matrix = inkMatrixRotate(canvas->matrix, radians);
}

void inkRotatef(inkCanvas* canvas, float radians)
{
	return inkRotate(canvas, radians);
}

void inkScale(inkCanvas* canvas, inkSize scale)
{
	assert(canvas != NULL);

	canvas->matrix = inkMatrixScale(canvas->matrix, scale);
}

void inkScalef(inkCanvas* canvas, float x, float y)
{
	inkScale(canvas, inkSizeMake(x, y));
}

void inkTranslate(inkCanvas* canvas, inkPoint offset)
{
	assert(canvas != NULL);

	canvas->matrix = inkMatrixTranslate(canvas->matrix, offset);
}

void inkTranslatef(inkCanvas* canvas, float x, float y)
{
	inkTranslate(canvas, inkPointMake(x, y));
}

void inkDrawCompareAndSetStates(inkRenderer* renderer, inkPresetGLData* origState, inkPresetGLData* stateIn, inkPresetGLData* newState)
{
	assert(renderer != NULL);
	assert(origState != NULL);
	assert(stateIn != NULL);
	assert(newState != NULL);

/*#ifdef GL_POINT_SIZE
	if (renderer->pointSizeFunc != NULL && stateIn->pointSize != newState->pointSize)
		renderer->pointSizeFunc(newState->pointSize);
#endif

#ifdef GL_LINE_WIDTH
	if (renderer->lineWidthFunc != NULL && stateIn->lineWidth != newState->lineWidth)
		renderer->lineWidthFunc(newState->lineWidth);
#endif*/

	if (stateIn->textureName != newState->textureName)
	{
		if (stateIn->textureName != 0)
		{
			if (origState->magFilter != stateIn->magFilter)
				renderer->setTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, stateIn->magFilter);
			if (origState->minFilter != stateIn->minFilter)
				renderer->setTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, stateIn->minFilter);
			if (origState->wrapS != stateIn->wrapS)
				renderer->setTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, stateIn->wrapS);
			if (origState->wrapT != stateIn->wrapT)
				renderer->setTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, stateIn->wrapT);
		}

		if (newState->textureName != 0)
		{
			renderer->disableClientFunc(GL_COLOR_ARRAY);
			renderer->enableClientFunc(GL_TEXTURE_COORD_ARRAY);

			renderer->enableFunc(GL_TEXTURE_2D);
			renderer->textureFunc(GL_TEXTURE_2D, newState->textureName);

			renderer->getTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, &origState->magFilter);
			renderer->getTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, &origState->minFilter);
			renderer->getTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, &origState->wrapS);
			renderer->getTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, &origState->wrapT);

			if (origState->magFilter != newState->magFilter)
				renderer->setTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, newState->magFilter);
			if (origState->minFilter != newState->minFilter)
				renderer->setTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, newState->minFilter);
			if (origState->wrapS != newState->wrapS)
				renderer->setTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, newState->wrapS);
			if (origState->wrapT != newState->wrapT)
				renderer->setTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, newState->wrapT);
		}
		else
		{
			renderer->disableFunc(GL_TEXTURE_2D);
			renderer->enableClientFunc(GL_COLOR_ARRAY);
			renderer->disableClientFunc(GL_TEXTURE_COORD_ARRAY);
		}
	}

	*stateIn = *newState;
}

unsigned int inkDraw(inkCanvas* canvas)
{
	return inkDrawv(canvas, (inkRenderer*)&inkRendererDefault);
}

unsigned int inkDrawv(inkCanvas* canvas, inkRenderer* renderer)
{
	assert(canvas != NULL);
	assert(renderer != NULL);

	assert(renderer->enableFunc);
	assert(renderer->disableFunc);
	assert(renderer->enableClientFunc);
	assert(renderer->disableClientFunc);
	assert(renderer->getBooleanFunc);
	assert(renderer->getFloatFunc);
	assert(renderer->getIntegerFunc);
	//assert(renderer->pointSizeFunc); // Optional
	//assert(renderer->lineWidthFunc); // Optional
	assert(renderer->textureFunc);
	assert(renderer->getTexParamFunc);
	assert(renderer->setTexParamFunc);
	assert(renderer->vertexFunc); 
	assert(renderer->textureCoordinateFunc);
	assert(renderer->colorFunc);
	assert(renderer->drawArraysFunc);
	assert(renderer->drawElementsFunc);

	inkArray* renderGroups = inkRenderGroups(canvas);

	if (renderGroups == NULL)
		return 0;

	inkRenderGroup* renderGroup;
	inkArray* vertexArray;
	inkVertex* vertices;

	unsigned int vertexArrayCount;
	unsigned int totalVertexCount = 0;

	inkPresetGLData startedGLData;
	inkPresetGLData previousGLData;
	inkPresetGLData origGLData;
	startedGLData.textureName = 0;

	if (renderer->isEnabledFunc(GL_TEXTURE_2D))
	{
		renderer->getIntegerFunc(GL_TEXTURE_BINDING_2D, (int*)&startedGLData.textureName);
	}

	if (startedGLData.textureName != 0)
	{
		renderer->getTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, &startedGLData.magFilter);
		renderer->getTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, &startedGLData.minFilter);
		renderer->getTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, &startedGLData.wrapS);
		renderer->getTexParamFunc(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, &startedGLData.wrapT);

		renderer->disableClientFunc(GL_COLOR_ARRAY);
		renderer->enableClientFunc(GL_TEXTURE_COORD_ARRAY);

		renderer->enableFunc(GL_TEXTURE_2D);
	}
	else
	{
		renderer->disableFunc(GL_TEXTURE_2D);
		renderer->enableClientFunc(GL_COLOR_ARRAY);
		renderer->disableClientFunc(GL_TEXTURE_COORD_ARRAY);
	}

/*#ifdef GL_POINT_SIZE
	renderer->getFloatFunc(GL_POINT_SIZE, &startedGLData.pointSize);
#endif
#ifdef GL_LINE_WIDTH
	renderer->getFloatFunc(GL_LINE_WIDTH, &startedGLData.lineWidth);
#endif*/

	previousGLData = startedGLData;
	origGLData = startedGLData;

	inkArrayPtrForEach(renderGroups, renderGroup)
	{
		vertexArray = renderGroup->vertices;
		vertexArrayCount = inkArrayCount(vertexArray);

		if (vertexArray == NULL || vertexArrayCount == 0)
			continue;

		inkDrawCompareAndSetStates(renderer, &origGLData, &previousGLData, &renderGroup->glData);

		if (vertexArray != NULL)
		{
			vertices = (inkVertex*)(vertexArray->elements);

			totalVertexCount += vertexArrayCount;

			renderer->vertexFunc(2, GL_FLOAT, sizeof(inkVertex), &(vertices->pos));
			renderer->textureCoordinateFunc(2, GL_FLOAT, sizeof(inkVertex), &(vertices->tex));
			renderer->colorFunc(4, GL_UNSIGNED_BYTE, sizeof(inkVertex), &(vertices->color));

			switch(renderGroup->glDrawType)
			{
				case inkDrawType_Arrays:
					renderer->drawArraysFunc(renderGroup->glDrawMode, 0, vertexArrayCount);
					break;
				case inkDrawType_Elements:
				{
					unsigned int indexCount = inkArrayCount(renderGroup->indices);
					if (indexCount == 0)
						break;

					unsigned short* indices = (unsigned short*)(renderGroup->indices->elements);
					renderer->drawElementsFunc(renderGroup->glDrawMode, indexCount, GL_UNSIGNED_SHORT, indices);
				}
					break;
				default:
					break;
			}
		}
	}

	inkDrawCompareAndSetStates(renderer, &origGLData, &previousGLData, &startedGLData);

	return totalVertexCount;
}
