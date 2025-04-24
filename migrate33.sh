#!/bin/bash
set -e

# ----------------------------
# Part 1: Repository Mirror with Update Detection
# ----------------------------

# Prompt for repository URLs
read -p "GitHub repository URL: " GITHUB_REPO
read -p "GitLab repository URL: " GITLAB_REPO

# Extract the repository name and owner from GitHub URL
REPO_NAME=$(basename "$GITHUB_REPO" .git)
GITHUB_OWNER=$(echo "$GITHUB_REPO" | awk -F'[:/]' '{print $(NF-1)}')

# Create tracking file path
TRACKING_FILE="$HOME/.${REPO_NAME}_last_commit.txt"

# Fetch latest commit hash from GitHub API (unauthenticated)
LATEST_COMMIT=$(curl -s \
  "https://api.github.com/repos/$GITHUB_OWNER/$REPO_NAME/commits/main" | jq -r '.sha')

# Read last known commit
if [[ -f "$TRACKING_FILE" ]]; then
    LAST_COMMIT=$(cat "$TRACKING_FILE")
else
    LAST_COMMIT=""
fi

# If the commit has changed, delete old repo and clone again
if [[ "$LATEST_COMMIT" != "$LAST_COMMIT" ]]; then
    echo "New update detected in GitHub repository."

    # Remove old repository directory if it exists
    if [[ -d "$REPO_NAME" ]]; then
        echo "Deleting old local copy of $REPO_NAME..."
        rm -rf "$REPO_NAME"
    fi

    echo "Cloning updated GitHub repository..."
    git clone "$GITHUB_REPO"

    # Navigate into the repository directory
    cd "$REPO_NAME" || { echo "Failed to change directory to $REPO_NAME."; exit 1; }
    echo "Changed directory to $REPO_NAME."

    # Remove existing origin and add GitLab as remote
    git remote remove origin 2>/dev/null || true
    if git remote get-url gitlab &>/dev/null; then
        echo "GitLab remote already exists."
    else
        echo "Adding GitLab remote origin..."
        git remote add gitlab "$GITLAB_REPO"
    fi

    # Configure Git identity if needed
    if ! git config --global user.email >/dev/null; then
        echo "Setting up Git user identity..."
        git config --global user.email "your-email@example.com"
        git config --global user.name "Your Name"
    fi

    # Check out the 'main' branch
    echo "Checking out main branch..."
    git checkout main 2>/dev/null || git checkout -b main

    # Push repository to GitLab
    echo "Pushing mirror of repository to GitLab..."
    git push --mirror gitlab

    echo "$LATEST_COMMIT" > "$TRACKING_FILE"
    echo "Repository mirror completed."
else
    echo "No changes detected in GitHub repository. Skipping clone and push."
    cd "$REPO_NAME" || exit
fi

# ----------------------------
# Part 2: Migrate GitHub Issues to GitLab
# ----------------------------

echo "Migrating GitHub issues to GitLab..."

GITHUB_REPO_NAME="$REPO_NAME"
read -p "GitLab project ID: " GITLAB_PROJECT_ID
read -p "GitLab access token: " GITLAB_TOKEN

page=1
while :; do
  response=$(curl -s \
    "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/issues?state=all&per_page=100&page=$page")
  issue_count=$(echo "$response" | jq '. | length')
  if [ "$issue_count" -eq "0" ]; then
    break
  fi

  for row in $(echo "$response" | jq -r '.[] | @base64'); do
    _jq() {
      echo ${row} | base64 --decode | jq -r ${1}
    }
    issue_number=$(_jq '.number')
    issue_title=$(_jq '.title')
    issue_body=$(_jq '.body')
    issue_state=$(_jq '.state')

    if [ "$issue_state" = "closed" ]; then
      curl -s -X POST "https://gitlab.com/api/v4/projects/$GITLAB_PROJECT_ID/issues" \
           -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
           -d "title=$issue_title" \
           -d "description=$issue_body" \
           -d "state_event=close"
    else
      curl -s -X POST "https://gitlab.com/api/v4/projects/$GITLAB_PROJECT_ID/issues" \
           -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
           -d "title=$issue_title" \
           -d "description=$issue_body"
    fi

    echo "Migrated GitHub issue #$issue_number: $issue_title"
  done

  page=$((page+1))
done

echo "Issues migration completed."

