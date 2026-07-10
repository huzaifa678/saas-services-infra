"""Custom Checkov policies for saas-services-infra.

Loaded via `checkov --external-checks-dir policy/checkov/custom`.

These deliberately overlap the OPA rules in policy/opa/terraform/. The redundancy
is the point: Checkov runs early and emits a GitLab/GitHub SAST report for the MR
widget; conftest/OPA is the hard gate immediately before apply. One tool failing
open must not let an insecure plan reach AWS.

ID range CKV_SAAS_1..CKV_SAAS_99 is reserved for this project.

NOTE ON SELF-CONTAINMENT
    Checkov loads each file in an external-checks-dir by path, so a sibling module
    (`from _helpers import ...`) is not reliably importable. Everything these
    checks need is defined in this file.
"""

from __future__ import annotations

from typing import Any

from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


def _unwrap(value: Any) -> Any:
    """Checkov hands attributes wrapped in a single-element list when scanning a
    plan, but bare when scanning HCL. Collapse both to the underlying scalar."""
    while isinstance(value, list) and len(value) == 1:
        value = value[0]
    return value


class MskAuthenticationRequired(BaseResourceCheck):
    """MSK must not allow unauthenticated access -- the live defect this repo
    shipped, where `client_authentication { unauthenticated = true }` was
    hardcoded with no SASL mechanism configured."""

    def __init__(self) -> None:
        super().__init__(
            name="MSK cluster must require authentication",
            id="CKV_SAAS_1",
            categories=[CheckCategories.NETWORKING],
            supported_resources=["aws_msk_cluster"],
        )

    def scan_resource_conf(self, conf: dict[str, Any]) -> CheckResult:
        blocks = conf.get("client_authentication")
        block = _unwrap(blocks)
        if not isinstance(block, dict):
            # No client_authentication block at all -> MSK defaults to open.
            return CheckResult.FAILED
        if _unwrap(block.get("unauthenticated")) is True:
            return CheckResult.FAILED
        return CheckResult.PASSED


class MskEncryptionInTransitTls(BaseResourceCheck):
    def __init__(self) -> None:
        super().__init__(
            name="MSK client-broker encryption must be TLS",
            id="CKV_SAAS_2",
            categories=[CheckCategories.ENCRYPTION],
            supported_resources=["aws_msk_cluster"],
        )

    def scan_resource_conf(self, conf: dict[str, Any]) -> CheckResult:
        enc = _unwrap(conf.get("encryption_info"))
        if not isinstance(enc, dict):
            return CheckResult.FAILED
        eit = _unwrap(enc.get("encryption_in_transit"))
        if not isinstance(eit, dict):
            # Absent block defaults to TLS on this provider.
            return CheckResult.PASSED
        cb = _unwrap(eit.get("client_broker"))
        if cb is None or cb == "TLS":
            return CheckResult.PASSED
        return CheckResult.FAILED


class EcrImmutableTags(BaseResourceCheck):
    def __init__(self) -> None:
        super().__init__(
            name="ECR image tags must be immutable",
            id="CKV_SAAS_3",
            categories=[CheckCategories.SUPPLY_CHAIN],
            supported_resources=["aws_ecr_repository"],
        )

    def scan_resource_conf(self, conf: dict[str, Any]) -> CheckResult:
        mutability = _unwrap(conf.get("image_tag_mutability"))
        # Defaults to MUTABLE when unset.
        if mutability == "IMMUTABLE":
            return CheckResult.PASSED
        return CheckResult.FAILED


class RdsNotPubliclyAccessible(BaseResourceCheck):
    def __init__(self) -> None:
        super().__init__(
            name="RDS instances must not be publicly accessible",
            id="CKV_SAAS_4",
            categories=[CheckCategories.NETWORKING],
            supported_resources=["aws_db_instance"],
        )

    def scan_resource_conf(self, conf: dict[str, Any]) -> CheckResult:
        if _unwrap(conf.get("publicly_accessible")) is True:
            return CheckResult.FAILED
        return CheckResult.PASSED


class ElastiCacheTransitEncryption(BaseResourceCheck):
    def __init__(self) -> None:
        super().__init__(
            name="ElastiCache must enable transit encryption",
            id="CKV_SAAS_5",
            categories=[CheckCategories.ENCRYPTION],
            supported_resources=["aws_elasticache_replication_group"],
        )

    def scan_resource_conf(self, conf: dict[str, Any]) -> CheckResult:
        if _unwrap(conf.get("transit_encryption_enabled")) is True:
            return CheckResult.PASSED
        return CheckResult.FAILED


check = MskAuthenticationRequired()
MskEncryptionInTransitTls()
EcrImmutableTags()
RdsNotPubliclyAccessible()
ElastiCacheTransitEncryption()
