#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

const char *allowed = "-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz";
const char *dtm_fmt_def = "%Y-%m-%d_%H-%M-%S"; // example: "%F %T"

void action_decode(int argc, char **argv);
int action_encode();
int decode(const char *buf, long int *val);
void encode(char *buf, size_t size, long int val);
int check(const char *str);

int action_encode()
{
	struct timespec tp;

	if (check(allowed))
		return 1;

	clock_gettime(CLOCK_REALTIME, &tp);

/*	symbols: 5, arr sz with term. zero: 6, max value (time_t): 1073741823, max value (date): 2004-01-10 16:37:03
	symbols: 6, arr sz with term. zero: 7, max value (time_t): 68719476735, max value (date): 4147-08-20 10:32:15
	symbols: 7, arr sz with term. zero: 8, max value (time_t): 4398046511103, max value (date): 141338-07-19 05:25:03 */

	char buf_sec[6+1];
	char buf_nsec[5+1];

	encode(buf_nsec, sizeof(buf_nsec), tp.tv_nsec);
	encode(buf_sec, sizeof(buf_sec), tp.tv_sec);
	printf("%s.%s\n", buf_sec, buf_nsec);

	return 0;
}

void action_decode(int argc, char **argv)
{
	const char *string = NULL, *tmp = NULL, *dtm_fmt = NULL;
	for ( ; *argv != NULL; ++argv) {
		tmp = *argv;
		if (*tmp == '+') {
			if (dtm_fmt == NULL)
				dtm_fmt = tmp + 1;
			else {
				fprintf(stderr, "error: only one fmt string is allowed.\n");
				exit(1);
			}
		}
		else {
			if (string == NULL)
				string = tmp;
			else {
				fprintf(stderr, "error: only one time string is allowed.\n");
				exit(1);
			}
		}
	}
	if (string == NULL) {
		fprintf(stderr, "error: time string is absent.\n");
		exit(1);
	}
	if (dtm_fmt == NULL)
		dtm_fmt = dtm_fmt_def;
	long int l;
	if (decode(string, &l) > -1) {
		char buf[1024];
		struct tm tm1;
		strftime(buf, sizeof buf, dtm_fmt, localtime_r(&l, &tm1));
		printf("%s\n", buf);
	}
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

int decode(const char *buf, long int *val)
{
	int ret = 0;
	int all_len = strlen(allowed);
	int hash_size = 256;
	short int *hash = malloc(sizeof(short int) * hash_size);
	short int *hash_e = hash + hash_size;
	for (short int *p = hash; p != hash_e; ++p)
		*p = HASH_NULL;
	for (const char *c = allowed; *c != '\0';  ++c)
		hash[*c] = c - allowed;
	*val = 0;
	for (const char *c = buf; *c != '\0' && *c != '.'; ++c) {
		short int cc = hash[*c];
		if (cc == HASH_NULL) {
			fprintf(stderr, "error: %d\n", c - buf);
			ret = -1; goto END;
		}
		*val = *val * all_len + cc;
	}
END:	free(hash);
	return ret;
}

void encode(char *buf, size_t size, long int val)
{
	if (size <= 0) {
		fprintf(stderr, "error: no enough space.\n");
		return;
	}

	int all_len = strlen(allowed);

	char *p = buf + size - 1;

	*p = '\0';

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
		action_decode(argc-1, argv+1);
	}
	return 0;
}
