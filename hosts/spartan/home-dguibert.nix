{ config, pkgs, lib, inputs
, ...}@args:
with lib;
{
  nixpkgs.overlays = [
    (import ./overlay.nix)
    (final: prev: {
      pinentry = prev.pinentry.override { enabledFlavors = [ "curses" "tty" ]; };
    })
  ];
  services.gpg-agent.pinentryFlavor = lib.mkForce "curses";

  programs.home-manager.enable = true;

  programs.bash.enable = true;
  programs.bash.bashrcExtra = /*(homes.withoutX11 args).programs.bash.initExtra +*/ ''
    export PATH=$HOME/bin:$PATH
    #export LD_LIBRARY_PATH=${pkgs.sssd}/lib:$LD_LIBRARY_PATH

    case $HOSTNAME in
      spartan0)
      ;;
      spartan*)
      export TMP=/dev/shm; export TMPDIR=$TMP; export TEMP=$TMP; export TEMPDIR=$TMP
      ;;
    esac
  '';

  programs.bash.shellAliases.ls="ls --color";

  programs.bash.initExtra = ''
    unset PROMPT_COMMAND
    export HISTCONTROL
    export HISTFILESIZE
    export HISTIGNORE
    export HISTSIZE
    unset HISTTIMEFORMAT
    # https://unix.stackexchange.com/a/430128
    # on every prompt, save new history to dedicated file and recreate full history
    # by reading all files, always keeping history from current session on top.
    update_history () {
      history -a ''${HISTFILE}.$$
      history -c
      history -r  # load common history file
      # load histories of other sessions
      for f in `ls ''${HISTFILE}.[0-9]* 2>/dev/null | grep -v "''${HISTFILE}.$$\$"`; do
        history -r $f
      done
      history -r "''${HISTFILE}.$$"  # load current session history
    }
    if [[ "$PROMPT_COMMAND" != *update_history* ]]; then
      export PROMPT_COMMAND="update_history''${PROMPT_COMMAND:+;$PROMPT_COMMAND }"
    fi

    # merge session history into main history file on bash exit
    merge_session_history () {
      if [ -e ''${HISTFILE}.$$ ]; then
        # fix wrong history files
        awk '/^[0-9]+ / { gsub("^[0-9]+ +", "") } { print }' $HISTFILE ''${HISTFILE}.$$ | \
        tac | awk '!seen[$0]++' | tac | ${pkgs.moreutils}/bin/sponge  $HISTFILE
        \rm ''${HISTFILE}.$$
      fi
    }
    trap merge_session_history EXIT


    # detect leftover files from crashed sessions and merge them back
    active_shells=$(pgrep `ps -p $$ -o comm=`)
    grep_pattern=`for pid in $active_shells; do echo -n "-e \.''${pid}\$ "; done`
    orphaned_files=`ls $HISTFILE.[0-9]* 2>/dev/null | grep -v $grep_pattern`

    if [ -n "$orphaned_files" ]; then
      echo Merging orphaned history files:
      for f in $orphaned_files; do
        echo "  `basename $f`"
        cat $f >> $HISTFILE
        \rm $f
      done
      tac $HISTFILE | awk '!seen[$0]++' | tac | ${pkgs.moreutils}/bin/sponge $HISTFILE
      echo "done."
    fi
    # https://www.gnu.org/software/emacs/manual/html_node/tramp/Remote-shell-setup.html#index-TERM_002c-environment-variable-1
    test "$TERM" != "dumb" || return

    # https://codeberg.org/dnkl/foot/issues/86
    # https://codeberg.org/dnkl/foot/wiki#user-content-how-to-configure-my-shell-to-emit-the-osc-7-escape-sequence
    _urlencode() {
            local length="''${#1}"
            for (( i = 0; i < length; i++ )); do
                    local c="''${1:$i:1}"
                    case $c in
                            %) printf '%%%02X' "'$c" ;;
                            *) printf "%s" "$c" ;;
                    esac
            done
    }
    osc7_cwd() {
            printf '\e]7;file://%s%s\a' "$HOSTNAME" "$(_urlencode "$PWD")"
    }
    PROMPT_COMMAND=''${PROMPT_COMMAND:+$PROMPT_COMMAND; }osc7_cwd

    # Provide a nice prompt.
    PS1=""
    PS1+='\[\033[01;37m\]$(exit=$?; if [[ $exit == 0 ]]; then echo "\[\033[01;32m\]✓"; else echo "\[\033[01;31m\]✗ $exit"; fi)'
    PS1+='$(ip netns identify 2>/dev/null)' # sudo setfacl -m u:$USER:rx /var/run/netns
    PS1+=' ''${GIT_DIR:+ \[\033[00;32m\][$(basename $GIT_DIR)]}'
    PS1+=' ''${ENVRC:+ \[\033[00;33m\]env:$ENVRC}'
    PS1+=' ''${SLURM_NODELIST:+ \[\033[01;34m\][$SLURM_NODELIST]\[\033[00m\]}'
    PS1+=' \[\033[00;32m\]\u@\h\[\033[01;34m\] \W '
    if !  command -v __git_ps1 >/dev/null; then
      if [ -e $HOME/code/git-prompt.sh ]; then
        source $HOME/code/git-prompt.sh
      fi
    fi
    if command -v __git_ps1 >/dev/null; then
      PS1+='$(__git_ps1 "|%s|")'
    fi
    PS1+='$\[\033[00m\] '

    export PS1
    case $TERM in
      dvtm*|st*|rxvt|*term)
        trap 'echo -ne "\e]0;$BASH_COMMAND\007"' DEBUG
      ;;
    esac

    eval "$(${pkgs.coreutils}/bin/dircolors)" &>/dev/null
    source ${config.scheme inputs.base16-shell}

    export TODOTXT_DEFAULT_ACTION=ls
    alias t='todo.sh'

    tput smkx
  '';

  programs.git.enable = true;
  programs.git.package = pkgs.gitFull;
  programs.git.userName = "David Guibert";
  programs.git.userEmail = "david.guibert@gmail.com";
  programs.git.aliases.files = "ls-files -v --deleted --modified --others --directory --no-empty-directory --exclude-standard";
  programs.git.aliases.wdiff = "diff --word-diff=color --unified=1";
  programs.git.aliases.bd  = "!git for-each-ref --sort='-committerdate:iso8601' --format='%(committerdate:iso8601)%09%(refname)'";
  programs.git.aliases.bdr = "!git for-each-ref --sort='-committerdate:iso8601' --format='%(committerdate:iso8601)%09%(refname)' refs/remotes/$1";
  programs.git.aliases.bs="branch -v -v";
  programs.git.aliases.df="diff";
  programs.git.aliases.dn="diff --name-only";
  programs.git.aliases.dp="diff --no-ext-diff";
  programs.git.aliases.ds="diff --stat -w";
  programs.git.aliases.dt="difftool";
  #programs.git.ignores
  programs.git.iniContent.clean.requireForce = true;
  programs.git.iniContent.rerere.enabled = true;
  programs.git.iniContent.rerere.autoupdate = true;
  programs.git.iniContent.rebase.autosquash = true;
  programs.git.iniContent.credential.helper = "password-store";
  programs.git.iniContent."url \"software.ecmwf.int\"".insteadOf = "ssh://git@software.ecmwf.int:7999";
  programs.git.iniContent.color.branch = "auto";
  programs.git.iniContent.color.diff = "auto";
  programs.git.iniContent.color.interactive = "auto";
  programs.git.iniContent.color.status = "auto";
  programs.git.iniContent.color.ui = "auto";
  programs.git.iniContent.diff.tool = "vimdiff";
  programs.git.iniContent.diff.renames = "copies";
  programs.git.iniContent.merge.tool = "vimdiff";

  # http://ubuntuforums.org/showthread.php?t=1150822
  ## Save and reload the history after each command finishes
  home.sessionVariables.SQUEUE_FORMAT="%.18i %.25P %35j %.8u %.2t %.10M %.6D %.6C %.6z %.15E %20R %W";
 #home.sessionVariables.SINFO_FORMAT="%30N  %.6D %.6c %15F %10t %20f %P"; # with state
  home.sessionVariables.SINFO_FORMAT="%30N  %.6D %.6c %15F %20f %P";
  home.sessionVariables.PATH="$HOME/bin:$PATH";
  #home.sessionVariables.MANPATH="$HOME/man:$MANPATH:/share/man";
  programs.man.enable = false; # RHEL 8 manpath fork bomb
  home.sessionVariables.PAGER="less -R";
  home.sessionVariables.GIT_PS1_SHOWDIRTYSTATE=1;
  # ✗ 1    dguibert@vbox-57nvj72 ~ $ systemctl --user status
  # Failed to read server status: Process org.freedesktop.systemd1 exited with status 1
  # ✗ 130    dguibert@vbox-57nvj72 ~ $ export XDG_RUNTIME_DIR=/run/user/$(id -u)
  #home.sessionVariables.XDG_RUNTIME_DIR="/run/user/$(id -u)";

  # Fix stupid java applications like android studio
  home.sessionVariables._JAVA_AWT_WM_NONREPARENTING = "1";

  home.packages = with pkgs; [
    (vim_configurable.override {
      guiSupport = "no";
      libX11=null; libXext=null; libSM=null; libXpm=null; libXt=null; libXaw=null; libXau=null; libXmu=null;
      libICE=null;
    })
    duc

    rsync

    gitAndTools.gitRemoteGcrypt
    gitAndTools.git-crypt

    gnumake
    #nix-repl
    pstree

    #teamviewer
    tig
    #haskellPackages.nix-deploy
    htop
    tree

    #wpsoffice
    file
    bc
    unzip

    sshfs-fuse

    moreutils

    editorconfig-core-c
    todo-txt-cli
    ctags
    dvtm
    abduco
    gnupg1compat

    nix
    gitAndTools.git-annex
    gitAndTools.hub
    gitAndTools.git-crypt
    gitFull #guiSupport is harmless since we also installl xpra
    (pkgs.writeScriptBin "git-annex-diff-wrapper" ''
      #!${runtimeShell}
      LANG=C ${diffutils}/bin/diff -u "$1" "$2"
      exit 0
    '')
    datalad
    subversion
    tig
    jq
    lsof
    #xpra
    htop
    tree

    nxsession
    xorg.setxkbmap

    # testing (removed 20171122)
    #Mitos
    #MemAxes
    python3

    socat
    pv
    netcat
  ];

  programs.direnv.enable = true;

  services.gpg-agent.enable = true;
  services.gpg-agent.enableSshSupport = true;
  # https://blog.eleven-labs.com/en/openpgp-almost-perfect-key-pair-part-1/

  home.stateVersion = "20.09";

  programs.bash.shellAliases.e = "emacsclient -s default -t -a \"\"";
  programs.bash.shellAliases.eg = "emacsclient -s default -n -c -a \"\"";
  home.sessionVariables.ALTERNATE_EDITOR = "";
  home.sessionVariables.EDITOR = "emacsclient -s default -t"; # $EDITOR opens in terminal
  home.sessionVariables.VISUAL = "emacsclient -s default -c -a emacs"; # $VISUAL opens in GUI mode
  programs.emacs.enable = true;
  programs.emacs.package = pkgs.my-emacs;
  services.emacs.enable = true;
}
