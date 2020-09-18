terraform {
  required_version = ">= 0.12"

  required_providers {
    aws        = ">= 3.5"
    random     = ">= 2.3"
    template   = ">= 2.1"
    tls        = ">= 2.2"
  }
}
