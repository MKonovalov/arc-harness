#!/bin/bash
# review post-hook: return to main branch.

if ! git checkout main 2>&1; then
    echo "WARNING: Failed to return to main branch. Next agent run may be on wrong branch."
fi
