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

#启用git                         #以可以使用 go get 安装
function set_git(){
	yum -y install git
}

#启用go
function set_go(){
	wget https://storage.googleapis.com/golang/go1.7.1.linux-amd64.tar.gz
	tar -zxvf go1.7.1.linux-amd64.tar.gz
	cp -rf go /usr/local/go
	rm -rf /root/go*
	mkdir /usr/local/gopackage
	sed -i 's?export GOROOT=/usr/local/go??g' /etc/profile                                
	sed -i '/^\s*$/d' /etc/profile                                                           
	sed -i '$a\export GOROOT=/usr/local/go' /etc/profile                      #添加Go路径到环境变量                  
	sed -i 's?export GOPATH=/usr/local/gopackage??g' /etc/profile                                
	sed -i '/^\s*$/d' /etc/profile                                                           
	sed -i '$a\export GOPATH=/usr/local/gopackage' /etc/profile 	          #添加Go安装文件路径到环境变量
	sed -i 's?export PATH=$PATH:$GOROOT/bin:$GOPATH/bin??g' /etc/profile                                
	sed -i '/^\s*$/d' /etc/profile                                                           
	sed -i '$a\export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' /etc/profile        #添加Go和Gopackage的bin到环境变量
	echo -e "\033[32;1m 输入 source /etc/profile 生效 \033[0m" 
}

root_only
set_git
set_go

# test