# gdate for macOS
# REF: https://apple.stackexchange.com/questions/135742/time-in-milliseconds-since-epoch-in-the-terminal
if [[ "$OSTYPE" == "darwin"* ]]; then
    {
        gdate
    } || {
        echo "\n$fg_bold[yellow]EyeRelax.zsh-theme depends on cmd [gdate] to get current time in milliseconds$reset_color"
        echo "$fg_bold[yellow][gdate] is not installed by default in macOS$reset_color"
        echo "$fg_bold[yellow]to get [gdate] by running:$reset_color"
        echo "$fg_bold[green]brew install coreutils;$reset_color"
        echo "$fg_bold[yellow]\nREF: https://github.com/ChesterYue/ohmyzsh-theme-passion#macos\n$reset_color"
    }
fi

# return value in second unit,  example: '1702020768.012',
_eye_relax_current_time_millis() {
    local time_millis
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        # Linux
        time_millis="$(date +%s.%3N)"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        time_millis="$(gdate +%s.%3N)"
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        # POSIX compatibility layer and Linux environment emulation for Windows
    elif [[ "$OSTYPE" == "msys" ]]; then
        # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
    elif [[ "$OSTYPE" == "win32" ]]; then
        # I'm not sure this can happen.
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        # ...
    else
        # Unknown.
    fi

    echo $time_millis
}

get_cur_folder_name() {
      if [[ "$HOME" == "$PWD" ]]; then
        echo ""
      else  
        echo "%{$fg[cyan]%}($(basename ${PWD}))%{$reset_color%}"
      fi
}

get_end_mark() {
    echo "$fg_bold[green] <== END"  # OK
    #echo "<== END"
}

#return -1, 0, 1
cmp() {
   awk -v n1="$1" -v n2="$2" 'BEGIN {print (n1<n2?"-1":n1==n2?"0":"1")}'
}

_eye_relax_update_git_info() {
    if [ -n "$__CURRENT_GIT_STATUS" ]; then
        _EYE_RELAX_GIT_INFO=$(git_super_status)
    else
        _EYE_RELAX_GIT_INFO=$(git_prompt_info)
    fi
}

# command execute before
# REF: http://zsh.sourceforge.net/Doc/Release/Functions.html
preexec() { # cspell:disable-line
    _EYE_RELAX_COMMAND_TIME_BEGIN="$(_eye_relax_current_time_millis)"
}

# command execute after
# REF: http://zsh.sourceforge.net/Doc/Release/Functions.html
precmd() { # cspell:disable-line
    local last_cmd_return_code=$?

    update_command_statusX() {
        local color=""
        local command_result=$1
        if $command_result; then
            color=""
        else
            color="%{$fg[red]%}"
        fi

        _EYE_RELAX_COMMAND_STATUS="${color}%(!.#.$ -->)%{$reset_color%}"
    }

    function update_command_status() {
        local arrow="";
        local color_reset="%{$reset_color%}";
        local reset_font="%{$fg_no_bold[white]%}";
        COMMAND_RESULT=$1;
        export COMMAND_RESULT=$COMMAND_RESULT
        if $COMMAND_RESULT;
        then
            arrow="%{$fg_bold[red]%}❱%{$fg_bold[yellow]%}❱%{$fg_bold[green]%}❱";  # WYH: when success
        else
            arrow="%{$fg_bold[red]%}❱❱❱";   # WYH: when failed
        fi
        _EYE_RELAX_COMMAND_STATUS="$(get_cur_folder_name) ${arrow}${reset_font}${color_reset}";
    }

    output_command_execute_after() {
        if [ "$_EYE_RELAX_COMMAND_TIME_BEGIN" = "-20200325" ] || [ "$_EYE_RELAX_COMMAND_TIME_BEGIN" = "" ]; then
            return 1
        fi

        # cmd
        local cmd="$(fc -ln -1)"  #WYH: previous command! 
        local color_cmd=""
        local command_result=$1
        if $command_result; then
            color_cmd="$fg[green]"
        else
            color_cmd="$fg[red]"
        fi
        local color_reset="$reset_color"
        cmd="${color_cmd}${cmd}${color_reset}"

        # time
        local time="[$(date +%H:%M:%S)]"

        # cost
        local time_end="$(_eye_relax_current_time_millis)"
        local cost=$(bc -l <<<"${time_end}-${_EYE_RELAX_COMMAND_TIME_BEGIN}")
        _EYE_RELAX_COMMAND_TIME_BEGIN="-20200325"

        local threshold=1  # print if cost time greater than 1 second
        local _print_cost_line=false
        local _cmpResult=$(cmp $cost $threshold)
        if [ "$_cmpResult" = "1" ]; then
            _print_cost_line=true
        fi

        local length_cost=${#cost}
        if [ "$length_cost" = "4" ]; then
            cost="0${cost}"
        fi
        cost="[ cost ${cost}s (show when longer than ${threshold} second) ]"

        echo "$fg_bold[green]└─>${color_reset}"  # newline

        if  $_print_cost_line; then
            #echo "${time} $fg[cyan]${cost}${color_reset} ${cmd} $(get_end_mark) "
            # don't echo last 'cmd' and end mark
            echo "${time} $fg[cyan]${cost}${color_reset} "
        fi

        #echo "$fg_bold[green]└─>"  # newline
    }

    # last_cmd
    local last_cmd_result=true
    if [ "$last_cmd_return_code" = "0" ]; then
        last_cmd_result=true
    else
        last_cmd_result=false
    fi

    _eye_relax_update_git_info

    update_command_status $last_cmd_result

    output_command_execute_after $last_cmd_result
}

# set option
setopt PROMPT_SUBST # cspell:disable-line

# git
ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[green]%}["
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg[green]%}]%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="  %{$fg[yellow]%}*"

