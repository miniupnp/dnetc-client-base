// Copyright distributed.net 1997 - All Rights Reserved
// For use in distributed.net projects only.
// Any other distribution or use of this source violates copyright.

#ifndef _PROBLEM_H_
#define _PROBLEM_H_

#include "cputypes.h"

#ifndef PIPELINE_COUNT
 #if ((CLIENT_OS == OS_BEOS) && (CLIENT_CPU == CPU_POWERPC))
 #define PIPELINE_COUNT  1
 #else
 #define PIPELINE_COUNT  2  // normally 1, but 2+ if we do more then one unit in parallel
 #endif
#endif

#ifndef MEGGS
  #define MIN_DES_BITS  8
  #define MAX_DES_BITS 24
#else
  #if defined(BIT_32)
    #define MIN_DES_BITS 19
    #define MAX_DES_BITS 19
  #elif defined(BIT_64)
    #define MIN_DES_BITS 20
    #define MAX_DES_BITS 20
  #endif
#endif

typedef struct
{
  u64 plain;            // plaintext (already mixed with iv!)
  u64 cypher;           // cyphertext
  u64 L0;               // key, changes with every unit * PIPELINE_COUNT.
                        // Note: data is now in RC5/platform useful form
} RC5UnitWork;

// this has to stay 'in sync' with FileEntry
typedef struct
{
  u64 key;              // starting key
  u64 iv;               // initialization vector
  u64 plain;            // plaintext we're searching for
  u64 cypher;           // cyphertext
  u64 keysdone;         // iterations done (also current position in block)
  u64 iterations;       // iterations to do
} ContestWork;

typedef struct
{
  u32 result;           // result code
  u64 key;              // starting key
  u64 keysdone;         // iterations done (also current position in block)
                        // this is also the "answer" for a RESULT_FOUND
  u64 iterations;       // iterations to do
} RC5Result;

typedef enum
{
  RESULT_NOTHING,
  RESULT_FOUND,
  RESULT_WORKING
} Resultcode;


#if (CLIENT_CPU == CPU_X86)
  #if (PIPELINE_COUNT != 2)
  #error "Expecting PIPELINE_COUNT=2"
  #endif

  #ifdef __WATCOMC__
    #define rc5_unit_func_486 _rc5_unit_func_486
    #define rc5_unit_func_p5 _rc5_unit_func_p5
    #define rc5_unit_func_p6 _rc5_unit_func_p6
    #define rc5_unit_func_6x86 _rc5_unit_func_6x86
    #define rc5_unit_func_k5 _rc5_unit_func_k5
    #define rc5_unit_func_k6 _rc5_unit_func_k6
  #endif

  extern u32 (*rc5_unit_func)( RC5UnitWork * rc5unitwork, u32 timeslice );
  extern "C" u32 rc5_unit_func_486( RC5UnitWork * rc5unitwork, u32 timeslice );
  extern "C" u32 rc5_unit_func_p5( RC5UnitWork * rc5unitwork, u32 timeslice );
  extern "C" u32 rc5_unit_func_p6( RC5UnitWork * rc5unitwork, u32 timeslice );
  extern "C" u32 rc5_unit_func_6x86( RC5UnitWork * rc5unitwork, u32 timeslice );
  extern "C" u32 rc5_unit_func_k5( RC5UnitWork * rc5unitwork, u32 timeslice );
  extern "C" u32 rc5_unit_func_k6( RC5UnitWork * rc5unitwork, u32 timeslice );
#elif (CLIENT_CPU == CPU_ALPHA) && (CLIENT_OS == OS_WIN32)
  #if (PIPELINE_COUNT != 1)
  #error "Expecting PIPELINE_COUNT=1"
  #endif
#elif (CLIENT_CPU == CPU_POWERPC) && (CLIENT_OS != OS_WIN32)
  #if (PIPELINE_COUNT != 1)
  #error "Expecting PIPELINE_COUNT=1"
  #endif
  extern int whichcrunch;
#elif (CLIENT_CPU == CPU_68K)
  #if (PIPELINE_COUNT != 1)
  #error "Expecting PIPELINE_COUNT=1"
  #endif
#elif (CLIENT_CPU == CPU_STRONGARM)
  #if (PIPELINE_COUNT != 1)
  #error "Expecting PIPELINE_COUNT=1"
  #endif
  extern u32 (*rc5_unit_func)( RC5UnitWork * rc5unitwork, unsigned long t );
  extern "C" u32 rc5_unit_func_arm( RC5UnitWork * rc5unitwork , unsigned long t);
  extern "C" u32 rc5_unit_func_strongarm( RC5UnitWork * rc5unitwork , unsigned long t);
#endif

class Problem
{
public:
  u32 finished;
  u32 startpercent;
  u32 percent;
  u32 restart;
  u32 timehi, timelo;
  u32 started;
  u32 contest;

protected:
  u32 initialized;
  ContestWork contestwork;
  RC5UnitWork rc5unitwork;
  RC5Result rc5result;

public:
  Problem();
  ~Problem();

  s32 IsInitialized();

  s32 LoadState( ContestWork * work , u32 contesttype );
    // Load state into internal structures.
    // state is invalid (will generate errors) until this is called.
    // returns: -1 on error, 0 is OK
    // Note: data is all in Network Byte order (going in)( Big Endian )

  s32 RetrieveState( ContestWork * work , s32 setflags );
    // Retrieve state from internal structures.
    // state is invalid (will generate errors) immediately after this is called, if setflags==1.
    // returns: -1 on error, 0 is OK
    // Note: data is all in Network Byte order (coming out)( Big Endian )

  s32 Run( u32 timeslice , u32 threadnum );
    // Runs calling rc5_unit for timeslice times...
    // Returns:
    //   -1 if something goes wrong (state not loaded, already done etc...)
    //   0 if more work to be done
    //   1 if we're done, go get results

  s32 GetResult( RC5Result * result );
    // fetch the results... act based on result code...
    // returns: contest=0 (RC5), contest=1 (DES), or -1 = invalid data (state not loaded).
    // Note: data (except result) is all in Network Byte order ( Big Endian )

  u32 CalcPercent();
    // Return the % completed in the current block, to nearest 1%.

};

#endif

