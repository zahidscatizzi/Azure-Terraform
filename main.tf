# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.20.0"
    }
  }

  required_version = ">= 1.3.7"
}

provider "azurerm" {
  features {}
}
resource "azurerm_resource_group" "AzureCloud" {
  name     = "Azure-Cloud"
  location = "eastus"
}

# Red Virtual
resource "azurerm_virtual_network" "vnet" {
  name                = "Virtual-Network"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.AzureCloud.name
  location            = azurerm_resource_group.AzureCloud.location
}

# SubNet Servidores
resource "azurerm_subnet" "snet" {
  name                 = "Subnet"
  address_prefixes     = ["10.0.1.0/24"]
  resource_group_name  = azurerm_resource_group.AzureCloud.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

# IP Publica Drupal
resource "azurerm_public_ip" "ip-drupal" {
  name                = "Public-IP-Drupal"
  allocation_method   = "Static"
  domain_name_label   = "drupal-server"
  resource_group_name = azurerm_resource_group.AzureCloud.name
  location            = azurerm_resource_group.AzureCloud.location
}

# IP Publica Moodle
resource "azurerm_public_ip" "ip-moodle" {
  name                = "Public-IP-Moodle"
  allocation_method   = "Static"
  domain_name_label   = "moodle-server"
  resource_group_name = azurerm_resource_group.AzureCloud.name
  location            = azurerm_resource_group.AzureCloud.location
}

# Interfaz de Red Drupal
resource "azurerm_network_interface" "net-drupal" {
  name                = "Network-Interface-Drupal"
  resource_group_name = azurerm_resource_group.AzureCloud.name
  location            = azurerm_resource_group.AzureCloud.location

  ip_configuration {
    name                          = "IP-Configuration-Drupal"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-drupal.id
  }
}

# Interfaz de Red Moodle
resource "azurerm_network_interface" "net-moodle" {
  name                = "Network-Interface-Moodle"
  resource_group_name = azurerm_resource_group.AzureCloud.name
  location            = azurerm_resource_group.AzureCloud.location

  ip_configuration {
    name                          = "IP-Configuration-Moodle"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-moodle.id
  }
}

# Subnet Base de Datos
resource "azurerm_subnet" "snetdb" {
  name                 = "SubnetDB"
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  resource_group_name  = azurerm_resource_group.AzureCloud.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Zona Privada DNS DataBase
resource "azurerm_private_dns_zone" "privatednsdb" {
  name                = "azurecloud.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.AzureCloud.name
}

# Link hacia la Virtual Network desde Zona Privada DNS
resource "azurerm_private_dns_zone_virtual_network_link" "dnsvnet" {
  name                  = "postgres-server"
  private_dns_zone_name = azurerm_private_dns_zone.privatednsdb.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.AzureCloud.name
}

# Servidor de Base de Datos
resource "azurerm_postgresql_flexible_server" "postgres-fs" {
  name                   = "postgres-fs"
  version                = "14"
  administrator_login    = "postgresadmin"
  administrator_password = "Admin123!"
  zone                   = "1"
  delegated_subnet_id    = azurerm_subnet.snetdb.id
  private_dns_zone_id    = azurerm_private_dns_zone.privatednsdb.id
  resource_group_name    = azurerm_resource_group.AzureCloud.name
  location               = azurerm_resource_group.AzureCloud.location
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
  depends_on             = [azurerm_private_dns_zone_virtual_network_link.dnsvnet]
}

# Creacion de base de datos Drupal
resource "azurerm_postgresql_flexible_server_database" "drupal-db" {
  name      = "drupal"
  server_id = azurerm_postgresql_flexible_server.postgres-fs.id
  collation = "en_US.UTF8"
  charset   = "UTF8"
}

#Creacion de base de datos Moodle
resource "azurerm_postgresql_flexible_server_database" "moodle-db" {
  name      = "moodle"
  server_id = azurerm_postgresql_flexible_server.postgres-fs.id
  collation = "en_US.UTF8"
  charset   = "UTF8"
}

# Reglas de Seguridad
resource "azurerm_network_security_group" "network-sg" {
  name                = "Network-Security-Group"
  resource_group_name = azurerm_resource_group.AzureCloud.name
  location            = azurerm_resource_group.AzureCloud.location
  # Acceso SSH
  security_rule {
    name                       = "Acceso-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # Acceso a Base de Datos
  security_rule {
    name                       = "Acceso-DB"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }
  #Acceso CMS y LMS
  security_rule {
    name                       = "Acceso-CMS-LMS"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Asociacion al Grupo de Seguridad Servidores
resource "azurerm_subnet_network_security_group_association" "servers-sg" {
  subnet_id                 = azurerm_subnet.snet.id
  network_security_group_id = azurerm_network_security_group.network-sg.id
}

# Asociacion al Grupo de Seguridad Servidor de Base de Datos
resource "azurerm_subnet_network_security_group_association" "database-sg" {
  subnet_id                 = azurerm_subnet.snetdb.id
  network_security_group_id = azurerm_network_security_group.network-sg.id
}

# Variable para el directorio de clave privada
variable "private_key_path" {
  default = "~/your/private/path"
}

# Maquina Virtual Drupal
resource "azurerm_linux_virtual_machine" "drupal-vm" {
  name                            = "Drupal-Machine"
  size                            = "Standard_B1s"
  admin_username                  = "adminDrupal"
  admin_password                  = "Admin123!"
  network_interface_ids           = [azurerm_network_interface.net-drupal.id]
  resource_group_name             = azurerm_resource_group.AzureCloud.name
  location                        = azurerm_resource_group.AzureCloud.location
  disable_password_authentication = false
  # Configuración del sistema operativo
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  # Conexion Clave Privada
  connection {
    type        = "ssh"
    user        = "adminWordpress"
    password    = "Admin123!"
    private_key = file(var.private_key_path)
    host        = azurerm_network_interface.net-drupal.private_ip_address
  }
}

# Maquina Virtual Moodle
resource "azurerm_linux_virtual_machine" "moodle-vm" {
  name                            = "Moodle-Machine"
  size                            = "Standard_B1s"
  admin_username                  = "adminMoodle"
  admin_password                  = "Admin123!"
  network_interface_ids           = [azurerm_network_interface.net-moodle.id]
  resource_group_name             = azurerm_resource_group.AzureCloud.name
  location                        = azurerm_resource_group.AzureCloud.location
  disable_password_authentication = false
  # Configuración del sistema operativo
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  # Conexion Clave Privada
  connection {
    type        = "ssh"
    user        = "adminMoodle"
    password    = "Admin123!"
    private_key = file(var.private_key_path)
    host        = azurerm_network_interface.net-moodle.private_ip_address
  }
}

# Alertas Uso de CPU
resource "azurerm_monitor_action_group" "mag" {
  name                = "Action-Group"
  resource_group_name = azurerm_resource_group.AzureCloud.name
  short_name          = "actiongroup"
}

resource "azurerm_monitor_metric_alert" "alertacpu" {
  name                     = "AlertaCPU-Usage"
  resource_group_name      = azurerm_resource_group.AzureCloud.name
  target_resource_location = azurerm_resource_group.AzureCloud.location
  scopes                   = ["/subscriptions/<your subscription id>"]
  description              = "Alerta sobre el alto uso de CPU en maquinas virtuales"
  target_resource_type     = "Microsoft.Compute/virtualMachines"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 50
  }

  action {
    action_group_id = azurerm_monitor_action_group.mag.id
  }
}