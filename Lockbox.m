//
//  Lockbox.m
//
//  Created by Mark H. Granoff on 4/19/12.
//  Copyright (c) 2012 Hawk iMedia. All rights reserved.
//

#import "Lockbox.h"
#import <Security/Security.h>

// Define DLog if user hasn't already defined his own implementation
#ifndef DLog
#ifdef DEBUG
#define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define DLog(...)
#endif
#endif

#define kDelimiter @"-|-"
#define DEFAULT_ACCESSIBILITY kSecAttrAccessibleWhenUnlocked

#if __has_feature(objc_arc)
#define LOCKBOX_ID __bridge id
#define LOCKBOX_DICTREF __bridge CFDictionaryRef
#else
#define LOCKBOX_ID id
#define LOCKBOX_DICTREF CFDictionaryRef
#endif

static NSString *_bundleId = nil;

@implementation Lockbox

+(void)initialize
{
    _bundleId = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:(NSString*)kCFBundleIdentifierKey]; 
}

+(NSMutableDictionary *)_service
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    
    [dict setObject: (LOCKBOX_ID) kSecClassGenericPassword  forKey: (LOCKBOX_ID) kSecClass];

    return dict;
}

+(NSMutableDictionary *)_query
{
    NSMutableDictionary* query = [NSMutableDictionary dictionary];
    
    [query setObject: (LOCKBOX_ID) kSecClassGenericPassword forKey: (LOCKBOX_ID) kSecClass];
    [query setObject: (LOCKBOX_ID) kCFBooleanTrue           forKey: (LOCKBOX_ID) kSecReturnData];

    return query;
}

// Prefix a bare key like "MySecureKey" with the bundle id, so the actual key stored
// is unique to this app, e.g. "com.mycompany.myapp.MySecretKey"
+(NSString *)_hierarchicalKey:(NSString *)key
{
    return [_bundleId stringByAppendingFormat:@".%@", key];
}

+(BOOL)setObject:(NSString *)obj forKey:(NSString *)key accessibility:(CFTypeRef)accessibility {
    return [self setObject:obj forKey:key accessibility:accessibility useAccessControl:NO];
}

+(BOOL)setObject:(NSString *)obj forKey:(NSString *)key accessibility:(CFTypeRef)accessibility useAccessControl:(BOOL)accessControl
{
    OSStatus status;
    
    NSString *hierKey = [self _hierarchicalKey:key];

    // If the object is nil, delete the item
    if (!obj) {
        NSMutableDictionary *query = [self _query];
        [query setObject:hierKey forKey:(LOCKBOX_ID)kSecAttrService];
        status = SecItemDelete((LOCKBOX_DICTREF)query);
        return (status == errSecSuccess);
    }
    
    NSMutableDictionary *dict = [self _service];
    [dict setObject: hierKey forKey: (LOCKBOX_ID) kSecAttrService];
    [dict setObject: [obj dataUsingEncoding:NSUTF8StringEncoding] forKey: (LOCKBOX_ID) kSecValueData];
    
    // If using access control, create an ACL and set the passed accessibility parameter
    if (accessControl) {
        CFErrorRef error = NULL;
        SecAccessControlRef sacObject =
            SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                            accessibility,
                                            kSecAccessControlUserPresence, &error);
        if(sacObject == NULL || error != NULL) {
            NSLog(@"can't create sacObject: %@", error);
            return NO;
        }
        [dict setObject: (LOCKBOX_ID) sacObject forKey: (LOCKBOX_ID) kSecAttrAccessControl];
        [dict setObject:@YES forKey: (LOCKBOX_ID) kSecUseNoAuthenticationUI];
    } else {
        [dict setObject: (LOCKBOX_ID) accessibility forKey: (LOCKBOX_ID) kSecAttrAccessible];
    }
    
    status = SecItemAdd ((LOCKBOX_DICTREF) dict, NULL);
    // We are suppressing the UI for save - will return Not Allowed if passcode set and exists (duplicate)
    // Interaction Not Allowed will also be returned if no passcode set
    if (status == errSecDuplicateItem || status == errSecInteractionNotAllowed) {
        return [self updateObject:obj forKey:key authoriationPrompt:nil];
    }
    if (status != errSecSuccess)
        DLog(@"SecItemAdd failed for key %@: %d", hierKey, (int)status);
    
    return (status == errSecSuccess);
}

