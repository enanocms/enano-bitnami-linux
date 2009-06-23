#!/bin/bash
DATE=`date "+%Y%m%d"`
VERSION="hg-$DATE"
REPO="./enano-hg"
REVISION="tip"

usage()
{
  cat <<EOF
Usage: $0 [flags]
Available command-line parameters:

  -h                This help
  -v version        Specify version of package (default: hg-$DATE)
  -r revision       Mercurial revision to pull (default: tip)
  -R repopath       Path to Mercurial repository (default: ./enano-hg)

EOF
  exit 1
}

fail()
{
  echo $1
  exit 1
}

while [ -n "$1" ]; do
  case "$1" in
    -v)
      VERSION="$2"
      shift
      ;;
    -r)
      REVISION="$2"
      shift
      ;;
    -R)
      REPO="$2"
      shift
      ;;
    *)
      usage
      ;;
  esac
  shift
done

if [ -z "$VERSION" -o -z "$REVISION" -o -z "$REPO" ]; then
  usage
fi

if [ ! -d "$REPO/.hg" ]; then
  echo "ERROR: Could not find the Enano Mercurial repository at $REPO."
  echo "Perhaps you need to obtain a copy?"
  echo "  $ hg clone http://hg.enanocms.org/repos/enano-1.1 ./enano-hg"
  echo "If you already have a copy somewhere else, make a symlink:"
  echo "  $ ln -s /path/to/enano/hg ./enano-hg"
  exit 1
fi

printf "Compacting self-extraction script..."
sed -f compact-shellscript.sed self-extract-src.sh > self-extract.sh || fail "Failed to generate compacted self-extract script"

printf "\nPulling latest code..."
hg -R $REPO archive -r $REVISION -t tgz enano-$VERSION.tar.gz || fail "Could not pull revision $REVISION from Mercurial repo"
printf "\nExtracting..."
tar xzCf `dirname $0`/stage enano-$VERSION.tar.gz || fail "Could not extract tarball"
rm -f enano-$VERSION.tar.gz
printf "\nCreating payload..."
cd stage
tar cjf ../enano-$VERSION-selfextract.tar.bz2 autorun.sh COPYING enano-$VERSION || fail "Could not create staging tarball"
rm -rf enano-$VERSION
cd ..
printf "\nWriting output..."
cat self-extract.sh enano-$VERSION-selfextract.tar.bz2 > enano-$VERSION-bitnami-module.sh || fail "Could not write output"
chmod +x enano-$VERSION-bitnami-module.sh
rm -f enano-$VERSION-selfextract.tar.bz2
echo -e "\nDone! Output written to enano-$VERSION-bitnami-module.sh"

