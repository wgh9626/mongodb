#!/bin/bash
# 判断kubectl
which kubectl > /dev/null 2>&1
if [ $? -ne 0 ];then
	echo "kubectl command not found, please check !!"
	exit 1
fi
# 检查prometheus-operator是否已经部署
kubectl api-resources -o name|grep servicemonitors >  /dev/null 2>&1
if [ $? -ne 0 ];then
	echo "servicemonitors CRD resources not found, please install prometheus-operator first !!"
	exit 1
# 设置已部署mongodb的命名空间
read -p "Please input the namespace of mongodb which have been deployed: "  mongodb_namespace
if [ ! -z $mongodb_namespace ];then
	kubectl get namespace $mongodb_namespace > /dev/null 2>&1
	if [ $? -ne 0 ];then
    echo "namespace $mongodb_namespace not found in k8s cluster, please check !!"
    exit 1
	fi
fi
# 设置已部署prometheus-operator所在的命名空间
read -p "Please input the namespace of prometheus-operator which have been deployed: " prometheus_namespace
if [ ! -z $prometheus_namespace ];then
	kubectl get namespace $prometheus_namespace > /dev/null 2>&1
	if [ $? -ne 0 ];then
    echo "namespace $prometheus_namespace not found in k8s cluster, please check !!"
    exit 1
	fi
fi
# 应用servicemonitor自动发现prometheus服务
kubectl apply -n $prometheus_namespace config/samples/servicemonitor.yaml