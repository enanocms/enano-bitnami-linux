#!/bin/bash

if test -z "$BASH"; then
  cmd="$0"
  if test "`basename $0`" = "$0"; then
    cmd="./$0"
  fi
  echo "This script is designed to be run using GNU bash."
  echo "Try: chmod +x $0 && $cmd"
  exit 1
fi

# OS X sed (at least leopard and up) seem to support -E
sedflags=Ee
if ( sed --version 2>&1 | grep 'GNU sed' 2>&1 ) > /dev/null ; then
	sedflags=re
fi

my_which_real()
{
  test -n "$1" || return 1
  local i
  local part
  for (( i=1; ; i++ )); do
    part=`echo "$PATH" | cut -d ':' -f $i`
    test -n "$part" || return 1
    if test -x "$part/$1"; then
      echo "$part/$1"
      return 0
    fi
  done
}

my_which()
{
  local out
  local r
  out=`my_which_real "$1"`
  r=$?
  if [ -z "$out" -o $r = 1 ]; then
    echo "ERROR: $1 command not found on system" 1>&2
    exit 1
  fi
  echo $out
  return $r
}

# Show the extraction progress spinner.
# Spins the propeller one time for each line on stdin
progressbit()
{
  local i
  local pbar
  local line
  i=0
  pbar="-\\|/"
  while read line; do
    ((i++))
    j=$(($i % ${#pbar}))
    echo -ne "\r${pbar:$j:1} Extracting..."
  done
}

# Create a temp directory. Very bad in terms of randomness source, but hey, I'm a security major. Can't help it.
mktempdir()
{
  local tempdir
  tempdir=/tmp/ext`$dd if=/dev/urandom bs=128 count=1 2>/dev/null | $md5sum - | cut -c 1-6`
  echo $tempdir
  return 0
}

# Outputs the raw compressed tarball data on stdout.
getdata()
{
  offset=`$cat $0 | $grep -an '^##DATA' | cut -d ':' -f 1 || exit 1`
  offset=$((offset + 1))
  $cat $0 | $tail -n+$offset
}

# Go through each required command, and make sure it's on the system. If not, fail.
for cmd in bzip2 tar grep tail cat wc dd; do
  my_which $cmd>/dev/null || exit 1
  eval $cmd=`my_which $cmd`
  if test x$? = x1; then
    exit 1
  fi
done

# special case for md5sum
if my_which_real md5sum 2>&1 > /dev/null; then
	md5sum=`my_which_real md5sum`
elif my_which_real openssl 2>&1 > /dev/null; then
	md5sum=md5sum
	md5sum()
	{
		local f=${1:--}
		cat $f | openssl dgst -md5 | sed -$sedflags 's/^\(stdin\)= //'
	}
else
	echo "Could not find md5sum or openssl"
	exit 1
fi

tempdir=""
extractonly=0
while test -n "$1"; do
  case "$1" in
    -x)
      extractonly=1
      if test -n "$2"; then
        tempdir=$2
      else
        tempdir=`echo $0 | sed -$sedflags 's/\.[a-z0-9_-]{1,5}$//'`
      fi
      ;;
  esac
  shift
done

# Make sure we have a working temp directory
test -n "$tempdir" || tempdir=`mktempdir`

if [ -d "$tempdir" ]; then
  if [ $extractonly = 1 ]; then
    i=0
    basetemp="$tempdir"
    while test -d "$tempdir"; do
      tempdir="${basetemp}${i}"
      ((i++))
    done
  else
    while test -d "$tempdir"; do
      tempdir=`mktempdir`
    done
  fi
fi

mkdir "$tempdir" || exit 1

# Finally, extract the data.
echo -ne "\e[?25l- Extracting..."
getdata | $bzip2 -dc | $tar xvCf $tempdir - | progressbit \
  || (
      rm -rf $tempdir
      echo -ne "\e[?25h"
      exit 1
     )

# clear out the extraction progress
echo -ne "\r\e[?25h"

# trap exits so we can clean up if the script is interrupted
handle_interrupt()
{
  rm -rf $tempdir
  # added in rev. 2, interrupts should cause an error exit
  exit 1
}
trap handle_interrupt 0

if test -x $tempdir/autorun.sh && test $extractonly != 1; then
  # Run the autorun script
  $tempdir/autorun.sh
  ret=$?
  rm -rf $tempdir
  exit $ret
else
  # Just let the user know where the files are and die.
  echo "Contents extracted to $tempdir."
fi

# free our trap on signals
trap "exit 0;" 0

# done!
exit 0

# don't touch this marker! Everything after this is expected to be binary data.

##DATA
