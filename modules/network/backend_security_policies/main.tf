locals {

  cr_rule_priority_60  = "request.path.matches('^.*/.env$')"
  cr_rule_priority_80  = "request.headers['host'].lower().contains('robothouse')"
  cr_rule_priority_100 = "has(request.headers['authorization']) && request.headers['authorization'] != \"\""

  cr_rule_priority_60_desc  = "Deny when request path ends with /.env"
  cr_rule_priority_80_desc  = "Allow when 'Host' header contains robothouse"
  cr_rule_priority_100_desc = "Allow when 'Authorization' header is present and not empty"
}

resource "google_compute_security_policy" "cr_backend_security_policy" {

  name    = "cr-backend-security-policy"
  project = var.project_id

  rule {
    action      = "deny(403)"
    priority    = "60"
    match {
      expr {
        expression = local.cr_rule_priority_60
      }
    }
    description = local.cr_rule_priority_60_desc
  }
  rule {
    action      = "allow"
    priority    = "80"
    match {
      expr {
        expression = local.cr_rule_priority_80
      }
    }
    description = local.cr_rule_priority_80_desc
  }
  rule {
    action      = "allow"
    priority    = "100"
    match {
      expr {
        expression = local.cr_rule_priority_100
      }
    }
    description = local.cr_rule_priority_100_desc
  }

  rule {
    action      = "deny(403)"
    priority    = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule, higher priority overrides it"
  }
}
