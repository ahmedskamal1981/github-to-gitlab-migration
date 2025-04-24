#!/bin/bash
set -e

# Prompt for repository URLs
read -p "GitHub repository URL: " GITHUB_REPO
read -p "GitLab repository URL: " GITLAB_REPO

# Clone the GitHub repository if a URL was provided
if [[ -n "$GITHUB_REPO" ]]; then
    echo "Cloning GitHub repository..."
    git clone "$GITHUB_REPO"
fi

# Navigate into the 'udemy-docker-mastery' repository if it exists
if [[ -d "udemy-docker-mastery" ]]; then
    cd udemy-docker-mastery
    echo "Changed directory to udemy-docker-mastery."

    # List current remote origins for verification
    echo "Listing remote origins:"
    git remote -v

    echo "Showing files:"
    ls

    # Add GitLab remote origin if it doesn't already exist
    if git remote get-url gitlab &>/dev/null; then
        echo "GitLab remote already exists."
    else
        echo "Adding GitLab remote origin..."
        git remote add gitlab "$GITLAB_REPO"
    fi

    # List remote origins again after adding GitLab
    echo "Listing remote origins:"
    git remote -v

    # Configure Git user identity if not set
    if ! git config --global user.email >/dev/null; then
        echo "Setting up Git user identity..."
        git config --global user.email "your-email@example.com"
        git config --global user.name "Your Name"
    fi

    # Create or switch to the 'main' branch
    echo "Creating main branch if it does not exist..."
    git checkout main 2>/dev/null || git checkout -b main

    # Fetch the latest changes from GitLab and rebase against the remote 'main' branch
    echo "Fetching latest changes from GitLab..."
    git fetch gitlab
    git rebase gitlab/main

    # Push the local 'main' branch to GitLab
    echo "Pushing to GitLab..."
    git push gitlab main

else
    echo "Repository 'udemy-docker-mastery' not found."
    exit 1
fi

echo "Done."

