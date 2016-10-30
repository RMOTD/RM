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
function snet_tools(){
	yum install net-tools
}

#预安装信息获取
function pre_install(){
	read -p "set ssh_port as:" ssh_set_port           #输入要设置成的ssh端口
}

#1.修改ssh端口
function ssh_port(){
	netstat -ntlp|grep sshd |awk -F: '{if($4!="")ssh_cur_port=$4}'         #获取当前ssh端口并输入到变量ssh_cur_port上
	sed -i "s/Port $ssh_cur_port/Port $sh_set_port/g" /etc/ssh/sshd_config    #端口替换
	systemctl restart sshd.service                                     #重启ssh服务
	iptables -A INPUT -p tcp --dport $sh_set_port -j ACCEPT          #开放防火墙
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
	sed -i "1iPS1='\[\e[33;1m\][\u@\H \A \w]\[\e[0;1m\]# '" /etc/bashrc
	source /etc/bashrc
}