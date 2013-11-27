#!/bin/bash

# Given a git url or a tarball name, this function will return a stamp name.
#
# $1: Stamp type: configure, build, extract, fetch.
# $2: File URL or tarball name.
# $3: Special suffix, e.g., "stage1" or "stage2"
#
get_stamp_name()
{
    local stamptype=$1
    local git_or_tar=$2
    local suffix=$3

    local validstamp="`echo ${stamptype} | egrep -c "^configure$|^build$|^extract$|^fetch$"`" 
    if test ${validstamp} -lt 1; then
	error "Invalid stamp type selected."
	return 1
    fi

    local name_fragment=
    if test "`echo "${git_or_tar}" | grep -c "\.tar"`" -gt 0; then
	# Strip the .tar.* from the archive file to get the stamp name.
	name_fragment="`echo "${git_or_tar}" | sed -e 's:\.tar.*::'`"
	# Strip any preceding directory information,
	# e.g., infrastructure/gmp-2.1.2.tar.xz -> gmp-2.1.2
	name_fragment="`basename ${name_fragment}`"
    else
	name_fragment="`get_git_tag ${git_or_tar}`"
	if test x"${name_fragment}" = x; then
	    error "Couldn't determine stamp name."
	    return 1
	fi
    fi

    local stamp_name="stamp-${stamptype}-${name_fragment}${suffix:+-${suffix}}"
    echo "${stamp_name}"
    return 0
}

# $1 Stamp Location
# $2 Stamp Name
#
create_stamp()
{
    local stamp_loc=$1
    local stamp_name=$2
    local ret=

    # Strip trailing slashes from the location directory.
    stamp_loc="`echo ${stamp_loc} | sed 's#/*$##'`"

    if test ! -d "${stamp_loc}"; then
	notice "'${stamp_loc}' doesn't exist, creating it."
	mkdir -p "${stamp_loc}"
    fi

    local full_stamp_path=
    full_stamp_path="${stamp_loc}/${stamp_name}"

    touch "${full_stamp_path}"
    ret=$?
    notice "Creating stamp ${full_stamp_path} (`stat -c %Y ${full_stamp_path}`)"
    return ${ret}
}

#
# $1 Stamp Location
# $2 Stamp Name
# $3 File to compare stamp against
# $4 Force
#
#   If stamp file is newer than the compare file return 0
#   If stamp file is NOT newer than the compare file return 1
#   If stamp file does not exist return 1
#
# Return Value:
#
#   1 - If the test_stamp function returns 1 then regenerate the stamp
#       after processing.
#
#   0 - Otherwise the test_stamp function returns 0 which means that
#       you should not proceed with processing.
#
#   255 - There is an error condition during stamp generation.  This is
#         a bug in cbuild2 or the filesystem.
#
check_stamp()
{
    local stamp_loc=$1
    local stamp_name=$2
    local compare_file=$3
    local local_force=$4

    if test ! -e "${compare_file}"; then
	error "File to test stamp against doesn't exist."
	return 255
    fi

    # Strip trailing slashes from the location directory.
    stamp_loc="`echo ${stamp_loc} | sed 's#/*$##'`"

    if test ${compare_file} -nt ${stamp_loc}/${stamp_name} -a x"${force}" = xno; then
        if test ! -e "${stamp_loc}/${stamp_name}"; then
	    notice "${stamp_loc}/${stamp_name} does not yet exist so continuing...."
	else
	    notice "${stamp_loc}/${stamp_name} (`stat -c %Y ${stamp_loc}/${stamp_name}`) is newer than ${compare_file} (`stat -c %Y ${compare_file}`)"
	fi
	return 1
    else
     	notice "${stamp_loc}/${stamp_name} (`stat -c %Y ${stamp_loc}/${stamp_name}`) is newer than ${compare_file} (`stat -c %Y ${compare_file}`)"
    fi    
    return 0
}
