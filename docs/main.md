### Release based version management:
"^x.x.x" Allowing updates within same minor versions.
"~x.x.x" Allow patch updates only.
"==x.x.x" Fixed version, no changes.
"*" Any latest available version allowed..
">=x.x.x" Greater than or equal to x.x.x
">=x.x.x <=y.y.y" Less than x.x.x greater than y.y.y
"x.x.x" same as "==x.x.x"
"|tag_name" If a release not following semver rules, the tag_name would be added after a |. No updates, version remains fixed.

### Branch based version management:
"%master" will update to latest commit at master branch.
"==%master" fixed commit at master branch no changes.
