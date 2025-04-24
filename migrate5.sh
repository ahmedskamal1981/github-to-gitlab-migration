#!/bin/bash
set -e  # Exit immediately if any command exits with a non-zero status

# Prompt the user for the GitHub repository URL
read -p "Enter the GitHub repository URL: " GITHUB_REPO

# Prompt the user for the GitLab repository URL (SSH URL expected)
read -p "Enter the GitLab repository URL: " GITLAB_REPO

# Determine the local directory name based on the GitHub repo name (remove the .git suffix if present)
LOCAL_DIR=$(basename "$GITHUB_REPO" .git)
if [ -z "$LOCAL_DIR" ]; then
  LOCAL_DIR="repo"
fi

# Step 1: Clone the GitHub repository in mirror mode (this clones all refs, branches, tags, etc.)
echo "Cloning GitHub repository from '$GITHUB_REPO' into directory '$LOCAL_DIR' (mirror mode)..."
git clone --mirror "$GITHUB_REPO" "$LOCAL_DIR"
if [ $? -ne 0 ]; then
  echo "Error: Failed to clone the GitHub repository."
  exit 1
fi

cd "$LOCAL_DIR" || exit

# Step 2: Add the GitLab repository as a remote (named "gitlab")
echo "Adding GitLab repository as a remote..."
git remote add gitlab "$GITLAB_REPO"
if [ $? -ne 0 ]; then
  echo "Error: Failed to add GitLab remote."
  exit 1
fi

# Step 3: Push all refs (branches, tags, etc.) to GitLab using --mirror
echo "Pushing all refs to GitLab..."
git push gitlab --mirror
if [ $? -ne 0 ]; then
  echo "Error: Failed to push to GitLab."
  exit 1
fi

echo "Migration completed successfully!"

