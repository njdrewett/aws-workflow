# aws-workflow
aws terraform security workflow and CI

First setup a CI/CD role in terraform the github can use via workflow actions
in /setup: run terrafrom apply.

Make sure the generated iam_role_arn in the output is the user in the role_to_assume in the .github\workflows\terraform.yaml file
e.g. "iam_role_arn" = "arn:aws:iam::980308885448:role/github-actions-oidc20230321183457034600000001"

Commits to this repo will automatically perform and apply to AWS. 

