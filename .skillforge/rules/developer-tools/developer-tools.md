This repo uses developer-tools which is a shared local-and-CI toolchain used to build, scan, publish, package, and deploy projects with consistent conventions.

The env var `DEV_TOOLS_HOME` should point to the documentation and source code of developer-tools.

You can assume that the shell has been configured to have access to all developer-tools scripts and required env vars.

The product-id of this repo can be obtained using the `whats-the-product-id.sh` script. If the script does not work, ask the user for the product-id.

The build scripts in this repo references reusable build scripts in developer-tools.

## GitLab repository

The remote GitLab repository for developer-tools is:
`git@gitlab.thalesdigital.io:ams/airlab-sg/common/components/developer-tools.git`

