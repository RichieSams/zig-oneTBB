
// Force-disable WAITPKG intrinsics in oneTBB across all translation units.
#include <oneapi/tbb/detail/_config.h>
#ifdef __TBB_WAITPKG_INTRINSICS_PRESENT
#undef __TBB_WAITPKG_INTRINSICS_PRESENT
#endif
#define __TBB_WAITPKG_INTRINSICS_PRESENT 0
