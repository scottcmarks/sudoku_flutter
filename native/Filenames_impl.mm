// Filenames_impl.mm — macOS/iOS implementation of get_full_filename()
// Uses NSBundle to locate .z resource files bundled inside the app.
// The group_maps/ folder is added to the Xcode target as a folder reference
// (Copy Bundle Resources), so files land at Contents/Resources/group_maps/.
//
// This replaces the Toolbox PlatformIndependent version (which hardcodes
// /usr/share/sudoku/group_maps/ and calls abort() on failure).

#import <Foundation/Foundation.h>
#include "Filenames.h"

using namespace std;

// No-op on macOS/iOS: NSBundle handles path resolution in get_full_filename.
void set_group_maps_dir(const char *) {}

string get_full_filename(const char *fname_no_ext, const char *ext)
{
    NSString *fName      = @(fname_no_ext);
    NSString *extension  = @(ext);

    // First look in the group_maps subdirectory (where .z files are bundled).
    NSString *path = [[NSBundle mainBundle] pathForResource:fName
                                                     ofType:extension
                                                inDirectory:@"group_maps"];
    if (!path) {
        // Fall back to root resources (flat bundle layout).
        path = [[NSBundle mainBundle] pathForResource:fName ofType:extension];
    }
    if (!path) {
        // Return a path that will cause get_zipped_file_contents() to return
        // NULL gracefully, triggering the square-map fallback in GroupMap.
        NSLog(@"Filenames_impl: resource not found: %@.%@", fName, extension);
        return "/dev/null/missing_resource/" + string(fname_no_ext) + "." + ext;
    }
    return path.UTF8String;
}
