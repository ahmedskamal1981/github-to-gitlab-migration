#!/bin/bash
set -e

# Display the current Git version
git --version

# Clone the GitHub repository using SSH to avoid credential prompts
git clone git@github.com:username/repository.git

# Extract repository name from the GitHub SSH URL and change into that directory
REPO_NAME=$(basename git@github.com:username/repository.git .git)
cd "$REPO_NAME"

# List the current remote origins
git remote -v

# Remove the existing remote 'origin' (executed twice as specified)
git remote remove origin
git remote remove origin

# Add the GitLab remote using its SSH URL (replace <GitLab_URL> with your GitLab repository SSH URL)
git remote add origin <GitLab_URL>

# Verify that the remote is now correctly set
git remote -v

# Push all branches, tags, and refs to GitLab using the mirror flag
git push --mirror origin

