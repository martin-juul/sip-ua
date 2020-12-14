#!/usr/bin/env sh

set -e

yarn build

cd src/.vuepress/dist

git init
git add -A
git commit -m 'deploy'

git push -f git@github.com:martin-juul/sip-ua.git master:gh-pages

cd ../../../
