# Tienda de Alimentos para Perritos 🐶

Pipeline CI/CD con GitHub Actions y AWS (Frontend + Backend + MySQL en contenedores Docker).

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC 10.0.0.0/16                      │
│                                                              │
│  ┌──────────── Subnet Pública 10.0.1.0/24 ──────────────┐  │
│  │  NAT Instance (t2.micro)     Frontend EC2 (Nginx:80)  │  │
│  └───────────────────────────────────────────────────────┘  │
│                          │                                   │
│  ┌──────────── Subnet Privada 10.0.2.0/24 ──────────────┐  │
│  │  Backend EC2 (Node:3001)       DB EC2 (MySQL:3306)    │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Estructura del Proyecto

```
├── backend/          # API Express + MySQL
├── frontend/         # HTML/JS + Nginx (proxy reverso)
├── db/               # MySQL 8 con datos iniciales
├── workflows/        # GitHub Actions CI/CD (copiar a .github/workflows/)
└── terraform/        # Infraestructura como código
    ├── modules/
    │   ├── ec2/              # Módulo reutilizable EC2
    │   └── security-group/   # Módulo reutilizable SG
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars.example
```

---

## Paso a Paso Completo

### PASO 1: Levantar la infraestructura con Terraform

#### 1.1 Prerrequisitos

- Terraform >= 1.5 instalado
- AWS CLI configurado con credenciales (o variables de entorno)
- Conocer tu IP pública (buscar "what is my ip" en Google)

#### 1.2 Configurar variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Editar `terraform.tfvars` con tus valores:

```hcl
aws_region           = "us-east-1"
my_ip                = "TU_IP_PUBLICA/32"    # Ej: 190.45.67.89/32
ssm_instance_profile = "LabInstanceProfile"  # El perfil IAM de tu lab
```

#### 1.3 Desplegar

```bash
terraform init
terraform plan
terraform apply
```

#### 1.4 Anotar los outputs

Terraform mostrará:
- `frontend_public_ip` → IP para abrir la app en el navegador
- `frontend_instance_id` → Para secret `EC2_FRONTEND_INSTANCE_ID`
- `backend_instance_id` → Para secret `EC2_BACKEND_INSTANCE_ID`
- `backend_private_ip` → Para configurar `proxy_pass` en nginx
- `db_instance_id` → Para secret `EC2_DB_INSTANCE_ID`
- `db_private_ip` → Para configurar `DB_HOST` en el backend

---

### PASO 2: Crear repositorios ECR

```bash
aws ecr create-repository --repository-name tienda-frontend --region us-east-1
aws ecr create-repository --repository-name tienda-backend --region us-east-1
aws ecr create-repository --repository-name tienda-db --region us-east-1
```

Anotar las URIs de cada repositorio (formato: `123456789012.dkr.ecr.us-east-1.amazonaws.com/tienda-frontend`).

---

### PASO 3: Preparar el repositorio en GitHub

#### 3.1 Crear repo y subir código

```bash
git init
git add .
git commit -m "Proyecto tienda perritos - estructura inicial"
git remote add origin https://github.com/TU_USUARIO/tienda-perritos.git
git push -u origin main
```

#### 3.2 Crear los workflows

Copiar los archivos de `workflows/` a `.github/workflows/`:

```bash
mkdir -p .github/workflows
cp workflows/*.yml .github/workflows/
git add .github/workflows
git commit -m "Agregar workflows CI/CD"
git push
```

---

### PASO 4: Configurar secretos en GitHub

Ir a **Settings → Secrets and variables → Actions** y crear:

| Secret | Valor |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Tu Access Key |
| `AWS_SECRET_ACCESS_KEY` | Tu Secret Key |
| `AWS_SESSION_TOKEN` | Token de sesión (si usas lab) |
| `AWS_REGION` | `us-east-1` |
| `ECR_REGISTRY` | `123456789012.dkr.ecr.us-east-1.amazonaws.com` |
| `ECR_REPO_URL_FRONTEND` | URI completa del repo ECR frontend |
| `ECR_REPO_URL_BACKEND` | URI completa del repo ECR backend |
| `ECR_REPO_URL_DB` | URI completa del repo ECR db |
| `EC2_FRONTEND_INSTANCE_ID` | Output de Terraform |
| `EC2_BACKEND_INSTANCE_ID` | Output de Terraform |
| `EC2_DB_INSTANCE_ID` | Output de Terraform |

---

### PASO 5: Actualizar IPs en el código

Con los outputs de Terraform, actualizar:

1. **`frontend/default.conf`** → Cambiar `proxy_pass` con la IP privada del backend:
   ```nginx
   proxy_pass http://<BACKEND_PRIVATE_IP>:3001;
   ```

2. **`backend/server.js`** → Cambiar `DB_HOST` con la IP privada de la DB:
   ```javascript
   DB_HOST = "10.0.2.xxx", // IP privada de la EC2 DB
   ```

Hacer commit y push:
```bash
git add .
git commit -m "Actualizar IPs de infraestructura"
git push
```

---

### PASO 6: Ejecutar y validar el pipeline

Al hacer push, los 3 workflows se ejecutarán automáticamente (uno por cada carpeta modificada).

Verificar en la pestaña **Actions** de GitHub que:
- Build ✅
- Push a ECR ✅
- Deploy vía SSM ✅

---

### PASO 7: Validar el despliegue en AWS

#### Verificar contenedores corriendo (vía SSM o SSH a la NAT):

```bash
# En cada EC2:
docker ps
```

#### Verificar la base de datos:

```bash
sudo docker exec -it tienda-db mysql -u root -padmin123 -e \
  "USE tienda_perritos; SELECT * FROM productos;"
```

#### Verificar la aplicación:

Abrir en el navegador: `http://<FRONTEND_PUBLIC_IP>`

- ✅ La app carga
- ✅ El backend responde
- ✅ Los productos de la BD se muestran correctamente

---

### PASO 8: Probar el pipeline con un cambio

Modificar algo simple para disparar el pipeline:

```bash
# Ejemplo: cambiar título del frontend
sed -i 's/Tienda de Alimentos/Tienda Premium de Alimentos/' frontend/index.html

git add .
git commit -m "Actualizar título del frontend"
git push
```

Observar en Actions cómo se ejecuta solo el pipeline del frontend.

---

## Evidencia requerida (PPT)

1. Captura del repositorio GitHub y estructura del proyecto
2. Capturas de los workflows ejecutados correctamente (pestaña Actions)
3. Evidencia de secrets configurados (sin mostrar valores)
4. Capturas de Amazon ECR mostrando imágenes publicadas
5. Capturas de logs del pipeline (build, push, deploy)
6. Evidencia de contenedores corriendo en EC2 (`docker ps`)
7. Captura de la aplicación funcionando en el navegador
8. Breve explicación del flujo CI/CD completo

---

## Explicación del flujo CI/CD

1. El desarrollador hace `git push` a la rama `main`
2. GitHub Actions detecta cambios en la carpeta correspondiente (frontend/backend/db)
3. El workflow se ejecuta: checkout → configura AWS → login ECR → build Docker → push imagen
4. Mediante AWS SSM, se envía un comando a la EC2 correspondiente
5. La EC2 hace pull de la nueva imagen desde ECR, detiene el contenedor viejo y levanta uno nuevo
6. La aplicación se actualiza sin intervención manual

---

## Destruir infraestructura

```bash
cd terraform
terraform destroy
```
