#include <cstdlib>
#include <cstdio>
#include <unistd.h>

int main(int argc, char **argv) {
  if(argc <= 1) alarm(10);
  void *v, *u;
  int *i, *j;
  
  void *mmap = malloc(0x20000);

  // normal
  v = malloc(24); u = malloc(24);
  free(v); free(u);

  // invalid fd
  i = (int*)malloc(40);
  free(i);
  *i = 0xdeadbeef;

  // loop
  v = malloc(56); u = malloc(56);
  free(v); free(u);
  // HACK: glibc 2.29 adds e->key to detect double free, set null to bypass the check
  ((size_t**)v)[1] = NULL;
  free(v);

  v = malloc(136);
  void** others = (void**)malloc(72); // also prevent small bin from being merged with top_chunk
  *others = mmap; // HACK: for tests to fetch the address of mmap
  free(v);
  v = malloc(152); // let 136 put into smallbin
  malloc(200); // to prevent merging with top_chunk
  free(v); // put into unsorted bin 
  char dummy;
  read(0, &dummy, 1); // function which does not use heap
}
