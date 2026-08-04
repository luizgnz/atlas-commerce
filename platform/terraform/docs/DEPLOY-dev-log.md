# Bitácora de despliegue — `live/aws/dev`

> **Fecha:** 2026-07-12
> **Cuenta AWS:** 724772086459 (perfil CLI `atlas-commerce`, usuario IAM `terraform-admin`)
> **Región:** eu-central-1 (Frankfurt)

Registro cronológico único del bootstrap del backend remoto, el primer despliegue end-to-end del ambiente `dev`, el hardening posterior contra valores hardcodeados, y el destroy final — en el orden real en que ocurrieron los hechos. Incorpora también los hallazgos de la revisión previa del bootstrap (2026-06-22) que seguían vigentes. Cada hallazgo se marca **✅ corregido** en el momento en que se diagnosticó y arregló, **✅ corregido después** si se resolvió en una pasada posterior, o **🔲 pendiente** si quedó abierto.

---

## 1. Bootstrap del backend remoto (`bootstrap/aws-backend`)

### 1.1 🔴 `backend.tf` declaraba un backend S3 parcial — **✅ corregido**

**Síntoma:** `terraform init` fallaba con:
```
Error: Error asking for input to configure backend "s3": bucket: EOF
```

**Causa:** `backend.tf` tenía `terraform { backend "s3" {} }`, contradiciendo el propio README del folder, que documenta que el bootstrap debe usar **estado local** (no puede depender de un backend que él mismo crea — problema chicken-and-egg).

**Fix aplicado en el momento:** se quitó el bloque `backend "s3" {}`, dejando `terraform {}` vacío con comentario explicativo. `terraform init` funcionó de inmediato después.

### 1.2 🔴 Tabla DynamoDB de locking creada pero nunca usada — **✅ corregido**

**Diagnóstico:** `main.tf` creaba `aws_dynamodb_table.terraform_locks`, pero el locking real ya lo hacía el S3 native lockfile (`use_lockfile = true`, Terraform ≥1.10 — confirmado en `versions.tf`). La tabla era un recurso huérfano: se aprovisionaba y mantenía sin que nada la consumiera.

**Fix aplicado en el momento:**
- Se eliminó el recurso `aws_dynamodb_table.terraform_locks` de `main.tf`, junto con `local.lock_table_name`, las variables `lock_table_name` y `enable_lock_table_deletion_protection`, y el output `terraform_lock_table_name`.
- Se aplicó `terraform apply` sobre el bootstrap para destruir la tabla ya creada en AWS (`0 added, 0 changed, 1 destroyed`).
- Se corrigió `backend_config_example_dev` (ver §1.4) para dejar de sugerir un `dynamodb_table` que ya no existe.

### 1.3 🟡 `backend.hcl` huérfano dentro de `bootstrap/aws-backend/` — **✅ corregido**

**Diagnóstico:** existía un `bootstrap/aws-backend/backend.hcl` sin ningún uso real (el bootstrap usa estado local, confirmado por `backend.tf` §1.1) y con datos obsoletos: apuntaba a la cuenta AWS `529601496188`, que no es la del usuario.

**Fix aplicado en el momento:** archivo eliminado — no tenía ninguna función.

### 1.4 🔴 Riesgo de transcripción manual del bucket de estado hacia cada `live/aws/<env>/backend.hcl` — **✅ corregido**

**Diagnóstico (posterior al despliegue de `dev`, ver §3):** el `backend.hcl` original de `live/aws/dev` apuntaba a la cuenta AWS `529601496188` (ajena), no a la cuenta real del usuario (`724772086459`). La causa era que ese archivo se había escrito a mano en algún momento anterior, sin generarlo desde el output real del bootstrap — es exactamente la clase de error que un valor hardcodeado facilita.

**Fix aplicado:** el output `backend_config_example_dev` (fijo a `dev`) se reemplazó por `backend_config_template`, parametrizable por ambiente vía `sed`, y se documentó en el README del bootstrap el comando exacto para generar cualquier `backend.hcl` sin transcripción manual:
```bash
cd platform/terraform/bootstrap/aws-backend
terraform output -raw backend_config_template | sed 's#<ENV>#dev#' > ../../live/aws/dev/backend.hcl
```
Verificado: el archivo generado con este comando coincide con los valores (`bucket`, `key`, `region`) ya aplicados en `dev`.

