#include "stdio.h"

#define BUF_SIZE 128
#define MAX_COPY 512

/**
 * ret2win target: writes markers/ret2win.txt,
 * then attempts to read the protected decoy
 */
void win(void);


/**
 * copy n bytes from input into buf WITHOUT checking n
 * against BUF_SIZE -- the missing check is the vulnerability
 */
static void vulnerable_copy(const unsigned char *input, size_t n) {
    char buf[BUF_SIZE];
    // TODO 
}


/**
 * read the whole file into a heap buffer, fclose() it, THEN 
 * call vulnerable_copy(input, n) so the overflow reaches 
 * only this frame's saved return address -- a clean ret2win
 */
static void parse_log(const char *path) {
    //TODO
}


int main(int argc, char *argv[]) {
    return 0;
}
