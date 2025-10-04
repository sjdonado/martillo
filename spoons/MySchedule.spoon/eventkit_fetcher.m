#import <EventKit/EventKit.h>
#import <Foundation/Foundation.h>
#import <stdio.h>

int main() {
    @autoreleasepool {
        EKEventStore *store = [[EKEventStore alloc] init];

        // Request access to calendar
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        __block BOOL accessGranted = NO;

        [store requestFullAccessToEventsWithCompletion:^(BOOL granted, NSError * _Nullable error) {
            accessGranted = granted;
            dispatch_semaphore_signal(sema);
        }];

        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

        if (!accessGranted) {
            printf("ACCESS_DENIED");
            return 1;
        }

        // Get today's date range
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDate *now = [NSDate date];
        NSDate *startOfDay = [calendar startOfDayForDate:now];
        NSDate *endOfDay = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startOfDay options:0];

        // Get all calendars from all sources (local, iCloud, subscribed, etc.)
        NSArray<EKCalendar *> *allCalendars = [store calendarsForEntityType:EKEntityTypeEvent];

        // Debug: Print calendar info to stderr
        fprintf(stderr, "DEBUG: Found %lu calendars\n", (unsigned long)[allCalendars count]);
        for (EKCalendar *cal in allCalendars) {
            fprintf(stderr, "DEBUG: Calendar: %s (Source: %s)\n",
                   [cal.title UTF8String], [cal.source.title UTF8String]);
        }

        // Create predicate for today's events from ALL calendars
        NSPredicate *predicate = [store predicateForEventsWithStartDate:startOfDay endDate:endOfDay calendars:allCalendars];
        NSArray<EKEvent *> *events = [store eventsMatchingPredicate:predicate];

        fprintf(stderr, "DEBUG: Found %lu events for today\n", (unsigned long)[events count]);
        printf("COUNT:%lu||", (unsigned long)[events count]);

        for (EKEvent *event in events) {
            // The predicate already expands recurring events, so we can use the dates directly
            NSTimeInterval timeDiff = [event.startDate timeIntervalSinceDate:now];
            NSString *title = event.title ?: @"";
            NSString *notes = event.notes ?: @"";
            BOOL hasRecurrence = (event.recurrenceRules.count > 0);

            // Format times
            NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
            timeFormatter.dateFormat = @"HH:mm";
            NSString *startTime = [timeFormatter stringFromDate:event.startDate];
            NSString *endTime = [timeFormatter stringFromDate:event.endDate];
            NSString *timeRange = [NSString stringWithFormat:@"%@ - %@", startTime, endTime];

            printf("%s|%.0f|%s|%s|%s||",
                   [title UTF8String], timeDiff, [timeRange UTF8String],
                   [notes UTF8String], hasRecurrence ? "true" : "false");
        }
    }
    return 0;
}
