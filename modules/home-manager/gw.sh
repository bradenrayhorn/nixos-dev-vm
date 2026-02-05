#!/bin/bash

# Configuration
GW_ROOT="/var/gw"
GIT_ROOT="/var/git"

gw() {
    local cmd="$1"
    shift

    # Helper: Extract owner/repo from current git repository
    _gw_get_repo_slug() {
        local url
        url=$(git config --get remote.origin.url)
        if [[ -z "$url" ]]; then
            return 1
        fi
        # Remove .git suffix and protocol parts to get "owner/repo"
        # Handles git@github.com:owner/repo.git and https://github.com/owner/repo.git
        echo "$url" | sed -E 's/.*github.com[:\/](.*)(\.git)?/\1/' | sed 's/\.git$//'
    }

    # Helper: Ensure date prefix exists
    _gw_format_workspace_name() {
        local input_name="$1"
        # Replace spaces with dashes
        local clean_name="${input_name// /-}"
        
        # If it doesn't already start with a date pattern (YYYY-MM-DD), add today's date
        if [[ ! "$clean_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}- ]]; then
            echo "$(date +%Y-%m-%d)-${clean_name}"
        else
            echo "$clean_name"
        fi
    }

    # Command: NEW
    if [[ "$cmd" == "new" ]]; then
        local name="$1"
        
        # Interactive input if no name provided
        if [[ -z "$name" ]]; then
            echo -n "Enter new workspace name: "
            read name
            if [[ -z "$name" ]]; then echo "Name required."; return 1; fi
        fi

        local ws_name=$(_gw_format_workspace_name "$name")
        local ws_path="$GW_ROOT/$ws_name"

        if [[ -d "$ws_path" ]]; then
            echo "Error: Workspace already exists: $ws_name"
            return 1
        fi

        echo "Creating workspace: $ws_path"
        mkdir -p "$ws_path"

        # Check if running from a git repo
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local repo_slug=$(_gw_get_repo_slug)
            local main_repo_path="$GIT_ROOT/$repo_slug"
            local target_wt_path="$ws_path/$repo_slug"

            if [[ -d "$main_repo_path" ]]; then
                echo "Detected git repo ($repo_slug). Creating worktree..."
                mkdir -p "$(dirname "$target_wt_path")"
                
                # Create worktree. Defaulting to a new branch named after the workspace
                git -C "$main_repo_path" worktree add -b "$ws_name" "$target_wt_path"
            else
                echo "Warning: Current repo ($repo_slug) not found in $GIT_ROOT. Skipping worktree creation."
            fi
        fi
        
        # Optional: Switch to it immediately? 
        # The prompt implies 'new' just creates, but usually users want to switch. 
        # Leaving as create-only based on prompt, but user can run 'gw switch' after.

    # Command: SWITCH
    elif [[ "$cmd" == "switch" ]]; then
        local target="$1"

        # Interactive selection using fzf if no name provided
        if [[ -z "$target" ]]; then
            if ! command -v fzf >/dev/null; then echo "Error: fzf not installed."; return 1; fi
            
            # List directory names in GW_ROOT, remove full path for display
            target=$(find "$GW_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | fzf --header="Select Workspace")
            if [[ -z "$target" ]]; then return 0; fi # User cancelled
        fi

        # Handle case where user types partial name (optional, strict match per prompt logic)
        local ws_path="$GW_ROOT/$target"
        
        # If strict path doesn't exist, try finding it via fuzzy match logic or just fail
        if [[ ! -d "$ws_path" ]]; then
             echo "Error: Workspace '$target' not found in $GW_ROOT"
             return 1
        fi

        echo "Switching to workspace: $target"

        # Git Logic
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local repo_slug=$(_gw_get_repo_slug)
            local main_repo_path="$GIT_ROOT/$repo_slug"
            local target_repo_path="$ws_path/$repo_slug"

            # Check if this repo belongs in the workspace
            if [[ -n "$repo_slug" && -d "$main_repo_path" ]]; then
                if [[ -d "$target_repo_path" ]]; then
                    # Repo exists in workspace, switch to it
                    echo "Repository exists in workspace. Jumping to $target_repo_path"
                    cd "$target_repo_path" || return 1
                else
                    # Repo does not exist, create worktree
                    echo "Repository not found in target workspace. Creating worktree..."
                    mkdir -p "$(dirname "$target_repo_path")"
                    
                    # Try to checkout existing branch if it matches workspace name, else create new
                    # Logic: Attempt to attach to existing branch 'workspace-name', else create it.
                    if git -C "$main_repo_path" show-ref --verify --quiet "refs/heads/$target"; then
                        git -C "$main_repo_path" worktree add "$target_repo_path" "$target"
                    else
                        git -C "$main_repo_path" worktree add -b "$target" "$target_repo_path"
                    fi
                    
                    cd "$target_repo_path" || return 1
                fi
                return 0
            fi
        fi

        # Fallback: Just cd to workspace root if not in a git repo
        cd "$ws_path" || return 1

    # Command: AGENT
    elif [[ "$cmd" == "agent" ]]; then
        # Must be inside a workspace
        if [[ "$PWD" != "$GW_ROOT"* ]]; then
            echo "Error: gw agent must be run from within a workspace ($GW_ROOT)"
            return 1
        fi

        # Identify the workspace root
        # We need to find which subdirectory of /var/gw we are in
        local relative_path="${PWD#$GW_ROOT/}"
        local ws_name="${relative_path%%/*}"
        local current_ws="$GW_ROOT/$ws_name"

        echo "Initializing agent for workspace: $ws_name"

        # Find all git repos in this workspace and map to /var/git
        # We look for .git files (worktrees use .git files, not folders)
        local repo_paths=()
        
        # Use find to locate .git references inside the workspace
        while IFS= read -r git_ref; do
            # git_ref is path/to/.git
            local worktree_root
            worktree_root=$(dirname "$git_ref")
            
            # Determine owner/repo from the path structure: .../workspace/owner/repo
            # This relies on the strict folder structure defined in prompt
            local path_inside_ws="${worktree_root#$current_ws/}"
            # path_inside_ws should be "owner/repo"
            
            local main_git_path="$GIT_ROOT/$path_inside_ws"
            
            if [[ -d "$main_git_path" ]]; then
                repo_paths+=("$main_git_path")
            fi
        done < <(find "$current_ws" -type f -name ".git" -o -type d -name ".git")

        if [[ ${#repo_paths[@]} -eq 0 ]]; then
            echo "No repositories found in this workspace."
            # Depending on strictness, we might fail here or just spawn empty agent
        fi

        echo "Spawning agent with repos: ${repo_paths[*]}"
        
        # Execute the external spawn-agent command
        # Assumes spawn-agent is in PATH
        spawn-agent "${repo_paths[@]}"

    else
        echo "Usage: gw {new|switch|agent}"
        return 1
    fi
}
