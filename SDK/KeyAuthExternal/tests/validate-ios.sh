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
echo 'iOS arm64 compilation and AES interoperability passed.'
