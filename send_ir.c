#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <time.h>
#include <string.h>
#include <errno.h>

#define BCM2835_PERI_BASE       0x3F000000  // Pi 2/3/Zero 2 W base
#define GPIO_BASE_OFFSET        0x200000
#define GPIO_BASE (BCM2835_PERI_BASE + GPIO_BASE_OFFSET)

#define BLOCK_SIZE (4*1024)

volatile unsigned *gpio;

#define GPFSEL0 0
#define GPFSEL1 1
#define GPFSEL2 2
#define GPSET0 7
#define GPCLR0 10

#define HEADER_MARK 9039
#define HEADER_SPACE 4406
#define ONE_MARK 639
#define ONE_SPACE 1601
#define ZERO_MARK 639
#define ZERO_SPACE 486
#define PTRAIL 641

#define BITS 32

static void sleep_us(long us) {
    struct timespec req, rem;
    req.tv_sec = us / 1000000;
    req.tv_nsec = (us % 1000000) * 1000;
    while (nanosleep(&req, &rem) == -1 && errno == EINTR) {
        req = rem;
    }
}

static void gpio_set_output(volatile unsigned *gpio, int pin) {
    int reg = pin / 10;
    int shift = (pin % 10) * 3;

    uint32_t val = gpio[reg];
    val &= ~(7 << shift);
    val |= (1 << shift);  // Output mode = 001
    gpio[reg] = val;
}

static void gpio_set(volatile unsigned *gpio, int pin) {
    if (pin < 32) {
        gpio[GPSET0] = 1 << pin;
    }
}

static void gpio_clear(volatile unsigned *gpio, int pin) {
    if (pin < 32) {
        gpio[GPCLR0] = 1 << pin;
    }
}

static void send_pair(volatile unsigned *gpio, int pin, long mark_us, long space_us) {
    gpio_set(gpio, pin);
    sleep_us(mark_us);
    gpio_clear(gpio, pin);
    sleep_us(space_us);
}

static void send_code(volatile unsigned *gpio, int pin, uint32_t code) {
    send_pair(gpio, pin, HEADER_MARK, HEADER_SPACE);

    for (int i = 0; i < BITS; i++) {
        if (code & (1 << i)) {
            send_pair(gpio, pin, ONE_MARK, ONE_SPACE);
        } else {
            send_pair(gpio, pin, ZERO_MARK, ZERO_SPACE);
        }
    }

    send_pair(gpio, pin, PTRAIL, 0);
}

static int parse_hex(const char *str, uint32_t *val) {
    char *endptr;
    errno = 0;
    unsigned long parsed = strtoul(str, &endptr, 0);  // base 0 = auto-detect hex or dec

    if (errno != 0) {
        perror("strtoul");
        return -1;
    }
    if (endptr == str || *endptr != '\0') {
        fprintf(stderr, "Invalid hex input: %s\n", str);
        return -1;
    }
    if (parsed > 0xFFFFFFFFUL) {
        fprintf(stderr, "Hex value out of range: %s\n", str);
        return -1;
    }

    *val = (uint32_t)parsed;
    return 0;
}

static int get_pin_from_env(void) {
    const char *env = getenv("IR_GPIO_PIN");
    if (!env) return 17;  // default GPIO17

    int pin = atoi(env);
    if (pin < 0 || pin > 53) {
        fprintf(stderr, "Warning: Invalid IR_GPIO_PIN=%s, using default 17\n", env);
        return 17;
    }
    return pin;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <hexcode1> [<hexcode2> ...]\n", argv[0]);
        fprintf(stderr, "Set GPIO pin via IR_GPIO_PIN environment variable (default 17)\n");
        return 1;
    }

    int pin = get_pin_from_env();

    int fd = open("/dev/gpiomem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("Failed to open /dev/gpiomem");
        return 1;
    }

    gpio = (volatile unsigned *)mmap(NULL, BLOCK_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    if (gpio == MAP_FAILED) {
        perror("mmap");
        return 1;
    }

    gpio_set_output(gpio, pin);
    gpio_clear(gpio, pin);

    for (int i = 1; i < argc; i++) {
        uint32_t code;
        if (parse_hex(argv[i], &code) != 0) {
            munmap((void *)gpio, BLOCK_SIZE);
            return 1;
        }
        printf("Sending code: 0x%08X on GPIO %d\n", code, pin);
        send_code(gpio, pin, code);
    }

    munmap((void *)gpio, BLOCK_SIZE);
    return 0;
}
