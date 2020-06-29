#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

pushd .

NUM_CPUS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || getconf NPROCESSORS_ONLN 2>/dev/null || echo 1)

TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

for i in "$@"
do
  GLIBC_VERSION="$i"
  if [ "$GLIBC_VERSION" = "2.16" ]; then
    GLIBC_FNAME="glibc-$GLIBC_VERSION.0"
  else
    GLIBC_FNAME="glibc-$GLIBC_VERSION"
  fi
  wget http://ftp.gnu.org/gnu/glibc/${GLIBC_FNAME}.tar.xz
  tar -xf ${GLIBC_FNAME}.tar.xz
  rm -f -- ${GLIBC_FNAME}.tar.xz
  cd ${GLIBC_FNAME}

  CFLAGS=""
  LDFLAGS=""
  CONFIGUREFLAGS=""

  # below are workarounds for compiling old versions on new platforms
  # see https://www.lordaro.co.uk/posts/2018-08-26-compiling-glibc.html for more details

  if dpkg --compare-versions "$GLIBC_VERSION" "le" "2.17"; then
    sed -i 's/struct obstack \*_obstack_compat;/struct obstack *_obstack_compat = NULL;/g' malloc/obstack.c
  fi
  
  if dpkg --compare-versions "$GLIBC_VERSION" "le" "2.18"; then
    sed -i 's/test -n "$critic_missing"/false/g' configure
  fi

  if dpkg --compare-versions "$GLIBC_VERSION" "le" "2.21"; then
    if [ -n "`gcc -v -E 2>&1 | grep 'Configured with' | sed 's/--/\n--/g' | grep enable-default-pie`" ]; then
      LDFLAGS="-no-pie"
    else
      LDFLAGS=""
    fi
  fi

  if dpkg --compare-versions "$GLIBC_VERSION" "le" "2.25"; then
    binutils_version=$(ld --version | head -1 | awk '{print $NF}')
    if dpkg --compare-versions "$binutils_version" "ge" "2.29"; then
      patch misc/regexp.c <<EOF
32,34c32,35
< /* Define the variables used for the interface.  */
< char *loc1;
< char *loc2;
---
> /* Define the variables used for the interface.  Avoid .symver on common
>    symbol, which just creates a new common symbol, not an alias.  */
> char *loc1 __attribute__ ((nocommon));
> char *loc2 __attribute__ ((nocommon));
39c40
< char *locs;
---
> char *locs __attribute__ ((nocommon));
EOF
    fi
  fi

  # workaround for https://sourceware.org/bugzilla/show_bug.cgi?id=25225
  if dpkg --compare-versions "$GLIBC_VERSION" "ge" "2.28" && dpkg --compare-versions "$GLIBC_VERSION" "le" "2.30"; then
    cat > test_cet.c <<EOF
int
main ()
{

#ifndef __CET__
#error no CET compiler support
#endif
  ;
  return 0;
}
EOF
    if gcc test_cet.c 2>/dev/null; then
      CONFIGUREFLAGS="--enable-cet"
    fi
    rm -f test_cet.c
  fi

  CFLAGS="-O2 -U_FORTIFY_SOURCE -fno-stack-protector"

  mkdir build
  cd build
  CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" ../configure --prefix=/opt/glibc${GLIBC_VERSION} --disable-werror $CONFIGUREFLAGS
  make -j$((NUM_CPUS+1)) LDFLAGS="$LDFLAGS" CFLAGS="$CFLAGS"
  make install

  cd "../.."
  rm -rf -- "${GLIBC_FNAME}"
done

popd

rm -rf -- "$TEMP_DIR"

exit 0
