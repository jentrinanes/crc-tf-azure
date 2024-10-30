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