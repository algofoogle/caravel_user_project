#!/bin/bash

for step in extract-parasitics create-spef-mapping caravel-sta; do
    echo "*** STEP: $step ----------------------------------------------------------------"
    if ! make $step; then
        echo "*** ERROR: Step $step failed; aborting."
        exit 1
    fi
done

echo "*** DONE ***"

