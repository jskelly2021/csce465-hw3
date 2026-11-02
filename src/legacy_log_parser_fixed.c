#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUF_SIZE 128

static int checked_copy(const unsigned char *input, size_t n) {
    unsigned char buf[BUF_SIZE];

    /* Check at the copy boundary even if the caller already checked. */
    if (n > sizeof(buf)) {
        fprintf(stderr, "Log exceeds the %d-byte limit\n", BUF_SIZE);
        return EXIT_FAILURE;
    }

    /* This is binary data: no trailing NUL byte is needed. */
    memcpy(buf, input, n);
    size_t preview_size = n < 32 ? n : 32;
    if (fwrite(buf, 1, preview_size, stdout) != preview_size ||
        fputc('\n', stdout) == EOF || fflush(stdout) == EOF) {
        fprintf(stderr, "Failed to write log preview\n");
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}

static int parse_log(const char *path) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        perror(path);
        return EXIT_FAILURE;
    }

    /* One extra byte detects oversized input without trusting file metadata
     * or allocating memory proportional to an untrusted file's size. */
    unsigned char input[BUF_SIZE + 1];
    size_t n = fread(input, 1, sizeof(input), file);
    int read_failed = ferror(file);
    int close_failed = fclose(file);
    if (read_failed || close_failed) {
        fprintf(stderr, "Failed to read or close log: %s\n", path);
        return EXIT_FAILURE;
    }
    if (n > BUF_SIZE) {
        fprintf(stderr, "Log exceeds the %d-byte limit\n", BUF_SIZE);
        return EXIT_FAILURE;
    }

    return checked_copy(input, n);
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s LOG_FILE\n", argv[0]);
        return EXIT_FAILURE;
    }
    return parse_log(argv[1]);
}
