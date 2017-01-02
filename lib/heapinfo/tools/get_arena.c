/*
 @author: david942j
 use for get libc's main_arena offset
 Sample Usage
 > ./get_arena
 > LD_LIBRARY_PATH=. ./get_arena
 > ./ld-linux.so.2 --library-path . ./get_arena
 */
#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>
#define SZ sizeof(size_t)
#define PAGE_SIZE 0x1000
void *search_head(size_t e) {
  e = (e >> 12) << 12;
  while(strncmp((void*)e, "\177ELF", 4)) e -= PAGE_SIZE;
  return (void*) e;
}
int main() {
  void **p = (void**)malloc(SZ*16); // small bin with chunk size SZ*18
  void *z = malloc(SZ); // prevent p merge with top chunk
  *p = z; // prevent compiler optimize
  free(p); // now *p must be the pointer of the (chunk_ptr) unsorted bin
  z = (void*)((*p) - (4 + 4 + SZ * 10 )); // mutex+flags+fastbin[]
  void* a = search_head((size_t)__builtin_return_address(0));
  printf("%p\n", z-a);
  return 0;
}
