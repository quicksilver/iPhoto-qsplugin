

#import "QSiPhotoSource.h"

#pragma mark Object Source
@implementation QSiPhotoObjectSource

- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry{
    NSString *libraryPath=[(NSString *)CFPreferencesCopyValue((CFStringRef) @"RootDirectory", (CFStringRef) @"com.apple.iPhoto", kCFPreferencesCurrentUser, kCFPreferencesAnyHost) autorelease];
	libraryPath=[libraryPath stringByAppendingPathComponent:@"AlbumData.xml"];
	
	if (![[NSFileManager defaultManager]fileExistsAtPath:libraryPath]) return YES;
    NSDate *modDate=[[[NSFileManager defaultManager] attributesOfItemAtPath:libraryPath error:nil]fileModificationDate];
	
	return [modDate compare:indexDate]==NSOrderedAscending;
}

- (NSImage *) iconForEntry:(NSDictionary *)dict{
    return [QSResourceManager imageNamed:@"iPhotoIcon"];
}

- (NSArray *) objectsForEntry:(NSDictionary *)theEntry{
    NSMutableArray *objects=[[NSMutableArray alloc] init];
	
    NSMutableArray *eventsObjects =[ [NSMutableArray alloc] init];
    QSObject *newObject;
    // Events are called 'Rolls'. Throughout the plugin we must check for both when looking at an applescript album
    NSArray *events = [[self iPhotoLibrary] objectForKey:@"List of Rolls"];
    for (NSDictionary *thisEvent in events) {
        newObject=[QSObject objectWithName:[thisEvent objectForKey:@"RollName"]];
        [newObject setObject:thisEvent forType:QSiPhotoEventPboardType];
        [newObject setPrimaryType:QSiPhotoEventPboardType];
        // Avoids duplicates (for example, the most recent album and the actual album)
        if (![eventsObjects containsObject:newObject]) {
            [eventsObjects addObject:newObject];
        }
    }
    
    //Albums - these include recently added albums/events, published albums etc.
    NSArray *albums=[[self iPhotoLibrary] objectForKey:@"List of Albums"];
    for (NSDictionary *thisAlbum in albums){
        newObject=[QSObject objectWithName:[thisAlbum objectForKey:@"AlbumName"]];
        [newObject setObject:thisAlbum forType:QSiPhotoAlbumPboardType];
        [newObject setPrimaryType:QSiPhotoAlbumPboardType];
        if (![objects containsObject:newObject]) {
            [objects addObject:newObject];
        }
    }
    
    // Do this so we get a nice order in the results: photos, last album, last 12 months, flagged, events then albums
    if ([eventsObjects count]) {
        NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(5,[eventsObjects count])];
        [objects insertObjects:eventsObjects atIndexes:indexes];
    }
    [eventsObjects release];
    
    return [objects autorelease];
}


#pragma mark Object Handler

- (BOOL)loadIconForObject:(QSObject *)object{
    if ([[object primaryType]isEqualToString:QSiPhotoAlbumPboardType] || [[object primaryType] isEqualToString:QSiPhotoEventPboardType]){
		NSString *type=nil;
        NSDictionary *albumDict=[object primaryObject];
        if ([[albumDict objectForKey:@"Master"]boolValue])
            [object setIcon:[QSResourceManager imageNamed:@"iPhotoLibraryIcon"]];
        else if ([(type=[albumDict objectForKey:@"Album Type"])isEqualToString:@"Smart"])
			[object setIcon:[QSResourceManager imageNamed:@"iPhotoSmartAlbumIcon"]];
        else if ([type isEqualToString:@"Regular"])
            [object setIcon:[QSResourceManager imageNamed:@"iPhotoAlbumIcon"]];
		else if ([type isEqualToString:@"Special Month"])
			[object setIcon:[QSResourceManager imageNamed:@"iPhotoSpecialMonthIcon"]];
		else if ([type isEqualToString:@"Special Roll"])
			[object setIcon:[QSResourceManager imageNamed:@"iPhotoSpecialRollIcon"]];
		else if ([type isEqualToString:@"Folder"])
			[object setIcon:[QSResourceManager imageNamed:@"GenericFolderIcon"]];
        else if ([type isEqualToString:@"Published"]) {
            // facebook published album
            if ([[albumDict objectForKey:@"URL"] rangeOfString:@"facebook.com"].length != NSNotFound) 
                [object setIcon:[QSResourceManager imageNamed:@"iPhotoFacebookPublishedAlbumIcon"]];
            else if ([[albumDict objectForKey:@"URL"] rangeOfString:@"gallery.me.com"].length != NSNotFound)
                [object setIcon:[QSResourceManager imageNamed:@"iPhotoMobileMePublishedAlbumIcon"]];
        }
		else
			[object setIcon:[QSResourceManager imageNamed:@"iPhotoEventIcon"]];
		return YES;
    }else if ([[object primaryType]isEqualToString:QSiPhotoPhotoType]){
		NSDictionary *imageDict=[object primaryObject];
		NSString *imagePath=[imageDict objectForKey:@"ThumbPath"];
        if (imagePath){
			[object setIcon:[[[NSImage alloc]initWithContentsOfFile:imagePath]autorelease]];
			return YES;
		}
	}
    return NO;
}

