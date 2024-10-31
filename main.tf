data "azurerm_client_config" "current" {}

# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.7.0"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

# Create the Resource Group
resource "azurerm_resource_group" "rg-cloud-resume-challenge" {
  name     = var.resource_group_name
  location = var.location
}

# Create the Storage Account 
resource "azurerm_storage_account" "sacrcjen" {
  name                     = "sacrcjen"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  network_rules {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
  static_website {
    index_document     = "index.html"
    error_404_document = "index.html"
  }
}

# Create CDN Endpoint
resource "azurerm_cdn_profile" "cdn-crc-jen" {
  name                = "cdn-crc-jen"
  location            = var.global-location
  resource_group_name = var.resource_group_name
  sku                 = "Standard_Microsoft"
}

resource "azurerm_cdn_endpoint" "cdncrcjen" {
  name                = "cdncrcjen"
  profile_name        = azurerm_cdn_profile.cdn-crc-jen.name
  location            = var.global-location
  resource_group_name = var.resource_group_name
  origin {
    name      = "default-origin-2e0b8c9c"
    host_name = "sacrcjen.z23.web.core.windows.net"
  }
}

# Create Custom Domain for a CDN Endpoint
data "azurerm_dns_zone" "resume-jtrinanes-com" {
  name                = "resume.jtrinanes.com"
  resource_group_name = var.resource_group_name
}

resource "azurerm_dns_cname_record" "resume-jtrinanes-com" {
  name                = "resume-jtrinanes-com"
  zone_name           = data.azurerm_dns_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  target_resource_id  = azurerm_cdn_endpoint.cdncrcjen.id
}

resource "azurerm_cdn_endpoint_custom_domain" "resume-jtrinanes-com" {
  name            = "resume-jtrinanes-com"
  cdn_endpoint_id = azurerm_cdn_endpoint.cdncrcjen.id
  host_name       = "${azurerm_dns_cname_record_resume-jtrinanes-com.name}.${data.azurerm_dns_zone.resume-jtrinanes-com.name}"
}

# Create Azure Cosmos DB Account
resource "azurerm_cosmosdb_account" "cosmosdbcrcjen" {
  name                             = "cosmosdbcrcjen"
  resource_group_name              = var.resource_group_name
  location                         = var.location
  offer_type                       = "Standard"
  kind                             = "GlobalDocumentDB"
  automatic_failover_enabled       = false
  multiple_write_locations_enabled = false
  capabilities {
    name = "EnableServerless"
  }
  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }
  geo_location {
    location          = var.location
    failover_priority = 0
  }
  analytical_storage {
    schema_type = "WellDefined"
  }
  capacity {
    total_throughput_limit = 4000
  }
  backup {
    type                = "Periodic"
    interval_in_minutes = 240
    retention_in_hours  = 8
    storage_redundancy  = "Local"
  }
}

# Create Azure Cosmos DB SQL Database
resource "azurerm_cosmosdb_sql_database" "cosmosdbcrcjendb" {
  name                = "VisitorCountDb"
  resource_group_name = var.resource_group_name
  account_name        = "${azurerm_cosmosdb_account.cosmosdbcrcjen.name}/VisitorCountDb"
}

# Configure SQL Role Definitions
resource "azurerm_cosmosdb_sql_role_definition" "sqlroledef1" {
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmosdbcrcjen.name
  role_definition_id  = "00000000-0000-0000-0000-000000000001"
  permissions {
    data_actions = [
      "Microsoft.DocumentDB/databaseAccounts/readMetadata",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read"
    ]
  }
  assignable_scopes = [
    "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.DocumentDB/databaseAccounts/${azurerm_cosmosdb_account.cosmosdbcrcjen.name}"
  ]
  name = "${azurerm_cosmosdb_account.cosmosdbcrcjen.name}/00000000-0000-0000-0000-000000000001"
}

resource "azurerm_cosmosdb_sql_role_definition" "sqlroledef2" {
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmosdbcrcjen.name
  role_definition_id  = "00000000-0000-0000-0000-000000000002"
  permissions {
    data_actions = [
      "Microsoft.DocumentDB/databaseAccounts/readMetadata",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*"
    ]
  }
  assignable_scopes = [
    "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.DocumentDB/databaseAccounts/${azurerm_cosmosdb_account.cosmosdbcrcjen.name}"
  ]
  name = "${azurerm_cosmosdb_account.cosmosdbcrcjen.name}/00000000-0000-0000-0000-000000000002"
}

# Create SQL Container
resource "azurerm_cosmosdb_sql_container" "cosmosdbcrcjencontainer" {
  name                = "${azurerm_cosmosdb_account.cosmosdbcrcjen.name}/${azurerm_cosmosdb_sql_database.cosmosdbcrcjendb.name}/VisitorCountContainer"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmosdbcrcjen.name
  database_name       = azurerm_cosmosdb_sql_database.cosmosdbcrcjendb.name
  partition_key_paths = [
    "/id"
  ]
  partition_key_kind    = "Hash"
  partition_key_version = 2
  conflict_resolution_policy {
    mode                     = "LastWriterWins"
    conflict_resolution_path = "/_ts"
  }
}

# Create Key Vault
resource "azurerm_key_vault" "keyvaultcrcjen" {
  name                      = "keyvaultcrcjen"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  sku_name                  = "standard"
  tenant_id                 = "${data.azurerm_client_config.current.tenant_id}"
  enable_rbac_authorization = true
  network_acls {
    bypass                     = "None"
    default_action             = "Allow"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}

resource "azurerm_key_vault_secret" "secret1" {
  name         = "${azurerm_key_vault.keyvaultcrcjen.name}/CosmosDbPrimaryKey"
  value        = "${azurerm_cosmosdb_account.cosmosdbcrcjen.primary_key}"
  key_vault_id = azurerm_key_vault.keyvaultcrcjen.id
}

resource "azurerm_key_vault_secret" "secret2" {
  name         = "${azurerm_key_vault.keyvaultcrcjen.name}/CosmosDbUri"
  value        = "${azurerm_cosmosdb_account.cosmosdbcrcjen.endpoint}"
  key_vault_id = azurerm_key_vault.keyvaultcrcjen.id
}