/*
 Copyright (c) 2013, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <AppKit/AppKit.h>

typedef enum {
  kSourceTextViewLanguage_Undefined = 0,
  kSourceTextViewLanguage_C,
  kSourceTextViewLanguage_CPP,
  kSourceTextViewLanguage_JavaScript,
  kSourceTextViewLanguage_Lua,
  kSourceTextViewLanguage_ShellScript
} SourceTextViewLanguage;

@interface SourceTextView : NSTextView {
@private
  SourceTextViewLanguage _language;
  BOOL _showLines;
  NSDictionary* _keywordColors;
  NSColor* _stringColor;
  NSColor* _commentColor;
  NSColor* _preprocessorColor;
  NSColor* _errorColor;
}
+ (NSMutableDictionary*)keywordColorsFromKeywordsPropertyList:(NSString*)path;

@property(nonatomic) SourceTextViewLanguage language;
@property(nonatomic, copy) NSString* source;  // Observe NSTextDidChangeNotification to know when source has been edited
@property(nonatomic) BOOL showLineNumbers;  // YES by default (this also controls wrapping)

@property(nonatomic, copy) NSDictionary* keywordColors;  // Maps keywords to NSColors
@property(nonatomic, copy) NSColor* stringColor;  // Strings are assumed to be '...' or "..."
@property(nonatomic, copy) NSColor* commentColor;  // Comments are assumed to be //... or /* ... */
@property(nonatomic, copy) NSColor* preprocessorColor;  // Preprocessor is assumed to be #...

- (void)setErrorLine:(NSUInteger)line;  // Starts at 1 (automatically cleared on edit or pass 0 to clear manually)
@property(nonatomic, copy) NSColor* errorHighlightColor;
@end

@interface SourceTextView (Actions)
- (void)shiftLeft:(id)sender;
- (void)shiftRight:(id)sender;
@end
