terraform {
  backend "gcs" {
    bucket = "<project-id>-tfstate"
    prefix = "env/dev"
  }
}
