#!/bin/zsh

g() {
  local cmd=$1
  shift

  case "$cmd" in
    clone)
      local repo_url=$1
      if [[ -z "$repo_url" ]]; then
        echo "Usage: g clone git@github.com:owner/repo.git"
        return 1
      fi

      local clean_path=$(echo "$repo_url" | sed 's/.*://' | sed 's/\.git$//')
      local repo=$(echo "$clean_path" | awk -F/ '{print $NF}')
      local owner=$(echo "$clean_path" | awk -F/ '{print $(NF-1)}')

      if [[ -z "$owner" || -z "$repo" ]]; then
        echo "Error: Could not parse owner/repo from $repo_url"
        return 1
      fi

      local bare_dir="/var/git/$owner/$repo.git"
      local main_workspace="/var/gw/main/$owner/$repo"

      if [[ ! -d "$bare_dir" ]]; then
        mkdir -p "/var/git/$owner"
        git clone --bare "$repo_url" "$bare_dir"
      fi

      if [[ ! -d "$main_workspace" ]]; then
        mkdir -p "/var/gw/main/$owner"
        local default_branch=$(git -C "$bare_dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
        [[ -z "$default_branch" ]] && default_branch="main"
        git -C "$bare_dir" worktree add "$main_workspace" "$default_branch"
      fi

      cd "$main_workspace"
      ;;

    new)
      # 1. Validation: Must be in a repo inside /var/gw
      if [[ ! "$PWD" =~ ^/var/gw/([^/]+)/([^/]+)/([^/]+) ]]; then
        echo "Error: Must be inside a workspace repo to create a new workspace."
        return 1
      fi
      
      local current_ws="${match[1]}"
      local owner="${match[2]}"
      local repo="${match[3]}"
      local bare_dir="/var/git/$owner/$repo.git"

      # 2. Prompts
      echo -n "Workspace name > "
      read ws_input
      [[ -z "$ws_input" ]] && { echo "Aborted: Name required."; return 1; }
      date_prefix=$(date +%F)
      sanitized_name=$(echo "$ws_input" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]\+/-/g')
      ws_name="${date_prefix}-${sanitized_name}"

      echo -n "Branch name (default: $ws_name) > "
      read branch_name
      [[ -z "$branch_name" ]] && branch_name="$ws_name"

      local new_ws_root="/var/gw/$ws_name"
      local new_repo_path="$new_ws_root/$owner/$repo"

      # 3. Create workspace and worktree
      mkdir -p "$new_ws_root"
      echo "$branch_name" > "$new_ws_root/.branch"
      
      # Create new worktree based on current HEAD
      git -C "$bare_dir" worktree add -b "$branch_name" "$new_repo_path"
      
      cd "$new_repo_path"
      ;;

    add)
      # 1. Identify workspace root
      if [[ ! "$PWD" =~ ^/var/gw/([^/]+) ]]; then
        echo "Error: Not in a workspace."
        return 1
      fi
      local ws_root="/var/gw/${match[1]}"
      local branch_name=$(cat "$ws_root/.branch" 2>/dev/null || echo "${match[1]}")

      # 2. FZF selection (filtering out already added)
      local selected=$(find /var/git -maxdepth 2 -mindepth 2 -type d | sed 's|^/var/git/||' | sed 's|\.git$||' | \
        while read r; do
          [[ ! -d "$ws_root/$r" ]] && echo "$r"
        done | fzf --prompt="repo > ")

      [[ -z "$selected" ]] && return 0

      local owner=$(echo "$selected" | cut -d'/' -f1)
      local repo=$(echo "$selected" | cut -d'/' -f2)
      local bare_dir="/var/git/$owner/$repo.git"
      local target_path="$ws_root/$owner/$repo"

      # 3. Add worktree
      mkdir -p "$ws_root/$owner"
      # Try to check out branch if exists, otherwise create it
      if git -C "$bare_dir" rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        git -C "$bare_dir" worktree add "$target_path" "$branch_name"
      else
        git -C "$bare_dir" worktree add -b "$branch_name" "$target_path"
      fi

      cd "$target_path"
      ;;

    rm)
      # 1. Select workspace to remove
      local target_ws=$(ls /var/gw | grep -v "^main$" | fzf --prompt="workspace > ")
      [[ -z "$target_ws" ]] && return 0

      echo -n "Are you sure you want to delete '$target_ws' and all its worktrees? (y/N): "
      read confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        return 1
      fi

      # 2. Remove Git worktrees cleanly
      # Find all .git files in the workspace (worktrees use files, not dirs, for .git)
      find "/var/gw/$target_ws" -name ".git" | while read wt_file; do
        local wt_dir=$(dirname "$wt_file")
        git -C "$wt_dir" worktree remove "$wt_dir" --force 2>/dev/null
      done

      # 3. Clean up directory
      rm -rf "/var/gw/$target_ws"
      echo "Workspace '$target_ws' removed."
      ;;

    switch)
      local current_ws=$(echo "$PWD" | grep -oP '^/var/gw/\K[^/]+')
      local target=$(find /var/gw -maxdepth 3 -mindepth 3 -type d 2>/dev/null | \
        sed 's|^/var/gw/||' | \
        awk -v ws="$current_ws" '
          {
            if (ws != "" && $0 ~ "^" ws "/") print "0|" $0
            else print "1|" $0
          }
        ' | sort -n | cut -d'|' -f2 | \
        fzf --prompt="repo > " --preview 'ls -F /var/gw/{}')

      [[ -n "$target" ]] && cd "/var/gw/$target"
      ;;

    agent)
      if [[ ! "$PWD" =~ ^/var/gw/([^/]+)/([^/]+)/([^/]+) ]]; then
        echo "Error: Must be inside a workspace repo."
        return 1
      fi

      local ws_name="${match[1]}"
      local ws_root="/var/gw/$ws_name"
      
      local selected=$(find "$ws_root" -maxdepth 2 -mindepth 2 -type d | \
        gum choose --no-limit --selected="$PWD" --header="Select accessible repos")

      [[ $? -eq 130 || -z "$selected" ]] && { echo "Cancelled."; return 0; }

      local paths_arg=$(echo "$selected" | tr '\n' ' ')

      echo "Launching agent..."
      spawn-agent $=paths_arg
      ;;

    *)
      echo "Usage: g {clone|new|add|switch|rm|agent}"
      return 1
      ;;

  esac
}

# --- Completion ---
_g_completion() {
  local -a commands
  commands=(
    'clone:Clone via SSH and setup main worktree'
    'new:Create a new workspace from current repo'
    'add:Add an existing repo to current workspace'
    'switch:Fuzzy search and switch between repos/workspaces'
    'rm:Remove a workspace and its worktrees'
    'agent:Launches agent in workspace'
  )
  if (( CURRENT == 2 )); then
    _describe -t commands 'g commands' commands
  fi
}
compdef _g_completion g
alias gs='g switch'