**Limitación que no se puede eliminar:** un bloque `backend "s3" {}` de Terraform no puede interpolar variables ni leer outputs de otro state (limitación del propio partial backend config). El account ID seguirá apareciendo como texto literal dentro de `backend.hcl` — lo que se elimina aquí es el riesgo de **transcribirlo mal a mano**, no el hardcode en sí.

---

## 2. Despliegue de `live/aws/dev`

### 2.1 Qué funcionó bien a la primera

- **Orden de dependencias del `plan`**: VPC → security groups → EKS control plane / RDS / Redis en paralelo → reglas de ingreso cruzadas (RDS/Redis from EKS) → OIDC provider → roles IRSA → addons. Terraform resolvió el grafo correctamente, sin `-target` ni ajustes manuales.
- **Tiempos de creación de los recursos "pesados"** (sin contar el problema de red de §2.2):
  - Redis (`aws_elasticache_replication_group`): 5m51s
  - RDS PostgreSQL (`aws_db_instance`): 6m30s
  - EKS control plane (`aws_eks_cluster`): 7m24s
- **Roles IRSA y policy attachments** (Velero, VPC CNI, EBS CSI, ALB Controller, External Secrets): todos se crearon en 0-1s cada uno, sin fricción, en cuanto el OIDC provider estuvo listo.
- **Variables requeridas sin default** (`eks_kubernetes_version`, `eks_cluster_endpoint_public_access_cidrs` en ese momento, `eks_node_instance_types`, `rds_engine_version`, `redis_engine_version`): el `plan` falló de forma clara y explícita pidiéndolas, sin sorpresas a mitad de `apply`.

### 2.2 🔴 Node group de EKS colgado indefinidamente por falta de NAT Gateway — **✅ corregido**

**Síntoma:** `module.eks.aws_eks_node_group.default` se quedó en `Still creating...` más de 16 minutos sin completar ni fallar explícitamente.

**Causa raíz:** `terraform.tfvars` tenía `enable_nat_gateway = false` (para evitar el costo de NAT en dev). Las subnets **privadas**, donde el node group lanza las instancias EC2, solo tenían la ruta local (`10.20.0.0/16`) — sin ruta `0.0.0.0/0` hacia ningún NAT Gateway ni VPC Endpoint. Los nodos EC2 no podían descargar las imágenes de kubelet/CNI ni registrarse contra el cluster.

**Diagnóstico en el momento:**
```bash
aws eks describe-nodegroup --cluster-name atlas-commerce-dev --nodegroup-name default \
  --query 'nodegroup.resources.autoScalingGroups[0].name'
# → None (el ASG nunca se creó con instancias)

aws ec2 describe-nat-gateways --filter "Name=tag:Project,Values=atlas-commerce"
# → [] (no hay NAT Gateway)

aws ec2 describe-route-tables --filters "Name=tag:Project,Values=atlas-commerce"
# → la route table de subnets privadas solo tiene la ruta local, sin 0.0.0.0/0
```

**Acción tomada en el momento:**
1. Se interrumpió el `apply` en curso.
2. Quedó un **lockfile S3 huérfano** (`terraform.tfstate.tflock`) — se liberó con `terraform force-unlock -force <lock-id>` (lock legítimo del propio proceso interrumpido).
3. Quedó un **node group huérfano en AWS** (fuera del state de Terraform, en `CREATING`, sin instancias EC2 reales) — se eliminó manualmente con `aws eks delete-nodegroup` antes de re-aplicar, para evitar un conflicto "ya existe".
4. Se cambió `enable_nat_gateway = false` → `true` en `terraform.tfvars`.
5. Se re-`plan`+`apply`: NAT Gateway, EIP y rutas privadas creadas; el node group completó esta vez en **2m44s** (vs. >16 min colgado sin red), confirmando el diagnóstico.

