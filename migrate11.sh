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

    # Fetch latest changes from origin
    echo "Fetching latest changes from origin..."
    git fetch origin --prune

    # Determine the default branch dynamically
    DEFAULT_BRANCH=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
    if [[ -z "$DEFAULT_BRANCH" ]]; then
        echo "Default branch not found via 'git remote show origin'. Trying HEAD file..."
        if [[ -f HEAD ]]; then
            DEFAULT_BRANCH=$(sed 's|ref: refs/heads/||' HEAD)
        fi
    fi

    if [[ -z "$DEFAULT_BRANCH" ]]; then
        echo "Error: Could not determine default branch. Exiting..."
        exit 1
    fi

    echo "Default branch detected: $DEFAULT_BRANCH"

    # Reset local repository to match remote default branch
    echo "Resetting local repository to match origin/$DEFAULT_BRANCH..."
    git reset --hard "origin/$DEFAULT_BRANCH"

    # Prune obsolete references
    echo "Pruning obsolete references from remote origin..."
    git remote prune origin

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

    # Force push all branches and tags to GitLab
    echo "Force pushing all branches and tags to GitLab..."
    git push --force gitlab --all  # Push all branches
    git push --force gitlab --tags  # Push all tags
    git reset --hard "origin/$DEFAULT_BRANCH"

else
    echo "Repository '$REPO_NAME.git' not found."
    exit 1
fi

echo "Done."

