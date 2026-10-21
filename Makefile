.PHONY: format format-check build test schemas cli-test adversarial resources release-verify

format:
	xcrun swift-format format --in-place --recursive --configuration .swift-format Sources Tests Package.swift

format-check:
	xcrun swift-format lint --strict --recursive --configuration .swift-format Sources Tests Package.swift

build:
	swift build --build-tests

test:
	swift test

schemas:
	.venv/bin/python Scripts/verify-schemas.py --self-test
	.venv/bin/python -m unittest discover -s Tests -p 'test_schema_contracts.py'

cli-test:
	sh Scripts/test-cli.sh

adversarial:
	sh Scripts/test-adversarial.sh

resources:
	swift build -c release
	UVK_RUN_RESOURCE_TESTS=1 swift test -c release --filter ResourceBoundaryTests
	python3 Scripts/verify-resources.py --executable .build/release/usdz-validator --output docs/verification/resource-results.md

release-verify:
	sh Scripts/verify-release.sh --evidence-dir .build/verification/current
