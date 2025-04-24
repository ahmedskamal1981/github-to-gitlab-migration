#!/bin/bash
set -e

# ----------------------------
# Part 1: Repository Mirror
# ----------------------------

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

# Push the repository to GitLab using the mirror flag
echo "Pushing mirror of repository to GitLab..."
git push --mirror gitlab

echo "Repository mirror completed."

# ----------------------------
# Part 2: Migrate GitHub Issues to GitLab
# ----------------------------
echo "Migrating GitHub issues to GitLab..."

# Prompt for necessary API information
read -p "GitHub owner/organization: " GITHUB_OWNER
# Use the extracted repository name as the GitHub repository name
GITHUB_REPO_NAME="$REPO_NAME"
read -p "GitLab project ID: " GITLAB_PROJECT_ID
read -p "GitHub access token: " GITHUB_TOKEN
read -p "GitLab access token: " GITLAB_TOKEN

# Pagination: GitHub returns up to 100 issues per page.
page=1
while :; do
  # Fetch issues from GitHub (all states, 100 per page)
  response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/issues?state=all&per_page=100&page=$page")
  issue_count=$(echo "$response" | jq '. | length')
  if [ "$issue_count" -eq "0" ]; then
    break
  fi

  # Process each issue on the current page
  for row in $(echo "$response" | jq -r '.[] | @base64'); do
    _jq() {
      echo ${row} | base64 --decode | jq -r ${1}
    }
    issue_number=$(_jq '.number')
    issue_title=$(_jq '.title')
    issue_body=$(_jq '.body')
    issue_state=$(_jq '.state')

    # Create the issue on GitLab, closing it if necessary
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

