#!/bin/bash
echo "此脚本为普通版一键部署脚本，docker和harbor的数据目录都为默认路径，如果需要手动指定路径，请去运行ocd-pro.sh脚本"
echo "执行此脚本前要注意容器化部署所有的包是否放在/root目录下，如果没有则按ctrl+c退出，并将包移动到/root下，如果确定所有包都在/root下，按回车继续
<Press enter to continue>"
read
#关闭防火墙
systemctl stop firewalld
systemctl disable firewalld
#修改主机名
hostnamectl --static set-hostname rancher
#启用ipv4转发
ipv4=$(sysctl net.ipv4.ip_forward | awk '{print $NF}')
if [ $ipv4 -eq 0 ]
then
        echo "ipv4转发未开启，正在自动启用中"
cat >>/etc/sysctl.conf<<EOF
net.ipv4.ip_forward = 1
EOF
sysctl -p /etc/sysctl.conf
else
        echo "ipv4转发已开启"
fi
#清理iptables规则
iptables -F
#检查80和443端口是否被占用
#!/bin/bash
if `lsof -Pi :443 -sTCP:LISTEN -t >/dev/null`&&`lsof -Pi :80 -sTCP:LISTEN -t >/dev/null`
then
echo "warning: 80和443端口已被占用，如果需要单节点部署rancher集群则需要80和443端口不被占用
！如果不是单节点部署，请忽略此警告"
echo "<Press enter to continue>"
read
fi
#部署开始前检查安装包是否存在
for i in /root/{docker-18.06.1-ce.tgz,harbor-offline-installer-v1.10.1.tgz,docker-compose-Linux-x86_64,bip1.0-images.tar.gz,rancher-images.tar.gz,rancher-load-images.sh,rancher-images.txt}
do
if [ -f $i ]
then
        echo -e "\e[1;32m$i存在\e[0m"
else
        echo "$i不存在，脚本将在3秒后自动退出"
        sleep 3
        exit
fi
done
        return

#开始部署
echo -e "\e[1;32m开始部署docker\e[0m"
dockergz="/root/docker-18.06.1-ce.tgz"
if  [ $? -eq 0 ];then
  tar zxvf $dockergz --strip-components 1 -C /usr/bin/
fi
echo -e "\e[1;32mdocker解压完成,执行docker服务注册\e[0m"
echo "====================================================================================="
#自动获取IP
net=$(find /etc/sysconfig/network-scripts/ifcfg-*|grep -v  ifcfg-lo | wc -l)
netc=$(find /etc/sysconfig/network-scripts/ifcfg-*|grep -v  ifcfg-lo | awk -F '-' '{print $3}')
if [[ $netc =~ ^eth.* ]]
then
        ip=$(ifconfig | grep eth* |grep inet|awk     NR==1'{print $2":8888"}')
elif [ $net != 1 ]
then
        nets=$(find /etc/sysconfig/network-scripts/ifcfg-*|grep -v  ifcfg-lo)
        ip=$(sed -n  '/^IPADDR/p'  $nets |awk  -F '='  '{print $2":8888"}')
elif [ $net == 1  ]
then
        netonly=$(find /etc/sysconfig/network-scripts/ifcfg-*|grep -v  ifcfg-lo)
        ip=$(sed -n  '/^IPADDR/p'  $netonly |awk  -F '='  '{print $2":8888"}')

fi
lip=$(echo $ip | awk -F ':' '{print $1}')
localip=$(ifconfig | grep -w "$lip" | awk '{print $2}')
if [ ! -n "$localip" ]
then
        echo "您当前输入的ip有误，请确认输入的ip是否为本机ip，如果您输入的是云服务器的公网ip，请忽略此警告"
        echo "<Press enter to continue>"
        read
fi
#部署docker
MAINPID="MAINPID"
cat  >>/etc/systemd/system/docker.service<<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd  --insecure-registry=$ip
ExecReload=/bin/kill -s HUP $MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
# restart the docker process if it exits prematurely
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF

