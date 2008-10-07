#!/bin/sh
package="userman"
[ "x$1" = "x-b" ] && also_build=1 || also_build=0
name=`grep Name: $package.spec | head -1 | awk '{print $2}'`
version=`grep Version: $package.spec | head -1 | awk '{print $2}'`
release=`grep Release: $package.spec | head -1 | awk '{print $2}'`
dir="$name-$version"
tar=$dir.tar.gz
tmp=/tmp/make-tarball-$$
rpmsrc=/usr/src/redhat/SOURCES
mkdir -p $tmp
cd $PWD
curdir=$PWD
cp -rp . $tmp/$dir
cd $tmp
tar --exclude .svn -czf $curdir/../$tar $dir
cd $curdir
rm -rf $tmp
echo $tar
if [ $also_build = 1 ]; then
  cp ../$tar $rpmsrc
  rpmbuild -ta $rpmsrc/$tar
  echo done
fi