- (NSString *)detailsOfObject:(QSObject *)object{
	if ([[object primaryType]isEqualToString:QSiPhotoAlbumPboardType] || [[object primaryType] isEqualToString:QSiPhotoEventPboardType]){
        NSDictionary *albumDict=[object primaryObject];
		NSUInteger count=[[albumDict objectForKey:@"PhotoCount"] unsignedIntegerValue];
        return [NSString stringWithFormat:@"%d photo%@",count, ESS(count)];
    }else if ([[object primaryType]isEqualToString:QSiPhotoPhotoType]){
		NSDictionary *imageDict=[object primaryObject];
		NSDate *date=[NSCalendarDate dateWithTimeIntervalSinceReferenceDate:[[imageDict objectForKey:@"DateAsTimerInterval"] doubleValue]];
		return [date description];
	}
    return NO;
}


- (BOOL)objectHasChildren:(QSObject *)object{
    if ([[object primaryType]isEqualToString:QSiPhotoAlbumPboardType] || [[object primaryType] isEqualToString:QSiPhotoEventPboardType]){
        NSDictionary *albumDict= [object primaryObject];
        return ([(NSArray *)[albumDict objectForKey:@"KeyList"] count] > 0) ? YES : NO;
    }
    return NO;
}
- (BOOL)objectHasValidChildren:(id <QSObject>)object{
    return YES;
}

- (BOOL)loadChildrenForObject:(QSObject *)object{
    if ([[object primaryType] isEqualToString:NSFilenamesPboardType]) {
        [object setChildren:[self objectsForEntry:nil]];
        return YES;
    }
    NSArray *children=[self childrenForObject:object];
    
    if (children){
        [object setChildren:children];
        return YES;   
    }
    return NO;
}

- (NSArray *)childrenForObject:(QSObject *)object{
    if ([[object primaryType]isEqualToString:QSiPhotoAlbumPboardType] || [[object primaryType] isEqualToString:QSiPhotoEventPboardType]){
        NSDictionary *albumDict=[object primaryObject];
        NSArray *photos=[[[self iPhotoLibrary] objectForKey:@"Master Image List"]objectsForKeys:[albumDict objectForKey:@"KeyList"] notFoundMarker:[NSNull null]];
		NSMutableArray *objects=[NSMutableArray arrayWithCapacity:[photos count]];
        QSObject *newObject;
        NSDictionary *photoInfo;
		NSString *path;
        for (photoInfo in photos){
			newObject=[QSObject objectWithName:[photoInfo objectForKey:@"Caption"]];
            [newObject setObject:photoInfo forType:QSiPhotoPhotoType];
            if (path=[photoInfo objectForKey:@"ImagePath"])
				[newObject setObject:[NSArray arrayWithObject:path] forType:NSFilenamesPboardType];
            [newObject setPrimaryType:QSiPhotoPhotoType];
            [objects addObject:newObject];
        }
        return objects;
    }
    return NO;
}

// Don't store this in memory. In some cases it can be > 11MB, so is a waste if it is only being accessed a few times.
- (NSDictionary *)iPhotoLibrary { 
        NSString *libraryPath=[(NSString *)CFPreferencesCopyValue((CFStringRef) @"RootDirectory", (CFStringRef) @"com.apple.iPhoto", kCFPreferencesCurrentUser, kCFPreferencesAnyHost) autorelease];
        libraryPath=[[libraryPath stringByAppendingPathComponent:@"AlbumData.xml"] stringByExpandingTildeInPath];
    return [NSDictionary dictionaryWithContentsOfFile:libraryPath]; 
}

@end


#pragma mark -
#pragma mark Action Provider

#define kQSiPhotoAlbumShowAction @"QSiPhotoAlbumShowAction"
#define kQSiPhotoAlbumSlideShowAction @"QSiPhotoAlbumSlideShowAction"

@implementation QSiPhotoActionProvider


-(iPhotoApplication *)iPhoto {
    if (!iPhoto) {
        iPhoto = [[SBApplication applicationWithBundleIdentifier:@"com.apple.iPhoto"] retain];
    }
    return iPhoto;
}

-(void)dealloc {
    [[self iPhoto] release];
    [super dealloc];
}

