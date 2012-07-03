


#import <Cocoa/Cocoa.h>

#define QSiPhotoAlbumPboardType @"qs.apple.iPhoto.album"
#define QSiPhotoEventPboardType @"qs.apple.iPhoto.event"
#define QSiPhotoPhotoType @"qs.apple.iPhoto.photo"
#define iPhotoBundleID @"com.apple.iPhoto"

#import "iPhoto.h"


iPhotoApplication *QSiPhoto();  // returns the iPhoto application


@interface QSiPhotoObjectSource : QSObjectSource {
}

- (NSDictionary *)iPhotoLibrary;
@end

@interface QSiPhotoActionProvider : QSActionProvider {
    iPhotoApplication *iPhoto;
}

- (NSDictionary *)iPhotoLibrary;


@end
