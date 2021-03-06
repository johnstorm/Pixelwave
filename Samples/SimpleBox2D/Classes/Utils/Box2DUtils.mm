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

#import "Box2DUtils.h"
#import "Box2DListeners.h"

@interface Box2DUtils(Private)
+ (b2Body *)bodyInWorld:(b2World *)physicsWorld
			withBodyDef:(b2BodyDef *)bodyDef
			 fixtureDef:(b2FixtureDef *)fixtureDef
				 shape0:(b2Shape *)shape0
			 shapesList:(va_list)list;
@end

@implementation Box2DUtils

#pragma mark -
#pragma mark Base Functions

+ (b2Body *)bodyInWorld:(b2World *)physicsWorld
			withBodyDef:(b2BodyDef *)bodyDef
			 fixtureDef:(b2FixtureDef *)fixtureDef
				 shapes:(b2Shape *)shape0, ...
{
	va_list args;
	va_start(args, shape0);

	b2Body *body = [Box2DUtils bodyInWorld:physicsWorld
							   withBodyDef:bodyDef
								fixtureDef:fixtureDef
									shape0:shape0
								shapesList:args];

	va_end(args);

	return body;
}

+ (b2Fixture *)fixtureInWorld:(b2World *)physicsWorld
						  atX:(float)xInPoints
							y:(float)yInPoints
{
	b2Vec2 pos = b2Vec2_px2m(xInPoints, yInPoints);

	b2AABB aabb;
	float touchRadius = 32.0f;
	b2Vec2 size_2 = b2Vec2_px2m(touchRadius, touchRadius);
	aabb.lowerBound = pos - size_2;
	aabb.upperBound = pos + size_2;

	// Query the world for overlapping shapes.
	QueryCallback callback(pos);

	physicsWorld->QueryAABB(&callback, aabb);

	return callback.m_fixture;
}

#pragma mark -
#pragma mark Utilities

+ (b2Body *)staticBodyInWorld:(b2World *)physicsWorld
				 withFriction:(float)friction
				  restitution:(float)restitution
					   shapes:(b2Shape *)shape0, ...
{
	b2BodyDef bodyDef;

	b2FixtureDef fixtureDef;
	fixtureDef.friction = friction;
	fixtureDef.restitution = restitution;

	va_list args;
	va_start(args, shape0);

	b2Body *body = [Box2DUtils bodyInWorld:physicsWorld
							   withBodyDef:&bodyDef
								fixtureDef:&fixtureDef
									shape0:shape0
								shapesList:args];

	va_end(args);

	return body;
}

+ (b2Body *)staticBodyInWorld:(b2World *)physicsWorld
				 withFriction:(float)friction
				  restitution:(float)restitution
					    shape:(b2Shape *)shape
{
	b2BodyDef bodyDef;
	b2FixtureDef fixtureDef;
	fixtureDef.friction = friction;
	fixtureDef.restitution = restitution;

	return [Box2DUtils bodyInWorld:physicsWorld
					   withBodyDef:&bodyDef
						fixtureDef:&fixtureDef
							shapes:shape, nil];
}

+ (b2Body *)staticBodyInWorld:(b2World *)physicsWorld
					withShape:(b2Shape *)shape
{
	b2BodyDef bodyDef;
	b2FixtureDef fixtureDef;

	return [Box2DUtils bodyInWorld:physicsWorld
					   withBodyDef:&bodyDef
						fixtureDef:&fixtureDef
							shapes:shape, nil];
}

+ (b2Body *)dynamicBodyInWorld:(b2World *)physicsWorld
				  withFriction:(float)friction
				   restitution:(float)restitution
						shapes:(b2Shape *)shape0, ...
{
	b2BodyDef bodyDef;
	bodyDef.type = b2_dynamicBody;

	b2FixtureDef fixtureDef;
	fixtureDef.friction = friction;
	fixtureDef.restitution = restitution;
	fixtureDef.density = 1.0f;

	va_list args;
	va_start(args, shape0);

	b2Body *body = [Box2DUtils bodyInWorld:physicsWorld
							   withBodyDef:&bodyDef
								fixtureDef:&fixtureDef
									shape0:shape0
								shapesList:args];

	va_end(args);

	return body;
}
+ (b2Body *)dynamicBodyInWorld:(b2World *)physicsWorld
				  withFriction:(float)friction
				   restitution:(float)restitution
						 shape:(b2Shape *)shape
{
	b2BodyDef bodyDef;
	bodyDef.type = b2_dynamicBody;

	b2FixtureDef fixtureDef;
	fixtureDef.friction = friction;
	fixtureDef.restitution = restitution;
	fixtureDef.density = 1.0f;

	return [Box2DUtils bodyInWorld:physicsWorld
					   withBodyDef:&bodyDef
						fixtureDef:&fixtureDef
							shapes:shape, nil];
}
+ (b2Body *)dynamicBodyInWorld:(b2World *)physicsWorld
					 withShape:(b2Shape *)shape
{
	b2BodyDef bodyDef;
	bodyDef.type = b2_dynamicBody;
	b2FixtureDef fixtureDef;
	fixtureDef.density = 1.0f;

	return [Box2DUtils bodyInWorld:physicsWorld
					   withBodyDef:&bodyDef
						fixtureDef:&fixtureDef
							shapes:shape, nil];
}

+ (b2Body *)staticBorderInWorld:(b2World *)physicsWorld
						   rect:(PXRectangle *)rect
					  thickness:(float)thickness
{
	// Convert all the values to meters
	float halfWidth = PointsToMeters(rect.width * 0.5f);
	float halfHeight = PointsToMeters(rect.height * 0.5f);

	float left = PointsToMeters(rect.left);
	float right = PointsToMeters(rect.right);
	float top = PointsToMeters(rect.top);
	float bottom = PointsToMeters(rect.bottom);

	thickness = PointsToMeters(thickness);

	// Create a body to hold the border shapes
	b2BodyDef bodyDef;
	b2Body *body = physicsWorld->CreateBody(&bodyDef);

	// Create all the shapes
	b2PolygonShape box;
	b2FixtureDef fixtureDef;

	fixtureDef.shape = &box;

	// Bottom
	box.SetAsBox(halfWidth, thickness, b2Vec2(left + halfWidth, bottom), 0.0f);
	body->CreateFixture(&fixtureDef);

	// Top
	box.SetAsBox(halfWidth, thickness, b2Vec2(left + halfWidth, top), 0.0f);
	body->CreateFixture(&fixtureDef);

	// Left
	box.SetAsBox(thickness, halfHeight, b2Vec2(left, top + halfHeight), 0.0f);
	body->CreateFixture(&fixtureDef);

	// Right
	box.SetAsBox(thickness, halfHeight, b2Vec2(right, top + halfHeight), 0.0f);
	body->CreateFixture(&fixtureDef);

	return body;
}

#pragma mark -
#pragma mark Private

+ (b2Body *)bodyInWorld:(b2World *)physicsWorld
			withBodyDef:(b2BodyDef *)bodyDef
			 fixtureDef:(b2FixtureDef *)fixtureDef
				 shape0:(b2Shape *)shape0
			 shapesList:(va_list)list
{
	b2Shape *shape = NULL;
	b2Body *body = NULL;

	body = physicsWorld->CreateBody(bodyDef);

	// Loop through the shapes
	for(shape = shape0; shape != nil; shape = va_arg(list, b2Shape *))
	{
		fixtureDef->shape = shape;
		body->CreateFixture(fixtureDef);
	}

	return body;
}

@end
