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
  free(v); free(u); free(v);

  v = malloc(136);
  void** others = (void**)malloc(72); // also prevent small bin merge with top_chunk
  *others = mmap; // hack for test can get address of mmap
  free(v);
  v = malloc(152); // let 136 put into smallbin
  malloc(200); // to prevent merge with top_chunk
  free(v); // put into unsorted bin 
  char dummy;
  read(0, &dummy, 1); // function which not use heap
}
