#pragma once
#include <string>
#include <string_view>

namespace keyauth {
// Exact legacy /api/v1/command wire format. Only use with a server-side wqd_ token.
struct Envelope {
    int version = 1;
    std::string algorithm = "A256GCM";
    std::string iv, ciphertext, tag;
};
Envelope encrypt(std::string_view jsonUTF8, std::string_view apiToken);
// Throws on ANY failure. Never returns unauthenticated plaintext.
std::string decrypt(const Envelope& envelope, std::string_view apiToken);
}
