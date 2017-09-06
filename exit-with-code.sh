#!/bin/bash

sleep 180
yes test-test-test | paste - - - - - - - - | head -1000 | nl

exit ${1:-0}
