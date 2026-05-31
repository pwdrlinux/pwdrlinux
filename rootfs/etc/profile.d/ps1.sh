if [ -n "$BASH_VERSION" ]; then
    if [ "$(id -u)" = "0" ]; then
        PS1='\[\e[1;31m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]# '
    else
        PS1='\[\e[1;35m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
    fi
else
    if [ "$(id -u)" = "0" ]; then
        PS1='$(id -un)@$(hostname):$(pwd)# '
    else
        PS1='$(id -un)@$(hostname):$(pwd)\$ '
    fi
fi

export PS1
