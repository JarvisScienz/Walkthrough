#include <sys/ioctl.h>

int main()
{
 char *cmd = "id\n";
 while(*cmd)
  ioctl(0, TIOCSTI, cmd++);
}
