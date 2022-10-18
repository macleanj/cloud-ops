#!/bin/bash

# Collection of useful git utilities.
# Todo

exit

# Search history for deleted files
# https://stackoverflow.com/questions/7203515/how-to-find-a-deleted-file-in-the-project-commit-history
# Example
git log --diff-filter=D --summary | grep delete | grep destroy

# Search history for changed content
# https://stackoverflow.com/questions/2928584/how-to-grep-search-committed-code-in-the-git-history
# Example
git rev-list --all | xargs git grep deleteConfigOcp
# Limited to subdir
git grep deleteConfigOcp $(git rev-list --all -- vars/) -- vars/
# Show file
git show b22040870939e4f96a6306d09679dc26b650f762:vars/vault.groovy

