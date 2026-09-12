provider "azurerm" {
  features {
  }
  environment                     = "public"
  use_msi                         = false
  use_cli                         = true
  use_oidc                        = false
  resource_provider_registrations = "none"
  subscription_id                 = "2213e8b1-dbc7-4d54-8aff-b5e315df5e5b"
}
