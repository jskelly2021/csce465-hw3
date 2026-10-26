#include "stdio.h"
#include <stdlib.h>
#include <string.h>

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
    memcpy(buf, input, n);
    fwrite(buf, 1, n < 32 ? n : 32, stdout);
    fputc('\n', stdout);
}


/**
 * read the whole file into a heap buffer, fclose() it, THEN 
 * call vulnerable_copy(input, n) so the overflow reaches 
 * only this frame's saved return address -- a clean ret2win
 */
static void parse_log(const char *path) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        perror(path);
        return;
    }

    unsigned char *input = malloc(MAX_COPY);
    if (input == NULL) {
        perror("malloc");
        fclose(file);
        return;
    }

    size_t n = fread(input, 1, MAX_COPY, file);
    if (ferror(file)) {
        fprintf(stderr, "Failed to read log: %s\n", path);
        fclose(file);
        free(input);
        return;
    }

    fclose(file);
    vulnerable_copy(input, n);
    free(input);
}


int main(int argc, char *argv[]) {
    if (argc != 2) {
        return 1;
    }
    parse_log(argv[1]);
    return 0;
}
