// Filenames_cli.cpp — CLI implementation of get_full_filename() / set_group_maps_dir()
//
// Used by the native/ Makefile build (test jigs).
// On macOS/iOS app builds, Filenames_impl.mm (NSBundle) is used instead.
// The Toolbox Filenames/Filenames.cpp is not compiled by either build.

#include "Filenames.h"
#include <cstdlib>
#include <string>

static std::string s_group_maps_dir;

void set_group_maps_dir(const char *path) {
    s_group_maps_dir = path ? path : "";
}

std::string get_full_filename(const char *fname_no_ext, const char *ext) {
    std::string dir;
    if (!s_group_maps_dir.empty()) {
        dir = s_group_maps_dir;
    } else {
        const char *env = getenv("SUDOKU_GROUP_MAPS_DIR");
        dir = env ? env : "/usr/share/sudoku/group_maps";
    }
    if (dir.back() != '/') dir += '/';
    return dir + fname_no_ext + "." + ext;
}
