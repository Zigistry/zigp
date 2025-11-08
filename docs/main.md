### Release based version management:
"^x.y.z" Allowing updates that don't change the left most 0.
"~x.y.z" Allow patch updates within same minor version.
"==x.x.x" Fixed version, no changes.
"*" Any latest available version allowed.
"x.y.z...a.b.c" updates within x.y.z and a.b.c range (both inclusive).
"|tag_name" If a release not following semver rules, and zigp is unable to parse it as a semver, the tag_name would be added after a |. No updates, version remains fixed.

### Branch based version management:
"%master" will update to latest commit at master branch.
"==%master" No changes.
