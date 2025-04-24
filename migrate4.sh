#!/bin/bash
set -e  # Exit immediately on error

# Prompt the user for the GitHub repository URL
read -p "Enter the URL for the GitHub repository: " GITHUB_REPO

# Prompt the user for the GitLab repository URL (SSH URL expected)
read -p "Enter the URL for the GitLab repository: " GITLAB_REPO

# Determine the local directory name based on the GitHub repo name (remove the .git suffix if present)
LOCAL_DIR=$(basename -s .git "$GITHUB_REPO")
if [ -z "$LOCAL_DIR" ]; then
  LOCAL_DIR="repo"
fi

# Step 1: Clone the GitHub repository
echo "Cloning GitHub repository from '$GITHUB_REPO' into directory '$LOCAL_DIR'..."
git clone "$GITHUB_REPO" "$LOCAL_DIR"
if [ $? -ne 0 ]; then
  echo "Error: Failed to clone the GitHub repository."
  exit 1
fi

cd "$LOCAL_DIR" || exit

# Remove any unwanted remote named "ssh_origin" if it exists
if git remote | grep -q "ssh_origin"; then
  echo "Removing unwanted remote 'ssh_origin'..."
  git remote remove ssh_origin
fi

# Step 2: Add the GitLab repository as a remote
echo "Adding GitLab repository as a remote..."
git remote add gitlab "$GITLAB_REPO"
if [ $? -ne 0 ]; then
  echo "Error: Failed to add GitLab remote."
  exit 1
fi

# Optional: Show the current remote configuration for debugging
echo "Current git remotes:"
git remote -v

# Step 3: Force push each branch individually using an explicit refspec
echo "Force pushing all branches to GitLab..."
for branch in $(git for-each-ref --format="%(refname:short)" refs/heads/); do
    echo "Force pushing branch: $branch"
    git push gitlab refs/heads/"$branch":refs/heads/"$branch" --force
    if [ $? -ne 0 ]; then
      echo "Error: Failed to force push branch '$branch'."
      exit 1
    fi
done

# Step 4: Force push all tags to GitLab
echo "Force pushing all tags to GitLab..."
git push gitlab --tags --force
if [ $? -ne 0 ]; then
  echo "Error: Failed to force push tags."
  exit 1
fi

echo "Migration completed successfully!"

