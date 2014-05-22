#!/usr/bin/env bash

# Every script needs RVM
source ~/.rvm/scripts/rvm

function use_jruby {
    rvm use jruby-1.7.12@${JOB_NAME:-l4e_topologies} --create
}

function setup_gems {
    gem install bundler --no-ri --no-rdoc
    bundle install
}

function rake_task {
    # Turn on error and exit options
    set -xe

    bundle exec rake $@
}