#判断docker是否部署成功
dockerce=/etc/systemd/system/docker.service
if  [  -f  $dockerce   ];then
   echo  "$dockerce" 该目录下有此docker配置文件
else
  echo   "$dockerce" 该目录下没有此docker配置文件
  return
fi

`systemctl daemon-reload`
 echo "加载docker配置文件"
  sleep 2
`systemctl start docker`
  echo  "启动docker"
 sleep 2
`systemctl enable docker`
 echo  docker开机自启动
  sleep 2

harborgz="/root/harbor-offline-installer-v1.10.1.tgz"
harborml='/root/harbor'

if  [ -e "$harborgz"    ];then
        echo "$harborgz" harbor压缩包文件存在
        tar xfvz  "$harborgz" >/dev/null
       else
       echo "$harborgz" harbor压缩包不存在，请上传!
fi

if  [ -d  "$harborml"   ];then
          echo  "$harborml" harbor解压完成！
         else
           echo  "$harborml" harbor目录不存在
           return
fi

compose=/root/docker-compose-Linux-x86_64
bin=docker-compose
if [ -e "$compose"   ];then
    echo "$compose" docker-compose文件存在
    mv $compose   /usr/local/bin/$bin
   else
   echo  "$compose" docker-compose文件不存在，请上传！
   return
fi

pose=/usr/local/bin/docker-compose
if  [  -x  "$pose"      ];then
    echo "$pose" docker-compose具有执行权限！
else
   echo  "$pose" docker-compose没有执行权限，正在自动赋予中
      `chmod +x $pose`
fi

hip=$(echo $ip | awk -F ':' '{print $1}')
hport=$(echo $ip | awk -F ':' '{print $2}')
sed -i "5s/ho.*/hostname:  $hip/g" /root/harbor/harbor.yml
if [ -n "$hport" ]
then
	sed -i  "10s/po.*/port: $hport/g"  /root/harbor/harbor.yml
else
	sed -i  "10s/po.*/port: 80/g"  /root/harbor/harbor.yml
fi
sed -i  '13,+5 s/https.*/#https:/g'  /root/harbor/harbor.yml
sed -i   '15s/port.*443/#port: 443/g'  /root/harbor/harbor.yml
sed -i  's/c.*h$/#certificate: \/your\/certificate\/path/g'  /root/harbor/harbor.yml
sed -i '18s/p.*h$/#private_key: \/your\/private\/key\/path/g' /root/harbor/harbor.yml
echo "====================================================================================="
x=/root/harbor/install.sh
h=/root/harbor
exist="docker inspect --format '{{.State.Running}}' harbor-jobservice"
if [  -x  "$x"   ]
then
    echo  "$x" 有此文件
    cd "$h" && ./install.sh
    echo  "$x" harbor正在部署，请稍等
    sleep  3
if  [ "${exist}" != "true"  ]
then
    echo "harbor部署成功"
else
    echo "harbor部署失败!"
    return
fi
fi
echo “正在将harbor加入系统服务并设置开机启动，请稍等”
mkdir /usr/local/etc/harbor
cp -p /root/harbor/docker-compose.yml /usr/local/etc/harbor/
cp -pR /root/harbor/common /usr/local/etc/harbor
touch /etc/systemd/system/harbor.service
cat >>/etc/systemd/system/harbor.service<<EOF
[Unit]
Description=Harbor
After=docker.service systemd-networkd.service systemd-resolved.service
Requires=docker.service
Documentation=http://github.com/vmware/harbor

[Service]
Type=simple
Restart=on-failure
RestartSec=5
ExecStart=/usr/local/bin/docker-compose -f  /usr/local/etc/harbor/docker-compose.yml up
ExecStop=/usr/local/bin/docker-compose -f /usr/local/etc/harbor/docker-compose.yml down

[Install]
WantedBy=multi-user.target
EOF
chmod +x /etc/systemd/system/harbor.service
systemctl daemon-reload
systemctl enable harbor
systemctl start harbor

