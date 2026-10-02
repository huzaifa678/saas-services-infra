FROM public.ecr.aws/docker/library/debian:bookworm-slim

ARG TERRAFORM_VERSION=1.9.8
ARG TERRAGRUNT_VERSION=1.1.0
ARG KUBECTL_VERSION=1.32.0
ARG HELM_VERSION=3.16.3
ARG AWSCLI_VERSION=2.17.65
ARG CHECKOV_VERSION=3.2.257
ARG TARGETARCH=amd64

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl unzip git jq python3 python3-pip bash; \
    rm -rf /var/lib/apt/lists/*

# Terraform
RUN set -eux; \
    curl -fsSL -o /tmp/tf.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip"; \
    unzip -o /tmp/tf.zip -d /usr/local/bin; \
    rm -f /tmp/tf.zip; \
    terraform version

# Terragrunt
RUN set -eux; \
    curl -fsSL -o /usr/local/bin/terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_${TARGETARCH}"; \
    chmod +x /usr/local/bin/terragrunt; \
    terragrunt --version

# kubectl
RUN set -eux; \
    curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl"; \
    chmod +x /usr/local/bin/kubectl; \
    kubectl version --client

# Helm
RUN set -eux; \
    curl -fsSL -o /tmp/helm.tgz "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz"; \
    tar -xzf /tmp/helm.tgz -C /tmp; \
    mv "/tmp/linux-${TARGETARCH}/helm" /usr/local/bin/helm; \
    rm -rf /tmp/helm.tgz "/tmp/linux-${TARGETARCH}"; \
    helm version

# AWS CLI v2
RUN set -eux; \
    case "${TARGETARCH}" in amd64) awsarch=x86_64;; arm64) awsarch=aarch64;; *) echo "unsupported arch"; exit 1;; esac; \
    curl -fsSL -o /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-${awsarch}-${AWSCLI_VERSION}.zip"; \
    unzip -q /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/aws /tmp/awscliv2.zip; \
    aws --version

# Checkov (policy scan parity with CI)
RUN set -eux; \
    pip3 install --no-cache-dir --break-system-packages "checkov==${CHECKOV_VERSION}"; \
    checkov --version

CMD ["bash"]
