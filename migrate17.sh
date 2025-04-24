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

# Extract the repository name from the GitHub URL (removing a trailing .git if present)
REPO_NAME=$(basename "$GITHUB_REPO" .git)

# Navigate into the repository directory if it exists
if [[ -d "$REPO_NAME" ]]; then
    cd "$REPO_NAME" || { echo "Failed to change directory to $REPO_NAME."; exit 1; }
    echo "Changed directory to $REPO_NAME."
else
    echo "Repository '$REPO_NAME' not found."
    exit 1
fi


    # List current remote origins
    echo "Listing remote origins:"
    git remote -v

    echo "Showing files:"
    ls

    git remote remove origin

    git remote -v

    # Add GitLab remote origin if not already present
    if git remote get-url gitlab &>/dev/null; then
        echo "GitLab remote already exists."
    else
        echo "Adding GitLab remote origin..."
        git remote add gitlab "$GITLAB_REPO"
    fi

    # Verify remote origins after adding GitLab remote
    echo "Listing remote origins after adding GitLab remote:"
    git remote -v

    # Configure Git user identity if not set
    if ! git config --global user.email >/dev/null; then
        echo "Setting up Git user identity..."
        git config --global user.email "your-email@example.com"
        git config --global user.name "Your Name"
    fi

    # Check out the 'main' branch (create it if it does not exist)
    echo "Checking out main branch..."
    git checkout main 2>/dev/null || git checkout -b main

    # Push the main branch to GitLab and set it as the upstream branch
    echo "Pushing main branch to GitLab..."
    git push --mirror gitlab
else
    echo "Repository 'udemy-docker-mastery' not found."
    exit 1
fi

echo "Done."
    
   
 
