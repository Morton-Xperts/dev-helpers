#!/usr/bin/env just

import './recipes/index.just'

@default:
    @echo "Available recipes:"
    @just --choose
