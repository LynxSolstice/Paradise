#!/bin/bash
set -euo pipefail

#nb: must be bash to support shopt globstar
shopt -s globstar

st=0

if grep -El '^\".+\" = \(.+\)' _maps/**/*.dmm;	then
    echo "ERROR: Non-TGM formatted map detected. Please convert it using Map Merger!"
    st=1
fi;
if grep -P '^\ttag = \"icon' _maps/**/*.dmm;	then
    echo "ERROR: tag vars from icon state generation detected in maps, please remove them."
    st=1
fi;
if grep -P 'pixel_[^xy]' _maps/**/*.dmm;	then
	echo "ERROR: Incorrect pixel offset variables detected in maps, please remove them."
	st=1
fi;
if grep -P 'step_[xy]' _maps/**/*.dmm;	then
    echo "ERROR: step_x/step_y variables detected in maps, please remove them."
    st=1
fi;

if grep -P '^/[\w/]\S+\(.*(var/|, ?var/.*).*\)' code/**/*.dm; then
    echo "ERROR: Changed files contains proc arguments with implicit 'var/', please remove them."
    st=1
fi;
if grep -P '^/*var/' code/**/*.dm; then
    echo "ERROR: Unmanaged global var use detected in code, please use the helpers."
    st=1
fi;
# Check for merge conflict markers and their associated description text.
if grep -P 'Merge Conflict Marker' _maps/**/*.dmm; then
    echo "ERROR: Merge conflict markers detected in map, please resolve all merge failures!"
    st=1
fi;
if grep -P '/obj/merge_conflict_marker' _maps/**/*.dmm; then
    echo "ERROR: Merge conflict markers detected in map, please resolve all merge failures!"
    st=1
fi;
# Check for non-515 compatable .proc/ syntax
if grep -P --exclude='__byond_version_compat.dm' '\.proc/' code/**/*.dm; then
    echo "ERROR: Outdated proc reference use detected in code, please use proc reference helpers."
    st=1
fi;
nl='
'
nl=$'\n'
while read f; do
    t=$(tail -c2 "$f"; printf x); r1="${nl}$"; r2="${nl}${r1}"
    if [[ ! ${t%x} =~ $r1 ]]; then
        echo "file $f is missing a trailing newline"
        st=1
    fi;
done < <(find . -type f -name '*.dm')

exit $st
