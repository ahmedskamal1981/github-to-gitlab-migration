#!/bin/bash
set -e

# ----------------------------
# Part 1: Mirror Repository
# ----------------------------

# Display the current Git version
git --version

# Clone the GitHub repository using SSH (adjust the URL accordingly)
git clone git@github.com:username/repository.git

# Change directory into the repository
REPO_NAME=$(basename git@github.com:username/repository.git .git)
cd "$REPO_NAME"

# List current remote origins
git remote -v

# Remove the existing remote 'origin' (ignoring errors if it doesn't exist)
git remote remove origin || true
git remote remove origin || true

# Add the GitLab remote using its SSH URL (replace <GitLab_URL> with your GitLab repository SSH URL)
git remote add origin <GitLab_URL>

# Verify that the remote is set correctly
git remote -v

# Mirror push all branches, tags, and refs to GitLab
git push --mirror origin

# ----------------------------
# Part 2: Migrate GitHub Issues
# ----------------------------
# This section uses the GitHub and GitLab APIs.
# Requirements:
#   - 'jq' must be installed (e.g., sudo apt-get install jq)
#   - A GitHub personal access token with repo access
#   - A GitLab personal access token with API permissions
#   - Your GitLab project ID (from your project settings)

# Set required variables (update these with your actual values)
GITHUB_OWNER="username"             # GitHub username or organization
GITHUB_REPO="repository"            # GitHub repository name
GITLAB_PROJECT_ID="<project_id>"     # GitLab project ID
GITHUB_TOKEN="your_github_token"     # GitHub personal access token
GITLAB_TOKEN="your_gitlab_token"     # GitLab personal access token

page=1
while :; do
  # Fetch issues from GitHub (all states, 100 per page)
  response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/issues?state=all&per_page=100&page=$page")
  issue_count=$(echo "$response" | jq '. | length')
  [ "$issue_count" -eq "0" ] && break

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

