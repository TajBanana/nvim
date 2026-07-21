If writing a new Gitlab CI pipeline definition file `.gitlab-ci.yml`, reuse the scripts and pipeline definition
available in the common Gitlab CI pipeline include repository
`git@gitlab.thalesdigital.io:ams/airlab-sg/common/components/devtools-gitlab-includes.git`.

If there is an existing Gitlab CI pipeline definition file, reference to project
`ams/airlab-sg/common/components/devtools-gitlab-includes` can be resolved to the same repository
`git@gitlab.thalesdigital.io:ams/airlab-sg/common/components/devtools-gitlab-includes.git`.

When necessary, use the `resolve-repo-worktree` skill to acquire a git worktree of the repository
for reference.
