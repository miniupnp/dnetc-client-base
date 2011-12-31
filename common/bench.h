/* Hey, Emacs, this a -*-C++-*- file !
 *
 * Copyright distributed.net 1997-2008 - All Rights Reserved
 * For use in distributed.net projects only.
 * Any other distribution or use of this source violates copyright.
*/
#ifndef __BENCH_H__
#define __BENCH_H__ "@(#)$Id: bench.h,v 1.18 2011/12/31 20:32:22 snikkel Exp $"

/* returns "rate", or 0 if not supported or core error */
ui64 TBenchmark( unsigned int contestid, unsigned int numsecs, int flags );
#define TBENCHMARK_QUIET       0x01
#define TBENCHMARK_IGNBRK      0x02
// do not use 0x80, it's internal to TBenchmark
//#define TBENCHMARK_CALIBRATION 0x80
ui64 BenchGetBestRate(unsigned int contestid);
void BenchResetStaticVars(void);

#endif /* __BENCH_H__ */
