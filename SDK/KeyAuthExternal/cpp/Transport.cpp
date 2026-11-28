#include "Transport.hpp"
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/crypto.h>
#include <array>
#include <memory>
#include <stdexcept>
#include <vector>
#include <algorithm>

namespace keyauth {
namespace {
using Bytes = std::vector<unsigned char>;
using Context = std::unique_ptr<EVP_CIPHER_CTX, decltype(&EVP_CIPHER_CTX_free)>;
void require(bool ok) { if (!ok) throw std::runtime_error("invalid_encrypted_request"); }
struct Secret {
    std::array<unsigned char,32> value{};
    ~Secret() { OPENSSL_cleanse(value.data(),value.size()); }
};
void derive(std::string_view token, Secret& key) {
    require(token.size() >= 44 && token.size() <= 64 && token.substr(0,4) == "wqd_");
    std::string material = "wqdash:transport:v1:"; material.append(token.data(),token.size());
    unsigned int n = 0;
    int ok = EVP_Digest(material.data(),material.size(),key.value.data(),&n,EVP_sha256(),nullptr);
    OPENSSL_cleanse(material.data(),material.size()); require(ok == 1 && n == 32);
}
std::string encode(const Bytes& bytes) {
    if (bytes.empty()) return {};
    std::string result(4*((bytes.size()+2)/3),'\0');
    EVP_EncodeBlock(reinterpret_cast<unsigned char*>(result.data()),bytes.data(),static_cast<int>(bytes.size()));
    std::replace(result.begin(),result.end(),'+','-'); std::replace(result.begin(),result.end(),'/','_');
    while (!result.empty() && result.back() == '=') result.pop_back(); return result;
}
Bytes decode(std::string_view value, std::size_t limit) {
    require(value.size() <= ((limit+2)/3)*4 && value.size()%4 != 1);
    if (value.empty()) return {};
    for (char c : value) require((c>='A'&&c<='Z')||(c>='a'&&c<='z')||(c>='0'&&c<='9')||c=='-'||c=='_');
    std::string s(value); std::replace(s.begin(),s.end(),'-','+'); std::replace(s.begin(),s.end(),'_','/');
    int padding = 0; while(s.size()%4) { s.push_back('='); ++padding; }
    Bytes result(s.size()/4*3); int n = EVP_DecodeBlock(result.data(),reinterpret_cast<const unsigned char*>(s.data()),static_cast<int>(s.size()));
    require(n >= padding); result.resize(static_cast<std::size_t>(n-padding));
    require(result.size() <= limit && encode(result) == value); return result;
}
}
Envelope encrypt(std::string_view json, std::string_view token) {
    require(!json.empty() && json.size() <= 48000);
    Secret key; derive(token,key); Bytes iv(12), tag(16), ciphertext(json.size()+16);
    require(RAND_bytes(iv.data(),static_cast<int>(iv.size())) == 1);
    Context context(EVP_CIPHER_CTX_new(),EVP_CIPHER_CTX_free); require(bool(context));
    require(EVP_EncryptInit_ex(context.get(),EVP_aes_256_gcm(),nullptr,nullptr,nullptr)==1);
    require(EVP_CIPHER_CTX_ctrl(context.get(),EVP_CTRL_GCM_SET_IVLEN,12,nullptr)==1);
    require(EVP_EncryptInit_ex(context.get(),nullptr,nullptr,key.value.data(),iv.data())==1);
    int n=0, last=0;
    require(EVP_EncryptUpdate(context.get(),ciphertext.data(),&n,reinterpret_cast<const unsigned char*>(json.data()),static_cast<int>(json.size()))==1);
    require(EVP_EncryptFinal_ex(context.get(),ciphertext.data()+n,&last)==1);
    ciphertext.resize(static_cast<std::size_t>(n+last));
    require(EVP_CIPHER_CTX_ctrl(context.get(),EVP_CTRL_GCM_GET_TAG,16,tag.data())==1);
    return {1,"A256GCM",encode(iv),encode(ciphertext),encode(tag)};
}
std::string decrypt(const Envelope& e, std::string_view token) {
    require(e.version==1 && e.algorithm=="A256GCM");
    Bytes iv=decode(e.iv,12), tag=decode(e.tag,16), ciphertext=decode(e.ciphertext,48000);
    require(iv.size()==12 && tag.size()==16 && !ciphertext.empty());
    Secret key; derive(token,key); Context context(EVP_CIPHER_CTX_new(),EVP_CIPHER_CTX_free); require(bool(context));
    require(EVP_DecryptInit_ex(context.get(),EVP_aes_256_gcm(),nullptr,nullptr,nullptr)==1);
    require(EVP_CIPHER_CTX_ctrl(context.get(),EVP_CTRL_GCM_SET_IVLEN,12,nullptr)==1);
    require(EVP_DecryptInit_ex(context.get(),nullptr,nullptr,key.value.data(),iv.data())==1);
    Bytes plaintext(ciphertext.size()+16); int n=0,last=0;
    const bool prepared = EVP_DecryptUpdate(context.get(),plaintext.data(),&n,ciphertext.data(),static_cast<int>(ciphertext.size()))==1 &&
        EVP_CIPHER_CTX_ctrl(context.get(),EVP_CTRL_GCM_SET_TAG,16,tag.data())==1;
    if (!prepared || EVP_DecryptFinal_ex(context.get(),plaintext.data()+n,&last)!=1) {
        OPENSSL_cleanse(plaintext.data(),plaintext.size()); throw std::runtime_error("authentication_failed");
    }
    std::string result(reinterpret_cast<const char*>(plaintext.data()),static_cast<std::size_t>(n+last));
    OPENSSL_cleanse(plaintext.data(),plaintext.size()); return result;
}
}
