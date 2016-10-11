#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
clear

#确保root用户运行脚本
function root_only(){
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[31;1m错误:你必须以root用户执行该脚本!\033[0m" 1>&2
   exit 1
fi
}


#获取IP 
function get_ip(){
    echo "获取服务器IP.....请稍后....."
    IP=`curl -s checkip.dyndns.com | cut -d' ' -f 6  | cut -d'<' -f 1`
    if [ -z $IP ]; then
        IP=`curl -s ifconfig.me/ip`
    fi
echo -e "\033[32;1mIP获取成功\033[0m"	
}
#安装信息获取
function get_info(){
	read -p "请设置登录leanote的端口号（默认：9000）:" lea_port                     #修改端口号
	if [ "$lea_port" = "" ]; then                                              #切记 变量输出一定带符号$  "$lea_port" = ""
		lea_port="9000"
	fi
	read -p "随便输入3个字符替换app.secret 否则会有安全问题（默认：AAA）:" app_aaa           #修改app.secret
	if [ "$app_aaa" = "" ]; then                                              
		app_aaa="AAA"
	fi
    echo -e "\033[33;1m!!!!信息确认!!!!\033[0m:"
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
	echo ""
	echo -e "端口号: [\033[32;1m$lea_port\033[0m]"
	echo -e "app.secret: [\033[32;1m$app_aaa\033[0m]"
	echo ""
    echo -e "\033[33;1m任意键确认，Ctrl+C放弃\033[0m"
	char=`get_char`

}
#安装mongodb
function set_mongodb(){
	cd /root/
	wget https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-2.6.4.tgz                                                       #下载 mongodb.2.6.4包
	tar -xzvf mongod*                                                                                                          #解压 
	cp -rf mongo*/bin/* /usr/local/bin                                                                                         #拷贝 将解压出来所有的bin下文件移动到usr/local/bin下（这样就不需要再添加环境变量运行）
	rm -rf mongo*                                                                                                              #删除 包及路径
	
	
	mkdir /root/data                                                                                                           #新建路径 存放mongodb数据库
	
	
	sed -i 's?/usr/local/bin/mongod -dbpath /root/data/ -logpath /root/data/mongod.log --logappend &??g' /etc/rc.d/rc.local    #检查是否已存在自启行，存在则先删掉
	sed -i '/^\s*$/d' /etc/rc.d/rc.local                                                                                       #删除所有空行
	sed -i '$a\/usr/local/bin/mongod -dbpath /root/data/ -logpath /root/data/mongod.log --logappend &' /etc/rc.d/rc.local      #添加自启动信息 到开机启动脚本中：（脚本默认没有声明环境变量，需要加入绝对地址）
	chmod +x /etc/rc.d/rc.local                                                                                                #添加可执行权限 (centos 7第一次启用ra.local时需要添加权限)
	
	
	mongod -dbpath /root/data/ -logpath /root/data/mongod.log --logappend &                                                    #开启mongodb（末尾加&表示以守护进程运行，可通过ps或ps -ef命令查看所有进程,然后通过kill命令结束）
	#开启成功后则mongodb在27017端口等待链接：waiting for connections on port 27017
} 
#安装leanote
function get_leanote(){
	wget http://downloads.sourceforge.net/project/leanote-bin/2.0/leanote-linux-amd64-v2.0.bin.tar.gz        #下载 leanote二进制版
	tar -xzvf leanote-linux-amd64-v2.0.bin.tar.gz                                                            #解压
	rm -rf leanote-linux-amd64-v2.0.bin.tar.gz                                                               #删除
	mongorestore -h localhost -d leanote --dir /root/leanote/mongodb_backup/leanote_install_data/            #mongodb导入leanote初始数据
	
	
	#编辑leanote配置文件
    cat > /root/leanote/conf/app.conf<<-EOF
	#------------------------
	# leanote config
	#------------------------

	http.port=${lea_port}

	site.url=http://${IP}:${lea_port} # or http://x.com:8080, http://www.xx.com:9000

	# admin username
	adminUsername=admin

	# mongdb
	db.host=127.0.0.1
	db.port=27017
	db.dbname=leanote # required
	db.username= # IF not exists, please leave it blank
	db.password= # IF not exists, please leave it blank
	# or you can set the mongodb url for more complex needs the format is:
	# mongodb://myuser:mypass@localhost:40001,otherhost:40001/mydb
	# db.url=mongodb://root:root123@localhost:27017/leanote
	# db.urlEnv=${MONGODB_URL} # set url from env. eg. mongodb://root:root123@localhost:27017/leanote

	# You Must Change It !! About Security!!
	app.secret=${app_aaa}ZzBeTnzpsHyjQX4zukbQ8qqtju9y2aDM55VWxAH9Qop19poekx3xkcDVvrD0y

	#--------------------------------
	# revel config
	# for dev
	#--------------------------------
	app.name=leanote
	http.addr=
	http.ssl=false
	cookie.httponly=false
	cookie.prefix=LEANOTE
	cookie.domain= # for share cookie with sub-domain
	cookie.secure=false
	format.date=2006-01-02
	format.datetime=2006-01-02 15:04:05 # 必须这样配置
	results.chunked=false

	log.trace.prefix = "TRACE "
	log.info.prefix  = "INFO  "
	log.warn.prefix  = "WARN  "
	log.error.prefix = "ERROR "

	# The default language of this application.
	i18n.default_language=en-us

	module.static=github.com/revel/modules/static

	[dev]
	mode.dev=true
	results.pretty=true
	watch=true

	module.testrunner = # github.com/revel/modules/testrunner

	log.trace.output = stderr
	log.info.output  = stderr
	log.warn.output  = stderr
	log.error.output = stderr

	[prod]
	mode.dev=false
	results.pretty=false
	watch=false

	module.testrunner =

	log.trace.output = off
	log.info.output  = off
	log.warn.output  = %(app.name)s.log
	log.error.output = %(app.name)s.log
	EOF
	
	
	sed -i '$s?ote/leanote?ote/leanote \&?' /root/leanote/bin/run.sh                                #修改启动脚本为守护进程、特殊字符&用\进行转意
	sed -i 's?sh /root/leanote/bin/run.sh &??g' /etc/rc.d/rc.local                                  #检查是否已存在自启行，存在则先删掉
	sed -i '/^\s*$/d' /etc/rc.d/rc.local                                                            #删除所有空行
	sed -i '$a\sh /root/leanote/bin/run.sh &' /etc/rc.d/rc.local                                    #添加自启动信息到开机启动脚本中
	
	sh /root/leanote/bin/run.sh &                                                                   #以守护进程方式启动
}
#关闭firewalld
function disale_firewalld(){
	systemctl stop firewalld.service                                                                     #用于Centos7停止默认防火墙firewalld
	systemctl disable firewalld.service                                                                  #禁止firewalld开机启动
}



#安装:1
function install_leanote(){
	get_ip
	get_info
	set_mongodb
	get_leanote
	disale_firewalld
	echo -e "###################################################################################"
	echo -e "#"
	echo -e "# [\033[32;1m安装完成!!\033[0m]"
	echo -e "#"
	echo -e "# 网站地址:\033[33;1mhttp://${IP}:${lea_port}\033[0m"
	echo -e "# 管理员账号:\033[33;1madmin\033[0m"
	echo -e "# 管理员密码:\033[33;1mabc123\033[0m (请尽快修改)"
	echo -e "#"
	echo -e "###################################################################################"
	echo -e ""
}

#备份:2
function leanote_backup(){
	rm -rf /root/leanote/mongodb_backup/leanote                                               #删除上次备份
	mongodump -h localhost -d leanote -o /root/leanote/mongodb_backup/                        #备份leanote单个数据库
	cd /root
	tar -zcvf /root/LEANOTE_backup_`date +%Y_%m_%d_%H.%M.%S`.tgz leanote                      #整个打包为.tgz文件
	echo -e "# [\033[32;1m已完成备份\033[0m]"
}

#恢复:3
function leanote_restore(){
	ls
	read -p "输入上面要恢复文件的文件名:" res_file
	
	set_mongodb
	
	mkdir /root/_leanote
	rm -rf /root/_leanote/*
	cp -rf /root/leanote/* /root/_leanote
	rm -rf /root/leanote
	
	tar -xzvf $res_file
	mongorestore -h localhost -d leanote --drop --dir /root/leanote/mongodb_backup/leanote
	
	sed -i 's?sh /root/leanote/bin/run.sh &??g' /etc/rc.d/rc.local
	sed -i '/^\s*$/d' /etc/rc.d/rc.local
	sed -i '$a\sh /root/leanote/bin/run.sh &' /etc/rc.d/rc.local
	
	disale_firewalld
	
	echo -e "# [\033[32;1m已完成，重启自动生效\033[0m]"
}



###########################
##         主程序        ##
###########################


#确保root用户运行脚本
root_only
ls
#操作选择
echo -e "#############################"
echo -e "# [\033[33;1m  Leanote安装脚本   \033[0m]"
echo -e "# [\033[33;1m  安装：1  \033[0m]"
echo -e "# [\033[33;1m  备份：2  \033[0m]"
echo -e "# [\033[33;1m  恢复：3  \033[0m]"
echo -e "#############################"
echo -e ""
read -p "选择要执行的操作:" lea_num

if [ "$lea_num" = "1" ]; then
	install_leanote
fi

if [ "$lea_num" = "2" ]; then
	leanote_backup
fi

if [ "$lea_num" = "3" ]; then
	leanote_restore
fi