**Fix estructural aplicado después (mismo día, ver §3):** el *default* de `enable_nat_gateway` en `variables.tf` también se cambió de `false` a `true`, para que cualquier ambiente nuevo creado desde este mismo código no repita el mismo colgado por partir del mismo default inseguro.

**Costo del fix:** NAT Gateway ≈ $0.045/hora (~$32/mes) + procesamiento de datos. Necesario, no opcional, mientras el node group EKS viva en subnets privadas sin otra ruta de salida.

### 2.3 🔴 ARN incorrecto para la política gestionada de EBS CSI driver — **✅ corregido**

**Síntoma:** tras resolver NAT, el `apply` avanzó hasta crear el node group y los addons `coredns`/`kube-proxy`, pero falló en el addon `ebs_csi`:
```
Error: attaching IAM Policy (arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicyV2)
to IAM Role (atlas-commerce-dev-ebs-csi-role): operation error IAM: AttachRolePolicy,
https response error StatusCode: 404, NoSuchEntity: Policy ... does not exist or is not attachable.
```

**Causa raíz:** `modules/aws/eks/ebs-csi.tf` usaba un path de ARN incorrecto. La política `AmazonEBSCSIDriverPolicyV2` vive en el path raíz `/policy/`, no en `/policy/service-role/` (a diferencia de la versión anterior `AmazonEBSCSIDriverPolicy`, sin `V2`, que sí usa `service-role/`). Fácil de confundir porque ambas variantes conviven en AWS con paths distintos.

**Diagnóstico en el momento:**
```bash
aws iam list-policies --scope AWS --query "Policies[?contains(PolicyName, 'EBSCSI')].{Name:PolicyName,Arn:Arn}"
# → arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2   (sin service-role/)
```

**Fix inmediato aplicado en el momento:** se corrigió el path a mano y se re-aplicó (`2 added`: el policy attachment y el addon `ebs_csi`). Apply completo: **74 recursos en el state, sin errores.**

**Fix estructural aplicado después (mismo día, ver §3):** en vez de dejar el ARN corregido "a mano" (que puede volver a romperse con la próxima política que alguien agregue), se reemplazaron los 6 ARNs de políticas AWS-managed hardcodeados en el módulo EKS (`iam.tf`, `irsa.tf`, `ebs-csi.tf`) por `data "aws_iam_policy"` — Terraform resuelve el ARN real buscando por **nombre**, eliminando la necesidad de adivinar el path. Verificado con `terraform plan` contra el ambiente ya desplegado: `No changes` — el ARN resuelto es idéntico al ya aplicado.

**Nota operativa:** el `apply` se había ejecutado como `terraform apply tfplan 2>&1 | tee log.txt` sin `set -o pipefail`, así que el exit code del comando fue el de `tee` (0), no el de `terraform apply` (el que realmente falló). El error se detectó por un monitor de log en paralelo, no por el exit code — casi pasa desapercibido. **✅ corregido después:** los scripts `scripts/aws/create-dev-now.sh` y `scripts/aws/destroy-dev-now.sh` ya declaran `set -euo pipefail` y corren `terraform` directamente (sin envolverlo en `| tee`), así que el exit code que se propaga es el de Terraform.

### 2.4 Estado al cierre del despliegue

**`terraform apply` finalizado sin errores.** 74 recursos en el state de `live/aws/dev`. Confirmado con `terraform plan` posterior: `No changes. Your infrastructure matches the configuration.`

| Componente | Estado |
|---|---|
| VPC + subnets (2 AZ) + NAT Gateway | ✅ |
| Security groups (ALB, EKS nodes, RDS, Redis) | ✅ |
| EKS cluster (control plane, v1.35) | ✅ ACTIVE |
| EKS node group (2× t3.medium) | ✅ ACTIVE |
| Addons: VPC CNI, CoreDNS, kube-proxy, EBS CSI | ✅ |
| Roles IRSA: Velero, ALB Controller, External Secrets, EBS CSI, VPC CNI | ✅ |
| RDS PostgreSQL 17.10 | ✅ |
| ElastiCache Redis 7.1 (primary + replica) | ✅ |
| Secrets Manager (`atlas-commerce/dev/platform`) | ✅ |
| Velero backup bucket (S3) | ✅ |

