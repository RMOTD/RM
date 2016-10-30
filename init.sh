#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
clear

#确保root用户运行
function root_only(){
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[31;1m错误:你必须以root用户执行该脚本!\033[0m" 1>&2
   exit 1
fi
echo -e "\033[32;1mroot用户确认成功\033[0m"
}

#启用ifconfig和netstat两个命令
function net_tools(){
	yum -y install net-tools
}

#预安装信息获取
function pre_install(){
	read -p "set ssh_port as:" ssh_set_port           #输入要设置成的ssh端口
}

#1.修改ssh端口
function ssh_port(){
	sed -i 's/^Port.*$/Port $sh_set_port/g' /etc/ssh/sshd_config          #端口替换
	systemctl restart sshd.service                                     #重启ssh服务
	iptables -A INPUT -p tcp --dport $sh_set_port -j ACCEPT        #开放防火墙
	service iptables save                                     #保存防火墙配置
	/bin/systemctl restart iptables.service                #重启iptables
}

#2.修改时区
function time_zone(){
	rm -rf /etc/localtime 
	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 
}

#3.修改命令行颜色等格式
function set_bashrc(){
	cat >> /etc/bashrc<<-EOF
	# /etc/bashrc

	# System wide functions and aliases
	# Environment stuff goes in /etc/profile

	# It's NOT a good idea to change this file unless you know what you
	# are doing. It's much better to create a custom.sh shell script in
	# /etc/profile.d/ to make custom changes to your environment, as this
	# will prevent the need for merging in future updates.

	# are we an interactive shell?
	PS1='\[\e[33;1m\][\u@\H \A \w]\[\e[0;1m\]# '
	if [ "$PS1" ]; then
	  if [ -z "$PROMPT_COMMAND" ]; then
	    case $TERM in
	    xterm*|vte*)
	      if [ -e /etc/sysconfig/bash-prompt-xterm ]; then
	          PROMPT_COMMAND=/etc/sysconfig/bash-prompt-xterm
	      elif [ "${VTE_VERSION:-0}" -ge 3405 ]; then
	          PROMPT_COMMAND="__vte_prompt_command"
	      else
	          PROMPT_COMMAND='printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/~}"'
	      fi
	      ;;
	    screen*)
	      if [ -e /etc/sysconfig/bash-prompt-screen ]; then
	          PROMPT_COMMAND=/etc/sysconfig/bash-prompt-screen
	      else
	          PROMPT_COMMAND='printf "\033k%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/~}"'
	      fi
	      ;;
	    *)
	      [ -e /etc/sysconfig/bash-prompt-default ] && PROMPT_COMMAND=/etc/sysconfig/bash-prompt-default
	      ;;
	    esac
	  fi
	  # Turn on parallel history
	  shopt -s histappend
	  history -a
	  # Turn on checkwinsize
	  shopt -s checkwinsize
	  [ "$PS1" = "\\s-\\v\\\$ " ] && PS1="[\u@\h \W]\\$ "
	  # You might want to have e.g. tty in prompt (e.g. more virtual machines)
	  # and console windows
	  # If you want to do so, just add e.g.
	  # if [ "$PS1" ]; then
	  #   PS1="[\u@\h:\l \W]\\$ "
	  # fi
	  # to your custom modification shell script in /etc/profile.d/ directory
	fi

	if ! shopt -q login_shell ; then # We're not a login shell
	    # Need to redefine pathmunge, it get's undefined at the end of /etc/profile
	    pathmunge () {
	        case ":${PATH}:" in
	            *:"$1":*)
	                ;;
	            *)
	                if [ "$2" = "after" ] ; then
	                    PATH=$PATH:$1
	                else
	                    PATH=$1:$PATH
	                fi
	        esac
	    }

	    # By default, we want umask to get set. This sets it for non-login shell.
	    # Current threshold for system reserved uid/gids is 200
	    # You could check uidgid reservation validity in
	    # /usr/share/doc/setup-*/uidgid file
	    if [ $UID -gt 199 ] && [ "`id -gn`" = "`id -un`" ]; then
	       umask 002
	    else
	       umask 022
	    fi

	    SHELL=/bin/bash
	    # Only display echos from profile.d scripts if we are no login shell
	    # and interactive - otherwise just process them to set envvars
	    for i in /etc/profile.d/*.sh; do
	        if [ -r "$i" ]; then
	            if [ "$PS1" ]; then
	                . "$i"
	            else
	                . "$i" >/dev/null
	            fi
	        fi
	    done

	    unset i
	    unset -f pathmunge
	fi
	# vim:ts=4:sw=4
	
	EOF
	echo -e "输入 source /etc/bashrc 生效"
}

#主程序

root_only
net_tools
pre_install
ssh_port
time_zone
set_bashrc