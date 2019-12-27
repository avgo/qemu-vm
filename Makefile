
all: bin bin/date-timestamp-for-file

bin:
	mkdir -v bin

bin/date-timestamp-for-file: src/date-timestamp-for-file.c
	gcc -std=gnu99 -o bin/date-timestamp-for-file src/date-timestamp-for-file.c

clean:
	rm -vf bin/date-timestamp-for-file