**Outputs clave:**
- `vpc_id`: `vpc-07d002536499af346`
- `rds_postgresql_address`: `atlas-commerce-dev-postgresql.clcswuoaik89.eu-central-1.rds.amazonaws.com`
- `redis_primary_endpoint`: `master.atlas-commerce-dev-redis.yxbmzd.euc1.cache.amazonaws.com`
- `platform_secret_arn`: `arn:aws:secretsmanager:eu-central-1:724772086459:secret:atlas-commerce/dev/platform-Tdz7fs`

---

## 3. Hardening posterior contra valores hardcodeados

Con `dev` ya desplegado y funcional, se revisó el código en busca de valores escritos a mano que no sobrevivirían a un segundo despliegue (otra cuenta AWS, otra máquina, otro ambiente) sin edición manual.

### 3.1 🔴 6 ARNs de políticas AWS-managed hardcodeados en el módulo EKS — **✅ corregido**

Ver detalle en §2.3. `modules/aws/eks/iam.tf`, `irsa.tf`, `ebs-csi.tf`: los 6 `policy_arn = "arn:aws:iam::aws:policy/..."` se reemplazaron por `data "aws_iam_policy" { name = "..." }` + `.arn`. Esto es lo que el bug de §2.3 realmente era: el path exacto de una política AWS-managed (`service-role/` o raíz) no es adivinable desde el nombre solo, y resolverlo por nombre elimina la clase de error completa, no solo la instancia que ya falló.

### 3.2 🔴 Bucket de estado hardcodeado a mano en cada `backend.hcl` — **✅ mitigado** (no 100% eliminable)

Ver detalle en §1.4. Se generó `backend_config_template` parametrizable y se documentó el comando de generación sin transcripción manual. El valor del account ID sigue apareciendo como texto literal en `backend.hcl` — es una limitación real de Terraform (los bloques `backend` no admiten interpolación), no un descuido de código.

### 3.3 🔴 IP pública del operador hardcodeada en `terraform.tfvars` — **✅ corregido**

**Diagnóstico:** `eks_cluster_endpoint_public_access_cidrs = ["190.46.102.227/32"]` era la IP pública del usuario en el momento del despliegue original. Cambia con la red (otra oficina, VPN, ISP con IP dinámica) y dejaría al operador sin acceso al endpoint público de la API de EKS hasta que alguien la actualizara a mano.

**Fix aplicado:**
- `eks_cluster_endpoint_public_access_cidrs` (en `eks-variables.tf`) ahora tiene `default = []`.
- Se agregó `data "http" "operator_public_ip"` en `locals.tf`, que solo se evalúa (`count`) cuando la variable queda vacía, consultando `https://checkip.amazonaws.com`.
- Un nuevo `local.eks_cluster_endpoint_public_access_cidrs` resuelve: valor explícito de la variable si se definió, o `["<ip-detectada>/32"]` si no.
- `eks.tf` y `terraform.tfvars` actualizados para usar el local en vez del valor fijo.
- Se agregó el provider `hashicorp/http` (`~> 3.4`) a `versions.tf`.

**Trade-off aceptado explícitamente:** esto acopla `terraform plan`/`apply` a que `checkip.amazonaws.com` esté disponible — si esa API cae, hasta un `plan` de solo lectura fallaría. Se prefirió esta opción sobre dejarlo documentado-pero-manual porque el riesgo real (nadie actualiza la IP a mano y se queda sin acceso) es más probable que el riesgo teórico (esa API específica de AWS caída). Para evitar la dependencia de red, fijar `eks_cluster_endpoint_public_access_cidrs` explícitamente en `terraform.tfvars` sigue siendo una opción soportada.

**Verificado:** `terraform init -upgrade` instaló el provider `http` sin errores; `terraform plan` con la auto-detección activa devolvió `No changes` — la IP detectada coincidió con la ya aplicada.

