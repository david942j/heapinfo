#include <cstdlib>
#include <cstdio>
class Car {
public:
  virtual const char* name(){return NULL;}
};

class Benz: public Car {
  const char *name(){return "Benz!";}
};

class Magic: public Car {
  const char *name(){
    system("sh");
    return "Magic!";
  }
};

Car* cars[10];
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
int main() {
  for(int i=0;i<10;i++) {
    switch(readint()) {
      case 1: cars[top++] = new Benz(); break;
      case 2: new Magic(); break; // dangerous! don't put into pool
      case 3: print(); break;
      case 4: del(); break;
      default: return 0;
    }
  }
  return 0;
}
