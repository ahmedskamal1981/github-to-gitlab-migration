#!/bin/bash
set -e

# Check if GitHub repository URL is provided
if [ -z "$GITHUB_REPO" ]; then
    echo "No GitHub repository URL provided."
    exit 1
fi

# Check if the repository directory already exists
if [ -d "$REPO_NAME" ]; then
    echo "Repository directory '$REPO_NAME' already exists. Pulling latest changes..."
    cd "$REPO_NAME" || { echo "Failed to change directory to '$REPO_NAME'."; exit 1; }
    git fetch --all --tags
    git pull --rebase
else
    echo "Cloning GitHub repository..."
    git clone "$GITHUB_REPO"
    cd "$REPO_NAME" || { echo "Failed to change directory to '$REPO_NAME'."; exit 1; }
    echo "Changed directory to '$REPO_NAME'."
    # Fetching tags after clone to ensure all tags are available
    git fetch --all --tags
fi

# Remove the GitHub origin remote and add the GitLab remote
echo "Setting up GitLab remote..."
git remote remove origin 2>/dev/null || true

if git remote get-url gitlab &>/dev/null; then
    echo "GitLab remote already exists."
else
    git remote add gitlab "$GITLAB_REPO"
fi

# Configure Git user identity globally if not already set
if ! git config --global user.email >/dev/null 2>&1; then
    echo "Setting up Git user identity..."
    git config --global user.email "your-email@example.com"
    git config --global user.name "Your Name"
fi

# Force push all branches and tags to GitLab
echo "Pushing all branches to GitLab..."
git push gitlab --all --force

echo "Pushing all tags to GitLab..."
git push gitlab --tags --force

echo "Repository migration to GitLab completed."

# ----------------------------
# Part 2: Migrate GitHub Issues to GitLab
# ----------------------------
echo "Migrating GitHub issues to GitLab..."

# Prompt for API information
read -p "GitHub owner/organization: " GITHUB_OWNER
GITHUB_REPO_NAME="$REPO_NAME"
read -p "GitLab project ID: " GITLAB_PROJECT_ID
read -p "GitHub access token: " GITHUB_TOKEN
read -p "GitLab access token: " GITLAB_TOKEN

# Pagination for GitHub issues migration
page=1
while :; do
  response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/issues?state=all&per_page=100&page=$page")
  issue_count=$(echo "$response" | jq '. | length')
  if [ "$issue_count" -eq "0" ]; then
    break
  fi

  for row in $(echo "$response" | jq -r '.[] | @base64'); do
    _jq() {
      echo "${row}" | base64 --decode | jq -r "${1}"
    }

    issue_number=$(_jq '.number')
    # Escape potential double quotes in title and body
    issue_title=$(_jq '.title' | sed 's/"/\\"/g')
    issue_body=$(_jq '.body' | sed 's/"/\\"/g')
    issue_state=$(_jq '.state')

    # Create GitLab issue; if the GitHub issue is closed, then close the GitLab issue too
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