### 3.4 🟡 READMEs desactualizados — **✅ corregido**

- `bootstrap/aws-backend/README.md`: mencionaba la tabla DynamoDB ya eliminada (§1.2) y no documentaba el flujo de generación de `backend.hcl` (§1.4/§3.2). Actualizado.
- `live/aws/dev/README.md`: describía "No NAT Gateway by default" y una sección de Cost Safety que ya no reflejaban el default corregido en §2.2. Actualizado.

### 3.5 🟢 Regla hacia adelante — políticas IAM custom del proyecto

No es un hardcode existente, sino una regla a aplicar en cambios futuros: si se agregan políticas IAM **propias** del proyecto (no AWS-managed) al módulo EKS u otros, no copiar el ARN resultante a mano — referenciar el recurso Terraform directamente (`aws_iam_policy.foo.arn`), igual que ya se hace en varias partes del código.

### 3.6 🔲 Pendiente — guardarraíl para NAT Gateway deshabilitado con EKS en subnets privadas

`enable_nat_gateway` ahora defaultea a `true` (§2.2), lo que evita el problema por omisión. No se implementó una validación explícita que falle rápido en `terraform plan` si alguien lo pone en `false` de todas formas con un node group EKS en subnets privadas — hoy, si se hiciera, el fallo seguiría apareciendo ~15-30 minutos después, a mitad de `apply`. Ejemplo de implementación si se decide agregarla:

```hcl
variable "enable_nat_gateway" {
  type    = bool
  default = true

  validation {
    condition     = var.enable_nat_gateway == true
    error_message = "EKS node groups run in private subnets and require NAT Gateway for outbound access. Disabling this will hang terraform apply for 15-30 minutes before failing."
  }
}
```

### 3.7 🔴 `live/aws/shared/backend.hcl` apuntaba a la cuenta AWS ajena — **✅ corregido**

Detectado durante la revisión de §1.4, fuera del alcance original de esta bitácora (el foco fue `dev`): `platform/terraform/live/aws/shared/backend.hcl` tenía `bucket = "atlas-commerce-shared-tfstate-529601496188-eu-central-1"` — la misma cuenta ajena (529601496188) que `dev` tenía antes de corregirse.

**Fix aplicado:** se corrigió el `bucket` a la cuenta real del usuario (`724772086459`) y se dejó el archivo con el mismo formato comentado que `live/aws/dev/backend.hcl`. Coincide con el valor que produce el comando de generación de §1.4 (`terraform output -raw backend_config_template | sed 's#<ENV>#shared#'`). Aún no se ha ejecutado `terraform init` contra este backend porque el ambiente `shared` todavía no se despliega.

### 3.8 🔲 Pendiente — VPC Endpoints como alternativa a NAT Gateway

Si en el futuro el costo de NAT Gateway en `dev` (~$32/mes) se vuelve una preocupación real, una alternativa más barata es usar VPC Endpoints de tipo Gateway/Interface para `s3`, `ecr.api`, `ecr.dkr`, `eks`, `logs`, en vez de NAT completo. No implementado ni evaluado en profundidad — no cubre el 100% de lo que un nodo pueda necesitar (cualquier salida a internet genérica seguiría fallando), así que no reemplaza a NAT sin análisis adicional.

### 3.9 🟡 `.terraform.lock.hcl` de `bootstrap/aws-backend` no commiteado — **✅ corregido después**

Detectado en una revisión previa del bootstrap (2026-06-22, antes de este ciclo de despliegue): el dependency lock file fija versiones y hashes exactos de providers (distinto del state lock y del lockfile de S3); sin commitearlo, cada `terraform init` puede resolver una versión de provider distinta dentro de `~> 5.0`, reintroduciendo el "en mi máquina funciona".

**Estado actual (verificado en este ciclo):** ya no aplica. El `.gitignore` actual no ignora `.terraform.lock.hcl`, y los tres lock files están trackeados en git: `bootstrap/aws-backend`, `live/aws/dev` y `live/aws/shared`. `git check-ignore` no marca ninguno como ignorado.

