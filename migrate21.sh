#!/bin/bash
set -e

# ----------------------------
# Part 1: Repository Mirror
# ----------------------------

# Prompt for repository URLs
read -p "GitHub repository URL: " GITHUB_REPO
read -p "GitLab repository URL: " GITLAB_REPO

# Extract the repository name from the GitHub URL (removing a trailing .git if present)
REPO_NAME=$(basename "$GITHUB_REPO" .git)

# Clone the GitHub repository
if [[ -n "$GITHUB_REPO" ]]; then
    echo "Cloning GitHub repository..."
    git clone "$GITHUB_REPO"
    cd "$REPO_NAME" || { echo "Failed to change directory to $REPO_NAME."; exit 1; }
    echo "Changed directory to $REPO_NAME."

    # Fetch all tags explicitly
    git fetch --all --tags
else
    echo "No GitHub repository URL provided."
    exit 1
fi

# Remove origin and add GitLab remote
echo "Setting up GitLab remote..."
git remote remove origin 2>/dev/null || true

if git remote get-url gitlab &>/dev/null; then
    echo "GitLab remote already exists."
else
    git remote add gitlab "$GITLAB_REPO"
fi

# Configure Git user identity if not set
if ! git config --global user.email >/dev/null; then
    echo "Setting up Git user identity..."
    git config --global user.email "your-email@example.com"
    git config --global user.name "Your Name"
fi

# Force push branches and tags to GitLab
echo "Pushing all branches to GitLab..."
git push gitlab --all --force

echo "Pushing all tags to GitLab..."
git push gitlab --tags --force

echo "Repository migration to GitLab completed."

# ----------------------------
# Part 2: Migrate GitHub Issues to GitLab
# ----------------------------
echo "Migrating GitHub issues to GitLab..."

# Prompt for necessary API information
read -p "GitHub owner/organization: " GITHUB_OWNER
GITHUB_REPO_NAME="$REPO_NAME"
read -p "GitLab project ID: " GITLAB_PROJECT_ID
read -p "GitHub access token: " GITHUB_TOKEN
read -p "GitLab access token: " GITLAB_TOKEN

# Pagination for GitHub issues
page=1
while :; do
  response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/issues?state=all&per_page=100&page=$page")
  issue_count=$(echo "$response" | jq '. | length')
  if [ "$issue_count" -eq "0" ]; then
    break
  fi

  for row in $(echo "$response" | jq -r '.[] | @base64'); do
    _jq() {
      echo ${row} | base64 --decode | jq -r ${1}
    }

    issue_number=$(_jq '.number')
    issue_title=$(_jq '.title' | sed 's/"/\\"/g')
    issue_body=$(_jq '.body' | sed 's/"/\\"/g')
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

