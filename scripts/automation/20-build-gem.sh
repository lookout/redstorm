#!/usr/bin/env bash
. $(dirname $0)/_init_.sh

export CI_REPORTS=spec/reports-jruby

mkdir -p pkg
gem build lookout-redstorm.gemspec
mv lookout-redstorm-*.gem pkg
