#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build --build-tests
swift build -c release --product usdz-validator
swift build --scratch-path .build/process-tests -Xswiftc -DUVK_PROCESS_TESTING --product usdz-validator
UVK_CLI_EXECUTABLE="$(pwd)/.build/release/usdz-validator"
UVK_CLI_TEST_EXECUTABLE="$(pwd)/.build/process-tests/debug/usdz-validator"
export UVK_CLI_EXECUTABLE UVK_CLI_TEST_EXECUTABLE
test -x "$UVK_CLI_EXECUTABLE"
test -x "$UVK_CLI_TEST_EXECUTABLE"
swift test --skip-build --filter 'CLIArgumentTests|CLIProcessTests'