**Recomendación hacia adelante:** para equipos multi-OS, considerar `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 ...` para incluir los hashes de todas las plataformas relevantes en cada lock file.

### 3.10 🟢 Ya validado — seguridad del bucket de estado (S3), sin cambios necesarios

Confirmado durante la revisión previa del bootstrap y no alterado por ningún fix de este ciclo — los cinco controles que importan para un bucket de state de Terraform (que contiene secretos en texto plano: contraseñas de RDS, tokens, etc.) están todos presentes en `bootstrap/aws-backend/main.tf`:

1. `aws_s3_bucket_public_access_block` con los 4 flags en `true`.
2. `aws_s3_bucket_ownership_controls` con `object_ownership = "BucketOwnerEnforced"` (ACLs desactivadas).
3. `aws_s3_bucket_versioning` = `Enabled` (recuperación ante corrupción o apply destructivo).
4. `aws_s3_bucket_server_side_encryption_configuration` = `AES256` (SSE-S3).
5. Bucket policy `DenyInsecureTransport` — deniega `s3:*` cuando `aws:SecureTransport = false`, forzando HTTPS/TLS.

Además: lifecycle rule que expira versiones non-current a 90 días (evita crecimiento indefinido del bucket), y `default_tags` en el provider para tags consistentes en todos los recursos.

### 3.11 🟢 Opcional, no urgente — hardening adicional del bucket de estado

Dos mejoras opcionales identificadas, ninguna aplicada porque no son necesarias para el caso de uso actual:

- **Defensa en profundidad en la bucket policy:** añadir (no reemplazar) una condición `aws:PrincipalAccount` a `DenyInsecureTransport` para limitar el acceso a la propia cuenta. Requiere probarse con cuidado para no bloquear a Terraform ni a servicios legítimos cross-account si los hubiera.
- **SSE-KMS en vez de SSE-S3:** el roadmap original mencionaba "KMS key opcional"; la implementación usa `AES256`. Para state de Terraform, SSE-S3 es perfectamente aceptable — SSE-KMS solo aporta control de acceso por clave (denegar `kms:Decrypt` a quien no deba leer el estado) a costa de complejidad y coste por petición.

---

## 4. Destroy del ambiente

Tras validar el despliegue y aplicar el hardening de la Sección 3, el ambiente `dev` completo se destruyó intencionalmente el mismo día (no fue un fallo): `terraform destroy` sobre `live/aws/dev`, confirmado con `terraform plan -destroy` antes de aplicar (60 recursos a eliminar, 0 a mantener).

**Resultado:** `Apply complete! Resources: 0 added, 0 changed, 60 destroyed.` Sin errores. Orden de destrucción resuelto correctamente por Terraform en sentido inverso a la creación (policies/configs superficiales → RDS/Redis/node group en paralelo → EKS cluster → subnets/VPC). Tiempos notables: RDS 1m54s, node group 2m20s, Redis 4m21s, EKS cluster 3m4s. `terraform state list` confirmado vacío después.

**Costo estimado del ciclo completo** (creación + ~20 min a full capacidad + destroy, precios de lista, no factura real — Cost Explorer no estaba habilitado en la cuenta durante el despliegue): por debajo de $1 USD, dominado por las ~4 horas que el control plane de EKS estuvo activo ($0.10/hora es un cargo fijo independiente de si hay nodos).

---

## 5. Siguiente fase (no iniciada)

El ambiente `dev` fue destruido (§4) tras esta validación — lo siguiente aplica para cuando se vuelva a desplegar. Fuera del alcance de Terraform, según el README raíz del repo ("Terraform aprovisiona infra; Helm despliega las apps"):

- Conectar `kubectl` al cluster: `aws eks update-kubeconfig --name atlas-commerce-dev --region eu-central-1 --profile atlas-commerce`.
- Desplegar Helm charts de las aplicaciones.
- Configurar ALB Controller y External Secrets Operator dentro del cluster, usando los roles IRSA ya creados por este despliegue.
- Resolver los pendientes de §3.6-§3.8 antes de replicar este patrón a `staging`/`prod`.
