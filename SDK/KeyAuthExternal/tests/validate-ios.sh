#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .validation
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
for source in ios/*.m; do
  xcrun clang -isysroot "$SDK" -target arm64-apple-ios15.0 -fobjc-arc -fmodules -Wall -Wextra -Werror=return-type -c "$source" -o ".validation/$(basename "$source").o"
done
xcrun clang++ -isysroot "$SDK" -target arm64-apple-ios15.0 -std=c++17 -fobjc-arc -fmodules -c objc-aes/KACommandCodec.mm -o .validation/KACommandCodec.o
OPENSSL=$(brew --prefix openssl@3)
c++ -std=c++17 -Wall -Wextra -Werror -I"$OPENSSL/include" -Icpp cpp/Transport.cpp tests/transport_cli.cpp -L"$OPENSSL/lib" -lcrypto -o .validation/transport_cli
node tests/interoperability.cjs "$PWD/.validation/transport_cli"
c++ -std=c++17 -Wall -Wextra -Werror -Icpp tests/literal_test.cpp -o .validation/literal_test
.validation/literal_test
echo 'Public literal obfuscation round-trip passed.'
node tests/create-grant-fixtures.cjs
xcrun clang -fobjc-arc -fmodules -Iios -framework Foundation -framework Security .validation/KASecurity-test.m tests/grant_tests.m -o .validation/grant_tests
.validation/grant_tests
echo 'iOS arm64 compilation and AES interoperability passed.'
