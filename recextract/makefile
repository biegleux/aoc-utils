CC=gcc
CFLAGS=-Os -s -Wall
TARGET=recextract

all: $(TARGET)

$(TARGET):
	$(CC) $(CFLAGS) -o $@ zlib-1.2.3\*.c recextract.c
clean:
	rm -rf *o $(TARGET)
