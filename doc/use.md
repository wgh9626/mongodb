### 安装mongodb集群

```shell
chmod +x *.sh
./main-install.sh
```



### 卸载mongodb集群

```shell
./main-uninstall.sh
```



### 获取mongodb连接信息

#### 1. 安装jq

```shell
wget https://wowjoy-operator.obs.cn-east-3.myhuaweicloud.com:443/rpm/centos7/oniguruma-6.8.2-2.el7.x86_64.rpm
wget https://wowjoy-operator.obs.cn-east-3.myhuaweicloud.com/rpm/centos7/jq-1.6-2.el7.x86_64.rpm
rpm -ivh *.rpm
```

### 2. 获取mongodb连接串

**格式:**

```shell
kubectl get secret <metadata.name>-<auth-db>-<username> -n <my-namespace> \ 
-o json | jq -r '.data | with_entries(.value |= @base64d)'
```

**举例:**

*获取admin库admin账号连接串*

```shell
kubectl get secrets  -n dev mongodb-admin-admin -ojson|jq -r '.data | with_entries(.value |= @base64d)'
```

```json
{
  "connectionString.standard": "mongodb://admin:Uv3683AYfr@mongodb-0.mongodb-svc.dev.svc.cluster.local:27017,mongodb-1.mongodb-svc.dev.svc.cluster.local:27017,mongodb-2.mongodb-svc.dev.svc.cluster.local:27017/admin?replicaSet=mongodb&ssl=false",
  "connectionString.standardSrv": "mongodb+srv://admin:Uv3683AYfr@mongodb-svc.dev.svc.cluster.local/admin?replicaSet=mongodb&ssl=false",
  "password": "Uv3683AYfr",
  "username": "admin"
}
```

*命名空间:* dev

*用户名: admin*

*密码: Uv3683AYfr*

*库: admin* 

*K8S同命名空间连接地址:  mongodb-svc*

*K8S跨命名空间连接地址:  mongodb-svc.dev.svc.cluster.local*	



#### 3. 测试命令行登录mongodb实例

```shell
 kubectl exec -it -n dev mongodb-0 mongo "mongodb+srv://admin:Uv3683AYfr@mongodb-svc.dev.svc.cluster.local/admin?replicaSet=mongodb&ssl=false"
```



### 添加用户

#### 1. 创建用户Secret文件

```yaml
./create_user.sh
```

#### 2. 手动编辑CRD配置，添加`spec.users`新用户

```shell
vim config/samples/mongodb.com_v1_mongodbcommunity_cr.yaml
```

**格式:**

```yaml
---
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: mongodb
spec:
...
  users:
    - name: <dbname>
      db: <dbname>
      passwordSecretRef:
        name: <dbname>-password
      roles:
        - name: dbOwner
          db: <dbname>
...
```

**举例: 添加`hcsb`数据库`hcsb`用户**

```yaml
---
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: mongodb
spec:
...
  users:
    - name: hcsb
      db: hcsb
      passwordSecretRef:
        name: hcsb-password
      roles:
        - name: dbOwner
          db: hcsb
...
```
#### 3. 应用修改的配置

```shell
kubectl apply -f config/samples/user/user-secret.yaml -n “你的命名空间”
kubectl apply -f config/samples/mongodb.com_v1_mongodbcommunity_cr.yaml -n “你的命名空间”
```

#### 4. 测试命令行用户登录mongodb实例

**格式:**
```shell
 kubectl exec -it -n 命名空间 mongodb-0 mongo "mongodb+srv://账号:密码@mongodb-svc.命名空间.svc.cluster.local/库名?replicaSet=mongodb&ssl=false"
```

**举例: 验证`dev`命名空间下mongodb集群`hcsb`用户权限**
```shell
 kubectl exec -it -n dev mongodb-0 mongo "mongodb+srv://hcsb:xxxx@mongodb-svc.dev.svc.cluster.local/hcsb?replicaSet=mongodb&ssl=false"
```

参考:  https://github.com/mongodb/mongodb-kubernetes-operator