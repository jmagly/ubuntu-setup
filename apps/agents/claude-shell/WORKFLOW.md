# Claude Shell Git Workflow

## Overview

The Claude Shell environment uses a standard git workflow with SSH authentication. The container clones your repository from a remote git server (GitHub, GitLab, etc.) and uses SSH keys for secure authentication.

## Setup

Your container is configured with:
- **`origin`**: Your remote git repository (SSH authenticated)
- **SSH Key**: Mounted from host for secure authentication
- **Standard Git**: Normal git commands work as expected

## Workflow

**In Container:**
```bash
# Make your changes
git add .
git commit -m "Your commit message"

# Push to remote repository
git push

# Pull latest changes from remote
git pull

# Create and switch branches
git checkout -b feature-branch
git push -u origin feature-branch
```

**No Host Actions Required**: Changes are pushed directly to your remote repository.

## Getting Started

### Initial Setup

1. **Prepare your SSH key**:
   ```bash
   # Ensure your SSH key has proper permissions
   chmod 600 ~/.ssh/id_rsa
   
   # Test SSH connection to your git provider
   ssh -T git@github.com  # For GitHub
   ssh -T git@gitlab.com  # For GitLab
   ```

2. **Start the container**:
   ```bash
   # Using the run script (recommended)
   ./scripts/run.sh --git-url git@github.com:user/repo.git --ssh-key ~/.ssh/id_rsa
   
   # Or using environment variables
   export GIT_REPO_URL="git@github.com:user/repo.git"
   export SSH_KEY_PATH="~/.ssh/id_rsa"
   ./scripts/run.sh
   ```

### SSH Configuration

The container automatically configures SSH with:
- Your SSH private key (mounted read-only)
- SSH config file (if present in same directory as key)
- Known hosts for common git providers (GitHub, GitLab, Bitbucket)

## Best Practices

1. **Standard Git Workflow**:
   - Pull before making changes: `git pull`
   - Create feature branches: `git checkout -b feature-name`
   - Commit regularly with descriptive messages
   - Push when ready: `git push`

2. **Branch Management**:
   - Use feature branches for development
   - Keep commits focused and atomic
   - Use descriptive commit messages
   - Merge or rebase as appropriate for your team

3. **Security**:
   - SSH keys are mounted read-only for security
   - Container has no access to host filesystem beyond mounted volumes
   - All git operations use SSH authentication
   - No persistent SSH agent - key is loaded per session

## Troubleshooting

### "Permission denied (publickey)" Error
- Verify SSH key path is correct and file exists
- Check SSH key permissions: `chmod 600 ~/.ssh/id_rsa`
- Test SSH connection: `ssh -T git@github.com`
- Ensure SSH key is added to your git provider account

### "Failed to clone repository" Error
- Verify the git repository URL is correct
- Check that you have access to the repository
- Ensure SSH key is authorized for the repository

### "Host key verification failed" Error
- The container automatically adds known hosts for common providers
- For custom git servers, you may need to add them manually
- Check your SSH config file if using custom hosts

## Examples

### Typical Development Session

```bash
# Start container with your repository
./scripts/run.sh --git-url git@github.com:user/repo.git --ssh-key ~/.ssh/id_rsa

# In container
cd /workspace/work
git pull  # Get latest changes
git checkout -b new-feature
# Make changes...
git add .
git commit -m "Add new feature"
git push -u origin new-feature
```

### Quick Fix Workflow

```bash
# In container
cd /workspace/work
git pull
# Make quick fix...
git add .
git commit -m "Fix critical bug"
git push
```

### Working with Existing Branches

```bash
# In container
cd /workspace/work
git pull
git checkout existing-branch
git pull origin existing-branch
# Make changes...
git add .
git commit -m "Update feature"
git push
```

This workflow provides a standard git experience with secure SSH authentication, eliminating host file system permission issues while maintaining full git functionality.