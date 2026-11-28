#import "KACommandCodec.h"
#include "../cpp/Transport.hpp"
#include <exception>
#include <stdexcept>

@implementation KACommandCodec
+ (NSDictionary *)encryptCommand:(NSDictionary *)command token:(NSString *)token error:(NSError **)error {
    NSData *bytes = [NSJSONSerialization dataWithJSONObject:command options:0 error:error]; if (!bytes) return nil;
    try {
        auto e = keyauth::encrypt(std::string_view((const char *)bytes.bytes,bytes.length),token.UTF8String);
        return @{@"version":@(e.version),@"algorithm":@(e.algorithm.c_str()),@"iv":@(e.iv.c_str()),@"ciphertext":@(e.ciphertext.c_str()),@"tag":@(e.tag.c_str())};
    } catch (const std::exception&) {
        if (error) *error = [NSError errorWithDomain:@"KeyAuth.AES" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Falha ao criptografar o comando."}]; return nil;
    }
}
+ (NSDictionary *)decryptEnvelope:(NSDictionary *)envelope token:(NSString *)token error:(NSError **)error {
    try {
        if (![envelope[@"version"] isEqual:@1]) throw std::runtime_error("version");
        for (NSString *field in @[@"algorithm",@"iv",@"ciphertext",@"tag"])
            if (![envelope[field] isKindOfClass:NSString.class]) throw std::runtime_error("field");
        keyauth::Envelope e{1,[envelope[@"algorithm"] UTF8String],[envelope[@"iv"] UTF8String],[envelope[@"ciphertext"] UTF8String],[envelope[@"tag"] UTF8String]};
        auto plain = keyauth::decrypt(e,token.UTF8String);
        NSData *data = [NSData dataWithBytes:plain.data() length:plain.size()];
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
        if (![json isKindOfClass:NSDictionary.class]) throw std::runtime_error("json");
        return json;
    } catch (const std::exception&) {
        if (error) *error = [NSError errorWithDomain:@"KeyAuth.AES" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Resposta criptografada inválida ou adulterada."}]; return nil;
    }
}
@end
