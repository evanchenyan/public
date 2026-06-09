要从 Helm chart 安装 GitLab Runner：

helm repo add gitlab https://charts.gitlab.io

helm search repo -l gitlab/gitlab-runner

helm repo update gitlab

helm install --namespace <NAMESPACE> gitlab-runner -f <CONFIG_VALUES_FILE> gitlab/gitlab-runner

helm upgrade --namespace <NAMESPACE> -f <CONFIG_VALUES_FILE> <RELEASE-NAME> gitlab/gitlab-runner

helm delete --namespace <NAMESPACE> <RELEASE-NAME>


