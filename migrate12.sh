#!/bin/bash
set -e  # Exit script on error

# Prompt for repository URLs
read -p "GitHub repository URL: " GITHUB_REPO
read -p "GitLab repository URL: " GITLAB_REPO

# Extract repository name from GitHub URL
REPO_NAME=$(basename -s .git "$GITHUB_REPO")

# Clone the GitHub repository as a mirror
if [[ -n "$GITHUB_REPO" ]]; then
    echo "Cloning GitHub repository as a mirror..."
    git clone --mirror "$GITHUB_REPO" "$REPO_NAME.git"
fi

# Navigate into the mirrored repository if it exists
if [[ -d "$REPO_NAME.git" ]]; then
    cd "$REPO_NAME.git"
    echo "Changed directory to $REPO_NAME.git."

    # List remote origins
    echo "Listing remote origins:"
    git remote -v

    # Update the mirror repository (fetch all changes and prune obsolete refs)
    echo "Updating mirror repository..."
    git remote update --prune

    # Add GitLab remote if it doesn't exist
    if git remote get-url gitlab &>/dev/null; then
        echo "GitLab remote already exists."
    else
        echo "Adding GitLab remote origin..."
        git remote add gitlab "$GITLAB_REPO"
    fi

    # Configure Git user identity if not set
    if ! git config --global user.email >/dev/null; then
        echo "Setting up Git user identity..."
        git config --global user.email "your-email@example.com"
        git config --global user.name "Your Name"
    fi

    # Force push all branches and tags to GitLab using mirror push
    echo "Force pushing all branches and tags to GitLab..."
    git push --all gitlab
else
    echo "Repository '$REPO_NAME.git' not found."
    exit 1
fi

echo "Done."

