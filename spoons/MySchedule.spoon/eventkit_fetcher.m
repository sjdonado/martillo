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

        // Get today's date range in local timezone
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDate *now = [NSDate date];

        // Get start and end of today in local timezone
        NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:now];
        NSDate *startOfDay = [calendar dateFromComponents:components];

        // Add 1 day to get end of today
        NSDateComponents *oneDayComponent = [[NSDateComponents alloc] init];
        oneDayComponent.day = 1;
        NSDate *endOfDay = [calendar dateByAddingComponents:oneDayComponent toDate:startOfDay options:0];

        // Debug: Print date range and timezone
        // fprintf(stderr, "DEBUG: Local timezone: %s\n", [[NSTimeZone.localTimeZone name] UTF8String]);
        // fprintf(stderr, "DEBUG: Searching events from %s to %s\n",
        //        [[startOfDay description] UTF8String],
        //        [[endOfDay description] UTF8String]);

        // Get all calendars from all sources (local, iCloud, subscribed, etc.)
        NSArray<EKCalendar *> *allCalendars = [store calendarsForEntityType:EKEntityTypeEvent];

        // Debug: Print calendar info and event count per calendar
        // fprintf(stderr, "DEBUG: Found %lu calendars\n", (unsigned long)[allCalendars count]);
        for (EKCalendar *cal in allCalendars) {
            // Get events for this specific calendar
            NSPredicate *calPredicate = [store predicateForEventsWithStartDate:startOfDay
                                                                     endDate:endOfDay
                                                                   calendars:@[cal]];
            NSArray<EKEvent *> *calEvents = [store eventsMatchingPredicate:calPredicate];

            fprintf(stderr, "  - %s: %lu events\n",
                   [cal.title UTF8String],
                   (unsigned long)[calEvents count]);

            // List events in this calendar
            for (EKEvent *evt in calEvents) {
                fprintf(stderr, "    * %s at %s\n",
                       [evt.title UTF8String],
                       [[evt.startDate description] UTF8String]);
            }
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
            NSString *calendarName = event.calendar.title ?: @"Unknown";

            // Debug: Print event details
            // fprintf(stderr, "DEBUG: Event '%s' from calendar '%s' (start: %s, recurrence: %s)\n",
            //        [title UTF8String],
            //        [calendarName UTF8String],
            //        [[event.startDate description] UTF8String],
            //        hasRecurrence ? "YES" : "NO");

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
