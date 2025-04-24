#!/bin/bash
set -e

# Prompt for repository URLs
read -p "GitHub repository URL: " GITHUB_REPO
read -p "GitLab repository URL: " GITLAB_REPO

# Clone the GitHub repository
if [[ -n "$GITHUB_REPO" ]]; then
    echo "Cloning GitHub repository..."
    git clone "$GITHUB_REPO"
fi

# Navigate into the 'udemy-docker-mastery' repository if it exists
if [[ -d "udemy-docker-mastery" ]]; then
    cd udemy-docker-mastery
    echo "Changed directory to udemy-docker-mastery."

    # List current remote origins
    echo "Listing remote origins:"
    git remote -v

    echo "Showing files:"
    ls

    # Add GitLab remote origin if not already present
    if git remote get-url gitlab &>/dev/null; then
        echo "GitLab remote already exists."
    else
        echo "Adding GitLab remote origin..."
        git remote add gitlab "$GITLAB_REPO"
    fi

    # List remote origins again to confirm
    echo "Listing remote origins:"
    git remote -v

    # Configure Git user identity if not set
    if ! git config --global user.email >/dev/null; then
        echo "Setting up Git user identity..."
        git config --global user.email "your-email@example.com"
        git config --global user.name "Your Name"
    fi

    # Ensure the master branch exists (optional)
    echo "Ensuring master branch exists..."
    git checkout master 2>/dev/null || git checkout -b master

    # Push all branches and tags to GitLab
    echo "Pushing all branches to GitLab..."
    git push --force gitlab --all

    echo "Pushing all tags to GitLab..."
    git push --force gitlab --tags

else
    echo "Repository 'udemy-docker-mastery' not found."
    exit 1
fi

echo "Done."

