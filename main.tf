provider "azurerm" {
  features {}
  # export ARM_SUBSCRIPTION_ID env variable to avoid hardcoding the subscription_id here
}

variable "prefix" {
  type = string
}

variable "location" {
  type = string
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = "${var.prefix}-rg"
}

resource "azurerm_key_vault" "kv" {
  name                = "${var.prefix}-kv"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}

resource "azurerm_data_factory" "data-factory-test-v1" {
  location               = var.location
  name                   = "${var.prefix}-df"
  public_network_enabled = true
  resource_group_name    = azurerm_resource_group.rg.name

  identity {
    identity_ids = []
    type         = "SystemAssigned"
  }
}

resource "azurerm_data_factory_linked_service_key_vault" "key-vault-dev" {
  data_factory_id = azurerm_data_factory.data-factory-test-v1.id
  name            = "AzureKeyVault1"
  parameters      = {}
  key_vault_id    = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_data_factory.data-factory-test-v1
  ]
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "blob-storage" {
  connection_string    = "DefaultEndpointsProtocol=https;AccountName=storageAccount;"
  data_factory_id      = azurerm_data_factory.data-factory-test-v1.id
  name                 = "AzureBlobStorage1"
  parameters           = {}
  use_managed_identity = true

  service_principal_linked_key_vault_key {
    linked_service_name = azurerm_data_factory_linked_service_key_vault.key-vault-dev.name
    secret_name         = "storage-key"
  }

  depends_on = [
    azurerm_data_factory.data-factory-test-v1,
    azurerm_data_factory_linked_service_key_vault.key-vault-dev
  ]
}
