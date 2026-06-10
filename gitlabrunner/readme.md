要从 Helm chart 安装 GitLab Runner：

helm repo add gitlab https://charts.gitlab.io

helm search repo -l gitlab/gitlab-runner

helm repo update gitlab

helm install --namespace <NAMESPACE> gitlab-runner -f <CONFIG_VALUES_FILE> gitlab/gitlab-runner

helm upgrade --namespace <NAMESPACE> -f <CONFIG_VALUES_FILE> <RELEASE-NAME> gitlab/gitlab-runner

helm delete --namespace <NAMESPACE> <RELEASE-NAME>


gitlab-runner register  --url http://gitlab.zevpa.com  --token glrt-_qrfO0qpKGiopwOVdiBYAW86MQp0OjEKdTozCw.01.120yq76s0

gitlab-runner run

helm install gitlab-runner -f values.yaml . --namespace gitlab-runner
NAME: gitlab-runner
LAST DEPLOYED: Wed Jun 10 09:08:07 2026
NAMESPACE: gitlab-runner
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
NOTES:
Your GitLab Runner should now be registered against the GitLab instance reachable at: "https://gitlab.zevpa.com"

Runner namespace "gitlab-runner" was found in runners.config template.

#############################################################################################
## WARNING: You enabled `rbac` without specifying if a service account should be created.  ##
## Please set `serviceAccount.create` to either `true` or `false`.                         ##
## For backwards compatibility a service account will be created.                          ##
#############################################################################################
a111@a111deMacBook-Pro gitlabrunner % 