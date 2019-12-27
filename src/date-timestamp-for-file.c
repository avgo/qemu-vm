#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

const char *allowed = "-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz";

void action_decode(const char *str);
int action_encode();
void decode(const char *buf, long int *val);
void encode(char *buf, size_t size, long int val);
int check(const char *str);

int action_encode()
{
	struct timespec tp;

	if (check(allowed))
		return 1;

	clock_gettime(CLOCK_REALTIME, &tp);

	struct tm tm1;

/*	symbols: 5, arr sz with term. zero: 6, max value (time_t): 1073741823, max value (date): 2004-01-10 16:37:03
	symbols: 6, arr sz with term. zero: 7, max value (time_t): 68719476735, max value (date): 4147-08-20 10:32:15
	symbols: 7, arr sz with term. zero: 8, max value (time_t): 4398046511103, max value (date): 141338-07-19 05:25:03 */

	char buf_sec[6+1];
	char buf_nsec[5+1];

	encode(buf_nsec, sizeof(buf_nsec), tp.tv_nsec);
	// strftime(buf_sec, sizeof buf_sec, "%Y-%m-%d_%H-%M-%S", localtime_r(&tp.tv_sec, &tm1));
	encode(buf_sec, sizeof(buf_sec), tp.tv_sec);
	// encode(buf_sec, sizeof(buf_sec), 1000000000);
	printf("%s.%s\n", buf_sec, buf_nsec);
#if 0
	for (int i = -4; i < 6; i += 1) {
		encode(buf_sec, sizeof(buf_sec), 4398046511103+i);
		printf("%s\n", buf_sec);
	}
#endif

	return 0;
}

void action_decode(const char *str)
{
	long int l;
	decode(str, &l);
	printf("%ld\n", l);
}

int check(const char *str) {
	int all_len = strlen(str);

	for (int i = 1; i < all_len; ++i) {
		if (str[i-1] >= str[i]) {
			char *err = malloc(i+3);
			if (err == NULL)
				err = "";
			else {
				char *err_p = err;
				*err_p = '\n'; ++err_p; --i;
				for (int j = 0; j < i; ++j, ++err_p)
					*err_p = ' ';
				*err_p = '^'; ++err_p;
				*err_p = '^'; ++err_p;
				*err_p = '\0';
			}
			fprintf(stderr,
				"error at pos (%d,%d) in\n%s%s\n",
				i, i+1, str, err
			);
			if (*err != '\0')
				free(err);
			return 1;
		}
	}

	return 0;
}

#define HASH_NULL -1

void decode(const char *buf, long int *val)
{
	int all_len = strlen(allowed);
	int hash_size = 256;
	short int *hash = malloc(sizeof(short int) * hash_size);
	short int *hash_e = hash + hash_size;
	for (short int *p = hash; p != hash_e; ++p)
		*p = HASH_NULL;
	for (const char *c = allowed; *c != '\0';  ++c) {
		hash[*c] = c - allowed;
	}
	*val = 0;
	for (const char *c = buf; *c != '\0'; ++c) {
		short int cc = hash[*c];
		if (cc == HASH_NULL) {
			fprintf(stderr, "error: %d\n", c - buf);
			free(hash);
			return;
		}
		*val = *val * all_len + cc;
	}
	free(hash);
}

void encode(char *buf, size_t size, long int val)
{
	int all_len = strlen(allowed);

	--size; buf[size] = '\0';

	char *p = buf + size;

	for ( ; val; val /= all_len) {
		if (p == buf) {
			fprintf(stderr, "error: no enough space.\n");
			memset(buf, 0, size);
			return;
		}
		--p; *p = allowed[val % all_len];
	}

	while ( buf < p ) {
		--p; *p = allowed[0];
	}
}

void test() {
	char buf[100];
	for (long int i = 950000000; i <= 2000000000; ++i) {
		encode(buf, sizeof buf, i);
		long int j;
		decode(buf, &j);
		if (i != j) {
			fprintf(stderr, "fail!\n");
			break;
		}
	}
}

int main(int argc, char *argv[])
{
	/* test(); return 0; */
	if (argc == 1) {
		action_encode();
	}
	else {
		action_decode(argv[1]);
	}
	return 0;
}
