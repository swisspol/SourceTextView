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

#import "AppDelegate.h"

@implementation AppDelegate

- (void)_sourceDidUpdate:(NSNotification*)notification {
  NSLog(@"Updated source!");
}

- (void)awakeFromNib {
  [_sourceTextView setLanguage:kSourceTextViewLanguage_Lua];
  NSMutableDictionary* keywords = [SourceTextView keywordColorsFromKeywordsPropertyList:[[NSBundle mainBundle] pathForResource:@"Keyword-Colors/Lua" ofType:@"plist"]];
  [keywords setObject:[NSColor redColor] forKey:@"lua"];
  [_sourceTextView setKeywordColors:keywords];
  
  [_sourceTextView setSource:[NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Source" ofType:@"lua"] encoding:NSUTF8StringEncoding error:NULL]];
  [_sourceTextView setErrorLine:3];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_sourceDidUpdate:) name:NSTextDidChangeNotification object:_sourceTextView];
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
  [_mainWindow makeKeyAndOrderFront:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)application {
  return YES;
}

@end
