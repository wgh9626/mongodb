#!/bin/bash
# 设置管理员密码
admin_pass=$(tr -dc '_A-Za-z0-9' </dev/urandom | head -c 10)
echo "Generate mongodb user: admin password: $admin_pass"
# 设置exporter密码
exporter_pass=$(tr -dc '_A-Za-z0-9' </dev/urandom | head -c 10)
echo "Generate mongodb user: exporter password: $exporter_pass"
# 设置esb密码
esb_pass=$(tr -dc '_A-Za-z0-9' </dev/urandom | head -c 10)
echo "Generate mongodb user: esb password: $esb_pass"
# 设置hcsb密码
hcsb_pass=$(tr -dc '_A-Za-z0-9' </dev/urandom | head -c 10)
echo "Generate mongodb user: hcsb password: $hcsb_pass"
# 设置最大内存限制
read -p "Please input mongodb memory GB limit (default:4): " mem_limit
# 设置cache大小
[ -z $mem_limit ] && mem_limit=4
let cache_size=$mem_limit*3/4
echo "Mongodb memory GB cache size: $cache_size GB"
# 设置最大CPU限制
read -p "Please input mongodb cpu limit (default:2): " cpu_limit
[ -z $cpu_limit ] && cpu_limit=2
# 设置数据存储大小
read -p "Please input mongodb data volume GB size(default:10): " data_volume_size
[ -z $data_volume_size ] && data_volume_size=10
mongodb_cr_template="config/samples/mongodb.com_v1_mongodbcommunity_cr.yaml.template"
mongodb_cr="config/samples/mongodb.com_v1_mongodbcommunity_cr.yaml"
cp $mongodb_cr_template $mongodb_cr
sed  -i "s/<admin-password-here>/$admin_pass/" $mongodb_cr
sed  -i "s/<exporter-password-here>/$exporter_pass/" $mongodb_cr
sed  -i "s/<esb-password-here>/$esb_pass/" $mongodb_cr
sed  -i "s/<hcsb-password-here>/$hcsb_pass/" $mongodb_cr
sed  -i "s/<your-cache-size-here>/$cache_size/" $mongodb_cr
sed  -i "s/<your-cpu-limit-here>/$cpu_limit/" $mongodb_cr
sed  -i "s/<your-mem-limit-here>/$mem_limit/" $mongodb_cr
sed  -i "s/<your-data-volume-size-here>/$data_volume_size/" $mongodb_cr
echo -e "1. Use registry-hz harbor\n2. Use hospital harbor"
read  harbor_choose
if [ ! -z $harbor_choose ];then
	if [ $harbor_choose -eq 2 ];then
    # set hospital deploy's harbor repo
    read -p "Please input hospital harbor url (default: harbor.rubikstack.com): " harbor_url
    read -p "Please input proxy repo name (default: wowjoy): " proxy_repo
    [ -z $harbor_url ] && harbor_url="harbor.rubikstack.com"
    [ -z $proxy_repo ] && proxy_repo="wowjoy"
    ping -c1 $harbor_url > /dev/null 2>&1
    if [ $? -ne 0 ];then
      echo "Harbor address ping not ok, Please Check!"
      exit 1
    fi
    # 替换 operator中的镜像地址
  	sed  -i "s/registry-hz.rubikstack.com/$harbor_url\/$proxy_repo/g" config/manager/manager.yaml
    # 替换 CRD自定义中的镜像地址
    sed  -i "s/registry-hz.rubikstack.com/$harbor_url\/$proxy_repo/g" config/samples/mongodb.com_v1_mongodbcommunity_cr.yaml
  fi
fi
######## 安装 #######
# 判断kubectl
which kubectl > /dev/null 2>&1
if [ $? -ne 0 ];then
	echo "kubectl command not found, please check !!"
	exit 1
fi
# 判断设置命名空间
read -p "Please input which namespace deploy mongodb: " namespace
if [ ! -z $namespace ];then
	kubectl get namespace $namespace > /dev/null 2>&1
	if [ $? -ne 0 ];then
    echo "namespace $namespace not found in k8s cluster, please check !!"
    exit 1
	fi
fi
# 判断设置存储类
kubectl get storageclass fast > /dev/null 2>&1
if [ $? -ne 0 ];then
	echo "storageclass "fast" not found, please check !!"
	exit 1
fi

function check_install() {
  resource=$1
  resource_name=$2
  if [[ "$resource" =~ ^(deployment|statefulset) ]];then
  	for ((i=3; i>0; i--))
  	do
  	  echo "Install...Please wait.."
  	  sleep 60
  		ready_replicas=$(kubectl get $resource/$resource_name  -n $namespace -ojsonpath='{.status.readyReplicas}')
  		echo $ready_replicas|egrep -we '(1|2|3)' >/dev/null 2>&1
  	done	
  else
    echo "Install...$resource: $resource_name"
    sleep 5
  	kubectl get $resource/$resource_name  -n $namespace > /dev/null 2>&1
  fi
  if [ $? -eq 0 ];then
    echo "$resource: $resource_name has been installed."
  else
    echo "$resource: $resource_name has'nt been installed."
    exit 1
  fi
}
# 安装CRD
kubectl apply -f config/crd/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
# 检查CRD安装情况
check_install crd mongodbcommunity.mongodbcommunity.mongodb.com
# 安装RBAC
kubectl apply -k config/rbac/  -n $namespace
# 检查RBAC安装情况
check_install role mongodb-kubernetes-operator
check_install rolebinding mongodb-kubernetes-operator
check_install serviceaccount mongodb-kubernetes-operator
# 安装mongodb-operator
kubectl create -f config/manager/manager.yaml -n $namespace
# 检查mongodb-operator安装情况
check_install deployment mongodb-kubernetes-operator
# 安装mongodb 副本集
kubectl apply -f config/samples/mongodb.com_v1_mongodbcommunity_cr.yaml -n $namespace
check_install mongodbcommunity mongodb
check_install statefulset mongodb
# 服务添加exporter端口
kubectl patch service -n $namespace mongodb-svc -p '{"spec": {"ports": [{"name": "mongodb-exporter","port": 9216, "targetPort": 9216}]}}'