# zsh-git-prompt
ZSH_THEME_GIT_PROMPT_SEPARATOR=" "
ZSH_THEME_GIT_PROMPT_BRANCH="%{$fg[green]%}"
ZSH_THEME_GIT_PROMPT_STAGED="%{$fg[yellow]%}%{+%G%}"
ZSH_THEME_GIT_PROMPT_CONFLICTS="%{$fg[red]%}%{x%G%}"
ZSH_THEME_GIT_PROMPT_CHANGED="%{$fg[yellow]%}%{●%G%}"
ZSH_THEME_GIT_PROMPT_BEHIND=" %{$fg[blue]%}"
ZSH_THEME_GIT_PROMPT_AHEAD="%{$fg[blue]%}|"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[yellow]%}%{…%G%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""

git_super_status() {
    precmd_update_git_vars >/dev/null 2>&1

    if [ -z "$__CURRENT_GIT_STATUS" ]; then
        return
    fi

    if [ "$GIT_BRANCH" = ":" ]; then
        echo ""
        return
    fi

    local git_status="$ZSH_THEME_GIT_PROMPT_PREFIX$ZSH_THEME_GIT_PROMPT_BRANCH$GIT_BRANCH%{${reset_color}%}"
    if [ "$GIT_BEHIND" -ne "0" ] || [ "$GIT_AHEAD" -ne "0" ]; then
        git_status="$git_status$ZSH_THEME_GIT_PROMPT_BEHIND$GIT_BEHIND%{${reset_color}%}$ZSH_THEME_GIT_PROMPT_AHEAD$GIT_AHEAD%{${reset_color}%}"
    fi

    if [ "$GIT_CHANGED" -ne "0" ] || [ "$GIT_CONFLICTS" -ne "0" ] || [ "$GIT_STAGED" -ne "0" ] || [ "$GIT_UNTRACKED" -ne "0" ]; then
        git_status="$git_status$ZSH_THEME_GIT_PROMPT_SEPARATOR"
    fi

    if [ "$GIT_STAGED" -ne "0" ]; then
        git_status="$git_status$ZSH_THEME_GIT_PROMPT_STAGED$GIT_STAGED%{${reset_color}%}"
    fi
    if [ "$GIT_CONFLICTS" -ne "0" ]; then
        git_status="$git_status$ZSH_THEME_GIT_PROMPT_CONFLICTS$GIT_CONFLICTS%{${reset_color}%}"
    fi
    if [ "$GIT_CHANGED" -ne "0" ]; then
        git_status="$git_status$ZSH_THEME_GIT_PROMPT_CHANGED$GIT_CHANGED%{${reset_color}%}"
    fi
    if [ "$GIT_UNTRACKED" -ne "0" ]; then
        git_status="$git_status$ZSH_THEME_GIT_PROMPT_UNTRACKED$GIT_UNTRACKED%{${reset_color}%}"
    fi
    if [ "$GIT_CHANGED" -eq "0" ] && [ "$GIT_CONFLICTS" -eq "0" ] && [ "$GIT_STAGED" -eq "0" ] && [ "$GIT_UNTRACKED" -eq "0" ]; then
        git_status="$git_status$ZSH_THEME_GIT_PROMPT_CLEAN"
    fi
    git_status="$git_status%{${reset_color}%}$ZSH_THEME_GIT_PROMPT_SUFFIX"

    echo $git_status
}

_eye_relax_prompt() {
    real_time() {
        # echo "[%*]";
        echo "[$(date +%H:%M:%S)]"
    }

    user_info() {
    #    echo "%n"

        #echo "$fg_bold[cyan]%n${color_reset}"  # newline

        echo "\033[33m%n\033[m"
        
        #echo "\\033[48;5;95;38;5;214m hello world\\033[0m"
    }

    python_info() {
        if [ -v CONDA_DEFAULT_ENV ]; then
            echo "%{$fg[magenta]%}(${CONDA_DEFAULT_ENV})%{$reset_color%}"
        elif [ -v VIRTUAL_ENV ]; then
            local parent=$(dirname ${VIRTUAL_ENV})
            if [[ "${PWD/#$parent/}" != "$PWD" ]]; then
                # PWD is under the parent
                echo "%{$fg[magenta]%}($(basename ${VIRTUAL_ENV}))%{$reset_color%}"
            else
                # PWD is not under the parent
                echo "%{$fg[magenta]%}(${VIRTUAL_ENV/#$HOME/~})%{$reset_color%}"
            fi
        fi
    }

    directory_info() {
        #    echo "%c";
        echo "%{$fg[cyan]%}${PWD/#$HOME/~}%{$reset_color%}"
    }

    git_info() {
        echo "${_EYE_RELAX_GIT_INFO}"
    }

    command_status() {
        echo "${_EYE_RELAX_COMMAND_STATUS}"
    }

    if [ -v CONDA_DEFAULT_ENV ] || [ -v VIRTUAL_ENV ]; then
        echo "$(real_time) $(user_info) $(python_info) $(directory_info) $(git_info)
$(command_status) "
    else
        echo "$(real_time) $(user_info) $(directory_info) $(git_info)
$(command_status) "
    fi
}

PROMPT='$(_eye_relax_prompt)'
