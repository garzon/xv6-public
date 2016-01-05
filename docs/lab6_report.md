# lab6 report

## Topic: locking

### race condition

If there is a time gap between reading and writing a varible and there is multiple processes/threads/processors doing the same thing at the same time, different processes/threads/processors may read different value or overwrite the value written by the others and causes unpredictable problems because of the uncertain sequences of operations and it is called race conditions. To avoid this kind of problem, a lock is used to prevent multiple threads or something else running in the critical section of the code. That is to say, the varible can be protected for some time and can only be access by only one when owning the lock. Of course, race conditions do not limit to read/write of a varbiable, everything shared or parallel running may causes problem.

### implementation in xv6

```c
// Acquire the lock.
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
acquire(struct spinlock *lk)
{
  pushcli(); // disable interrupts to avoid deadlock.
  if(holding(lk))
    panic("acquire");

  // The xchg is atomic.
  // It also serializes, so that reads after acquire are not
  // reordered before it. 
  while(xchg(&lk->locked, 1) != 0)
    ;

  // Record info about lock acquisition for debugging.
  lk->cpu = cpu;
  getcallerpcs(&lk, lk->pcs);
}

// Release the lock.
void
release(struct spinlock *lk)
{
  if(!holding(lk))
    panic("release");

  lk->pcs[0] = 0;
  lk->cpu = 0;

  // The xchg serializes, so that reads before release are 
  // not reordered after it.  The 1996 PentiumPro manual (Volume 3,
  // 7.2) says reads can be carried out speculatively and in
  // any order, which implies we need to serialize here.
  // But the 2007 Intel 64 Architecture Memory Ordering White
  // Paper says that Intel 64 and IA-32 will not move a load
  // after a store. So lock->locked = 0 would work here.
  // The xchg being asm volatile ensures gcc emits it after
  // the above assignments (and after the critical section).
  xchg(&lk->locked, 0);

  popcli();
}
```

To implement the `acquire()` function, xv6 disables interrupts during locking and uses atomic instruction `xchg` in x86 to obtain the lock. And `release()` is the inversed function that xchgs the flag and enables interrupts. We can see that the others have to busy wait for the owner of the lock to leave the critical section, and in fact it is called spinlock.     

So, a solution to this kind of problem is shown below.

```c

void threadWorker() {
	...
	acquire(&lock);
	
	// critical section
	count = getCount();
	count += 1;
	setCount(counter);

	// leave
	release(&lock);
	...
}

```

