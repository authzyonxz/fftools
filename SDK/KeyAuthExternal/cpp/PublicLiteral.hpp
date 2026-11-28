#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
#include <string>

// Cosmetic obfuscation for PUBLIC labels/URLs, never a container for secrets.
// An analyst controlling the process can recover every decoded value.
namespace keyauth {
template<std::size_t N, std::uint8_t Seed> class PublicLiteral {
    std::array<std::uint8_t,N-1> encoded_{};
public:
    constexpr explicit PublicLiteral(const char (&text)[N]) {
        for(std::size_t i=0;i<N-1;i++) encoded_[i]=static_cast<std::uint8_t>(text[i]) ^ static_cast<std::uint8_t>(Seed+i*29u);
    }
#if defined(__clang__) || defined(__GNUC__)
    __attribute__((noinline))
#endif
    std::string reveal() const {
        volatile std::uint8_t runtimeSeed=Seed;
        std::string result(N-1,'\0');
        for(std::size_t i=0;i<N-1;i++) result[i]=static_cast<char>(encoded_[i] ^ static_cast<std::uint8_t>(runtimeSeed+i*29u));
        return result;
    }
};
}
#define KA_PUBLIC_LITERAL(text) ([] { constexpr keyauth::PublicLiteral<sizeof(text),0xA7> value(text); return value.reveal(); }())