sleep 2
echo "====================================================================================="
#echo rancher-load-images.sh、这个脚本会载入文件rancher-images.tar.gz中的镜像，并将它们推送到自己的私用镜像库中。
#read -p "请输入登陆harborIP及端口=" IP
#ACCOUNT=admin
#PASSWD=Harbor12345
docker login $ip -u admin -p Harbor12345
#docker login $ip

ranchersh="/root/rancher-load-images.sh"
rancherfile="/root/rancher-images.txt"
if  [ -f $ranchersh    ];then
    echo "$ranchersh" 上传rancher脚本存在
else
    echo  "$ranchersh" 上传rancher脚本不存在，请上传！
    return
fi
    sleep 1

if  [ -x $ranchersh    ];then
    echo  "$ranchersh" 上传rancher脚本具有执行权限
else
    echo  "$ranchersh" 上传rancher脚本没有执行权限，正在自动赋予中
fi

sleep 1
echo  "====================================================================================="
echo "rancher镜像正在推送中，此步骤根据机器性能不同推送时间为30-60分钟，请耐心等待"
curl -u "admin:Harbor12345" -X POST -H "Content-Type: application/json" "$ip/api/projects" -d '{"project_name": "rancher","metadata": {"public": "true"}}'
cd /root/
bash $ranchersh  --image-list  $rancherfile  --registry  $ip/rancher

out=$(ls -l /data/registry/docker/registry/v2/repositories/rancher/rancher | grep "^d" | wc -l)

if [ $out -ge 72 ]
then
    echo  "rancher目录下镜像文件完整!"
else  
    echo  "rancher该目录下镜像文件不完整，正在重新执行推送操作，请稍等（重新推送操作完成后请登录harbor检查镜像是否完整!）"
    bash $ranchersh  --image-list  $rancherfile  --registry  $ip/rancher
fi

echo  "====================================================================================="
echo  "启动rancher主容器"
docker run -d --restart=unless-stopped -p 1080:80 -p 1443:443  -e CATTLE_SYSTEM_DEFAULT_REGISTRY=$ip/rancher  -e CATTLE_SYSTEM_CATALOG=bundled   $ip/rancher/rancher/rancher:v2.4.17
docker ps | grep -q 1443   > /dev/null
if [ $?  != "true"   ];then
   echo  "rancher主容器启动成功"
else
   echo  "rancher主容器启动失败"
   return
fi

#mkdir -p /opt/backup
#mv   $harborgz  $ranchergz  $dockergz $rancherfile  $ranchersh   /opt/backup/

read -p "请输入harbor项目名(此项目名为想要在harbor中新建的项目名称，输入后脚本会自动创建): " project

sleep 3

curl=$(curl -s $ip | grep Harbor | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
if [ $curl == Harbor ] &> /dev/null
then
        echo -n
else
        echo harborip或端口错误，脚本将在3秒后自动退出
        return
fi

curl -u "admin:Harbor12345" -X POST -H "Content-Type: application/json" "$ip/api/projects" -d '{"project_name": "'$project'","metadata": {"public": "true"}}' &> /dev/null

echo "镜像正在自动load并推送中，请耐心等待"

docker load -i /root/bip1.0-images.tar.gz

touch /root/images.txt
touch /root/imagename.txt
images=$(docker images | grep 161.189.83.164 | awk '{print $1 ":" $2}')
imagename=$(docker images | grep 161.189.83.164 | awk -F '/' '{print $3}' | awk '{print $1 ":" $2}')

echo "$images" > images.txt
echo "$imagename" > imagename.txt
exec 3<"/root/images.txt"
exec 4<"/root/imagename.txt"
while read line1<&3 && read line2<&4
do
 docker tag $line1 $ip/$project/$line2
 docker push $ip/$project/$line2
done

rm -f /root/images.txt
rm -f /root/imagename.txt

echo "脚本已执行完成，请断开ssh工具重新连接，以确保机器名更改成功"
