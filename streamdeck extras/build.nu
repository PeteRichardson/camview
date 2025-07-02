let views = [
  "ALL"
  "DOORANDDRIVEWAY"
  "DRIVEWAY"
  "DRIVEWAY2"
  "FAMILYROOM"
  "FIREPIT"
  "FRONTDOOR"
  "GARBAGE"
  "KATSALLEY"
  "SIDEYARD"
  "SUMMARY"
]

let build_dir = "apps"
mkdir $build_dir

for view in $views {                          # e.g. DRIVEWAY (from views list above)
    let target_define = ($view | str upcase)  # e.g. DRIVEWAY
    let exe_name = ($view | str downcase)     # e.g. driveway
    let app = $"($exe_name).app"              # e.g. driveway.app
    let exe_dir = $"($build_dir)/($exe_name).app/Contents/MacOS"   # e.g. driveway.app/Contents/MacOS
    ^mkdir -p $exe_dir                        # e.g. apps/driveway.app/Contents/MacOS
    print $"Building ($exe_dir)/($exe_name)..."

    do {
        # build and strip the executables. (each should be about 51K)
        ^swiftc -O -D $target_define -o $"($exe_dir)/($exe_name)" main.swift target.swift
        ^strip -x $"($exe_dir)/($exe_name)"
        let size = (ls $"($exe_dir)/($exe_name)" | get size)
        print $"   ✅ Size: ($size) bytes"
    } catch {
        print $"❌ Failed to build ($view)"
    }
}