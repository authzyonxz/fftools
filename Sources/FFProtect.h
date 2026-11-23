//
//  FFProtect.h
//  FFPatch — light hardening helpers.
//
//  Honest scope: this raises the cost of casual inspection of the IPA. It does
//  not make the binary unreadable — a sideloaded app can always be dumped. What
//  actually protects the payloads is that they never ship inside the IPA: the
//  catalogue serves them AES-256-CBC + HMAC-SHA256 (FPP1) and the key material
//  is only ever decoded at runtime.
//

#ifndef FF_PROTECT_H
#define FF_PROTECT_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*! Decodes a XOR-masked byte blob (mask = 0x5B ^ (index * 31)) into a string.
    `Scripts/protect_config.py` generates the masks. */
NSString *_Nullable FFMaskedString(const unsigned char *bytes, size_t length);

/*! Same for bytes. */
NSData *_Nullable FFMaskedData(const unsigned char *bytes, size_t length);

/*! Catalogue base URL from the bundled masked Catalog.plist. */
NSString *_Nullable FFCatalogBaseURL(void);

/*! Master secret used to derive the FPP1 keys (never stored in clear). */
NSData *_Nullable FFMasterSecret(void);

/*! Installs process hardening (anti-debug). Safe to call once at launch. */
void FFProtectInstall(void);

/*! YES when a debugger is attached / the process is being traced. */
BOOL FFIsBeingTraced(void);

NS_ASSUME_NONNULL_END

#endif /* FF_PROTECT_H */