+(BOOL)updateObject:(NSString *)obj forKey:(NSString *)key authoriationPrompt:(NSString*)prompt
{
    NSString *hierKey = [self _hierarchicalKey:key];
    NSDictionary *query;
    if (prompt) {
        query = @{
                 (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                 (__bridge id)kSecAttrService: hierKey,
                 (__bridge id)kSecUseOperationPrompt: prompt
                 };
    } else {
        query = @{
                  (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                  (__bridge id)kSecAttrService: hierKey
                  };
    }
    
    NSDictionary *changes = @{
                              (__bridge id)kSecValueData: [obj dataUsingEncoding:NSUTF8StringEncoding]
                              };
    
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)changes);
    
    return (status == errSecSuccess);
}

+(NSString *)objectForKey:(NSString *)key authorizationPrompt:(NSString *)prompt
{
    NSString *hierKey = [self _hierarchicalKey:key];

    NSMutableDictionary *query = [self _query];
    [query setObject:hierKey forKey: (LOCKBOX_ID)kSecAttrService];
    if (prompt) {
        [query setObject: (LOCKBOX_ID) prompt forKey: (LOCKBOX_ID) kSecUseOperationPrompt];
    }

    CFDataRef data = nil;
    OSStatus status =
    SecItemCopyMatching ( (LOCKBOX_DICTREF) query, (CFTypeRef *) &data );
    if (status != errSecSuccess && status != errSecItemNotFound)
        DLog(@"SecItemCopyMatching failed for key %@: %d", hierKey, (int)status);
    
    if (!data)
        return nil;

    NSString *s = [[NSString alloc] 
                    initWithData: 
#if __has_feature(objc_arc)
                   (__bridge_transfer NSData *)data 
#else
                   (NSData *)data
#endif
                    encoding: NSUTF8StringEncoding];

#if !__has_feature(objc_arc)
    [s autorelease];
    CFRelease(data);
#endif
    
    return s;    
}


#pragma mark - Public API


#pragma mark - String

+(BOOL)setString:(NSString *)value forKey:(NSString *)key
{
    return [self setString:value forKey:key accessibility:DEFAULT_ACCESSIBILITY];
}

