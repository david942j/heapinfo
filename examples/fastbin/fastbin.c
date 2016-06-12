/* Problem Credit: seanwupi */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
void sh(char *cmd) {
  system(cmd);
}
*/

int main() {
  setvbuf(stdout, 0, _IONBF, 0);
  int cmd, idx, sz;
  char* ptr[10];
  memset(ptr, 0, sizeof(ptr));
  puts("1. malloc + gets\n2. free\n3. puts");
  while (1) {
    printf("> ");
    scanf("%d %d", &cmd, &idx);
    idx %= 10;
    if (cmd==1) {
      scanf("%d%*c", &sz);
      ptr[idx] = malloc(sz);
      gets(ptr[idx]);
    } else if (cmd==2) {
      free(ptr[idx]);
    } else if (cmd==3) {
      puts(ptr[idx]);
    } else {
      exit(0);
    }
  }
  return 0;
}
