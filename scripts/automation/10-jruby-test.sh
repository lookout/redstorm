#!/usr/bin/env bash
. $(dirname $0)/_init_.sh

export CI_REPORTS=spec/reports-jruby

use_jruby
setup_gems

bundle install --deployment
bundle exec redstorm deps
bundle exec redstorm build

rake_task spec
