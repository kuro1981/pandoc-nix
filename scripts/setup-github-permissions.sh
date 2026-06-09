#!/usr/bin/env bash
set -euo pipefail

echo "Configuring GitHub repository settings for automated Pandoc updates..."

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "Repository: ${REPO}"

cat <<EOF

================================================================
MANUAL CONFIGURATION REQUIRED
================================================================

Step 1: GitHub Actions permissions
1. Open: https://github.com/${REPO}/settings/actions
2. In "Workflow permissions", choose "Read and write permissions"
3. Check "Allow GitHub Actions to create and approve pull requests"
4. Save

Step 2: Enable auto-merge
1. Open: https://github.com/${REPO}/settings
2. In "Pull Requests", enable "Allow auto-merge"
3. Save

After this, test update automation with:
  gh workflow run "Check for Pandoc Updates"

================================================================

EOF

mkdir -p .github

cat > .github/REPOSITORY_SETTINGS.md <<'EOF'
# Repository Settings Configuration

This repository requires specific GitHub settings for automated Pandoc updates.

## Required Settings

### GitHub Actions Permissions

1. Open Settings -> Actions -> General
2. Under "Workflow permissions":
   - Select "Read and write permissions"
   - Check "Allow GitHub Actions to create and approve pull requests"
3. Save

These settings allow the update workflow to:
- Modify files in the repository
- Create pull requests for version updates
- Update the flake.lock file

## Verification

After configuring settings:

```bash
gh workflow run "Check for Pandoc Updates"
gh run list --workflow="Check for Pandoc Updates"
```

## Troubleshooting

If you see "GitHub Actions is not permitted to create or approve pull requests":
- Recheck workflow permissions
- Verify branch protection is not blocking PR creation by actions
- Confirm workflow uses built-in GITHUB_TOKEN with proper permissions
EOF

echo "Created .github/REPOSITORY_SETTINGS.md"