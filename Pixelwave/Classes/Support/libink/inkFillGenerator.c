//
//  inkFillGenerator.c
//  ink
//
//  Created by John Lattin on 11/8/11.
//  Copyright (c) 2011 Spiralstorm Games. All rights reserved.
//

#include "inkFillGenerator.h"

inkFillGenerator* inkFillGeneratorCreate(inkTessellator* tessellator, inkArray* renderGroups, void* fill, inkMatrix invGLMatrix)
{
	inkFillGenerator* fillGenerator = malloc(sizeof(inkFillGenerator));

	if (fillGenerator != NULL)
	{
		inkGenerator* generator = inkGeneratorCreate(tessellator, fill, invGLMatrix);

		if (generator == NULL)
		{
			inkFillGeneratorDestroy(fillGenerator);
			return NULL;
		}

		fillGenerator->generator = generator;

		inkTessellatorSetGLData(tessellator, inkFillUpdateGLData(fill, inkTessellatorGetGLData(tessellator)));
		inkTessellatorSetInvGLMatrix(tessellator, invGLMatrix);

		inkTessellatorBeginPolygon(tessellator, renderGroups);
	}

	return fillGenerator;
}

void inkFillGeneratorDestroy(inkFillGenerator* fillGenerator)
{
	if (fillGenerator != NULL)
	{
		if (fillGenerator->generator != NULL)
		{
			inkTessellatorEndPolygon(fillGenerator->generator->tessellator);
			inkGeneratorDestroy(fillGenerator->generator);
		}

		free(fillGenerator);
	}
}

void inkFillGeneratorMoveTo(inkFillGenerator* fillGenerator, inkPoint position)
{
	if (fillGenerator == NULL)
		return;

	inkGeneratorMoveTo(fillGenerator->generator, position, NULL, NULL);
}

void inkFillGeneratorLineTo(inkFillGenerator* fillGenerator, inkPoint position, bool isCurve)
{
	if (fillGenerator == NULL)
		return;

	inkGeneratorLineTo(fillGenerator->generator, position, isCurve);
}

void inkFillGeneratorEnd(inkFillGenerator* fillGenerator)
{
	if (fillGenerator == NULL)
		return;

	inkGeneratorEnd(fillGenerator->generator);
}