- (NSDictionary *)iPhotoLibrary { 
    NSString *libraryPath=[(NSString *)CFPreferencesCopyValue((CFStringRef) @"RootDirectory", (CFStringRef) @"com.apple.iPhoto", kCFPreferencesCurrentUser, kCFPreferencesAnyHost) autorelease];
    libraryPath=[[libraryPath stringByAppendingPathComponent:@"AlbumData.xml"] stringByExpandingTildeInPath];
    return [NSDictionary dictionaryWithContentsOfFile:libraryPath]; 
}

- (void)emptyTrash {
    // Launches iPhoto - not the end of the world
    [[self iPhoto] emptyTrash];
}

- (QSObject *)slideshow:(QSObject *)dObject{
    // There are some quirks with starting a slideshow straight away. Instead, it's easier to 'select' (or 'show') the album in iPhoto, then launch a slideshow for the current album (...usingAlbum:nil]; below)
    [self show:dObject];
    
    // Doesn't work with events yet
    [[self iPhoto] startSlideshowAsynchronous:1 displayIndex:0 iChat:0 usingAlbum:nil];
    return nil;
}

- (QSObject *) show:(QSObject *)dObject{
    NSString *albumName=[[dObject objectForType:QSiPhotoAlbumPboardType]objectForKey:@"AlbumName"];
    
    // Won't be used until Events are available for scripting
    if (!albumName) {
        albumName = [[dObject objectForType:QSiPhotoAlbumPboardType]objectForKey:@"RollName"];
    }
    if (!albumName) {
        NSBeep();
        NSLog(@"Error getting album name, aborting slideshow");
        return nil;
    }
    SBElementArray *albums = [[self iPhoto] albums];
    iPhotoAlbum *theAlbum = [albums objectWithName:albumName];
    [theAlbum select];
    [[self iPhoto] activate];
    return nil;
}

-(id)resolveProxyObject:(id)proxy{ 
//	NSLog(@"proxyx, %@",proxy);
	
	
	if (![[self iPhoto] isRunning]) {
		return nil;
    }
	
	if ([[proxy identifier] isEqualToString:@"com.apple.iPhoto"] || !proxy){
        
        NSArray *selection = [[self iPhoto] selection];
        
        if (!selection || ![selection count]) {
            return nil;
        }
        
        // It's an album that's selected
        if ([[selection objectAtIndex:0] isKindOfClass:[[iPhoto classForScriptingClass:@"album"] class]]) {
            NSMutableArray *albumSelection = [[NSMutableArray alloc] initWithCapacity:[selection count]];
            NSArray *albums = [[self iPhotoLibrary] objectForKey:@"List of Albums"];
            QSObject *newObject;
            for (iPhotoAlbum *eachAlbum in selection) {
                NSUInteger index = [albums indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                    BOOL passed = [[(NSDictionary *)obj objectForKey:@"AlbumName"] isEqualToString:[eachAlbum name]];
                    return passed ? YES : [[(NSDictionary *)obj objectForKey:@"AlbumName"] isEqualToString:[eachAlbum name]];
                }];
                if (index == NSNotFound) {
                    continue;
                }
                newObject = [QSObject objectWithName:[eachAlbum name]];
                [newObject setObject:[albums objectAtIndex:index] forType:QSiPhotoAlbumPboardType];
                [newObject setPrimaryType:QSiPhotoAlbumPboardType];
                [albumSelection addObject:newObject];
            }
            return [QSObject objectByMergingObjects:albumSelection];
        }
        
        NSMutableArray *fileSelection = [[NSMutableArray alloc] initWithCapacity:[selection count]];
        for (iPhotoPhoto *eachPhoto in  selection) {
            [fileSelection addObject:[eachPhoto imagePath]];
        }
        
        //		NSLog(@"result %@",[QSObject fileObjectsWithURLArray:[result objectValue]]);
		
		return [QSObject fileObjectWithArray:[fileSelection autorelease]];
	}else if ([[proxy identifier] isEqualToString:@"QSiPhotoSelectedAlbumProxy"]) {
        iPhotoAlbum *selectedAlbum = [[self iPhoto] currentAlbum];
        
        NSArray *albums = [[self iPhotoLibrary] objectForKey:@"List of Albums"];
        NSString *name = [selectedAlbum name];
        NSUInteger index = [albums indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            BOOL passed = [[(NSDictionary *)obj objectForKey:@"AlbumName"] isEqualToString:name];
            return passed ? YES : [[(NSDictionary *)obj objectForKey:@"AlbumName"] isEqualToString:name];        }];
        
        QSObject *newObject = [QSObject objectWithName:[selectedAlbum name]];
        [newObject setObject:[albums objectAtIndex:index] forType:QSiPhotoAlbumPboardType];
        [newObject setPrimaryType:QSiPhotoAlbumPboardType];
        return newObject;
		}
	//	NSLog(@"result %@",[result stringValue]);
	return nil;
}

@end