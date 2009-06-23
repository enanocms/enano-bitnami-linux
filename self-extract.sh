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

my_which_real()
{
	test -n "$1" || return 1
	local i
	local part
	for (( i=1; ; i++ )); do
		part=`echo "$PATH" | cut -d ':' -f $i`
		test -n "$part" || return 1
		if test -x "$part/$1"; then echo "$part/$1"; return 0; fi
	done
}

my_which()
{
	local out
	local r
	out=`my_which_real "$1"`
	r=$?
	if test -z "$out" -o $r = 1 ; then echo "ERROR: $1 command not found on system" 1>&2;exit 1;fi
	echo $out
	return $r
}

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

mktempdir()
{
	local tempdir
	tempdir=/tmp/ext`$dd if=/dev/urandom bs=128 count=1 2>/dev/null | $md5sum - | cut -c 1-6`
	echo $tempdir
	return 0
}

getdata()
{
	offset=`$cat $0 | $grep -an '^##DATA' | cut -d ':' -f 1 || exit 1`
	offset=$((offset + 1))
	$cat $0 | $tail -n+$offset
}

for cmd in bzip2 tar grep tail cat wc dd md5sum; do
	my_which $cmd>/dev/null || exit 1
	eval $cmd=`my_which $cmd`
	if test x$? = x1; then
		exit 1
	fi
done

tempdir=""
extractonly=0
while test -n "$1"; do
	case "$1" in
	-x)
		extractonly=1
		if test -n "$2"; then
      tempdir=$2
    else
      tempdir=`echo $0 | sed -re 's/\.[a-z0-9_-]{1,5}$//'`
    fi
		;;
	esac
	shift
done

test -n "$tempdir" || tempdir=`mktempdir`

if test -d "$tempdir"; then
if test $extractonly = 1; then
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
echo -ne "\e[?25l- Extracting..."
getdata | $bzip2 -dc | $tar xvCf $tempdir - | progressbit \
  || (
      rm -rf $tempdir
      echo -ne "\e[?25h"
      exit 1
     )

echo -ne "\r\e[?25h"

# trap exits so we can clean up if the script is interrupted
handle_interrupt()
{
  rm -rf $tempdir
}
trap handle_interrupt 0

if test -x $tempdir/autorun.sh && test $extractonly != 1; then
	$tempdir/autorun.sh
	ret=$?
	rm -rf $tempdir
	exit $ret
else
	echo "Contents extracted to $tempdir."
fi

trap "exit 0;" 0

exit 0

##DATA
