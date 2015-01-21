#!/bin/bash
# 
#   Copyright (C) 2014 Linaro, Inc
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# 

# To run, this script takes arguments in the same format as abe.sh. The two
# arguments it needs is the target archicture to build, and the gcc backport
# branch name. Example:
# $PATH/test-backport.sh --target arm-linux-gnueabihf gcc.git~4.9-backport-209419
usage()
{
    # Format this section with 75 columns.
    cat << EOF
  test-backport.sh [--help] [f|--fileserver remote file server] --target triplet branch
EOF
    return 0
}

if test $# -lt 2; then
    echo "ERROR: No branches to build!"
    usage
    exit
fi

# load commonly used functions
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "Error: this script needs to be run from a configured Abe tree!" 1>&2
fi
abe="`which $0`"
abe_path="`dirname ${abe}`"
topdir="${abe_path}"
abe="`basename $0`"

basedir="/work/logs"
repo="gcc.git"
fileserver="abe.tcwglab.linaro.org"
branch=""

OPTS="`getopt -o s:r:f:w:o:t:g:h -l target:,fileserver:,help:,snapshots:,repo:,workspace:,options -- "$@"`"
while test $# -gt 0; do
    echo 1 = "$1"
    case $1 in
        -s|--snapshots) local_snapshots=$2 ;;
        -f|--fileserver) fileserver=$2 ;;
	-r|--repo) repo=$2 ;;
        -w|--workspace) user_workspace=$2 ;;
        -o|--options) user_options=$2 ;;
	-t|--target) target=$2 ;;
        -h|--help) usage ;;
	*) branch=$1;;
	--) break ;;
    esac
    shift
done

if test "`echo ${branch} | grep -c gcc.git`" -gt 0; then
    branch="`echo ${branch} | sed -e 's:gcc.git~::'`"
fi

#if test x"${git_reference_dir}" != x; then
#    srcdir="${git_reference_dir}/${branch}"
#else
    git_reference_dir="${local_snapshots}"
    srcdir="${local_snapshots}/${branch}"
#fi

rm -fr ${srcdir}
git-new-workdir ${git_reference_dir}/${repo} ${srcdir} ${branch}

# Get the last two revisions
declare -a revisions=(`cd ${srcdir} && git log -n 2 | grep ^commit | cut -d ' ' -f 2`)

# Force GCC to not build the docs
export BUILD_INFO=""

# Don't try to add comments to Gerrit if run manually
if test x"${GERRIT_PATCHSET_REVISION}" != x; then
    gerrit="--enable gerrit"
else
    gerrit=""
fi

# Checkout all the sources
bash -x ${topdir}/abe.sh --checkout all

resultsdir="/tmp/abe-${target}@"
i=0
while test $i -lt ${#revisions[@]}; do
    job="Backport.job"
    dir="${basedir}/gcc-linaro-${version}/${branch}/${job}${BUILD_NUMBER}/${arch}.${target}/${revisions[$i]}"

    # Don't build if a previous build of this revision exists
    exists="`ssh ${fileserver} "if test -d ${dir}; then echo YES; else echo NO; fi"`"
    if test x"${exists}" = x"YES"; then
	continue
    fi
    bash -x ${topdir}/abe.sh ${gerrit} --disable update --check --target ${target} gcc=gcc.git@${revisions[$i]} --build all --disable make_docs
    if test $? -gt 0; then
	echo "ERROR: Abe failed!"
	exit 1
    fi
    sums="`find ${local_builds}/${build}/${target} -name \*.sum`"
    logs="`echo ${sums} | sed 's/\.sum/.log/g'`"
    manifest="`find ${local_builds}/${build}/${target} -name manifest.txt`"
    if test x"${sums}" != x; then
	mkdir -p ${resultsdir}${revisions[$i]}
	cp -f ${sums} ${logs} ${manifest} ${resultsdir}${revisions[$i]}/
	    # We don't need these files leftover from the DejaGnu testsuite
            # itself.
	xz -f ${resultsdir}${revisions[$i]}/*.{sum,log}
	rm -f ${resultsdir}${revisions[$i]}/{x,xXx,testrun}.*
    fi

    mv ${manifest} ${manifest}.${revisions[$i]}
    ssh ${fileserver} mkdir -p ${dir}

    # Compress and copy all files from the first build
    xz ${resultsdir}${revisions[0]}/*.sum ${resultsdir}${revisions[$i]}/*.log
    scp ${resultsdir}${revisions[0]}/* ${fileserver}:${dir}/
    
    i="`expr $i + 1`"
done

# Test results and logs optionally get copied to this fileserver.
if test x"${fileserver}" != x; then
    # Diff the two directories
    scp ${topdir}/tcwgweb.sh ${fileserver}:/tmp/tcwgweb$$.sh
    dir1="${basedir}/gcc-linaro-${version}/${branch}/${job}${BUILD_NUMBER}/${arch}.${target}/${revisions[0]}"
    dir2="${basedir}/gcc-linaro-${version}/${branch}/${job}${BUILD_NUMBER}/${arch}.${target}/${revisions[1]}"
    ssh  ${fileserver} /tmp/tcwgweb$$.sh --email --tdir ${dir1} ${dir2}
fi
