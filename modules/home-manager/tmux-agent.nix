{
  ...
}:
{
  programs.tmux = {
    enable = true;
    extraConfig = ''
      # Use Ctrl-a as prefix instead of default Ctrl-b
      unbind C-b
      set -g prefix C-a
      bind C-a send-prefix

      # Different color scheme
      set -g status-bg blue
      set -g status-fg white
      set -g pane-active-border-style bg=default,fg=cyan
      set -g pane-border-style fg=blue

      set -g mouse on
      set -g default-terminal "xterm-ghostty"
      set -g history-limit 50000
      set -g base-index 1
      set-option -g renumber-windows on
      set -s escape-time 0

      bind n new-window -c "#{pane_current_path}"
      bind 1 select-window -t :1
      bind 2 select-window -t :2
      bind 3 select-window -t :3
      bind 4 select-window -t :4
      bind 5 select-window -t :5
      bind 6 select-window -t :6
      bind 7 select-window -t :7
      bind 8 select-window -t :8
      bind 9 select-window -t :9
      bind 0 select-window -t :0
      bind . select-window -n
      bind , select-window -p
      bind < swap-window -t -1
      bind > swap-window -t +1
      bind X confirm-before "kill-window"
      bind v split-window -h -c "#{pane_current_path}"
      bind b split-window -v -c "#{pane_current_path}"
      bind R command-prompt -I "" "rename-window '%%'"
      bind f resize-pane -Z
      bind h select-pane -L
      bind l select-pane -R
      bind k select-pane -U
      bind j select-pane -D
      bind H run-shell 'old=`tmux display -p "#{pane_index}"`; tmux select-pane -L; tmux swap-pane -t $old'
      bind J run-shell 'old=`tmux display -p "#{pane_index}"`; tmux select-pane -D; tmux swap-pane -t $old'
      bind K run-shell 'old=`tmux display -p "#{pane_index}"`; tmux select-pane -U; tmux swap-pane -t $old'
      bind L run-shell 'old=`tmux display -p "#{pane_index}"`; tmux select-pane -R; tmux swap-pane -t $old'
      bind x confirm-before "kill-pane"
      bind / copy-mode

      set-option -g status-keys vi
      set-option -g set-titles on
      set-option -g set-titles-string 'tmux - #W'
      set -g bell-action any
      set-option -g visual-bell off
      set-option -g set-clipboard off
      setw -g mode-keys vi
      setw -g monitor-activity on
      set -g visual-activity on
      set -g status-style fg=colour15
      set -g status-justify centre
      set -g status-left '''
      set -g status-right '''
      set -g status-interval 1
      set -g message-style fg=colour0,bg=colour3
      setw -g window-status-bell-style fg=colour1
      setw -g window-status-current-style fg=cyan,bold
      setw -g window-status-style fg=colour254
      setw -g window-status-current-format ' #{?#{==:#W,#{b:SHELL}},#{b:pane_current_path},#W} '
      setw -g window-status-format ' #{?#{==:#W,#{b:SHELL}},#{b:pane_current_path},#W} '
    '';
  };
}
