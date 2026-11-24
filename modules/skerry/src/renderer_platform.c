#include <moonbit.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

/* Keep these values in sync with RendererPlatform in renderer_selection.mbt. */
enum skerry_platform {
    SKERRY_PLATFORM_OTHER = 0,
    SKERRY_PLATFORM_WINDOWS = 1,
    SKERRY_PLATFORM_MACOS = 2,
    SKERRY_PLATFORM_LINUX = 3,
};

MOONBIT_FFI_EXPORT
int32_t moonbit_skerry_renderer_platform(void) {
#if defined(_WIN32)
    return SKERRY_PLATFORM_WINDOWS;
#elif defined(__APPLE__) && TARGET_OS_OSX
    return SKERRY_PLATFORM_MACOS;
#elif defined(__linux__) && !defined(__ANDROID__)
    return SKERRY_PLATFORM_LINUX;
#else
    return SKERRY_PLATFORM_OTHER;
#endif
}
