/*
 Copyright (c) 2013-2016, Pierre-Olivier Latour
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

#import "SourceTextView.h"

#define kFontName @"Menlo Regular"
#define kFontSize 11
#define kCharacterWidth 7
#define kLineHeight 13
#define kRulerThickness 38

typedef enum {
  kSourceToken_Code = 0,
  kSourceToken_SingleQuoteString,
  kSourceToken_DoubleQuoteString,
  kSourceToken_LineComment,
  kSourceToken_BlockComment,
  kSourceToken_Preprocessor
} SourceToken;

typedef void (*SourceTokenCallback)(NSString* source, SourceToken token, NSRange range, void* userInfo);

@interface SourceTextView () <NSTextViewDelegate>
@end

@interface SourceRulerView : NSRulerView
@property(nonatomic, assign) SourceTextView* sourceView;
@end

static void _SourceColorizeCallback(NSString* source, SourceToken token, NSRange range, void* userInfo) {
  SourceTextView* view = (__bridge SourceTextView*)userInfo;
  static NSCharacterSet* characters = nil;
  static NSCharacterSet* charactersInverted = nil;
  NSColor* color;
  
  if (characters == nil) {
    characters = [NSCharacterSet characterSetWithCharactersInString:@"0123456789#ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz"];
  }
  if (charactersInverted == nil) {
    charactersInverted = [characters invertedSet];
  }
  
  switch (token) {
    
    case kSourceToken_Code:
    if ([view keywordColors]) {
      NSUInteger start2 = range.location;
      NSUInteger end2 = range.location + range.length;
      while (1) {
        range = [source rangeOfCharacterFromSet:characters options:0 range:NSMakeRange(start2, end2 - start2)];
        if (range.location != NSNotFound) {
          start2 = range.location;
          if (start2 == end2) {
            break;
          }
        }
        
        range = [source rangeOfCharacterFromSet:charactersInverted options:0 range:NSMakeRange(start2, end2 - start2)];
        if (range.location == NSNotFound) {
          range.location = end2;
        }
        if (range.location != start2) {
          NSRange subRange = NSMakeRange(start2, range.location - start2);
          if ((color = [[view keywordColors] objectForKey:[source substringWithRange:subRange]])) {
            [view setTextColor:color range:subRange];
          }
          start2 = range.location;
          if (start2 == end2) {
            break;
          }
        } else {
          break;
        }
      }
    }
    break;
    
    case kSourceToken_SingleQuoteString:
    case kSourceToken_DoubleQuoteString:
    if ((color = [view stringColor])) {
      [view setTextColor:color range:range];
    }
    break;
    
    case kSourceToken_LineComment:
    case kSourceToken_BlockComment:
    if ((color = [view commentColor])) {
      [view setTextColor:color range:range];
    }
    break;
    
    case kSourceToken_Preprocessor:
    if ((color = [view preprocessorColor])) {
      [view setTextColor:color range:range];
    }
    break;
    
  }
}

@implementation SourceRulerView

- (CGFloat)requiredThickness {
  return kRulerThickness;
}

- (void)setSourceView:(SourceTextView*)view {
  _sourceView = view;
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)aRect {
  static NSDictionary* attributes = nil;
  static NSColor* backColor = nil;
  static NSColor* lineColor = nil;
  NSRect bounds = [self bounds];
  
  if (backColor == nil) {
    backColor = [NSColor colorWithDeviceRed:0.90 green:0.90 blue:0.90 alpha:1.0];
  }
  if (lineColor == nil) {
    lineColor = [NSColor grayColor];
  }
  if (attributes == nil) {
    attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor darkGrayColor], NSForegroundColorAttributeName, [NSFont fontWithName:kFontName size:kFontSize], NSFontAttributeName, nil];
  }
  
  [backColor set];
  NSRectFill(aRect);
  [lineColor set];
  NSFrameRect(NSMakeRect(bounds.origin.x + bounds.size.width - 1, aRect.origin.y, 1, aRect.size.height));
  
  NSUInteger start = ([_sourceView visibleRect].origin.y + aRect.origin.y) / kLineHeight + 1;
#if defined(__LP64__) && __LP64__
  CGFloat offset = fmod([_sourceView visibleRect].origin.y + aRect.origin.y, kLineHeight);
#else
  CGFloat offset = fmodf([_sourceView visibleRect].origin.y + aRect.origin.y, kLineHeight);
#endif
  for (NSUInteger i = 0; i < aRect.size.height / kLineHeight + 1; ++i) {
    NSPoint point;
    point.x = (start + i < 10 ? bounds.origin.x + 4 * kCharacterWidth - 1 : (start + i < 100 ? bounds.origin.x + 3 * kCharacterWidth - 1 : (start + i < 1000 ? bounds.origin.x + 2 * kCharacterWidth - 1 : bounds.origin.x + 1 * kCharacterWidth - 1)));
    point.y = (aRect.origin.y / kLineHeight + i) * kLineHeight - offset - 4;
    [[NSString stringWithFormat:@"%lu", (long)(start + i)] drawAtPoint:point withAttributes:attributes];
  }
}

@end

@implementation SourceTextView

+ (NSMutableDictionary*) keywordColorsFromKeywordsPropertyList:(NSString*)path {
  NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
  
  // Read the plist file
  NSArray* array = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfFile:path] options:NSPropertyListImmutable format:NULL error:NULL];
  if (![array isKindOfClass:[NSArray class]]) {
    return nil;
  }
  
  // Extract colors and keywords
  for (NSDictionary* entry in array) {
    NSColor* color = [NSColor colorWithDeviceRed:[[entry objectForKey:@"color-red"] floatValue] green:[[entry objectForKey:@"color-green"] floatValue] blue:[[entry objectForKey:@"color-blue"] floatValue] alpha:1.0];
    NSScanner* scanner = [NSScanner scannerWithString:[entry objectForKey:@"keywords"]];
    while (![scanner isAtEnd]) {
      NSString* keyword;
      [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
      if ([scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&keyword]) {
        [dictionary setObject:color forKey:keyword];
      }
    }
  }
  
  return dictionary;
}

+ (void)_parseSource:(NSString*)source range:(NSRange)range language:(SourceTextViewLanguage)language callback:(SourceTokenCallback)callback userInfo:(void*)info {
  SourceToken state = kSourceToken_Code;
  NSRange subRange;
  
  // Safe checks
  if ((range.location + range.length > [source length]) || (range.length == 0) || (callback == NULL)) {
    return;
  }
  
  // Copy string contents into buffer
  unichar* buffer = malloc(range.length * sizeof(unichar));
  if (buffer == NULL) {
    return;
  }
  [source getCharacters:buffer range:range];
  
  // Scan characters
  NSUInteger tokenStart = 0;
  for (NSUInteger i = 0; i < range.length; ++i) {
    SourceToken oldState = state;
    switch (buffer[i]) {
      
      case '#': {
        if (state != kSourceToken_Code) {
          break;
        }
        if ((language == kSourceTextViewLanguage_C) || (language == kSourceTextViewLanguage_CPP)) {
          state = kSourceToken_Preprocessor;
        } else if (language == kSourceTextViewLanguage_ShellScript) {
          state = kSourceToken_LineComment;
        }
        break;
      }
      
      case '-': {
        if (language == kSourceTextViewLanguage_Lua) {
          if (state != kSourceToken_Code) {
            break;
          }
          if (i + 1 == range.length) {
            break;
          }
          if (buffer[i + 1] == '-') {
            if ((i + 3 < range.length) && (buffer[i + 2] == '[') && (buffer[i + 3] == '[')) {
              state = kSourceToken_BlockComment;
              i += 3;
            } else {
              state = kSourceToken_LineComment;
              i += 1;
            }
          }
        }
        break;
      }
    
      case ']': {
        if (language == kSourceTextViewLanguage_Lua) {
          if (state != kSourceToken_BlockComment) {
            break;
          }
          if (i + 1 == range.length) {
            break;
          }
          if (buffer[i + 1] == ']') {
            state = kSourceToken_Code;
            i += 1;
          }
        }
        break;
      }
      
      case '/': {
        if ((language == kSourceTextViewLanguage_C) || (language == kSourceTextViewLanguage_CPP) || (language == kSourceTextViewLanguage_JavaScript)) {
          if ((state != kSourceToken_Code) && (state != kSourceToken_Preprocessor)) {
            break;
          }
          if (i + 1 == range.length) {
            break;
          }
          if (buffer[i + 1] == '/') {
            state = kSourceToken_LineComment;
            i += 1;
          } else if (buffer[i + 1] == '*') {
            state = kSourceToken_BlockComment;
            i += 1;
          }
        }
        break;
      }
      
      case '\n': {
        if ((state == kSourceToken_LineComment) || (state == kSourceToken_Preprocessor)) {
          state = kSourceToken_Code;
        }
        break;
      }
      
      case '*': {
        if ((language == kSourceTextViewLanguage_C) || (language == kSourceTextViewLanguage_CPP) || (language == kSourceTextViewLanguage_JavaScript)) {
          if (state != kSourceToken_BlockComment) {
            break;
          }
          if (i + 1 == range.length) {
            break;
          }
          if (buffer[i + 1] == '/') {
            state = kSourceToken_Code;
            i += 1;
          }
        }
        break;
      }
      
      case '\'': {
        if ((state != kSourceToken_Code) && (state != kSourceToken_SingleQuoteString)) {
          break;
        }
        if (i > 0) {
          if(buffer[i - 1] == '\\')
          break;
        }
        if (state == kSourceToken_SingleQuoteString) {
          state = kSourceToken_Code;
        } else {
          state = kSourceToken_SingleQuoteString;
        }
        break;
      }
      
      case '"': {
        if ((state != kSourceToken_Code) && (state != kSourceToken_DoubleQuoteString)) {
          break;
        }
        if (i > 0) {
          if(buffer[i - 1] == '\\')
          break;
        }
        if(state == kSourceToken_DoubleQuoteString) {
          state = kSourceToken_Code;
        } else {
          state = kSourceToken_DoubleQuoteString;
        }
        break;
      }
      
    }
    
    if ((state != oldState) && (i > 0)) {
      subRange.location = tokenStart;
      if (state == kSourceToken_BlockComment) {
        tokenStart = i - (language == kSourceTextViewLanguage_Lua ? 3 : 1);
      } else if (state == kSourceToken_LineComment) {
        tokenStart = i - 1;
      } else if ((state == kSourceToken_Code) && (oldState != kSourceToken_LineComment)) {
        tokenStart = i + 1;
      } else {
        tokenStart = i;
      }
      subRange.length = tokenStart - subRange.location;
      
      (*callback)(source, oldState, NSMakeRange(range.location + subRange.location, subRange.length), info);
    }
  }
  if (tokenStart < range.length) {
    subRange.location = tokenStart;
    subRange.length = range.length - tokenStart;
    
    (*callback)(source, state, NSMakeRange(range.location + subRange.location, subRange.length), info);
  }
  
  //Release buffer
  free(buffer);
}

- (void)_finishInitialization {
  [self setMaxSize:NSMakeSize(10000000, 10000000)];
  [self setAutoresizingMask:NSViewNotSizable];
  
  [self setDelegate:self];
  _language = kSourceTextViewLanguage_Undefined;
  _showLineNumbers = YES;
  _stringColor = [NSColor colorWithDeviceRed:0.6 green:0.3 blue:0.0 alpha:1.0];
  _commentColor = [NSColor darkGrayColor];
  _preprocessorColor = [NSColor blueColor];
  _errorHighlightColor = [NSColor colorWithDeviceRed:1.0 green:0.4 blue:0.5 alpha:1.0];
  [self setFont:[NSFont fontWithName:kFontName size:kFontSize]];
  [self setSmartInsertDeleteEnabled:NO];
  [self setAutomaticQuoteSubstitutionEnabled:NO];
  [self setAutomaticDashSubstitutionEnabled:NO];
  [self setAutomaticTextReplacementEnabled:NO];
  [self setAutomaticSpellingCorrectionEnabled:NO];
  [self setAllowsUndo:YES];
  
#if 0
  NSMutableParagraphStyle* style = [NSMutableParagraphStyle new];
  [style setTabStops:[NSArray array]];
  for (NSUInteger i = 0; i < 128; ++i) {
    NSTextTab* tabStop = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:(i * 4 * kCharacterWidth)];
    [style addTabStop:tabStop];
    [tabStop release];
  }
  [[self textStorage] addAttributes:[NSDictionary dictionaryWithObject:style forKey:NSParagraphStyleAttributeName] range:NSMakeRange(0, [[[self textStorage] string] length])];
  [style release];
#endif
}

- (id)initWithFrame:(NSRect)frame {
  if ((self = [super initWithFrame:frame])) {
    [self _finishInitialization];
  }
  return self;
}

- (id)initWithCoder:(NSCoder*)coder {
  if ((self = [super initWithCoder:coder])) {
    [self _finishInitialization];
  }
  return self;
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem {
  if ([anItem action] == @selector(paste:)) {
    return ([self isEditable] && [self preferredPasteboardTypeFromArray:[[NSPasteboard generalPasteboard] types] restrictedToTypesFromArray:[NSArray arrayWithObject:NSStringPboardType]]);
  }
  if (([anItem action] == @selector(shiftLeft:)) || ([anItem action] == @selector(shiftRight:))) {
    return ([[self window] firstResponder] == self);
  }
  return [super validateUserInterfaceItem:anItem];
}

- (void)paste:(id)sender {
  [self pasteAsPlainText:sender];
}

// FIXME: This does not work correctly if the text view contains text
- (void)_showLineNumbers:(BOOL)flag {
  NSScrollView* scrollView = (NSScrollView*)[[self superview] superview];
  NSTextContainer* container = [[[self layoutManager] textContainers] objectAtIndex:0];
  
  if ([scrollView isKindOfClass:[NSScrollView class]]) {
    if (flag) {
      Class rulerClass = [NSScrollView rulerViewClass];
      [NSScrollView setRulerViewClass:[SourceRulerView class]];
      [scrollView setHasVerticalRuler:YES];
      [scrollView setRulersVisible:YES];
      [NSScrollView setRulerViewClass:rulerClass];
      SourceRulerView* rulerView = (SourceRulerView*)[scrollView verticalRulerView];
      [rulerView setSourceView:self];
      [rulerView setRuleThickness:kRulerThickness];
      
      [scrollView setHasHorizontalScroller:YES];
      [container setWidthTracksTextView:NO];
      [container setHeightTracksTextView:NO];
      [container setContainerSize:NSMakeSize(10000000, 10000000)];  // This forces a refresh
      [self setHorizontallyResizable:YES];
    } else {
      [scrollView setHasVerticalRuler:NO];
      
      [scrollView setHasHorizontalScroller:NO];
      [container setWidthTracksTextView:YES];
      [container setHeightTracksTextView:NO];
      [container setContainerSize:NSMakeSize(10, 10000000)];  // This forces a refresh
      [self setHorizontallyResizable:NO];
    }
  }
}

- (void)setShowLineNumbers:(BOOL)flag {
  if (flag != _showLineNumbers) {
    [self _showLineNumbers:flag];
    _showLineNumbers = flag;
  }
}

- (void)viewDidMoveToSuperview {
  NSScrollView* scrollView = (NSScrollView*)[[self superview] superview];
  
  [self _showLineNumbers:_showLineNumbers];
  
  if ([scrollView isKindOfClass:[NSScrollView class]]) {
    [scrollView setLineScroll:kLineHeight];
  }
}

- (void)insertNewline:(id)sender {
  NSString* string = [[self textStorage] mutableString];
  NSRange range = [self selectedRange];
  
  [self insertText:@"\n"];
  
  if ((range.location != NSNotFound) && (range.location > 0)) {
    NSRange subRange = [string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, range.location)];
    if (subRange.location == NSNotFound) {
      subRange.location = 0;
    } else {
      subRange.location += 1;
    }
    NSRange subRange2 = [string rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet] options:0 range:NSMakeRange(subRange.location, range.location - subRange.location)];
    if (subRange2.location == NSNotFound) {
      subRange2.location = range.location;
    }
    [self insertText:[string substringWithRange:NSMakeRange(subRange.location, subRange2.location - subRange.location)]];
  }
}

- (void)_highlightLine:(NSUInteger)line withColor:(NSColor*)color {
  NSString* string = [self string];
  NSUInteger length = [string length];
  NSUInteger count = 0;
  NSUInteger location = 0;
  
  while (location < length) {
    NSRange range = [string rangeOfString:@"\n" options:0 range:NSMakeRange(location, length - location)];
    if (range.location == NSNotFound) {
      range.location = length;
    }
    if (line == count) {
      range = NSMakeRange(location, range.location - location);
      if(color) {
        [[self textStorage] addAttribute:NSBackgroundColorAttributeName value:color range:range];
      } else {
        [[self textStorage] removeAttribute:NSBackgroundColorAttributeName range:range];
      }
      break;
    }
    location = range.location + 1;
    ++count;
  }
}

- (void)_highlightAllLinesWithColor:(NSColor*)color {
  NSRange range = NSMakeRange(0, [[self string] length]);
  if(color) {
    [[self textStorage] addAttribute:NSBackgroundColorAttributeName value:color range:range];
  } else {
    [[self textStorage] removeAttribute:NSBackgroundColorAttributeName range:range];
  }
}

- (void)_textDidChange {
  NSString* string = [self string];
  NSRange range = NSMakeRange(0, [string length]);

  [self setTextColor:nil range:range];
  [SourceTextView _parseSource:string range:range language:_language callback:_SourceColorizeCallback userInfo:(__bridge void*)self];

  [self _highlightAllLinesWithColor:nil];
}

- (void)setErrorLine:(NSUInteger)line {
  if (line > 0) {
    [self _highlightLine:(line - 1) withColor:_errorHighlightColor];
  } else {
    [self _highlightAllLinesWithColor:nil];
  }
}

- (void)setLanguage:(SourceTextViewLanguage)language {
  _language = language;
  [self _textDidChange];
}

- (void)setSource:(NSString*)source {
  if (![source isEqualToString:[self string]]) {
    [self setString:([source length] ? source : @"")];
    [self _textDidChange];
  }
}

- (NSString*)source {
  return [self string];
}

- (void)setKeywordColors:(NSDictionary*)keywords {
  _keywordColors = [keywords copy];
  
  [self _textDidChange];
}

- (void)setStringColor:(NSColor*)color {
  _stringColor = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
  
  [self _textDidChange];
}

- (void)setCommentColor:(NSColor*)color {
  _commentColor = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
  
  [self _textDidChange];
}

- (void)setPreprocessorColor:(NSColor*)color {
  _preprocessorColor = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
  
  [self _textDidChange];
}

- (void) setErrorHighlightColor:(NSColor*)color {
  _errorHighlightColor = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
  
  [self _textDidChange];
}

#pragma mark - NSTextViewDelegate

- (void)textDidChange:(NSNotification*)notification {
  [self _textDidChange];
}

@end

@implementation SourceTextView (Actions)

- (NSRange)__shiftLeft:(NSRange)range {
  NSString* string = [[self textStorage] mutableString];
  NSRange newRange = range;
  
  if (![string length]) {
    return newRange;
  }
  
  NSRange subRange = [string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, range.location)];
  if (subRange.location == NSNotFound) {
    range.length += range.location;
    range.location = 0;
  } else {
    range.length += range.location - subRange.location - 1;
    range.location = subRange.location + 1;
  }
  if ([string characterAtIndex:range.location] == '\t') {
    if (range.location < newRange.location) {
      newRange.location -= 1;
      newRange.length += 1;
    }
  } else if (range.length == 0) {
    return newRange;
  }
  
  while (1) {
    if ([string characterAtIndex:range.location] == '\t') {
      [self replaceCharactersInRange:NSMakeRange(range.location, 1) withString:@""];
      if (newRange.length > 0) {
        newRange.length -= 1;
      }
      if (range.length > 0) {
        range.length -= 1;
      }
    }
    
    subRange = [string rangeOfString:@"\n" options:0 range:range];
    if ((subRange.location == NSNotFound) || (subRange.location + 1 == range.location + range.length)) {
      break;
    }
    range.length -= subRange.location - range.location + 1;
    range.location = subRange.location + 1;
  }
  
  [self didChangeText];
  
  return newRange;
}

- (NSRange)__shiftRight:(NSRange)range {
  NSString* string = [[self textStorage] mutableString];
  NSRange newRange = range;
  
  NSRange subRange = [string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, range.location)];
  if (subRange.location == NSNotFound) {
    range.length += range.location;
    range.location = 0;
  } else {
    range.length += range.location - subRange.location - 1;
    range.location = subRange.location + 1;
  }
  newRange.location += 1;
  newRange.length -= 1;
  
  while (1) {
    [self replaceCharactersInRange:NSMakeRange(range.location, 0) withString:@"\t"];
    newRange.length += 1;
    range.length += 1;
    
    subRange = [string rangeOfString:@"\n" options:0 range:range];
    if ((subRange.location == NSNotFound) || (subRange.location + 1 == range.location + range.length)) {
      break;
    }
    range.length -= subRange.location - range.location + 1;
    range.location = subRange.location + 1;
  }
  
  [self didChangeText];
  
  return newRange;
}

- (void)_shiftLeft:(NSValue*)valueRange {
  NSRange range = [valueRange rangeValue];
  NSRange newRange = [self __shiftLeft:range];
  if(!NSEqualRanges(newRange, range)) {
    [[self undoManager] registerUndoWithTarget:self selector:@selector(_shiftRight:) object:[NSValue valueWithRange:newRange]];
    [self setSelectedRange:newRange];
  }
}

- (void)shiftLeft:(id)sender {
  [self _shiftLeft:[NSValue valueWithRange:[self selectedRange]]];
}

- (void)_shiftRight:(NSValue*)valueRange {
  NSRange range = [valueRange rangeValue];
  NSRange newRange = [self __shiftRight:range];
  if(!NSEqualRanges(newRange, range)) {
    [[self undoManager] registerUndoWithTarget:self selector:@selector(_shiftLeft:) object:[NSValue valueWithRange:newRange]];
    [self setSelectedRange:newRange];
  }
}

- (void)shiftRight:(id)sender {
  [self _shiftRight:[NSValue valueWithRange:[self selectedRange]]];
}

@end
