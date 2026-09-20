#pragma once
#import <Foundation/Foundation.h>

// Keep the selected dictionary in memory: meter updates must not read files.
static NSString *PrismaLanguage = @"en";
static NSDictionary<NSString*,NSString*> *PrismaStrings;
static NSDictionary<NSString*,NSString*> *PrismaJapaneseStrings;
static NSString *PrismaLanguageFor(NSInteger mode, NSArray<NSString*> *preferred) {
 if(mode==1)return @"ja";
 if(mode==2)return @"en";
 for(NSString *identifier in preferred){
  NSString *code=[[[identifier stringByReplacingOccurrencesOfString:@"_" withString:@"-"] componentsSeparatedByString:@"-"][0] lowercaseString];
  if([@[@"ja",@"en"] containsObject:code])return code;
 }
 return @"en";
}
static void PrismaLoadLanguage(NSString *language, NSString *resources) {
 PrismaLanguage=language;
 NSString *path=[[resources stringByAppendingPathComponent:[language stringByAppendingString:@".lproj"]] stringByAppendingPathComponent:@"Localizable.strings"];
 PrismaStrings=[NSDictionary dictionaryWithContentsOfFile:path]?:@{};
 if(!PrismaJapaneseStrings.count)PrismaJapaneseStrings=[NSDictionary dictionaryWithContentsOfFile:[[resources stringByAppendingPathComponent:@"ja.lproj"] stringByAppendingPathComponent:@"Localizable.strings"]]?:@{};
}
static NSString *PL(NSString *key){return PrismaStrings[key]?:key;}
static NSString *PrismaLocalizedError(NSString *error) {
 if(!error.length)return error;
 for(NSString *key in PrismaJapaneseStrings){
  for(NSString *source in @[key,PrismaJapaneseStrings[key]]){
   if([error isEqual:source])return PL(key);
   if([error hasPrefix:[source stringByAppendingString:@" (Core Audio:"]])return [PL(key) stringByAppendingString:[error substringFromIndex:source.length]];
  }
 }
 return error;
}
static BOOL PrismaRefreshLanguage(NSUserDefaults *defaults) {
 NSArray *preferred=[defaults stringArrayForKey:@"AppleLanguages"]?:NSLocale.preferredLanguages;
 NSString *language=PrismaLanguageFor([defaults integerForKey:@"languageMode"],preferred);
 if(PrismaStrings&&[language isEqual:PrismaLanguage])return NO;
 PrismaLoadLanguage(language,NSBundle.mainBundle.resourcePath);
 return YES;
}
static void PrismaSetLanguagePreference(NSUserDefaults *defaults, NSInteger mode) {
 mode=mode>=0&&mode<=2?mode:0;
 [defaults setInteger:mode forKey:@"languageMode"];
 // Apple's own dialogs use the app's language preference on its next launch.
 if(mode==0)[defaults removeObjectForKey:@"AppleLanguages"];
 else [defaults setObject:@[mode==1?@"ja":@"en"] forKey:@"AppleLanguages"];
 PrismaRefreshLanguage(defaults);
}
