#!/bin/bash

sleep 360
yes test-test-test | paste - - - - - - - - | head -1000 | nl
sleep 5
exit ${1:-0}
