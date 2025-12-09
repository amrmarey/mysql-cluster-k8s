# 🐬 MySQL InnoDB Cluster on Kubernetes

[![MySQL](https://img.shields.io/badge/MySQL-8.4.7%20LTS-blue?style=for-the-badge&logo=mysql&logoColor=white)](https://dev.mysql.com/doc/refman/8.4/en/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Operator](https://img.shields.io/badge/Operator-2.1.9-orange?style=for-the-badge)](https://dev.mysql.com/doc/mysql-operator/en/)

Production-ready MySQL InnoDB Cluster deployment using Oracle MySQL Operator for Kubernetes.

## 📋 Features

- ✅ **3-node InnoDB Cluster** with automatic failover
- ✅ **MySQL Router** for transparent connection routing
- ✅ **TLS encryption** for secure communication
- ✅ **Persistent storage** with configurable PVCs
- ✅ **Resource quotas & limits** for proper governance
- ✅ **Network policies** for security isolation
- ✅ **Pod anti-affinity** for high availability
- ✅ **Performance tuning** with optimized my.cnf

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    mysql-cluster namespace                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐        │
│  │   MySQL     │   │   MySQL     │   │   MySQL     │        │
│  │  Primary    │◄──│ Secondary 1 │──►│ Secondary 2 │        │
│  │   (RW)      │   │    (RO)     │   │    (RO)     │        │
│  └──────┬──────┘   └─────────────┘   └─────────────┘        │
│         │                                                    │
│         │ Group Replication (Port 33061)                    │
│         │                                                    │
│  ┌──────▼──────────────────────────────────────────┐        │
│  │              MySQL Router (HA)                   │        │
│  │  ┌─────────┐              ┌─────────┐           │        │
│  │  │Router 1 │              │Router 2 │           │        │
│  │  │:6446 RW │              │:6446 RW │           │        │
│  │  │:6447 RO │              │:6447 RO │           │        │
│  │  └─────────┘              └─────────┘           │        │
│  └─────────────────────────────────────────────────┘        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                    Application Access
```

## 📁 Project Structure

```
mysql-cluster-k8s/
├── README.md                 # This file
├── requirments.sh           # Installation script
├── namespace.yaml           # Namespace + ResourceQuota + LimitRange
├── network-policy.yaml      # Network isolation policies
├── secret.yaml              # Secret template (reference only)
├── mysql-cluster.yaml       # InnoDBCluster configuration
└── service.yaml             # Service configurations
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster v1.28+
- `kubectl` configured with cluster access
- Storage class available for PVCs
- OpenSSL (for password generation)

### Installation

```bash
# Clone or navigate to this directory
cd mysql-cluster-k8s

# Run the installation script
chmod +x requirments.sh
./requirments.sh

# Deploy network policies
kubectl apply -f network-policy.yaml

# Deploy the MySQL cluster
kubectl apply -f mysql-cluster.yaml

# Watch the cluster come up
kubectl -n mysql-cluster get pods -w
```

### Verify Installation

```bash
# Check operator status
kubectl -n mysql-operator get pods

# Check cluster status
kubectl -n mysql-cluster get innodbcluster

# View cluster details
kubectl -n mysql-cluster describe innodbcluster mycluster
```

## 🔌 Connecting to MySQL

### Port Forward (Development)

```bash
# Forward Router's read-write port
kubectl -n mysql-cluster port-forward svc/mycluster 3306:6446

# Connect using mysql client
mysql -h 127.0.0.1 -P 3306 -u root -p
```

### Connection Ports

| Port | Purpose | Description |
|------|---------|-------------|
| 6446 | Read-Write | Primary node connections |
| 6447 | Read-Only | Secondary node connections |
| 6448 | X Protocol RW | MySQL X Protocol (Read-Write) |
| 6449 | X Protocol RO | MySQL X Protocol (Read-Only) |

### From Within Kubernetes

```yaml
# Use this connection string in your application
host: mycluster.mysql-cluster.svc.cluster.local
port: 6446  # Read-Write
# or
port: 6447  # Read-Only
```

## ⚙️ Configuration

### Customizing Resources

Edit `mysql-cluster.yaml` to adjust:

```yaml
spec:
  instances: 3  # Number of MySQL instances
  
  podSpec:
    containers:
      - name: mysql
        resources:
          requests:
            cpu: "500m"
            memory: "2Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
```

### Storage Configuration

Update the storage class to match your cluster:

```yaml
datadirVolumeClaimTemplate:
  storageClassName: standard  # Change to your storage class
  resources:
    requests:
      storage: 20Gi
```

### MySQL Configuration

Modify the `mycnf` section for MySQL tuning:

```yaml
mycnf: |
  [mysqld]
  max_connections=500
  innodb_buffer_pool_size=1G
  # Add your configurations here
```

## 🔐 Security

### Password Management

**Never commit passwords to Git!** Use one of these approaches:

1. **Kubernetes Secrets** (from command line):
   ```bash
   kubectl create secret generic mysql-cluster-secret \
     --namespace=mysql-cluster \
     --from-literal=rootPassword="$(openssl rand -base64 24)"
   ```

2. **External Secrets Operator** for production:
   - HashiCorp Vault
   - AWS Secrets Manager
   - Azure Key Vault

### Network Policies

The included network policies:
- Default deny all traffic
- Allow DNS resolution
- Allow internal MySQL cluster communication
- Allow MySQL Router access from labeled namespaces

To allow an application namespace to connect:
```bash
kubectl label namespace my-app-namespace mysql-access=true
```

## 📊 Monitoring

### Cluster Status

```bash
# Quick status check
kubectl -n mysql-cluster get innodbcluster

# Detailed status
kubectl -n mysql-cluster get innodbcluster mycluster -o yaml

# View MySQL logs
kubectl -n mysql-cluster logs -l mysql.oracle.com/cluster=mycluster
```

### Shell Access

```bash
# Connect to primary node
kubectl -n mysql-cluster exec -it mycluster-0 -- mysqlsh root@localhost

# Check cluster status in MySQL Shell
cluster.status()
```

## 🔧 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Pods stuck in Pending | Check PVC status and storage class |
| Cluster not forming | Verify all pods are running, check logs |
| Connection refused | Ensure network policies allow traffic |
| Secret not found | Create the secret before deploying cluster |

### Useful Commands

```bash
# Check events
kubectl -n mysql-cluster get events --sort-by='.lastTimestamp'

# Check PVCs
kubectl -n mysql-cluster get pvc

# Describe a pod
kubectl -n mysql-cluster describe pod mycluster-0
```

## 📚 References

- [MySQL Operator Documentation](https://dev.mysql.com/doc/mysql-operator/en/)
- [MySQL InnoDB Cluster](https://dev.mysql.com/doc/refman/8.4/en/mysql-innodb-cluster-introduction.html)
- [MySQL Router](https://dev.mysql.com/doc/mysql-router/8.4/en/)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
