#!/bin/bash
######## 卸载 #######
# 判断kubectl
which kubectl > /dev/null 2>&1
if [ $? -ne 0 ];then
	echo "kubectl command not found, please check !!"
	exit 1
fi
# 设置命名空间
read -p "Please input which namespace remove mongodb: " namespace
if [ ! -z $namespace ];then
	kubectl get namespace $namespace > /dev/null 2>&1
	if [ $? -ne 0 ];then
    echo "namespace $namespace not found in k8s cluster, please check !!"
    exit 1
	fi
fi
# 卸载mongodb 副本集
kubectl delete  -f config/samples/mongodb.com_v1_mongodbcommunity_cr.yaml -n $namespace
# 卸载mongodb-operator
kubectl delete -f config/manager/manager.yaml -n $namespace
# 卸载RBAC
kubectl delete -k config/rbac/  -n $namespace
# 卸载CRD
kubectl delete -f config/crd/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
# 检查CRD安装情况
echo "Remove mongodb in namespace: $namespace sucessfully !"
