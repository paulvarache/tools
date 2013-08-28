#!/bin/bash
# import functions from pull-all, must be in same folder as make-release
. "`dirname $0`/pull-all.sh"

# version number
## TODO(dfreedman): date stamped for now, follow polymer/package.json in the future
## make sure to update polymer/package.json to reflect this value
VERSION=`date "+v0.0.%Y%m%d"`

# ssh auth, easier to script
POLYMER_PATH="git@github.com:Polymer"

# Changelog format: - commit message ([commit](commit url on github))
PRETTY="- %s ([commit](https://github.com/Polymer/$REPO/commit/%h))"

tag_repos() {
  FAILED=()
  for REPO in ${REPOS[@]}; do
    # skip web animations repo
    if [ $REPO = 'web-animations-js' ]; then
      continue
    fi
    pushd $REPO >/dev/null
    log "TAGGING" "$REPO"
    git tag -f "$VERSION"
    if [ $? -ne 0 ]; then
      FAILED+=($REPO)
    fi
    # push only tags
    git push --tags
    popd >/dev/null
  done
  status_report "TAG"
}

gen_changelog() {
  for REPO in ${REPOS[@]}; do
    # skip web animations repo
    if [ $REPO = 'web-animations-js' ]; then
      continue
    fi
    pushd $REPO >/dev/null
    log "GEN CHANGELOG" "$REPO"
    # find slightly older tag, sorted alphabetically
    OLD_VERSION="`git tag -l | tail -n 2 | head -n 1`"
    if [[ -n $OLD_VERSION ]]; then
      echo "#### $REPO" >> "../changelog.md"
      git log $OLD_VERSION..$VERSION --pretty="$PRETTY" >> "../changelog.md"
    fi
    popd >/dev/null
  done
  ok
}

build() {
  pushd polymer >/dev/null
  log "INSTALLING" "node modules"
  npm --silent install
  log "TESTING" "polymer"
  grunt test
  if [ $? -ne 0 ]; then
    err "polymer FAILED TESTING!"
    die
  fi
  log "BUILDING" "polymer"
  grunt
  # version number on build file
  cp polymer.min.js polymer-${VERSION}.min.js
  cp polymer.min.js.map polymer-${VERSION}.min.js.map
  mv build.log polymer{,-$VERSION}.min.js{,.map} ../
  ok
  popd >/dev/null
}

package() {
  log "ZIPPING" "ALL REPOS"
  zip -q -x "polymer-$VERSION/polymer.min.js*" -x "*.git*" -x "*node_modules/*" -x "*tools/*" -r polymer-all-$VERSION.zip polymer-$VERSION
  ok
}

release() {
  mkdir -p polymer-$VERSION
  pushd polymer-$VERSION >/dev/null
  sync_repos
  tag_repos
  gen_changelog
  build
  popd >/dev/null
  package
}

release
