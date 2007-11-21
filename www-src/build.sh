#!/bin/bash

SRC_DIR=`dirname "$0"`
SRC_DIR=`cd "$SRC_DIR"; pwd`
BIN_DIR="$SRC_DIR/../www"
PHP=`which php php-cgi`
PHP="$PHP -q -d include_path=.:.."

cd "$SRC_DIR"
[ -d "$BIN_DIR" ] || mkdir "$BIN_DIR"

# -- Copy all files...
#
tar cv --exclude=*.php        \
       --exclude=.svn         \
       --exclude=_*.html      \
       --exclude=build.sh     \
       . | (cd "$BIN_DIR"; tar xf -)

# -- Convert all flat PHP files...
#
find . -type f -name '*.php' -a \! -name '_*' | while read F; do
    HTML="${F%.php}.html"
    if [ ! -f "$HTML" ]; then
        TARGET="$BIN_DIR/${F%.php}.html"
        DIR=`dirname "$F"`
        FILE=`basename "$F"`
        echo "$FILE -> $TARGET from $DIR"
        cd "$DIR" && $PHP "$FILE" >"$TARGET"
        cd "$SRC_DIR"
    fi
done

# -- Convert any documentation...
#
if [ -d docs -a -f docs/index.php ]; then
  cd docs
  find . -type f -name '_*.html' | while read F; do
    BASE="${F%.html}"
    ID="${BASE#./_}"
    TARGET="$BIN_DIR/docs/$ID.html"
    echo $BASE $ID $TARGET
    $PHP index.php "$ID" >"$TARGET"
  done
fi

