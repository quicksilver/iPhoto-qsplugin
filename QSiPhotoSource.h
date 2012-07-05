


#import <Cocoa/Cocoa.h>

#define QSiPhotoAlbumPboardType @"qs.apple.iPhoto.album"
#define QSiPhotoEventPboardType @"qs.apple.iPhoto.event"
#define QSiPhotoPhotoType @"qs.apple.iPhoto.photo"
#define iPhotoBundleID @"com.apple.iPhoto"

#import "iPhoto.h"



@interface QSiPhotoObjectSource : QSObjectSource {
}

- (NSDictionary *)iPhotoLibrary;
@end

@interface QSiPhotoActionProvider : QSActionProvider {
    iPhotoApplication *iPhoto;
}

@property (retain) iPhotoApplication *iPhoto;

- (NSDictionary *)iPhotoLibrary;


@end
