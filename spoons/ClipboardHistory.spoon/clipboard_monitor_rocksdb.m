#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <stdio.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 3) {
            printf("ERROR: Usage: %s <rocksdb_binary> <db_path>\n", argv[0]);
            return 1;
        }

        NSString *rocksdbBinary = [NSString stringWithUTF8String:argv[1]];
        NSString *dbPath = [NSString stringWithUTF8String:argv[2]];

        // Get clipboard content
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        if (!pasteboard) {
            printf("ERROR: Could not access pasteboard\n");
            return 1;
        }

        NSArray<NSString *> *types = [pasteboard types];
        if (!types || [types count] == 0) {
            printf("ERROR: No pasteboard types\n");
            return 1;
        }

        // Determine content type and get content
        NSString *contentType = @"Text";
        NSString *content = nil;
        NSString *preview = nil;
        NSString *sizeDisplay = @"";

        // Check for images first (screenshots)
        if ([types containsObject:@"public.png"]) {
            contentType = @"PNG image";
            NSData *imageData = [pasteboard dataForType:@"public.png"];
            if (imageData && [imageData length] > 0) {
                double sizeKB = (double)[imageData length] / 1024.0;

                // Save image to temp file
                NSString *tempDir = NSTemporaryDirectory();
                NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
                NSString *tempImagePath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"clipboard_image_%@.png", timestamp]];

                BOOL saved = [imageData writeToFile:tempImagePath atomically:YES];
                if (saved) {
                    content = tempImagePath;
                } else {
                    NSString *desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"yyyy-MM-dd 'at' HH.mm.ss"];
                    NSString *formattedTime = [formatter stringFromDate:[NSDate date]];
                    content = [desktopPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Screenshot %@.png", formattedTime]];
                }

                preview = [NSString stringWithFormat:@"Screenshot (%.1f KB)", sizeKB];
                if ([imageData length] >= 1024 * 1024) {
                    sizeDisplay = [NSString stringWithFormat:@"%.1f MB", sizeKB / 1024.0];
                } else {
                    sizeDisplay = [NSString stringWithFormat:@"%.1f KB", sizeKB];
                }
            }
        } else if ([types containsObject:@"public.jpeg"]) {
            contentType = @"JPEG image";
            NSData *imageData = [pasteboard dataForType:@"public.jpeg"];
            if (imageData && [imageData length] > 0) {
                double sizeKB = (double)[imageData length] / 1024.0;

                NSString *tempDir = NSTemporaryDirectory();
                NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
                NSString *tempImagePath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"clipboard_image_%@.jpg", timestamp]];

                BOOL saved = [imageData writeToFile:tempImagePath atomically:YES];
                if (saved) {
                    content = tempImagePath;
                } else {
                    NSString *desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"yyyy-MM-dd 'at' HH.mm.ss"];
                    NSString *formattedTime = [formatter stringFromDate:[NSDate date]];
                    content = [desktopPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Image %@.jpg", formattedTime]];
                }

                preview = [NSString stringWithFormat:@"JPEG Image (%.1f KB)", sizeKB];
                if ([imageData length] >= 1024 * 1024) {
                    sizeDisplay = [NSString stringWithFormat:@"%.1f MB", sizeKB / 1024.0];
                } else {
                    sizeDisplay = [NSString stringWithFormat:@"%.1f KB", sizeKB];
                }
            }
        } else if ([types containsObject:@"public.file-url"]) {
            contentType = @"File path";
            NSString *fileURL = [pasteboard stringForType:@"public.file-url"];
            if (fileURL && [fileURL length] > 0) {
                NSURL *url = [NSURL URLWithString:fileURL];
                if (url && [url path]) {
                    content = [url path];
                    preview = [url lastPathComponent];
                } else {
                    content = fileURL;
                    preview = fileURL;
                }
                NSUInteger urlLength = [fileURL length];
                if (urlLength >= 1024) {
                    sizeDisplay = [NSString stringWithFormat:@"%.1f KB", (double)urlLength / 1024.0];
                } else {
                    sizeDisplay = [NSString stringWithFormat:@"%lu bytes", (unsigned long)urlLength];
                }
            }
        } else {
            // Try to get text content
            NSString *stringContent = [pasteboard stringForType:@"public.utf8-plain-text"];
            if (!stringContent || [stringContent length] == 0) {
                stringContent = [pasteboard stringForType:@"NSStringPboardType"];
            }

            if (stringContent && [stringContent length] > 0) {
                NSString *strippedContent = [stringContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([strippedContent length] == 0) {
                    printf("ERROR: Content is only whitespace\n");
                    return 1;
                }

                contentType = @"Text";
                content = stringContent;
                preview = stringContent;
                NSUInteger textLength = [stringContent length];
                if (textLength >= 1024) {
                    sizeDisplay = [NSString stringWithFormat:@"%.1f KB", (double)textLength / 1024.0];
                } else {
                    sizeDisplay = [NSString stringWithFormat:@"%lu bytes", (unsigned long)textLength];
                }
            }
        }

        if (!content || [content length] == 0) {
            printf("ERROR: No clipboard content found\n");
            return 1;
        }

        // Clean up preview
        if ([preview length] > 80) {
            preview = [[preview substringToIndex:77] stringByAppendingString:@"..."];
        }
        preview = [preview stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        preview = [preview stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
        preview = [preview stringByReplacingOccurrencesOfString:@"\t" withString:@" "];

        // Escape quotes for shell safety
        NSString *escapedContent = [content stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        NSString *escapedType = [contentType stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        NSString *escapedPreview = [preview stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        NSString *escapedSize = [sizeDisplay stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];

        // Call RocksDB binary to add entry
        NSString *command = [NSString stringWithFormat:@"\"%@\" \"%@\" add \"%@\" \"%@\" \"%@\" \"%@\"",
                            rocksdbBinary, dbPath, escapedContent, escapedType, escapedPreview, escapedSize];

        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/bin/sh";
        task.arguments = @[@"-c", command];

        NSPipe *pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        task.standardError = pipe;

        [task launch];
        [task waitUntilExit];

        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        if (task.terminationStatus == 0 && output && [output length] > 0) {
            printf("%s", [output UTF8String]);
        } else {
            printf("ERROR: Failed to add entry to RocksDB\n");
            return 1;
        }
    }
    return 0;
}
