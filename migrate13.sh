#!/bin/bash
set -e

# Prompt for repository URLs
read -p "GitHub repository URL: " GITHUB_REPO
read -p "GitLab repository URL: " GITLAB_REPO

# Clone the repositories
if [[ -n "$GITHUB_REPO" ]]; then
    echo "Cloning GitHub repository..."
    git clone "$GITHUB_REPO"
fi

# Navigate into the 'udemy-docker-mastery' repository if it exists
if [[ -d "udemy-docker-mastery" ]]; then
    cd udemy-docker-mastery
    echo "Changed directory to udemy-docker-mastery."

    # List remote origins
    echo "Listing remote origins:"
    git remote -v

    echo "show fils:"
    ls

    # Add GitLab remote origin
    if git remote get-url gitlab &>/dev/null; then
        echo "GitLab remote already exists."
    else
        echo "Adding GitLab remote origin..."
        git remote add gitlab "$GITLAB_REPO"
    fi

    # List remote origins
    echo "Listing remote origins:"
    git remote -v

    # Configure Git user identity if not set
    if ! git config --global user.email >/dev/null; then
        echo "Setting up Git user identity..."
        git config --global user.email "your-email@example.com"
        git config --global user.name "Your Name"
    fi

    # create master branch
    echo "Creating master branch if not exists..."
    git checkout master 2>/dev/null || git checkout -b master

    # Fetch latest changes from GitLab and rebase
    echo "Fetching latest changes from GitLab..."
    git fetch gitlab
    git rebase gitlab/master

    # Push to GitLab origin
    echo "Pushing to GitLab..."
    git push gitlab master

else
    echo "Repository 'udemy-docker-mastery' not found."
    exit 1
fi

echo "Done." 
