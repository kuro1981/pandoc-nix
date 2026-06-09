# Repository Settings Configuration

This repository requires specific GitHub settings to enable automated Pandoc updates.

## Required Settings

### GitHub Actions Permissions

1. Navigate to Settings -> Actions -> General
2. Under "Workflow permissions":
   - Select "Read and write permissions"
   - Check "Allow GitHub Actions to create and approve pull requests"
3. Click Save

These settings allow the update workflow to:
- Modify files in the repository
- Create pull requests for version updates
- Update the flake.lock file

## Verification

After configuring the settings, verify with:

```bash
# Manually trigger the update workflow
gh workflow run "Check for Pandoc Updates"

# Check workflow status
gh run list --workflow="Check for Pandoc Updates"
```

## Troubleshooting

If you see "GitHub Actions is not permitted to create or approve pull requests":
- Ensure the settings above are configured correctly
- Ensure branch protection rules do not block actions from creating PRs
- Confirm workflows use the built-in GITHUB_TOKEN with write permissions
