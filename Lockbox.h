//
//  Lockbox.h
//
//  Created by Mark H. Granoff on 4/19/12.
//  Copyright (c) 2012 Hawk iMedia. All rights reserved.
//

@interface Lockbox : NSObject

/*
 * For use with TouchID / Passcode, use accessibility value kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
 */

/* String */
+(BOOL)setString:(NSString *)value forKey:(NSString *)key;
+(BOOL)setString:(NSString *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility;
+(NSString *)stringForKey:(NSString *)key;
+(NSString *)stringForKey:(NSString *)key authorizationPrompt:(NSString *)prompt;

/* Array */
+(BOOL)setArray:(NSArray *)value forKey:(NSString *)key;
+(BOOL)setArray:(NSArray *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility;
+(NSArray *)arrayForKey:(NSString *)key;
+(NSArray *)arrayForKey:(NSString *)key authorizationPrompt:(NSString *)prompt;

/* Set */
+(BOOL)setSet:(NSSet *)value forKey:(NSString *)key;
+(BOOL)setSet:(NSSet *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility;
+(NSSet *)setForKey:(NSString *)key;
+(NSSet *)setForKey:(NSString *)key authorizationPrompt:(NSString *)prompt;

/* Dictionary */
+(BOOL)setDictionary:(NSDictionary *)value forKey:(NSString *)key;
+(BOOL)setDictionary:(NSDictionary *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility;
+(NSDictionary *)dictionaryForKey:(NSString *)key;
+(NSDictionary *)dictionaryForKey:(NSString *)key authorizationPrompt:(NSString *)prompt;

/* Date */
+(BOOL)setDate:(NSDate *)value forKey:(NSString *)key;
+(BOOL)setDate:(NSDate *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility;
+(NSDate *)dateForKey:(NSString *)key;
+(NSDate *)dateForKey:(NSString *)key authorizationPrompt:(NSString *)prompt;

@end
