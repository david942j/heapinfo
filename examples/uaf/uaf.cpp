#include <cstdlib>
#include <cstdio>
class Car {
public:
  virtual const char* name(){return NULL;}
};

class Benz: public Car {
  const char *name(){return "Benz!";}
};

class Toyota: public Car {
  const char *name(){return "Toyota!";}
};

void magic() {
  system("sh");
}
Car* cars[100];
int top = 0;
char *name;
int readint() {
  int x;
  scanf("%d", &x);
  return x;
}
void print() {
  for(int i=0;i<top;i++)
    printf("%s\n", cars[i]->name());
}
void del() {
  size_t x = readint();
  if(x >= top) return;
  delete cars[x];
}
void record() {
  printf("How long is your name?\n");
  size_t len = readint();
  if(len > 100) return;
  name = (char*) malloc(len);
  fgets(name, len, stdin);
}
int main() {
  for(int i=0;i<100;i++) {
    switch(readint()) {
      case 1: cars[top++] = new Benz(); break;
      case 2: cars[top++] = new Toyota(); break;
      case 3: print(); break;
      case 4: del(); break;
      case 5: record(); break;
      default: return 0;
    }
  }
  return 0;
}
