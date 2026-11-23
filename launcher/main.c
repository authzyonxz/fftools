//  launcher/main.c
//  External — the IPA's MH_EXECUTE binary.
//
//  All app logic lives in Frameworks/ffpatch.dylib (Sources/*.m). This stub
//  exists for one reason: dyld only launches MH_EXECUTE binaries, so a plain
//  dylib cannot be the app's main binary. 60 lines, no UIKit, no state.

#include <dlfcn.h>
#include <libgen.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef int (*FFAppMainFn)(int argc, char **argv);

static int ExternalLoadAndRun(const char *dylibPath, int argc, char **argv, int *exitStatus) {
    void *handle = dlopen(dylibPath, RTLD_NOW | RTLD_GLOBAL);
    if (handle == NULL) {
        fprintf(stderr, "External: dlopen(%s) falhou: %s\n", dylibPath, dlerror());
        return 0;
    }
    FFAppMainFn entry = (FFAppMainFn)dlsym(handle, "FFAppMain");
    if (entry == NULL) {
        fprintf(stderr, "External: símbolo FFAppMain ausente em %s\n", dylibPath);
        return 0;
    }
    if (exitStatus != NULL) *exitStatus = entry(argc, argv);
    return 1;
}

int main(int argc, char **argv) {
    char executablePath[4096];
    uint32_t size = (uint32_t)sizeof(executablePath);
    if (_NSGetExecutablePath(executablePath, &size) != 0) {
        fprintf(stderr, "External: não resolveu o próprio caminho\n");
        return 1;
    }

    // _NSGetExecutablePath may hand back a non-canonical path; keep a copy
    // because dirname() mutates its argument.
    char buffer[4096];
    strncpy(buffer, executablePath, sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';
    const char *directory = dirname(buffer);

    char candidate[8192];
    int appExitStatus = 1;

    // Preferred layout: App.app/Frameworks/ffpatch.dylib (matches Theos and
    // Xcode's Frameworks folder and what the packaging script produces).
    snprintf(candidate, sizeof(candidate), "%s/Frameworks/ffpatch.dylib", directory);
    if (ExternalLoadAndRun(candidate, argc, argv, &appExitStatus)) return appExitStatus;

    // Fallback: dylib dropped next to the executable.
    snprintf(candidate, sizeof(candidate), "%s/ffpatch.dylib", directory);
    if (ExternalLoadAndRun(candidate, argc, argv, &appExitStatus)) return appExitStatus;

    fprintf(stderr, "External: ffpatch.dylib não encontrada em %s (Frameworks/ e raiz)\n",
            directory);
    return 1;
}
