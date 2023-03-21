
module "oidc_provider" {
  
  source = "../modules/oidc-provider"

  allowed_repos_branches = [
    { 
      org = "njdrewett"
      repo = "aws-workflow"
      branch = "main"
    }
  ]
}
