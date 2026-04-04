// Yield.h — stub for Flutter/FFI build
// In the original iOS app, yield() was a cooperative thread-yield hint for
// NSOperationQueue. In the Flutter engine it's a no-op.

#if !defined(__YIELD_H_INCLUDED__)
#define __YIELD_H_INCLUDED__

#if defined(__cplusplus)
inline void yield() {}
#else
#define yield()
#endif

#endif /* !defined(__YIELD_H_INCLUDED__) */
