#include <errno.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>

struct stat_var {
	char c;
	const char *title;
	size_t offset;
};

struct stat_var stat_opts[] = {
	{ 'X', "read:          ", offsetof(struct stat, st_atim) },
	{ 'Y', "modification:  ", offsetof(struct stat, st_mtim) },
	{ 'Z', "change:        ", offsetof(struct stat, st_ctim) },
	{ 0 }
};

const char *allowed = "-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz";
const char *dtm_fmt_def = "%Y-%m-%d_%H-%M-%S"; // example: "%F %T"

void action_decode(int argc, char **argv);
int action_encode();
int decode(const char *buf, long int *val, char **endptr);
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
	const char *string = NULL, *tmp = NULL, *dtm_fmt = NULL, *encode_date = NULL, *stat_opt = NULL, *filename = NULL;
	for ( ; *argv != NULL; ) {
		tmp = *argv;
		if (*tmp == '+') {
			if (dtm_fmt == NULL) {
				dtm_fmt = tmp + 1; ++argv;
			}
			else {
				fprintf(stderr, "error: only one fmt string is allowed.\n");
				exit(1);
			}
		}
		else if (*tmp == '@') {
			if (tmp[1] == '@' && tmp[2] == '\0') {
				if (filename == NULL) {
					if (argv[1] == NULL) {
						fprintf(stderr, "error: filename is required after @@.\n");
						exit(1);
					}
					else if (argv[2] == NULL) {
						filename = argv[1]; ++argv;
					}
					else if (argv[3] == NULL) {
						stat_opt = argv[1];
						filename = argv[2]; argv += 2;
					}
					else {
						fprintf(stderr, "error: bad parameter '%s' after filename.\n",
							argv[3]);
						exit(1);
					}
				}
				else {
					fprintf(stderr, "error: only one filename is allowed.\n");
					exit(1);
				}
			}
			else {
				encode_date = tmp + 1; ++argv;
			}
		}
		else if (string == NULL) {
			string = tmp; ++argv;
		}
		else {
			fprintf(stderr, "error: only one time string is allowed.\n");
			exit(1);
		}
	}
	long int l;
	if (filename != NULL) {
		char stat_opt_c;
		if (stat_opt != NULL) {
			stat_opt_c = *stat_opt;
			if (stat_opt_c == '\0') {
				fprintf(stderr, "error: stat opt is empty.\n");
				exit(1);
			}
			if (stat_opt[1] != '\0') {
				fprintf(stderr, "error: bad stat opt '%s', stat opt must be one char.\n", stat_opt);
				exit(1);
			}
		}
		struct stat st;
		if (lstat(filename, &st) == -1) {
			fprintf(stderr, "error: Can't open %s. %s (%u).\n", filename, strerror(errno), errno);
			exit(1);
		}

		char buf_sec[6+1];
		char buf_nsec[5+1];

		if (stat_opt) {
			struct stat_var *stv_i;

			for (stv_i = stat_opts; stv_i->c && stv_i->c != stat_opt_c; ++stv_i) ;

			if (!stv_i->c) {
				fprintf(stderr, "error: bad stat opt '%s'.\n", stat_opt);
				exit(1);
			}

			struct timespec* stv_i_ts = (struct timespec*) ( ((char*)&st) + stv_i->offset );

			encode(buf_nsec, sizeof(buf_nsec), stv_i_ts->tv_nsec);
			encode(buf_sec, sizeof(buf_sec), stv_i_ts->tv_sec);

			printf("%s.%s\n", buf_sec, buf_nsec);
		}
		else {
			for (struct stat_var *stv_i = stat_opts; stv_i->c; ++stv_i) {
				struct timespec* stv_i_ts = (struct timespec*) ( ((char*)&st) + stv_i->offset );

				encode(buf_nsec, sizeof(buf_nsec), stv_i_ts->tv_nsec);
				encode(buf_sec, sizeof(buf_sec), stv_i_ts->tv_sec);

				char buf[1024];
				struct tm tm1;
				strftime(buf, sizeof buf, "%F %T", localtime_r(&stv_i_ts->tv_sec, &tm1));

				printf("%s%s.%s %s.%09d\n", stv_i->title, buf_sec, buf_nsec, buf, stv_i_ts->tv_nsec);
			}
		}
	}
	else if (encode_date == NULL) {
		if (string == NULL) {
			fprintf(stderr, "error: time string is absent.\n");
			exit(1);
		}
		if (dtm_fmt == NULL) {
			char *endptr;

			decode(string, &l, &endptr);

			if (string == endptr)
				return;

			char buf[1024];
			struct tm tm1;

			if (localtime_r(&l, &tm1) == NULL) {
				fprintf(stderr, "error: %s (%u).\n", strerror(errno), errno);
				return;
			}

			size_t n = strftime(buf, sizeof buf, dtm_fmt_def, &tm1);

			if (*endptr == '.') {
				++endptr;
				decode(endptr, &l, &endptr);
				snprintf(buf + n, sizeof(buf) - n, ".%09u\n", l);
			}
			else {
				buf[n] = '\n'; ++n;
				buf[n] = '\0';
			}

			fputs(buf, stdout);
		}
	}
	else {
		if (string != NULL) {
			fprintf(stderr, "error: bad parameter '%s'.\n", string);
			exit(1);
		}
		if (dtm_fmt != NULL) {
			fprintf(stderr, "error: format parameter is not needed if @ is specified.\n");
			exit(1);
		}

		char *ptr;

		l = strtol(encode_date, &ptr, 10);

		if (ptr == encode_date) {
			if (*ptr == '\0')
				fprintf(stderr, "error: decimal digits expected after '@' symbol.\n");
			else
				fprintf(stderr, "error: bad value of @ parameter (%s).\nerror: only decimal digits are allowed.\n",
						ptr);
			exit(1);
		}

		char buf_sec[6+1];

		encode(buf_sec, sizeof(buf_sec), l);

		printf("%s\n", buf_sec);
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

int decode(const char *buf, long int *val, char **endptr)
{
	int all_len = strlen(allowed);
	int hash_size = 256;
	short int *hash = malloc(sizeof(short int) * hash_size);
	short int *hash_e = hash + hash_size;
	for (short int *p = hash; p != hash_e; ++p)
		*p = HASH_NULL;
	for (const char *c = allowed; *c != '\0';  ++c)
		hash[*c] = c - allowed;
	*val = 0;
	const char *c;
	for (c = buf; *c != '\0'; ++c) {
		short int cc = hash[*c];
		if (cc == HASH_NULL)
			break;
		*val = *val * all_len + cc;
	}
	free(hash);
	if (endptr != NULL) *endptr = (char*) c;
	return 0;
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
		decode(buf, &j, NULL);
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
