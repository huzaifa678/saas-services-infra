"""Unit tests for the custom Checkov policies.

Run:  python3 -m pytest policy/checkov/tests -q

A custom Checkov check that silently returns PASSED for every input is worse than
no check: it shows up green in the SAST report. These tests pin the conf-shape
handling, which is where such checks break -- the same attribute arrives wrapped
in a list when Checkov scans a plan and bare when it scans raw HCL.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
from checkov.common.models.enums import CheckResult

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "custom"))

import saas_checks as m  # noqa: E402

P, F = CheckResult.PASSED, CheckResult.FAILED


@pytest.mark.parametrize(
    ("conf", "expected"),
    [
        ({"client_authentication": [{"unauthenticated": [True]}]}, F),
        ({"client_authentication": [{"unauthenticated": [False], "sasl": [{"iam": [True]}]}]}, P),
        ({"client_authentication": [{"sasl": [{"iam": [True]}]}]}, P),
        ({}, F),  # no client_authentication block at all
    ],
)
def test_msk_authentication(conf, expected):
    assert m.MskAuthenticationRequired().scan_resource_conf(conf) == expected


@pytest.mark.parametrize(
    ("conf", "expected"),
    [
        ({"encryption_info": [{"encryption_in_transit": [{"client_broker": ["TLS"]}]}]}, P),
        ({"encryption_info": [{"encryption_in_transit": [{"client_broker": ["PLAINTEXT"]}]}]}, F),
        ({"encryption_info": [{"encryption_in_transit": [{"client_broker": ["TLS_PLAINTEXT"]}]}]}, F),
        ({"encryption_info": [{}]}, P),  # eit block absent -> provider default TLS
        ({}, F),  # no encryption_info at all
    ],
)
def test_msk_encryption_in_transit(conf, expected):
    assert m.MskEncryptionInTransitTls().scan_resource_conf(conf) == expected


@pytest.mark.parametrize(
    ("conf", "expected"),
    [
        ({"image_tag_mutability": ["IMMUTABLE"]}, P),
        ({"image_tag_mutability": ["MUTABLE"]}, F),
        ({}, F),  # defaults to MUTABLE
    ],
)
def test_ecr_immutable_tags(conf, expected):
    assert m.EcrImmutableTags().scan_resource_conf(conf) == expected


@pytest.mark.parametrize(
    ("conf", "expected"),
    [
        ({"publicly_accessible": [True]}, F),
        ({"publicly_accessible": [False]}, P),
        ({}, P),  # defaults to not-public
    ],
)
def test_rds_public(conf, expected):
    assert m.RdsNotPubliclyAccessible().scan_resource_conf(conf) == expected


@pytest.mark.parametrize(
    ("conf", "expected"),
    [
        ({"transit_encryption_enabled": [True]}, P),
        ({"transit_encryption_enabled": [False]}, F),
        ({}, F),
    ],
)
def test_elasticache_transit(conf, expected):
    assert m.ElastiCacheTransitEncryption().scan_resource_conf(conf) == expected
