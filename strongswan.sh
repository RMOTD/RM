#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
clear


##################################################################################################################
########################                       1.安装环境准备                          ###########################
##################################################################################################################

#1.确保root用户运行
function root_only(){
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[31;1m错误:你必须以root用户执行该脚本!\033[0m" 1>&2
   exit 1
fi
echo -e "\033[32;1mroot用户确认成功\033[0m"
}

#2.禁用selinux
function dis_selinux(){
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
echo -e "\033[32;1mselinux已禁用\033[0m"
}

#3.安装环境
function yum_install(){
	yum -y install pam-devel openssl-devel make gcc curl
echo -e "\033[32;1m必要运行库已安装\033[0m"
}

#4.获取IP 
function get_ip(){
    echo "获取服务器IP............请稍等....."
    IP=`curl -s checkip.dyndns.com | cut -d' ' -f 6  | cut -d'<' -f 1`
    if [ -z $IP ]; then
        IP=`curl -s ifconfig.me/ip`
    fi
echo -e "\033[32;1mIP已获取\033[0m"	
}


##################################################################################################################
########################                      2.预安装信息获取                         ###########################
##################################################################################################################


#预安装信息获取
function pre_install(){
    echo -e "#################################################################"
    echo -e "#\033[33;1m                IPSec IKEv2 VPN installation                   \033[0m#"
    echo -e "#\033[33;1m                                                               \033[0m#"
    echo -e "#\033[33;1m                   centos6.x or 7.x                            \033[0m#"
    echo -e "#################################################################"
    echo -e ""
	#VPS类型
    echo "Choose the type of your VPS(Xen、KVM: 1  ,  OpenVZ: 2):"
    read -p "(1 or 2):" os_choice
    if [ "$os_choice" = "1" ]; then
        os="1"
		os_str="Xen、KVM"
		else
			if [ "$os_choice" = "2" ]; then
				os="2"
				os_str="OpenVZ"
				else
				echo "input error!"
				exit 1
			fi
    fi
	#1:SNAT or 2:MASQUERADE ?
    echo "use 1:SNAT or 2:MASQUERADE ?, SNAT require a static ip address."
    read -p "1 or 2 ? (default_value:2):" use_SNAT
    if [ "$use_SNAT" = "1" ]; then
    	use_SNAT_str="1"
		flag_SNAT_MASQUERADE="SNAT"
    	echo "Some servers has elastic IP (AWS) or mapping IP.In this case,you should input the IP address which is binding in network interface."
    	read -p "static ip or network interface ip (default_value:${IP}):" static_ip
	if [ "$static_ip" = "" ]; then
		static_ip=$IP
	fi
    else
    	use_SNAT_str="0"
		flag_SNAT_MASQUERADE="MASQUERADE"
    fi
	#IP提取
	echo "please input the ip (or domain) of your VPS:"
    read -p "ip or domain(default_value:${IP}):" vps_ip
	if [ "$vps_ip" = "" ]; then
		vps_ip=$IP
	fi
	#证书信息
	echo "please input the cert country(C):"
    read -p "C(default value:AAA):" my_cert_c
	if [ "$my_cert_c" = "" ]; then
		my_cert_c="AAA"
	fi
	echo "please input the cert organization(O):"
    read -p "O(default value:BBB):" my_cert_o
	if [ "$my_cert_o" = "" ]; then
		my_cert_o="BBB"
	fi
	echo "please input the cert common name(CN):"
    read -p "CN(default value:${IP}):" my_cert_cn
	if [ "$my_cert_cn" = "" ]; then
		my_cert_cn="${IP}"
	fi
	#信息确认
	echo "####################################"
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    echo -e "\033[33;1m!!!!Confirm the information!!!!\033[0m:"
	echo ""
	echo -e "the type of your server: [\033[32;1m$os_str\033[0m]"
	echo -e "NAT Type:[\033[32;1m${flag_SNAT_MASQUERADE}\033[0m]"	
	echo -e "the ip(or domain) of your server: [\033[32;1m$vps_ip\033[0m]"
	echo -e "the cert_info:[\033[32;1mC=${my_cert_c}, O=${my_cert_o}, CN=${my_cert_cn}\033[0m]"
	echo ""
    echo -e "\033[33;1many key to confirm，or Ctrl+C to cancel\033[0m"
	char=`get_char`
    cur_dir=`pwd`
    cd $cur_dir
echo -e "\033[32;1mpreinstallation complete\033[0m"	
}


##################################################################################################################
########################                      3.strongswan安装                         ###########################
##################################################################################################################

#1.安装strongswan
function install_strongswan(){
    if [ -f strongswan.tar.gz ];then
        echo -e "strongswan.tar.gz [\033[32;1mfound\033[0m]"
    else
        if ! wget --no-check-certificate https://download.strongswan.org/strongswan.tar.gz;then
            echo "Failed to download strongswan.tar.gz"
            exit 1
        fi
    fi
    tar xzf strongswan*.tar.gz
    if [ $? -eq 0 ];then
        cd $cur_dir/strongswan*/
    else
        echo ""
        echo "Unzip strongswan.tar.gz failed!"
        exit 1
    fi
	# 以上为下载，下面为安装过程
	if [ "$os" = "1" ]; then
		./configure  --enable-eap-identity --enable-eap-md5 \
--enable-eap-mschapv2 --enable-eap-tls --enable-eap-ttls --enable-eap-peap  \
--enable-eap-tnc --enable-eap-dynamic --enable-eap-radius --enable-xauth-eap  \
--enable-xauth-pam  --enable-dhcp  --enable-openssl  --enable-addrblock --enable-unity  \
--enable-certexpire --enable-radattr --enable-swanctl --enable-openssl --disable-gmp

	else
		./configure  --enable-eap-identity --enable-eap-md5 \
--enable-eap-mschapv2 --enable-eap-tls --enable-eap-ttls --enable-eap-peap  \
--enable-eap-tnc --enable-eap-dynamic --enable-eap-radius --enable-xauth-eap  \
--enable-xauth-pam  --enable-dhcp  --enable-openssl  --enable-addrblock --enable-unity  \
--enable-certexpire --enable-radattr --enable-swanctl --enable-openssl --disable-gmp --enable-kernel-libipsec

	fi
	make; make install
	#生成证书
	cd $cur_dir
    if [ -f ca.pem ];then
        echo -e "ca.pem [\033[32;1mfound\033[0m]"
    else
        echo -e "ca.pem [\033[32;1mauto create\033[0m]"
		echo "creating ca.pem ..."
		ipsec pki --gen --outform pem > ca.pem
    fi
	
	if [ -f ca.cert.pem ];then
        echo -e "ca.cert.pem [\033[32;1mfound\033[0m]"
    else
        echo -e "ca.cert.pem [\033[33;1mauto create\033[0m]"
		echo "creating ca.cert.pem ..."
		ipsec pki --self --in ca.pem --dn "C=${my_cert_c}, O=${my_cert_o}, CN=${my_cert_cn}" --ca --outform pem >ca.cert.pem
    fi
	if [ ! -d my_key ];then
        mkdir my_key
    fi
	mv ca.pem my_key/ca.pem
	mv ca.cert.pem my_key/ca.cert.pem
	cd my_key
	ipsec pki --gen --outform pem > server.pem	
	ipsec pki --pub --in server.pem | ipsec pki --issue --cacert ca.cert.pem \
--cakey ca.pem --dn "C=${my_cert_c}, O=${my_cert_o}, CN=${vps_ip}" \
--san="${vps_ip}" --flag serverAuth --flag ikeIntermediate \
--outform pem > server.cert.pem
	ipsec pki --gen --outform pem > client.pem	
	ipsec pki --pub --in client.pem | ipsec pki --issue --cacert ca.cert.pem --cakey ca.pem --dn "C=${my_cert_c}, O=${my_cert_o}, CN=VPN Client" --outform pem > client.cert.pem
	echo "configure the pkcs12 cert password:"
	openssl pkcs12 -export -inkey client.pem -in client.cert.pem -name "client" -certfile ca.cert.pem -caname "${my_cert_cn}"  -out client.cert.p12
	echo "####################################"
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    echo "Press any key to install ikev2 VPN cert"
	cp -r ca.cert.pem /usr/local/etc/ipsec.d/cacerts/
	cp -r server.cert.pem /usr/local/etc/ipsec.d/certs/
	cp -r server.pem /usr/local/etc/ipsec.d/private/
	cp -r client.cert.pem /usr/local/etc/ipsec.d/certs/
	cp -r client.pem  /usr/local/etc/ipsec.d/private/	
	echo -e "\033[32;1mstrongswan installed\033[0m"
}

#2.配置strongswan.conf
function configure_strongswan(){
 cat > /usr/local/etc/strongswan.conf<<-EOF
 charon {
        load_modular = yes
        duplicheck.enable = no
        compress = yes
        plugins {
                include strongswan.d/charon/*.conf
        }
        dns1 = 8.8.8.8
        dns2 = 8.8.4.4
        nbns1 = 8.8.8.8
        nbns2 = 8.8.4.4
        }
include strongswan.d/*.conf
EOF
echo -e "\033[32;1mstrongswan.conf configuration completed\033[0m"
}

#3.配置ipsec.conf
function configure_ipsec(){
 cat > /usr/local/etc/ipsec.conf<<-EOF
config setup
    uniqueids=never 

conn iOS_cert
    keyexchange=ikev1
    fragmentation=yes
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn android_xauth_psk
    keyexchange=ikev1
    left=%defaultroute
    leftauth=psk
    leftsubnet=0.0.0.0/0
    right=%any
    rightauth=psk
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    auto=add

conn networkmanager-strongswan
    keyexchange=ikev2
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn ios_ikev2
    keyexchange=ikev2
    ike=aes256-sha256-modp2048,3des-sha1-modp2048,aes256-sha1-modp2048!
    esp=aes256-sha256,3des-sha1,aes256-sha1!
    rekey=no
    left=%defaultroute
    leftid=${vps_ip}
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=eap-mschapv2
    rightsourceip=10.31.2.0/24
    rightsendcert=never
    eap_identity=%any
    dpdaction=clear
    fragmentation=yes
    auto=add

conn windows7
    keyexchange=ikev2
    ike=aes256-sha1-modp1024!
    rekey=no
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=eap-mschapv2
    rightsourceip=10.31.2.0/24
    rightsendcert=never
    eap_identity=%any
    auto=add
	

EOF
echo -e "\033[32;1mipsec.conf configuration completed\033[0m"
}

#4.配置ipsec.secrets
function configure_secrets(){
	cat > /usr/local/etc/ipsec.secrets<<-EOF
: RSA server.pem
: PSK "PSK"
: XAUTH "XAUTH"
1 %any : EAP "1"
2 %any : EAP "2"
3 %any : EAP "3"
	EOF
echo -e "\033[32;1mipsec.secrets configuration completed\033[0m"
}


##################################################################################################################
########################                      3.最后配置及启动                         ###########################
##################################################################################################################

#1.设置iptables
function iptables_set(){
	systemctl stop firewalld.service                                     #用于Centos7停止默认防火墙firewalld
	systemctl disable firewalld.service                                  #禁止firewalld开机启动
	yum -y install iptables-services                                     #安装iptables防火墙
	
	#sed -i '/net.ipv4.ip_forward/ s/\(.*= \).*/\11/' /etc/sysctl.conf    #永久修改net.ipv4.ip_forward=0为1，  重启依然有效（但没有考虑到文件中没有net.ipv4.ip_forward=0的情况）
	sed -i 's/net.ipv4.ip_forward=1//g' /etc/sysctl.conf                 #检查是否已存在net.ipv4.ip_forward=1，存在则先删掉，防止出现原文件中没有net.ipv4.ip_forward=0的情况
	sed -i '/^\s*$/d' /etc/sysctl.conf                                   #删除所有空行
	sed -i '$a\net.ipv4.ip_forward=1' /etc/sysctl.conf                   #重新添加一句net.ipv4.ip_forward=1 
	
    sysctl -w net.ipv4.ip_forward=1                                      #暂时性修改net.ipv4.ip_forward=1     重启失效 仅作临时开启
	
    if [ "$os" = "1" ]; then
	    # Xen、KVM 的iptables设置（eth0）
		interface="eth0"
	else
	    # OpenVZ 的iptables设置（venet0）
		interface="venet0"
    fi	
	
	iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A FORWARD -s 10.31.2.0/24  -j ACCEPT
	iptables -A INPUT -i $interface -p esp -j ACCEPT
	iptables -A INPUT -i $interface -p udp --dport 500 -j ACCEPT
	iptables -A INPUT -i $interface -p udp --dport 4500 -j ACCEPT
	#iptables -A FORWARD -j REJECT
	if [ "$use_SNAT_str" = "1" ]; then
		iptables -t nat -A POSTROUTING -s 10.31.2.0/24 -o $interface -j SNAT --to-source $static_ip
	else
	iptables -t nat -A POSTROUTING -s 10.31.2.0/24 -o $interface -j MASQUERADE
	fi
	service iptables save
echo -e "\033[32;1miptables_set completed\033[0m"	
}

#2.启动ipsec
function ipsec_start(){
	ipsec start
	sed -i 's?/usr/local/sbin/ipsec start??g' /etc/rc.d/rc.local    #检查是否已存在自启行，存在则先删掉
	sed -i '/^\s*$/d' /etc/rc.d/rc.local                            #删除所有空行
	sed -i '$a\/usr/local/sbin/ipsec start' /etc/rc.d/rc.local      #编辑/etc/rc.local，最后加入/usr/local/sbin/ipsec start，实现开机启动。
	chmod +x /etc/rc.d/rc.local                                     #Centos 6可省略 7增加了权限限制
	rm -rf /root/strongswan*                                        #删除安装残留
echo -e "\033[32;1mipsec_xl2tpd_started\033[0m"		
}



###########################
##         主程序        ##
###########################
#1.安装环境准备
root_only
dis_selinux
yum_install
get_ip
#2.预安装信息获取
pre_install
#3.Strongswan安装
install_strongswan
configure_strongswan
configure_ipsec
configure_secrets
#4.最后配置及启动
iptables_set
ipsec_start
echo -e "###################################################################################"
echo -e "#"
echo -e "# [\033[32;1mInstallation Complete\033[0m]"
echo -e "# login information:"
echo -e "# Username:\033[33;1m 1 2 3\033[0m (for 3 users)"
echo -e "# Password:\033[33;1m 1 2 3\033[0m"
echo -e "# PSK:\033[33;1m PSK\033[0m"
echo -e "# you could change the Username and Password in\033[32;1m /usr/local/etc/ipsec.secrets\033[0m" 
echo -e "# \033[32;1mIPSec\033[0m(IKEv1)  for Android/iOS/OSX"
echo -e "# \033[32;1mIKEv2\033[0m         for iOS/WindowsPhone/Windows/OSX/Linux"
echo -e "# for using IKEv2, the cert in \033[32;1m ${cur_dir}/my_key/ca.cert.pem \033[0m is need."
echo -e "#"
echo -e "###################################################################################"
echo -e ""