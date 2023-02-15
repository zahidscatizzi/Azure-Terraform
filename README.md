# Azure-Terraform
Archivo de configuración de Terraform que monta virtual networks, subnets, bases de datos y maquinas virtuales usadas como servidores de Drupal y Moodle.

Una vez que toda nuestra infraestructura esta funcionando debemos hacer los siguientes pasos:
1) Añadimos la siguiente extension a nuestro Servidore de base de datos.
```bash
az postgres flexible-server parameter set --resource-group Azure-Cloud  --server-name postgres-fs --subscription <your subscription id> --name azure.extensions --value PG_TGRM
```
2) Accedemos vía ssh a nuestras maquinas virtuales y realizamos un git-clone de los scripts de instalación.
```bash
git clone https://github.com/zahidscatizzi/Scripts.git
```
## Servidor Moodle
Otorgamos permiso al script para ejecutarlo.
```bash
sudo chmod 775 moodle.sh
./moodle.sh
```
 Una vez que se finalice de ejecutar el script, se abrirá el archivo `php.ini` y lo modificaremos. Buscaremos la linea:
```bash
;max_input_vars = 1000
max_input_vars = 10000
```
Accedemos a nuestro portal de instalación de moodle: [Instalación Moodle](http://moodle-server.eastus.cloudapp.azure.com/azuremoodle). 
## Servidor Drupal
Otorgamos permiso al script para ejecutarlo.
```bash
sudo chmod 775 drupal.sh
./drupal.sh
```
Creamos la siguiente extensión en nuestra base de datos.
```bash
CREATE EXTENSION pg_trgm;
```
Ahora que finalizo de ejecutarse el script, añadimos la siguientes lineas al archivo `drupal.conf`
```bash
Alias /drupal /var/www/html/azuredrupal
<Directory /var/www/html/azuredrupal>
        Require all granted
        AllowOverride All
</Directory>
```
Finalmente accedemos a nuestro portal de instalación de drupal: [Instalación Drupal](http://drupal-server.eastus.cloudapp.azure.com/azuredrupal).