+(BOOL)setString:(NSString *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility
{
    return [self setObject:value forKey:key accessibility:accessibility];
}

+(BOOL)setString:(NSString *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility useAccessControl:(BOOL)accessControl {
    return [self setObject:value forKey:key accessibility:accessibility useAccessControl:accessControl];
}

+(NSString *)stringForKey:(NSString *)key
{
    return [self stringForKey:key authorizationPrompt:nil];
}

+(NSString *)stringForKey:(NSString *)key authorizationPrompt:(NSString *)prompt
{
    return [self objectForKey:key authorizationPrompt:prompt];
}

#pragma mark - Array

+(BOOL)setArray:(NSArray *)value forKey:(NSString *)key
{
    return [self setArray:value forKey:key accessibility:DEFAULT_ACCESSIBILITY];
}

+(BOOL)setArray:(NSArray *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility
{
    return [self setArray:value forKey:key accessibility:accessibility useAccessControl:NO];
}

+(BOOL)setArray:(NSArray *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility useAccessControl:(BOOL)accessControl
{
    NSString *components = nil;
    if (value != nil && value.count > 0) {
        components = [value componentsJoinedByString:kDelimiter];
    }
    return [self setObject:components forKey:key accessibility:accessibility useAccessControl:accessControl];
}

+(NSArray *)arrayForKey:(NSString *)key
{
    return [self arrayForKey:key authorizationPrompt:nil];
}

+(NSArray *)arrayForKey:(NSString *)key authorizationPrompt:(NSString *)prompt
{
    NSArray *array = nil;
    NSString *components = [self objectForKey:key authorizationPrompt:prompt];
    if (components)
        array = [NSArray arrayWithArray:[components componentsSeparatedByString:kDelimiter]];
    
    return array;
}

#pragma mark - Set

+(BOOL)setSet:(NSSet *)value forKey:(NSString *)key
{
    return [self setSet:value forKey:key accessibility:DEFAULT_ACCESSIBILITY];
}

+(BOOL)setSet:(NSSet *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility
{
    return [self setSet:value forKey:key accessibility:accessibility useAccessControl:NO];
}

+(BOOL)setSet:(NSSet *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility useAccessControl:(BOOL)accessControl
{
    return [self setArray:[value allObjects] forKey:key accessibility:accessibility useAccessControl:accessControl];
}

+(NSSet *)setForKey:(NSString *)key
{
    return [self setForKey:key authorizationPrompt:nil];
}

+(NSSet *)setForKey:(NSString *)key authorizationPrompt:(NSString *)prompt
{
    NSSet *set = nil;
    NSArray *array = [self arrayForKey:key authorizationPrompt:prompt];
    if (array)
        set = [NSSet setWithArray:array];
    
    return set;
}

#pragma mark - Dictionary

+ (BOOL)setDictionary:(NSDictionary *)value forKey:(NSString *)key
{
    return [self setDictionary:value forKey:key accessibility:DEFAULT_ACCESSIBILITY];
}

+ (BOOL)setDictionary:(NSDictionary *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility
{
    return [self setDictionary:value forKey:key accessibility:accessibility useAccessControl:NO];
}

+ (BOOL)setDictionary:(NSDictionary *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility useAccessControl:(BOOL)accessControl
{
    NSMutableArray * keysAndValues = [NSMutableArray arrayWithArray:value.allKeys];
    [keysAndValues addObjectsFromArray:value.allValues];
    
    return [self setArray:keysAndValues forKey:key accessibility:accessibility useAccessControl:accessControl];
}

+ (NSDictionary *)dictionaryForKey:(NSString *)key
{
    return [self dictionaryForKey:key authorizationPrompt:nil];
}

+ (NSDictionary *)dictionaryForKey:(NSString *)key authorizationPrompt:(NSString *)prompt
{
    NSArray * keysAndValues = [self arrayForKey:key authorizationPrompt:prompt];
    
    if (!keysAndValues || keysAndValues.count == 0)
        return nil;
    
    if ((keysAndValues.count % 2) != 0)
    {
        DLog(@"Dictionary for %@ was not saved properly to keychain", key);
        return nil;
    }
    
    NSUInteger half = keysAndValues.count / 2;
    NSRange keys = NSMakeRange(0, half);
    NSRange values = NSMakeRange(half, half);
    return [NSDictionary dictionaryWithObjects:[keysAndValues subarrayWithRange:values]
                                       forKeys:[keysAndValues subarrayWithRange:keys]];
}

#pragma mark - Date

+(BOOL)setDate:(NSDate *)value forKey:(NSString *)key
{
    return [self setDate:value forKey:key accessibility:DEFAULT_ACCESSIBILITY];
}

+(BOOL)setDate:(NSDate *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility
{
    return [self setDate:value forKey:key accessibility:accessibility useAccessControl:NO];
}

+(BOOL)setDate:(NSDate *)value forKey:(NSString *)key accessibility:(CFTypeRef)accessibility useAccessControl:(BOOL)accessControl
{
    if (!value)
        return [self setObject:nil forKey:key accessibility:accessibility];
    NSNumber *rti = [NSNumber numberWithDouble:[value timeIntervalSinceReferenceDate]];
    return [self setObject:[rti stringValue] forKey:key accessibility:accessibility useAccessControl:accessControl];
}

+(NSDate *)dateForKey:(NSString *)key
{
    return [self dateForKey:key authorizationPrompt:nil];
}

+(NSDate *)dateForKey:(NSString *)key authorizationPrompt:(NSString *)prompt
{
    NSString *dateString = [self objectForKey:key authorizationPrompt:prompt];
    if (dateString)
        return [NSDate dateWithTimeIntervalSinceReferenceDate:[dateString doubleValue]];
    return nil;
}

@end
